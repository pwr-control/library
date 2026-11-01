%% test_ekf_im - check of the induction machine EKF (ekf_im_setup + ekf_im_step) without Simulink
%
% Simulates the 261 kW machine of inv_im (ABB M3BP 355MLB 6, 460 V, 60 Hz, behind the 230 uH
% output inductor) under a rotor-flux oriented speed control and runs the EKF on the simulated
% measurements:
%   0   - 0.7 s   magnetization at standstill (EKF speed and load torque on hold)
%   0.7 - 1.7 s   speed ramp 0 -> 0.5 pu, load torque 0.3 pu from 1.2 s
%   1.7 - 2.5 s   0.5 pu, load torque 0.8 pu from 2.0 s
%   2.5 - 3.0 s   speed ramp 0.5 -> 0.8 pu
% The plant is the continuous model of the filter with the same parameters, integrated with RK4 in
% four sub-steps, plus 1 A rms of white noise and the 12-bit quantization on the measured currents.
% The control is ideal (no dead time, no delay, voltage applied as computed) and uses the true flux
% angle and speed (ekf_in_the_loop = false, the filter only observes) or the estimated ones (true:
% sensorless). The command computed at step k is applied in [t_k, t_k+1] and the current is sampled
% at t_k without delay, so the filter takes the command of the previous step (n_delay_u = 1).
%
% Run from any folder with the library on the path (addpath(genpath('C:\github\library'))). Set
% ekf_in_the_loop or do_plot in the workspace before running to change the defaults. About 1 s in
% MATLAB.
%
% See also ekf_im_setup, ekf_im_step.

if ~exist('ekf_in_the_loop', 'var')
    ekf_in_the_loop = false;
end
if ~exist('do_plot', 'var')
    do_plot = true;
end

%% machine and filter
ts = 125e-6;                                % [s] control period (8 kHz)
l_series = 230e-6;                          % [H] inverter output inductor of inv_im
r_series = 157*0.05*l_series;               % [Ohm]
im = im_setup('ABB M3BP 355MLB 6 261kW', 261e3, 460, 411, 60, 1195, 6, 0.95, 0.88, 2e-3, ...
              460, 180, 60, 77, 470, 50, 5, 0.75);
ekf = ekf_im_setup(im, ts, l_series, r_series);
ekf.q_adc = 1049.835/2048;                  % [A] 12-bit acquisition on +-1050 A
t_mag = 0.7;                                % [s] magnetization before the speed control
ekf.n_hold = round(t_mag/ts);
ekf.n_delay_u = 1;
ekf.displayInfo();

% coefficients as a struct, as in the MATLAB Function block of the model
names = {'ts', 'omega_b', 'sigma_n', 'rs_n', 'lm_n', 'lr_n', 'alpha_n', 'kr', 'tau_m', ...
         'q_diag', 'r_diag', 'p0_diag', 'cov_order'};
e = struct();
for n = 1:numel(names)
    e.(names{n}) = ekf.(names{n});
end

% plant: same model, load torque as an input, true states [i_alpha i_beta psi_alpha psi_beta omega]
wb = e.omega_b; s = e.sigma_n; a = e.alpha_n; lm = e.lm_n; kr = e.kr; tm = e.tau_m;
b = lm/(s*e.lr_n);
g = e.rs_n/s + b*a*lm;
plant = @(z, u, tl) [wb*(-g*z(1) + b*a*z(3) + b*z(5)*z(4) + u(1)/s);
                     wb*(-g*z(2) + b*a*z(4) - b*z(5)*z(3) + u(2)/s);
                     wb*(a*lm*z(1) - a*z(3) - z(5)*z(4));
                     wb*(a*lm*z(2) - a*z(4) + z(5)*z(3));
                     (kr*(z(3)*z(2) - z(4)*z(1)) - tl)/tm];

%% control (rotor-flux oriented, pu)
i_mag = 180*sqrt(2)/ekf.ibez;               % no-load current of the machine [pu]
psi_ref = lm*i_mag;                         % rated rotor flux [pu]
i_max = 1.5;                                % [pu] current limit
k_psi = 6;                                  % flux: feed-forward psi_ref/Lm plus proportional
kp_w = 4.54; ki_w = 21.4;                   % speed PI, torque output (3 Hz with tau_m = 0.24 s)
kp_c = 2*pi*300; ki_c = kp_c*2*pi*30;       % current: 300 Hz loop with model decoupling [1/s]
w_ref_fun = @(t) 0.5*min(max(t - t_mag, 0), 1) + 0.6*min(max(t - 2.5, 0), 0.5);
tl_fun = @(t) 0.3*(t >= 1.2) + 0.5*(t >= 2.0);

%% simulation
t_end = 3.0;
N = round(t_end/ts);
nsub = 4;
h = ts/nsub;
if exist('rng', 'file') || exist('rng', 'builtin')
    rng(1);
else
    randn('seed', 1); %#ok<RAND>
end
noise = ekf.sigma_i/ekf.ibez;               % [pu rms]
qa = ekf.q_adc/ekf.ibez;                    % [pu] quantization step

z = zeros(5, 1);                            % true state
x = ekf.x0;                                 % estimate
P = diag(ekf.p0_diag);
u_hist = zeros(2, 4);                       % commands of the last steps, newest first
w_int = 0;
c_int = [0; 0];
log_t = (0:N-1)'*ts;
log_z = zeros(N, 5);
log_x = zeros(N, 6);
log_u = zeros(N, 2);
log_y = zeros(N, 2);
log_tl = zeros(N, 1);
log_hold = false(N, 1);

for k = 1:N
    t = log_t(k);
    tl = tl_fun(t);

    % current sampled at t_k
    y = z(1:2) + noise*randn(2, 1);
    y = qa*round(y/qa);

    % filter: the voltage of [t_k-1, t_k] is the command computed n_delay_u steps before
    standstill = (k - 1) < ekf.n_hold;
    u_ekf = u_hist(:, ekf.n_delay_u);
    [x, P] = ekf_im_step(x, P, u_ekf, y, standstill, e);

    % control
    if ekf_in_the_loop
        pa = x(3); pb = x(4); w = x(5);
    else
        pa = z(3); pb = z(4); w = z(5);
    end
    psi = hypot(pa, pb);
    if psi > 1e-6
        ca = pa/psi; sa = pb/psi;
    else
        ca = 1; sa = 0;
    end
    i_d = ca*y(1) + sa*y(2);
    i_q = -sa*y(1) + ca*y(2);
    id_ref = min(max(psi_ref/lm + k_psi*(psi_ref - psi), 0), i_max);
    if t >= t_mag
        w_err = w_ref_fun(t) - w;
        t_ref = kp_w*w_err + w_int;
        w_int = min(max(w_int + ki_w*ts*w_err, -2), 2);
    else
        t_ref = 0;
    end
    iq_max = sqrt(i_max^2 - id_ref^2);
    iq_ref = min(max(t_ref/(kr*max(psi, 0.1)), -iq_max), iq_max);
    w_s = w + a*lm*i_q/max(psi, 0.1);       % stator pulsation [pu]
    err = [id_ref - i_d; iq_ref - i_q];
    c_int = c_int + ki_c*ts*err;
    v = (kp_c*err + c_int)/wb;
    u_d = s*(g*i_d - b*a*psi - w_s*i_q + v(1));
    u_q = s*(g*i_q + b*w*psi + w_s*i_d + v(2));
    u = [ca*u_d - sa*u_q; sa*u_d + ca*u_q];
    u_hist = [u, u_hist(:, 1:end-1)];

    % log at t_k
    log_z(k, :) = z';
    log_x(k, :) = x';
    log_u(k, :) = u_ekf';
    log_y(k, :) = y';
    log_tl(k) = tl;
    log_hold(k) = standstill;

    % plant from t_k to t_k+1 with the command held (RK4)
    for j = 1:nsub
        k1 = plant(z, u, tl);
        k2 = plant(z + h/2*k1, u, tl);
        k3 = plant(z + h/2*k2, u, tl);
        k4 = plant(z + h*k3, u, tl);
        z = z + h/6*(k1 + 2*k2 + 2*k3 + k4);
    end
end

%% results
theta_true = atan2(log_z(:, 4), log_z(:, 3));
theta_hat = atan2(log_x(:, 4), log_x(:, 3));
e_theta = mod(theta_hat - theta_true + pi, 2*pi) - pi;
windows = [0.3 0.7; 0.7 1.2; 1.2 1.7; 1.7 2.0; 2.0 2.5; 2.5 3.0];
fprintf('\nIM EKF test (EKF in the loop: %d)\n', ekf_in_the_loop);
fprintf('  window [s]    max|angle err| [deg]   max|speed err| [pu]   T_load true/est at the end [pu]\n');
for n = 1:size(windows, 1)
    idx = log_t >= windows(n, 1) & log_t < windows(n, 2);
    last = find(idx, 1, 'last');
    fprintf('  %.1f - %.1f      %8.3f               %9.5f              %.3f / %.3f\n', windows(n, 1), ...
            windows(n, 2), max(abs(e_theta(idx)))*180/pi, max(abs(log_x(idx, 5) - log_z(idx, 5))), ...
            log_tl(last), log_x(last, 6));
end

if do_plot
    figure('Name', 'test_ekf_im');
    subplot(4, 1, 1);
    plot(log_t, log_z(:, 5), log_t, log_x(:, 5), '--'); grid on;
    ylabel('\omega [pu]'); legend('true', 'EKF', 'Location', 'northwest');
    title(sprintf('IM EKF test, EKF in the loop: %d', ekf_in_the_loop));
    subplot(4, 1, 2);
    plot(log_t, e_theta*180/pi); grid on; ylabel('flux angle error [deg]');
    subplot(4, 1, 3);
    plot(log_t, hypot(log_z(:, 3), log_z(:, 4)), log_t, hypot(log_x(:, 3), log_x(:, 4)), '--'); grid on;
    ylabel('|\psi_r| [pu]');
    subplot(4, 1, 4);
    plot(log_t, log_tl, log_t, log_x(:, 6), '--'); grid on;
    ylabel('T_{load} [pu]'); xlabel('t [s]');
end
