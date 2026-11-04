function p = afe_uvw_ctrl_param_example(ts, f_nom)
%AFE_UVW_CTRL_PARAM_EXAMPLE  Example parameter struct p of the afe_uvw_ctrl library blocks.
%
%   p = afe_uvw_ctrl_param_example            control period 125 us (4 kHz PWM, double update), 50 Hz grid
%   p = afe_uvw_ctrl_param_example(ts, f_nom) given control period [s] and grid frequency [Hz]
%
%   One struct for the five blocks of afe_uvw_ctrl.slx (grid_voltage_sequences,
%   grid_current_sequences_q_ctrl, frt_vde4110, current_ctrl_uvw, islanding_detector): the common
%   fields at the top level, one sub-struct per block. The numbers are those of the model
%   afe_uvw_three_phase of pwr-control/modelization-and-control (init_model.m, library class
%   ctrl_afe_setup, frt_settings, setup_global_filters). Copy this file next to your model, change the
%   numbers, keep the field names. All blocks read the same struct: give it to every mask (e.g.
%   param.afe.uvw = afe_uvw_ctrl_param_example(param.glb_time.ts_afe, param.grid.fgrid)).
%
%   See also grid_voltage_sequences, grid_current_sequences_q_ctrl, frt_vde4110, current_ctrl_uvw,
%   islanding_detector.

    if nargin < 1 || isempty(ts)
        ts = 125e-6;                        % [s] control period: 1/(2*fpwm) with double update
    end
    if nargin < 2 || isempty(f_nom)
        f_nom = 50;                         % [Hz]
    end

    % ---------------------------------------------------------------- common
    p.ts          = ts;                     % [s] control period: the integration step of all blocks.
                                            % The blocks inherit their sample time: run them inside a
                                            % triggered or discrete subsystem clocked at ts (as the
                                            % control of the model), or in a fixed-step discrete
                                            % model with step ts (the test bench)
    p.omega_nom   = 2*pi*f_nom;             % [rad/s] nominal grid pulsation (base of omega_pu)

    % ---------------------------------------------------------------- grid_voltage_sequences
    p.vseq.avg_order    = 2;        % averaging window = grid period / avg_order (2: half period, the
                                    % 100 Hz ripple of the other sequence is removed; 1: full period)
    p.vseq.omega_pu_min = 0.1;      % [pu] limits of the measured pulsation used for the window
    p.vseq.omega_pu_max = 2;
    p.vseq.t_enable     = 0.025;    % [s] averages are zero before this time (dmavg_filter_enable_time)

    % ---------------------------------------------------------------- grid_current_sequences_q_ctrl
    p.iseq.avg_order    = 2;
    p.iseq.omega_pu_min = 0.1;
    p.iseq.omega_pu_max = 2;
    p.iseq.t_enable     = 0.025;
    p.iseq.kp_pos       = 0.25;     % PI of the positive-sequence eta grid current (kp_rc_pos_grid)
    p.iseq.ki_pos       = 35;       % [1/s] (ki_rc_pos_grid)
    p.iseq.kp_neg       = 0.25;     % PI of the negative-sequence xi and eta grid currents (kp_rc_neg_grid)
    p.iseq.ki_neg       = 35;       % [1/s] (ki_rc_neg_grid)
    p.iseq.lim_pos_eta  = 1.0;      % [pu] limit of the stack current references (ieta_pos_ref_lim)
    p.iseq.lim_neg_xi   = 1.0;      % [pu] (the model uses ieta_pos_ref_lim here too)
    p.iseq.lim_neg_eta  = 0.5;      % [pu] (ieta_neg_ref_lim)
    p.iseq.err_sign     = -1;       % error = err_sign*(reference - measured): -1 when the grid current
                                    % is measured towards the converter (the model), +1 otherwise

    % ---------------------------------------------------------------- frt_vde4110
    % voltage-rate observers (vr_obs of ctrl_afe_setup): poles of the discrete double-integrator
    % observer at exp(obs_poles*ts); obs_kx, obs_kv are the gains the block reads
    p.frt.obs_poles   = [-0.1 -0.4]*p.omega_nom;    % [rad/s]
    [p.frt.obs_kx, p.frt.obs_kv] = double_integrator_observer_gains(p.frt.obs_poles, ts);
    p.frt.t_obs_release = 0.025;    % [s] observers held at zero before this time (time_release)
    % detection thresholds (LVRT_detector constants)
    p.frt.v_pos_low     = 0.85;     % [pu] positive sequence below this ... (LVRT_VPOS_TH_LOW)
    p.frt.v_pos_high    = 1.15;     % [pu] ... or above this is a fault (LVRT_VPOS_TH_HIGH)
    p.frt.v_hyst        = 0.1;      % [pu] band narrowing to leave the fault (LVRT_SEQ_DETECTION_HYST)
    p.frt.v_neg_max     = 0.1;      % [pu] negative sequence above this is a fault (LVRT_VNEG_TH)
    p.frt.v_pos_dot_max = 2.0;      % [pu/s] the voltage must also change faster than this (LVRT_VPOS_DOT_TH)
    p.frt.v_neg_dot_max = 2.0;      % [pu/s] (LVRT_VNEG_DOT_TH)
    p.frt.t_rearm       = 0.125;    % [s] idle time needed before a new detection (1000 samples of 125 us)
    p.frt.t_hold_max    = 7.625;    % [s] fault longer than this -> EXCEEDED (61000 samples of 125 us)
    % power limitation during the fault
    p.frt.pwrlim_v_pos  = 0.8;      % [pu] limit the active power when v_pos < this ... (LVRT_VPOS_PWRLIM_TH)
    p.frt.pwrlim_v_neg  = 0.1;      % [pu] ... or v_neg > this (LVRT_VNEG_PWRLIM_TH)
    p.frt.pwrlim_hyst   = 0.1;      % [pu] release when v_pos > pwrlim_v_pos + hyst and ...
    p.frt.pwrlim_v_neg_release = 0.7;   % [pu] ... v_neg < this (the model: LVRT_VPOS_PWRLIM_TH - hyst;
                                    % a tighter release would be e.g. 0.05)
    % reduced dynamic grid support (the model keeps it off)
    p.frt.reddyn_enabled = 0;
    p.frt.reddyn_v_pos   = 0.7;     % [pu] (LVRT_VPOS_RED_DYN_TH)
    p.frt.reddyn_v_neg   = 0.2;     % [pu] (LVRT_VNEG_RED_DYN_TH)
    % reactive current references
    p.frt.k_frt_ref      = 2;       % [pu/pu] reactive current per voltage change (frt_settings.k_frt_ref)
    p.frt.t_avg_prefault = 0.5;     % [s] window of the pre-fault voltage averages (avg_flt_500ms)
    p.frt.t_avg_start    = 0.05;    % [s] the pre-fault averages start here (after the start-up of the
                                    % sequence averages: t_enable + one grid period)
    p.frt.lim_pos_eta    = 1.0;     % [pu] limits of the grid current references (i_grid_pos_eta_lim)
    p.frt.lim_neg_xi     = 0.5;     % [pu] (i_grid_neg_xi_lim)
    p.frt.lim_neg_eta    = 0.5;     % [pu] (i_grid_neg_eta_lim)
    p.frt.lim_pos_eta_red = 0.1;    % [pu] the same with reduced dynamic support (i_grid_*_red_lim)
    p.frt.lim_neg_xi_red  = 0.1;
    p.frt.lim_neg_eta_red = 0.1;
    p.frt.f_lpf_ref      = 161;     % [Hz] low pass of the references (g0_161Hz = 2*pi*161*ts)

    % ---------------------------------------------------------------- current_ctrl_uvw
    p.ictrl.kp        = 0.6;        % resonant PI: proportional gain (res_pi.kp_rpi, LVRT setting of init_model)
    p.ictrl.ki        = 35;         % [1/s] resonant gain (res_pi.ki_rpi)
    p.ictrl.delta_res = 0.005;      % damping of the resonator (0 = ideal resonator). The model's class has
                                    % 0.015 for its forward Euler resonator, whose poles are outside the unit
                                    % circle (gain 10.8 at w instead of 3.7); the block integrates the
                                    % resonator with forward-backward Euler (poles inside the circle), and
                                    % 0.005 gives it the same gain 10.8 at w: same loop as the model
    p.ictrl.omega_res = p.omega_nom;    % [rad/s] resonance pulsation
    p.ictrl.mag_lim   = 1;          % [pu] length of the alpha/beta output vector above which it is scaled
    p.ictrl.mag_scale_max = 10;     % largest scaling factor
    p.ictrl.out_delay = 1;          % 1: alpha/beta output one step late (as the model's Unit Delays), 0: no delay
    p.ictrl.kp_z      = 0.5;        % zero-sequence current PI (kp_is_z)
    p.ictrl.ki_z      = 18;         % [1/s] (ki_is_z)
    p.ictrl.u_z_lim   = 1;          % [pu] limit of u_gamma
    p.ictrl.iz_ref    = 0;          % [pu] zero-sequence current reference

    % ---------------------------------------------------------------- islanding_detector
    p.island.h_avg_order  = 1;      % harmonic averaging window = grid period / h_avg_order
    p.island.omega_pu_min = 0.5;    % [pu] limits of the measured pulsation used for the window
    p.island.omega_pu_max = 1.5;
    p.island.t_enable     = 0.1;    % [s] no detection before this time (start-up of the measurements)
    p.island.tau_f        = 0.02;   % [s] low pass of the frequency
    p.island.obs_poles    = [-20 -80];   % [rad/s] poles of the ROCOF observer (continuous time)
    [p.island.obs_kx, p.island.obs_kv] = double_integrator_observer_gains(p.island.obs_poles, ts);
    p.island.u_valid      = 0.5;    % [pu] frequency and harmonic criteria only above this voltage
    % thresholds and delays as the network protection of VDE-AR-N 4105 / 4110 (U< 0.8 Un 2.7 s, U>> 1.15 Un
    % 0.1 s, f< 47.5 Hz 0.1 s, f> 51.5 Hz 0.1 s); the slow under-voltage stage lets the converter ride
    % through a grid fault (frt_vde4110) without an islanding trip
    p.island.u_min        = 0.8;    % [pu] under-voltage ...
    p.island.t_trip_u_min = 2.7;    % [s] ... for this time
    p.island.u_max        = 1.15;   % [pu] over-voltage ...
    p.island.t_trip_u_max = 0.1;    % [s] ... for this time
    p.island.f_min        = 47.5/f_nom;     % [pu] under-frequency ...
    p.island.f_max        = 51.5/f_nom;     % [pu] over-frequency ...
    p.island.t_trip_f     = 0.1;    % [s] ... for this time
    p.island.rocof_max    = 2.5;    % [Hz/s] rate of change of frequency ...
    p.island.t_trip_rocof = 0.1;    % [s] ... for this time
    p.island.h_max        = 0.1;    % [pu/pu] sqrt(u5^2 + u7^2)/u1 above this ... (EN 50160 allows up to 6 %
                                    % 5th and 5 % 7th harmonic on the grid: set it above the background)
    p.island.t_trip_h     = 0.1;    % [s] ... for this time
    p.island.latch        = 1;      % 1: the output stays 1 until enable goes to 0
end


function [kx, kv] = double_integrator_observer_gains(poles, ts)
%DOUBLE_INTEGRATOR_OBSERVER_GAINS  Gains of the discrete observer of a double integrator.
%   Plant x' = v, v' = 0 sampled with ts: A = [1 ts; 0 1], C = [1 0]. The observer
%       x+ = x + ts*(v + kx*(u - x)),  v+ = v + ts*kv*(u - x)
%   has the gain L = [kx*ts; kv*ts] and the poles of A - L*C are placed at z = exp(poles*ts):
%   characteristic polynomial z^2 - (2 - l1)*z + (1 - l1 + ts*l2), hence l1 = 2 - (z1 + z2) and
%   l2 = (z1*z2 - 1 + l1)/ts (the same result as acker in ctrl_afe_setup).
    z = exp(poles*ts);
    l1 = 2 - (z(1) + z(2));
    l2 = (z(1)*z(2) - 1 + l1)/ts;
    kx = l1/ts;
    kv = l2/ts;
end
