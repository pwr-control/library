%% test_semiconductors_bridges_param - parameters of test_semiconductors_bridges.slx
% Creates the struct tb used by the test bench of library/masked_models/semiconductors_bridges.
% All 18 bridges share the same dc voltage, modulation, load and solver settings; the device
% data are the mask defaults of the three families (ideal switch, Infineon FF450R17ME4 for the
% IGBT cells, Wolfspeed CAB450M12XM3 for the MOSFET cells).
%
% Run test_semiconductors_bridges_run.m to simulate and check the model.

% --- modulation and timing ------------------------------------------------------------------
tb.fpwm       = 10e3;      % [Hz]  PWM carrier frequency (all modulators)
tb.dead_time  = 1e-6;      % [s]   dead time (all modulators)
tb.tc         = 1e-6;      % [s]   modulator sampling time and local solver step of every bridge
tb.nonlin_iter = 3;        % [-]   fixed-cost nonlinear iterations of the local solvers
tb.gate_on    = 15;        % [V]   gate command when on  (ideal switch Vth and MOSFET G_th sit in between)
tb.gate_off   = -10;       % [V]   gate command when off
tb.f_out      = 50;        % [Hz]  fundamental frequency of the modulation
tb.m_amp      = 0.8;       % [-]   modulation index: duty = 0.5 + 0.5*m_amp*sin for the duty-cycle
                           %       modulators, m = m_amp*sin for the [-1, 1] modulators
tb.t_stop     = 0.06;      % [s]   three fundamental periods; the check uses the last one
tb.ts_log     = 2e-6;      % [s]   sample time of the To Workspace blocks

% --- dc link and load -----------------------------------------------------------------------
tb.Vdc    = 800;           % [V]   total dc voltage; split in two Vdc/2 sources for the half bridges and the T-type bridges
tb.load.R = 2;             % [Ohm] series R-L load (per phase for the three-phase bridges, star connected)
tb.load.L = 2e-3;          % [H]

% --- ideal switch bridges (mask: Rds_on, Vdon_diode, Rdon_diode, Csnubber, Rsnubber, Vth) -----
tb.ideal.Rds_on     = 1.85e-3;   % [Ohm]
tb.ideal.Vdon_diode = 0.35;      % [V]
tb.ideal.Rdon_diode = 1.85e-3;   % [Ohm]
tb.ideal.Csnubber   = 6e-9;      % [F]
tb.ideal.Rsnubber   = 3e3;       % [Ohm]
tb.ideal.Vth        = 7.5;       % [-]   between gate_off and gate_on

% --- IGBT bridges: igbt_simple_2th, Infineon FF450R17ME4 at 125 degC -------------------------
% (library/setup_files/semiconductor_devices_data/devices_source_dataname/infineon_FF450R17ME4.m)
tb.igbt.vce_sat        = 0.96;   % [V]    knee of the output characteristic
tb.igbt.rce_on         = 3.05;   % [mOhm] slope
tb.igbt.v_gamma        = 0.90;   % [V]    diode knee
tb.igbt.rd_on          = 2.15;   % [mOhm] diode slope
tb.igbt.Gce_off        = 1e-6;   % [1/Ohm]
tb.igbt.Vth_gate       = 5.8;    % [V]
tb.igbt.Vth_gate_hyst  = 0.85;   % [V]
tb.igbt.Eon            = 135;    % [mJ]   at 450 A, 900 V
tb.igbt.Eoff           = 155;    % [mJ]
tb.igbt.Err            = 110;    % [mJ]
tb.igbt.Ic_ref         = 450;    % [A]
tb.igbt.Vdc_ref        = 900;    % [V]
tb.igbt.Vblock_Errf    = 50;     % [V]
tb.igbt.time_constant_edge  = 1;    % [us]
tb.igbt.time_constant_ploss = 200;  % [us]  2 x Tsw
tb.igbt.Csnubber       = 12e-12; % [F]    numerical snubber
tb.igbt.Rsnubber       = 2200;   % [Ohm]
tb.igbt.rth_switch_JH  = 0.093;  % [K/W]  RthJC max + RthCH typ + 4 mK/W TIM
tb.igbt.rth_switch_HA  = 0.05;   % [K/W]  heatsink to ambient, per die
tb.igbt.rth_diode_JH   = 0.152;  % [K/W]
tb.igbt.rth_diode_HA   = 0.05;   % [K/W]
tb.igbt.JunctionTermalMass = 0.81; % [J/K]
tb.igbt.Tambient       = 40;     % [degC]
tb.igbt.mass_heatsink  = 1;      % [kg]   per die
tb.igbt.specific_heat  = 900;    % [J/(K kg)] aluminium

% --- MOSFET bridges: mos_simple_2th, Wolfspeed CAB450M12XM3 ---------------------------------
% (library/setup_files/semiconductor_devices_data/devices_source_dataname/wolfspeed_CAB450M12XM3.m)
tb.mos.rds_on    = 2.6;      % [mOhm] at Tj_ref
tb.mos.alpha_R   = 0;        % [1/K]  0 = no electrothermal feedback (use 0.005..0.008 for SiC)
tb.mos.Tj_ref    = 125;      % [degC]
tb.mos.Roff      = 1e7;      % [Ohm]
tb.mos.v_gamma   = 4.5;      % [V]    body diode knee
tb.mos.rd_on     = 0.185;    % [mOhm]
tb.mos.two_die   = 0;        % [-]    body diode: its losses are charged to the transistor die
tb.mos.G_th      = 0.5;      % [-]    gate threshold, between gate_off and gate_on
tb.mos.Eon       = 24;       % [mJ]   at 450 A, 600 V
tb.mos.Eoff      = 8;        % [mJ]
tb.mos.Err       = 1.1;      % [mJ]
tb.mos.Ic_ref    = 450;      % [A]
tb.mos.Vdc_ref   = 600;      % [V]
tb.mos.ki        = 1;        % [-]
tb.mos.kv        = 1;        % [-]
tb.mos.Vth_off   = 50;       % [V]
tb.mos.Vth_on    = 25;       % [V]
tb.mos.V_sm      = 10;       % [V]
tb.mos.time_constant_edge  = 0.1;  % [us]  << dead time
tb.mos.tau_v               = 10;   % [us]
tb.mos.time_constant_ploss = 200;  % [us]
tb.mos.i_eps     = 1e-3;     % [A]
tb.mos.Csnubber  = 12e-12;   % [F]
tb.mos.Rsnubber  = 2200;     % [Ohm]
tb.mos.rth_switch_JH = 0.116;  % [K/W]  RthJC + RthCH + TIM
tb.mos.rth_switch_HA = 0.05;   % [K/W]
tb.mos.rth_diode_JH  = 0.116;  % [K/W]  unused with two_die = 0
tb.mos.rth_diode_HA  = 0.05;   % [K/W]
tb.mos.JunctionTermalMass = 0.2; % [J/K]
tb.mos.Tambient      = 40;     % [degC]
tb.mos.mass_heatsink = 1;      % [kg]
tb.mos.specific_heat = 900;    % [J/(K kg)]
