
%% FF1200XTR17T2P5 (IGBT) (Tj = 125 degC)
device_name = 'infineon_FF1200XTR17T2P5';

Vth = 5.8;                                              % [V]
Rce_on = 0.15e-3;                                       % [Ohm]
Vce_sat = 2.20;                                         % [V]
Vdon_diode = 2.00;                                      % [V]
Rdon_diode = 0.15e-3;                                   % [Ohm]
Eon = 340e-3;                                           % [J] @ Tj = 125°C
Eoff = 465e-3;                                          % [J] @ Tj = 125°C
Erec = 290e-3;                                          % [J] @ Tj = 125°C
Voff_sw_losses = 900;                                   % [V]
Ion_sw_losses = 1200;                                   % [A]
JunctionTermalMass = 0.2;                               % [J/K]
Rtim = 0.01;                                            % [K/W]
Rth_switch_JC = 26.8/1000;                              % [K/W]
Rth_switch_CH = 20.1/1000;                              % [K/W]
Rth_switch_JH = Rtim + Rth_switch_JC + Rth_switch_CH;   % [K/W]
Rth_diode_JC = 51.4/1000;                               % [K/W]
Rth_diode_CH = 27.1/1000;                               % [K/W]
Rth_diode_JH = Rtim + Rth_diode_JC + Rth_diode_CH;      % [K/W]
Lstray_module = 10e-9;                                  % [H]
Irr = 1500;                                             % [A]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------