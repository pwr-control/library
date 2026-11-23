
%% CM1200DW-24T (IGBT)
device_name = 'mitsubishi_CM1200DW-24T';
device_type = 'Si-IGBT';

Vth = 6.0;                                              % [V]
Rce_on = 0.15e-3;                                       % [Ohm]
Vce_sat = 1.70;                                         % [V]
Vdon_diode = 1.60;                                      % [V]
Rdon_diode = 0.15e-3;                                   % [Ohm]
Eon = 179e-3;                                           % [J] @ Tj = 125°C
Eoff = 145e-3;                                          % [J] @ Tj = 125°C
Erec = 70e-3;                                          % [J] @ Tj = 125°C
Voff_sw_losses = 600;                                   % [V]
Ion_sw_losses = 1200;                                   % [A]
JunctionTermalMass = 1.0;                               % [J/K]
Rtim = 1.0/1000;                                        % [K/W]
Rth_switch_JC = 29.0/1000;                              % [K/W]
Rth_switch_CH = 20.0/1000;                              % [K/W]
Rth_switch_JH = Rtim + Rth_switch_JC + Rth_switch_CH;   % [K/W]
Rth_diode_JC = 46.0/1000;                               % [K/W]
Rth_diode_CH = 20.0/1000;                               % [K/W]
Rth_diode_JH = Rtim + Rth_diode_JC + Rth_diode_CH;      % [K/W]
Lstray_module = 18e-9;                                  % [H]
Qrr = 94e-6;                                            % [C]
trr = 400e-9;                                           % [s]
Irr = 2*Qrr/trr;                                        % [A]
Cies = 291e-9;                                          % [F]
Coes = 8.3e-9;                                          % [F]
Cres = 3.6e-9;                                          % [F]
Rgate_internal = .33;                                   % [F]
td_on = 0.8e-6;                                         % [s]
trise = 0.20e-6;                                        % [s]
td_off = 1.40e-6;                                       % [s]
tfall = 0.40e-6;                                        % [s]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------