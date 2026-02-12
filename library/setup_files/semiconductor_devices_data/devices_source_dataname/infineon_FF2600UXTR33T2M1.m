
%% FF2600UXTR33T2M1 (MOSFET)
device_name = 'infineon_FF2600UXTR33T2M1';

Vth = 4.3;                                              % [V]
Rds_on = 4.9e-3;                                        % [Ohm]
Vdon_diode = 4.4;                                       % [V]
Vgamma = Vdon_diode;                                    % [V]
Rdon_diode = 0.85e-3;                                   % [Ohm]
Eon = 210e-3;                                           % [J] @ Tj = 125°C
Eoff = 100e-3;                                          % [J] @ Tj = 125°C
Eerr = 33e-3;                                           % [J] @ Tj = 125°C
Voff_sw_losses = 1800;                                  % [V]
Ion_sw_losses = 750;                                    % [A]
JunctionTermalMass = 0.2;                               % [J/K]
Rtim = 0.01;                                            % [K/W]
Rth_mosfet_JC = 33/1000;                                % [K/W]
Rth_mosfet_CH = 26/1000;                                % [K/W]
Rth_mosfet_JH = Rtim + Rth_mosfet_JC + Rth_mosfet_CH;   % [K/W]
Lstray_module = 30e-9;                                  % [H]
Irr = 1100;                                             % [A]
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