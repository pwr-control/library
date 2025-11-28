
%% CAB760M12HM3 (SiC MOSFET - assume Tj = 100 degC)
Vth = 2.5;                                              % [V]
Rds_on = 2e-3;                                          % [Ohm]
Vdon_diode = 5;                                         % [V]
Vgamma = Vdon_diode;                                    % [V]
Rdon_diode = 0.185e-3;                                  % [Ohm]
Eon = 21e-3;                                            % [J] @ Tj = 125°C
Eoff = 18e-3;                                           % [J] @ Tj = 125°C
Eerr = 3.5e-3;                                          % [J] @ Tj = 125°C
Voff_sw_losses = 600;                                   % [V]
Ion_sw_losses = 760;                                    % [A]
JunctionTermalMass = 0.2;                               % [J/K]
Rtim = 0.01;                                            % [K/W]
Rth_mosfet_JC = 68/1000;                                % [K/W]
Rth_mosfet_CH = 12/1000;                                % [K/W]
Rth_mosfet_JH = Rtim + Rth_mosfet_JC + Rth_mosfet_CH;   % [K/W]
Lstray_module = 10e-9;                                  % [H]
Irr = 540;                                              % [A]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------