

%% DP650B1700T104001 (IGBT) (Tj = 100 degC.)

Eon_25 = 115e-3;
Eon_150 = 200e-3;
Eoff_25 = 120e-3;
Eoff_150 = 225e-3;
Erec_25 = 120e-3;
Erec_150 = 225e-3;
Eon_100 = (Eon_150-Eon_25)/125*100+Eon_25;
Eoff_100 = (Eoff_150-Eoff_25)/125*100+Eoff_25;
Erec_100 = (Erec_150-Erec_25)/125*100+Erec_25;

Vth = 5.8;                                              % [V]
Rce_on = 0.15e-3;                                       % [Ohm]
Vce_sat = 2.25;                                         % [V]
Vdon_diode = 2.25;                                      % [V]
Rdon_diode = 0.15e-3;                                   % [Ohm]
Eon = Eon_100;                                          % [J] @ Tj = 125°C
Eoff = Eoff_100;                                        % [J] @ Tj = 125°C
Erec = Erec_100;                                        % [J] @ Tj = 125°C
Voff_sw_losses = 900;                                   % [V]
Ion_sw_losses = 650;                                    % [A]
JunctionTermalMass = 0.2;                               % [J/K]
Rtim = 0.01;                                            % [K/W]
Rth_switch_JC = 37.0/1000;                              % [K/W]
Rth_switch_CH = 16.0/1000;                              % [K/W]
Rth_switch_JH = Rtim + Rth_switch_JC + Rth_switch_CH;   % [K/W]
Rth_diode_JC = 60.0/1000;                               % [K/W]
Rth_diode_CH = 16.0/1000;                               % [K/W]
Rth_diode_JH = Rtim + Rth_diode_JC + Rth_diode_CH;      % [K/W]
Lstray_module = 18e-9;                                  % [H]
Irr = 900;                                              % [A]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------