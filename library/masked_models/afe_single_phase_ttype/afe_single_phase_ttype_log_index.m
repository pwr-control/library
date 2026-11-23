function idx = afe_single_phase_ttype_log_index()
%AFE_SINGLE_PHASE_TTYPE_LOG_INDEX  Indices of the ctrl_log output [32x1] of afe_single_phase_ttype/afe_single_phase_ttype_mod1.
%
%   idx = afe_single_phase_ttype_log_index()
%
%   Example, with ctrl_log logged as a timeseries "log_afe":
%       idx = afe_single_phase_ttype_log_index();
%       plot(log_afe.Time, log_afe.Data(:, [idx.i_d idx.i_d_ref]))
%
%   Every step: t_loc, ramp, trgo, m, enable. The others are updated at the control trigger and held in between.
%   Currents in pu of ibez, AC voltages in pu of ubez, DC voltages in pu of udc_nom (p.hw of the block).

    idx.t_loc        = 1;    % [s]   local time of the block
    idx.ramp         = 2;    %       carrier, triangle 0..1
    idx.trgo         = 3;    %       control trigger flag
    idx.corr         = 4;    %       correction of the local clock (alignment PI)
    idx.theta        = 5;    % [rad] angle of the PLL
    idx.theta_hat    = 6;    % [rad] angle of the double integrator observer, the angle of the control
    idx.omega_hat_pu = 7;    % [pu]  estimated pulsation in pu of omega_nom
    idx.u_ac         = 8;    % [pu]  acquired terminal voltage a - b (one control step behind, quantized)
    idx.i_s          = 9;    % [pu]  acquired converter current (line a, out of the bridge; with the optional noise)
    idx.udc          = 10;   % [pu]  acquired DC-link voltage
    idx.udc_p        = 11;   % [pu]  acquired upper bank voltage (dc+ to np)
    idx.udc_n        = 12;   % [pu]  acquired lower bank voltage (np to dc-)
    idx.u_xi         = 13;   % [pu]  grid vector in the PLL frame, in-phase component (pu of ug_nom)
    idx.u_eta        = 14;   % [pu]  grid vector in the PLL frame, quadrature component (the PLL error)
    idx.ubeta        = 15;   % [pu]  virtual quadrature component of the grid voltage (pu of ug_nom)
    idx.i_alpha      = 16;   % [pu]  fundamental of the current (first harmonic tracker)
    idx.i_beta       = 17;   % [pu]  quadrature of the fundamental of the current
    idx.i_d          = 18;   % [pu]  current in the dq frame of theta_hat, d (in phase with the terminal voltage)
    idx.i_q          = 19;   % [pu]  q
    idx.i_d_ref      = 20;   % [pu]  d current reference (mode 0: rate-limited p.ctrl.i_ref; mode 1: -output of the DC-link PI)
    idx.i_q_ref      = 21;   % [pu]  q current reference (p.ctrl.iq_ref)
    idx.m_d          = 22;   % [pu]  modulation index vector, d (after the DC-link feed-forward and the limiter)
    idx.m_q          = 23;   % [pu]  q
    idx.clip_i       = 24;   %       clip flag of the current PI
    idx.m            = 25;   %       modulation index of leg u (leg v gets -m), saturated in [m_low, m_up]
    idx.udc_ref      = 26;   % [pu]  filtered DC-link voltage reference (mode 1, else 0)
    idx.e_udc        = 27;   % [pu]  error of the DC-link loop (mode 1, else 0)
    idx.sat_udc      = 28;   %       saturation flag of the DC-link PI
    idx.enable       = 29;   %       gates enabled (from the first control step with t_master >= p.pwm.t_enable)
    idx.mode         = 30;   %       p.ctrl.mode
    idx.slave        = 31;   %       p.ctrl.slave
    idx.udc_f        = 32;   % [pu]  low-passed DC-link voltage of the loop (mode 1)
end
