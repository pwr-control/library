function [x, P] = ekf_im_step(x, P, u, y, standstill, e) %#codegen
%EKF_IM_STEP one step of the extended Kalman filter of the induction machine
%
%   [x, P] = ekf_im_step(x, P, u, y, standstill, e)
%
% Prediction from the previous sample to the current one with the voltage applied in between, then
% correction with the current measured at the current sample. Called once per control period by the
% MATLAB Function block of the model (in inv_im: block ekf of im_control), or by a script.
%
%   x     6x1 estimate at the previous sample, [i_alpha; i_beta; psi_alpha; psi_beta; omega; T_load]
%         in pu
%   P     6x6 covariance of x (pu^2)
%   u     2x1 stator voltage [u_alpha; u_beta] in pu of ubez, applied between the previous and the
%         current sample (the caller takes care of the delays of the drive, see n_delay_u in
%         ekf_im_setup)
%   y     2x1 stator current [i_alpha; i_beta] in pu of ibez, measured at the current sample
%   standstill  true while the shaft is known to be at standstill (magnetization before the speed
%               control starts): speed and load torque are held at zero and not updated
%   e     coefficients: an ekf_im_setup object in a script, a struct with the same field names in a
%         MATLAB Function block (objects cannot be block parameters). Fields used: ts, omega_b,
%         sigma_n, rs_n, lm_n, lr_n, alpha_n, kr, tau_m, q_diag (6x1), r_diag (2x1), p0_diag (6x1),
%         cov_order
%
%   x, P  estimate and covariance at the current sample, after the correction
%
% Model (time in seconds, quantities in pu, see ekf_im_setup):
%   di_alpha/dt   = wb*(-g*i_alpha + b*alpha*psi_alpha + b*omega*psi_beta + u_alpha/sigma)
%   di_beta/dt    = wb*(-g*i_beta  + b*alpha*psi_beta  - b*omega*psi_alpha + u_beta/sigma)
%   dpsi_alpha/dt = wb*(alpha*Lm*i_alpha - alpha*psi_alpha - omega*psi_beta)
%   dpsi_beta/dt  = wb*(alpha*Lm*i_beta  - alpha*psi_beta  + omega*psi_alpha)
%   domega/dt     = (kr*(psi_alpha*i_beta - psi_beta*i_alpha) - T_load)/tau_m
%   dT_load/dt    = 0
%
% Algorithm:
%   1. standstill: speed and load torque set to zero together with their rows and columns of P, no
%      process noise on them. On the first sample after the hold the two variances restart from p0.
%   2. prediction with the second-order Taylor expansion of the continuous model,
%        x- = x + ts*f(x,u) + ts^2/2*A(x)*f(x,u),   A = df/dx (Jacobian),
%      instead of forward Euler x + ts*f: with Euler the rotor-flux mode of the discrete model
%      leaves the unit circle above about 0.28 pu of speed at 8 kHz and the flux angle is biased.
%   3. covariance P- = F*P*F' + Q with F = I + ts*A (cov_order 1) or I + ts*A + (ts*A)^2/2
%      (cov_order 2). F linearizes the prediction around the previous estimate.
%   4. correction with y = C*x + v, C = [I2 0]: gain K = P-*C'/(C*P-*C' + R), x = x- + K*(y - C*x-),
%      Joseph form P = (I - K*C)*P-*(I - K*C)' + K*R*K', which stays symmetric and positive.
%
% See also ekf_im_setup.

ts = e.ts;
wb = e.omega_b;
s  = e.sigma_n;
a  = e.alpha_n;
lm = e.lm_n;
kr = e.kr;
tm = e.tau_m;
b  = lm/(s*e.lr_n);                 % beta  = Lm/(sigma Lr)
g  = e.rs_n/s + b*a*lm;             % gamma = Rs/sigma + beta alpha Lm
q  = e.q_diag(:);
r  = e.r_diag(:);
u  = u(:);
y  = y(:);

% ---- 1. hold of the mechanical states during the magnetization
% At standstill the speed is not observable (zero stator frequency): without the hold the filter
% would let omega and T_load drift on the noise before the speed control starts.
if standstill
    x(5:6) = 0;
    P(5:6, :) = 0;
    P(:, 5:6) = 0;
    q(5:6) = 0;
elseif P(5, 5) == 0 && P(6, 6) == 0
    % first sample after the hold: speed and load torque become estimated states again
    P(5, 5) = e.p0_diag(5);
    P(6, 6) = e.p0_diag(6);
end

ia = x(1);
ib = x(2);
pa = x(3);
pb = x(4);
om = x(5);
tl = x(6);

% ---- continuous model f(x, u) [pu/s]
f = [wb*(-g*ia + b*a*pa + b*om*pb + u(1)/s);
     wb*(-g*ib + b*a*pb - b*om*pa + u(2)/s);
     wb*(a*lm*ia - a*pa - om*pb);
     wb*(a*lm*ib - a*pb + om*pa);
     (kr*(pa*ib - pb*ia) - tl)/tm;
     0];

% ---- Jacobian A = df/dx [1/s], evaluated at the previous estimate
A = [wb*(-g),    0,          wb*b*a,     wb*b*om,    wb*b*pb,   0;
     0,          wb*(-g),    -wb*b*om,   wb*b*a,     -wb*b*pa,  0;
     wb*a*lm,    0,          -wb*a,      -wb*om,     -wb*pb,    0;
     0,          wb*a*lm,    wb*om,      -wb*a,      wb*pa,     0;
     -kr*pb/tm,  kr*pa/tm,   kr*ib/tm,   -kr*ia/tm,  0,         -1/tm;
     0,          0,          0,          0,          0,         0];

% ---- 2. state prediction, second-order Taylor
Af = A*f;
xp = x + ts*f + ts^2/2*Af;

% ---- 3. covariance prediction
F = eye(6) + ts*A;
if e.cov_order >= 2
    F = F + (ts*A)*(ts*A)/2;
end
Pp = F*P*F' + diag(q);

% ---- 4. correction with the measured current (C = [I2 0])
S = Pp(1:2, 1:2) + diag(r);         % covariance of the innovation
K = Pp(:, 1:2)/S;                   % Kalman gain, 6x2
x = xp + K*(y - xp(1:2));
IKC = eye(6);
IKC(:, 1:2) = IKC(:, 1:2) - K;      % I - K*C
P = IKC*Pp*IKC' + K*diag(r)*K';     % Joseph form
P = (P + P')/2;                     % remove the rounding asymmetry

% during the hold the corrected speed and load torque are discarded as well, so that the outputs
% read zero speed and the first sample after the hold finds their variances at zero
if standstill
    x(5:6) = 0;
    P(5:6, :) = 0;
    P(:, 5:6) = 0;
end
end
