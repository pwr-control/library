
%% CAB760M12HM3 (SiC MOSFET - assume Tj = 100 degC)

Vth = 2.5;                                              % [V]
Rds_on = 2e-3;                                          % [Ohm]
g_fs = 550;                                             % [A/V]
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
Ld = Lstray_module/2;                                   % [H]
RLd = 0;                                                % [Ohm]
Ls = Lstray_module/2;                                   % [H]
RLs = 0;                                                % [Ohm]
Irr = 540;                                              % [A]
Ciss = 80e-9;                                           % [F]
Coss = 3.0e-9;                                          % [F]
Crss = 90e-12;                                          % [F]
Cgs = Ciss - Crss;                                      % [F]
Cgd = Crss;                                             % [F]
Cds = Coss - Crss;                                      % [F]
Rgate_internal = 0.5*1.75;                              % [Ohm]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------