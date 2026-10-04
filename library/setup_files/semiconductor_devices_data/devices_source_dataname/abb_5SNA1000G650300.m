
%% 5SNA1000G650300 (IGBT) data at 125°C junction
device_name = 'abb_5SNA1000G650300';
device_type = 'Si-IGBT';

Vth = 5.5;                                              % [V]
Rce_on = 2.00e-3;                                       % [Ohm]
Vce_sat = 4.15;                                         % [V]
Vdon_diode = 3.45;                                      % [V]
Rdon_diode = 1.00e-3;                                   % [Ohm]
Eon = 5250e-3;                                          % [J] @ Tj = 125°C
Eoff = 5400e-3;                                         % [J] @ Tj = 125°C
Erec = 4150e-3;                                         % [J] @ Tj = 125°C
Voff_sw_losses = 3600;                                  % [V]
Ion_sw_losses = 1000;                                   % [A]
JunctionTermalMass = 1.0;                               % [J/K]
Rtim = 4.0/1000;                                        % [K/W]
Rth_switch_JC = 9.80/1000;                              % [K/W]
Rth_switch_CH = 8.00/1000;                              % [K/W]
Rth_switch_JH = Rtim + Rth_switch_JC + Rth_switch_CH;   % [K/W]
Rth_diode_JC = 16.0/1000;                               % [K/W]
Rth_diode_CH = 11.0/1000;                               % [K/W]
Rth_diode_JH = Rtim + Rth_diode_JC + Rth_diode_CH;      % [K/W]
Lstray_module = 18e-9;                                  % [H]
Irr = 2230;                                             % [A]
Cies = 101e-9;                                          % [F]
Cres = 30e-9;                                           % [F]
Rgate_internal = 0.74;                                  % [Ohm]
td_on = 500e-9;                                         % [s]
trise = 160e-9;                                         % [s]
td_off = 5650e-9;                                       % [s]
tfall = 460e-9;                                         % [s]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------

% igbt_dyn parameters (switching-dynamics model), read by device_igbt_setting.
% Moved here from device_igbt_setting.m, where they were the defaults of every
% IGBT. Source: datasheet 5SYA 1465-03, Tvj = 125 degC. The full set, with the
% diode_rr parameters and the test-bench data, is in secom-matlab-models:
% PROP-2026-005-ABB-SSW/static_switch_abb_bergamo/param_5SNA1000G650300.m
% [DS] datasheet table, [FIT] fitted on a datasheet curve, [EST] estimate.
igbt_dyn_param.Vth   = 6.7;      % [V]     [FIT] Fig.2 square-law fit (150C: 6.40, 25C: 8.18)
igbt_dyn_param.Kp    = 123;      % [A/V^2] [FIT] Fig.2 (150C: 118, 25C: 151)
igbt_dyn_param.lam   = 0;        % [1/V]   output conductance not needed
igbt_dyn_param.Cge   = 150e-9;   % [F]     [FIT] Fig.9 pre-plateau slope (~4 uC over 30 V)
igbt_dyn_param.Cgc0  = 210e-9;   % [F]     [FIT] Fig.9 post-plateau slope minus Cge
igbt_dyn_param.Vjc   = 1;        % [V]     [FIT] with mc: Miller plateau charge 3.07 uC
igbt_dyn_param.mc    = 0.87;     % [-]     [FIT] over 3600 V, Cgc(25 V) = 12 nF
igbt_dyn_param.Cce0  = 100e-9;   % [F]     [EST] Coes not in datasheet: Cce(3600 V) ~ 1.7 nF,
igbt_dyn_param.Vjo   = 1;        % [V]     [EST] f_ring ~ 8 MHz with 168 nH.
igbt_dyn_param.mo    = 0.5;      % [-]     [EST] Tune on the measured ringing frequency
igbt_dyn_param.Rg    = 0.74;     % [Ohm]   [DS] RGint
igbt_dyn_param.ftail = 0.25;     % [-]     [EST] tail energy ~ VCC*ftail*I0*tauT = 2.7 J,
igbt_dyn_param.tauT  = 3e-6;     % [s]     [EST] consistent with Eoff = 5.4 J (RGoff = 15 Ohm)
igbt_dyn_param.dsm   = 0.1;      % [V]     numerics
% ------------------------------------------------------------
