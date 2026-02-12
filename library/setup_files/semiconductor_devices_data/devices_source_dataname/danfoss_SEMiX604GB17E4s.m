

%% SEMiX604GB17E4s (IGBT) (Tj = 150 degC.)
device_name = 'infineon_SEMiX604GB17E4s';

Vth = 5.8;                                              % [V]
Rce_on = 0.15e-3;                                       % [Ohm]
Vce_sat = 2.25;                                         % [V]
Vdon_diode = 2.25;                                      % [V]
Rdon_diode = 0.15e-3;                                   % [Ohm]
Eon = 255e-3;                                           % [J] @ Tj = 125°C
Eoff = 255e-3;                                          % [J] @ Tj = 125°C
Erec = 150e-3;                                          % [J] @ Tj = 125°C
Voff_sw_losses = 1200;                                  % [V]
Ion_sw_losses = 600;                                    % [A]
JunctionTermalMass = 2;                                 % [J/K]
Rtim = 0.01;                                            % [K/W]
Rth_switch_JC = 42.0/1000;                              % [K/W]
Rth_switch_CH = 16.0/1000;                              % [K/W]
Rth_switch_JH = Rtim + Rth_switch_JC + Rth_switch_CH;   % [K/W]
Rth_diode_JC = 95.0/1000;                               % [K/W]
Rth_diode_CH = 16.0/1000;                               % [K/W]
Rth_diode_JH = Rtim + Rth_diode_JC + Rth_diode_CH;      % [K/W]
Lstray_module = 22e-9;                                  % [H]
Irr = 660;                                              % [A]
Cies = 48e-9;                                           % [F]
Coes = 2.0e-9;                                          % [F]
Cres = 1.52e-9;                                         % [F]
Rgate_internal = 1.25;                                  % [F]
Rgate_on = 2.0;                                         % [F]
Rgate_off = 2.0;                                        % [F]
td_on = 390e-9;                                         % [s]
trise = 60e-9;                                          % [s]
td_off = 920e-9;                                        % [s]
tfall = 180e-9;                                         % [s]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------