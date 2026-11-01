function [ua_grid_emu, ub_grid_emu, uc_grid_emu, gamma_grid_emulator, omega_grid_emulator] = grid_emulator(t)
%#codegen
% GRID_EMULATOR
% MATLAB Function copy of three_phase_voltage_emulator/three_phase_voltage_source_emulator:
% same mask parameters, same output bus. The original integrates five continuous states
% (the grid angle and four first-order LVRT filters fed by constants). Their solution is
% known in closed form, so here it is written as a function of the time t and the block
% has no states.
%
% INPUT
%   t : simulation time [s], from the Clock block (the simulation must start at t = 0,
%       where the states of the original start from zero)
%
% PARAMETERS (mask parameters of the block, scope Parameter)
%   freq      : nominal frequency [Hz]
%   ugrid_nom : nominal line-to-line rms voltage [V]
%   vp_xi_pu, vp_eta_pu, vn_xi_pu, vn_eta_pu : positive / negative sequence references [pu]
%   fcut_lvrt : cut-off frequency of the first-order LVRT filter [Hz]
%
% OUTPUTS (elements of the bus grid_emulator_outputs, same order as the original)
%   ua_grid_emu, ub_grid_emu, uc_grid_emu : phase voltages [V]
%   gamma_grid_emulator : grid angle, wrapped to [-pi, pi) [rad]
%   omega_grid_emulator : grid angular frequency [rad/s]

% phase_gen: Constant omega_grid_emulator_nom -> Integrator (starts from 0) -> bounder
omega_grid_emulator = freq*2*pi;
gamma_grid_emulator = -pi + mod(omega_grid_emulator*t + 3*pi, 2*pi);

% sequences_voltage_source: Constant -> LVRT_ss_flt -> Gain ugrid_phase.
% LVRT_ss_flt is 1/(s/(2*pi*fcut_lvrt) + 1) with zero initial state: with a constant
% input u applied from t = 0 its output is (1 - exp(-2*pi*fcut_lvrt*t))*u.
k_flt = 0;
if t > 0
    k_flt = 1 - exp(-2*pi*fcut_lvrt*t);
end
ugrid_phase = ugrid_nom/sqrt(3/2);
vp_xi  = ugrid_phase*(k_flt*vp_xi_pu);
vp_eta = ugrid_phase*(k_flt*vp_eta_pu);
vn_xi  = ugrid_phase*(k_flt*vn_xi_pu);
vn_eta = ugrid_phase*(k_flt*vn_eta_pu);

% voltage_reference: xieta2alphabeta_pos + xieta2alphabeta_neg -> alphabeta2abc
c = cos(gamma_grid_emulator);
s = sin(gamma_grid_emulator);
alpha = (vp_xi*c - vp_eta*s) + (vn_xi*c + vn_eta*s);
beta  = (vp_xi*s + vp_eta*c) + (-vn_xi*s + vn_eta*c);

ua_grid_emu = alpha;
ub_grid_emu = -0.5*alpha + sqrt(3)/2*beta;
uc_grid_emu = -0.5*alpha - sqrt(3)/2*beta;
end
