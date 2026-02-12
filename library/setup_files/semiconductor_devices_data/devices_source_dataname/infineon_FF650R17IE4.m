
%% FF650R17IE4 (IGBT)
device_name = 'infineon_FF650R17IE4';

Vth = 5.5;                                              % [V]
Rce_on = 0.15e-3;                                       % [Ohm]
Vce_sat = 2.35;                                         % [V]
Vdon_diode = 2.0;                                       % [V]
Rdon_diode = 0.15e-3;                                   % [Ohm]
Eon = 300e-3;                                           % [J] @ Tj = 125°C
Eoff = 205e-3;                                          % [J] @ Tj = 125°C
Erec = 135e-3;                                          % [J] @ Tj = 125°C
Voff_sw_losses = 900;                                   % [V]
Ion_sw_losses = 650;                                    % [A]
JunctionTermalMass = 1.0;                               % [J/K]
Rtim = 4.0/1000;                                        % [K/W]
Rth_switch_JC = 36.0/1000;                              % [K/W]
Rth_switch_CH = 14.0/1000;                              % [K/W]
Rth_switch_JH = Rtim + Rth_switch_JC + Rth_switch_CH;   % [K/W]
Rth_diode_JC = 72.0/1000;                               % [K/W]
Rth_diode_CH = 27.0/1000;                               % [K/W]
Rth_diode_JH = Rtim + Rth_diode_JC + Rth_diode_CH;      % [K/W]
Lstray_module = 18e-9;                                  % [H]
Irr = 760;                                              % [A]
Cies = 54e-9;                                           % [F]
Cres = 1.7e-9;                                          % [F]
Rgate_internal = 2.3;                                   % [F]
td_on = 0.6e-6;                                         % [s]
trise = 0.11e-6;                                        % [s]
td_off = 1.25e-6;                                       % [s]
tfall = 0.49e-6;                                        % [s]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------