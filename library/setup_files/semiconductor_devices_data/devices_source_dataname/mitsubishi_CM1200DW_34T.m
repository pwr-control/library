
%% CM1200DW-34T (IGBT)
device_name = 'mitsubishi_CM1200DW-34T';
device_type = 'Si-IGBT';

Vth = 6.0;                                              % [V]
Rce_on = 0.25e-3;                                       % [Ohm]
Vce_sat = 2.40;                                         % [V]
Vdon_diode = 2.80;                                      % [V]
Rdon_diode = 0.25e-3;                                   % [Ohm]

% Rg = 0 Ohm
% Eon = 140e-3;                                           % [J] @ Tj = 125°C
% Eoff = 310e-3;                                          % [J] @ Tj = 125°C
% Erec = 220e-3;                                          % [J] @ Tj = 125°C

% Rg = 1 Ohm
Eon = 420e-3;                                           % [J] @ Tj = 125°C
Eoff = 310e-3;                                          % [J] @ Tj = 125°C
Erec = 140e-3;                                          % [J] @ Tj = 125°C

Voff_sw_losses = 1000;                                  % [V]
Ion_sw_losses = 1200;                                   % [A]
JunctionTermalMass = 0.65;                              % [J/K]
Rtim = 1.0/1000;                                        % [K/W]
Rth_switch_JC = 28.0/1000;                              % [K/W]
Rth_switch_CH = 20.0/1000;                              % [K/W]
Rth_switch_JH = Rtim + Rth_switch_JC + Rth_switch_CH;   % [K/W]
Rth_diode_JC = 43.0/1000;                               % [K/W]
Rth_diode_CH = 20.0/1000;                               % [K/W]
Rth_diode_JH = Rtim + Rth_diode_JC + Rth_diode_CH;      % [K/W]
Lstray_module = 18e-9;                                  % [H]
Qrr = 72e-6;                                            % [C]
trr = 300e-9;                                           % [s]
Irr = 2*Qrr/trr;                                        % [A]
Cies = 330e-9;                                          % [F]
Coes = 8.7e-9;                                          % [F]
Cres = 2.8e-9;                                          % [F]
Rgate_internal = 0.67;                                  % [F]
td_on = 0.8e-6;                                         % [s]
trise = 0.20e-6;                                        % [s]
td_off = 0.80e-6;                                       % [s]
tfall = 0.60e-6;                                        % [s]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------