function [ua_grid_emu, ub_grid_emu, uc_grid_emu, gamma_grid_emulator, omega_grid_emulator, ...
    vp_xi, vp_eta, vn_xi, vn_eta, dx] = grid_emulator_frt(t, x)
%#codegen
% GRID_EMULATOR_FRT
% MATLAB Function copy of three_phase_voltage_with_frt_emulator/
% three_phase_voltage_source_with_frt_emulator: same mask parameters, same output bus.
% The Step, Rate Limiter, Constant, Sum and MATLAB Function blocks of the original are
% written here as functions of the time t. The eight LVRT state-space filters
% (Am, Bm, Cm) keep their continuous states: they are integrated by the Integrator
% block next to this function, which receives dx and returns x.
%
% INPUTS
%   t : simulation time [s], from the Clock block (the simulation must start at t = 0)
%   x : states of the eight LVRT filters, 8*size(Am,1) x 1, zero at t = 0.
%       Filter k uses x((k-1)*n+1 : k*n), n = size(Am,1):
%       1 vp_xi, 2 vp_eta, 3 vn_xi, 4 vn_eta  (sequence references [pu])
%       5, 6, 7 amplitudes of the phases U, V, W [pu], 8 phase shift [rad]
%
% PARAMETERS: the 23 mask parameters of the block (scope Parameter)
%
% OUTPUTS (elements of the bus grid_emulator_outputs, same order as the original)
%   ua_grid_emu, ub_grid_emu, uc_grid_emu : phase voltages [V]
%   gamma_grid_emulator : grid angle, wrapped to [-pi, pi) [rad]
%   omega_grid_emulator : grid angular frequency [rad/s]
%   vp_xi, vp_eta, vn_xi, vn_eta : filtered sequence voltages [V]
%   dx : derivative of x, to the Integrator
%
% VARIANTS (the Variant Source blocks of the original, same conditions)
%   enable_frt_1_m = 0, enable_frt_2_m = 0 : constant sequence references
%   enable_frt_2_m = 1 : dips on the sequence references (deep* parameters)
%   enable_frt_1_m = 1 : dips on the phase amplitudes (Amplitude_U/V/W) and phase
%                        shift of V and W; the sequence outputs follow the deep* profile
%   The two flags cannot be both 1 (two active variants in the original): the mask
%   initialization stops with an error.

n    = size(Am, 1);
kv   = nominal_voltage_m/sqrt(3/2);      % Gain blocks [V/pu]
vref = Vemu_ref_norm_m;
slew = Vemu_ref_norm_m/t_ramp_m;         % Rate Limiters: rising +slew, falling -slew [pu/s]
ton  = start_time_LVRT_m;
toff = end_time_LVRT_m;

frt_seq = (enable_frt_1_m || enable_frt_2_m);   % voltage_source: (enable_frt_1 || enable_frt_2) == 1
frt_abc = (enable_frt_1_m == 1);                % voltage_reference1: enable_frt_1 == 1

% phase_gen1: Constant -> Integrator (starts from 0) -> bounder
omega_grid_emulator = nominal_frequency_m*2*pi;
gamma_grid_emulator = -pi + mod(omega_grid_emulator*t + 3*pi, 2*pi);

% inputs of the eight filters
u = zeros(8, 1);
if frt_seq
    % voltage_source: Step at 0, start, end -> Rate Limiter -> Add (+ - +)
    dp_xi = vp_xi_pu_m*deepPOSxi_m;
    u(1) = rl_step(t, 0, vp_xi_pu_m, slew) - rl_step(t, ton, dp_xi, slew) ...
         + rl_step(t, toff, dp_xi, slew);
    u(2) = rl_step(t, 0, vp_eta_pu_m, slew) - rl_step(t, ton, deepPOSeta_m, slew) ...
         + rl_step(t, toff, deepPOSeta_m, slew);
    u(3) = rl_step(t, 0, vn_xi_pu_m, slew) - rl_step(t, ton, deepNEGxi_m, slew) ...
         + rl_step(t, toff, deepNEGxi_m, slew);
    u(4) = rl_step(t, 0, vn_eta_pu_m, slew) - rl_step(t, ton, deepNEGeta_m, slew) ...
         + rl_step(t, toff, deepNEGeta_m, slew);
else
    % voltage_source: Constant blocks
    u(1) = vp_xi_pu_m;
    u(2) = vp_eta_pu_m;
    u(3) = vn_xi_pu_m;
    u(4) = vn_eta_pu_m;
end
if frt_abc
    % voltage_source_with_frt: Step at 0, start, end -> Rate Limiter -> Add (+ - +) for
    % each phase; phase shift: Step at start - Step at end, without Rate Limiter
    du = vref*(1 - Amplitude_U_m);
    dv = vref*(1 - Amplitude_V_m);
    dw = vref*(1 - Amplitude_W_m);
    u(5) = rl_step(t, 0, vref, slew) - rl_step(t, ton, du, slew) + rl_step(t, toff, du, slew);
    u(6) = rl_step(t, 0, vref, slew) - rl_step(t, ton, dv, slew) + rl_step(t, toff, dv, slew);
    u(7) = rl_step(t, 0, vref, slew) - rl_step(t, ton, dw, slew) + rl_step(t, toff, dw, slew);
    u(8) = Phase_shift_m*step_at(t, ton) - Phase_shift_m*step_at(t, toff);
end

% ss_flt: dx/dt = Am*x + Bm*u, y = Cm*x (no D term, as in the original)
xc = x(:);
dx = zeros(8*n, 1);
y  = zeros(8, 1);
for k = 1:8
    idx = (k - 1)*n + (1:n);
    xk = xc(idx);
    dx(idx) = Am*xk + Bm*u(k);
    y(k) = Cm*xk;
end

% Gain nominal_voltage_m/sqrt(3/2)
vp_xi  = kv*y(1);
vp_eta = kv*y(2);
vn_xi  = kv*y(3);
vn_eta = kv*y(4);

if frt_abc
    % voltage_source_with_frt: Phase_a1, Phase_b1, Phase_c1, then Gain
    ua_grid_emu = kv*(y(5)*cos(gamma_grid_emulator));
    ub_grid_emu = kv*(y(6)*cos(gamma_grid_emulator - y(8) - 2*pi/3));
    uc_grid_emu = kv*(y(7)*cos(gamma_grid_emulator + y(8) - 4*pi/3));
else
    % voltage_reference1: xieta2alphabeta_pos + xieta2alphabeta_neg -> alphabeta2abc
    c = cos(gamma_grid_emulator);
    s = sin(gamma_grid_emulator);
    alpha = (vp_xi*c - vp_eta*s) + (vn_xi*c + vn_eta*s);
    beta  = (vp_xi*s + vp_eta*c) + (-vn_xi*s + vn_eta*c);
    ua_grid_emu = alpha;
    ub_grid_emu = -0.5*alpha + sqrt(3)/2*beta;
    uc_grid_emu = -0.5*alpha - sqrt(3)/2*beta;
end
end

function y = step_at(t, t_step)
% Step block: 0 before t_step, 1 from t_step on
y = 0;
if t >= t_step
    y = 1;
end
end

function y = rl_step(t, t_step, v, slew)
% Step block (0 -> v at t_step) followed by a continuous-time Rate Limiter with rising
% slew rate +slew and falling slew rate -slew. In continuous mode the Rate Limiter
% starts from its input (y(0) = u(0)), so a step at t = 0 passes without ramp; a later
% step becomes a ramp of slope slew that ends on v.
y = 0;
if t >= t_step
    if t_step <= 0 || ~(slew < Inf)
        y = v;
    else
        r = slew*(t - t_step);
        if r >= abs(v)
            y = v;
        elseif v >= 0
            y = r;
        else
            y = -r;
        end
    end
end
end
