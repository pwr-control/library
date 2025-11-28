
%% FF650R17IE4D_B2 (IGBT)
Vth = 5.5;                                              % [V]
Rce_on = 0.15e-3;                                       % [Ohm]
Vce_sat = 2.35;                                         % [V]
Vdon_diode = 1.7;                                       % [V]
Rdon_diode = 0.15e-3;                                   % [Ohm]
Eon = 260e-3;                                           % [J] @ Tj = 125°C
Eoff = 205e-3;                                          % [J] @ Tj = 125°C
Erec = 155e-3;                                          % [J] @ Tj = 125°C
Voff_sw_losses = 900;                                   % [V]
Ion_sw_losses = 650;                                    % [A]
JunctionTermalMass = 0.2;                               % [J/K]
Rtim = 0.01;                                            % [K/W]
Rth_switch_JC = 36/1000;                                % [K/W]
Rth_switch_CH = 15/1000;                                % [K/W]
Rth_switch_JH = Rtim + Rth_switch_JC + Rth_switch_CH;   % [K/W]
Rth_diode_JC = 52/1000;                                 % [K/W]
Rth_diode_CH = 22/1000;                                 % [K/W]
Rth_diode_JH = Rtim + Rth_diode_JC + Rth_diode_CH;      % [K/W]
Lstray_module = 18e-9;                                  % [H]
Irr = 860;                                              % [A]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------