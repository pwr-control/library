
%% FF450R12KT4 (IGBT)
Vth = 5.8;                                              % [V]
Rce_on = 0.15e-3;                                       % [Ohm]
Vce_sat = 2.15;                                         % [V]
Vdon_diode = 1.75;                                      % [V]
Rdon_diode = 0.15e-3;                                   % [Ohm]
Eon = 30e-3;                                            % [J] @ Tj = 125°C
Eoff = 40e-3;                                           % [J] @ Tj = 125°C
Erec = 35e-3;                                           % [J] @ Tj = 125°C
Voff_sw_losses = 600;                                   % [V]
Ion_sw_losses = 450;                                    % [A]
JunctionTermalMass = 0.2;                               % [J/K]
Rtim = 0.01;                                            % [K/W]
Rth_switch_JC = 62/1000;                                % [K/W]
Rth_switch_CH = 30/1000;                                % [K/W]
Rth_switch_JH = Rtim + Rth_switch_JC + Rth_switch_CH;   % [K/W]
Rth_diode_JC = 110/1000;                                % [K/W]
Rth_diode_CH = 55/1000;                                 % [K/W]
Rth_diode_JH = Rtim + Rth_diode_JC + Rth_diode_CH;      % [K/W]
Lstray_module = 18e-9;                                  % [H]
Irr = 550;                                              % [A]
Cies = 28e-9;                                           % [F]
Cres = 1.1e-9;                                          % [F]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------