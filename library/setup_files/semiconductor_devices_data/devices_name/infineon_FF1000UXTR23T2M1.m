
%% FF1000UXTR23T2M1 (MOSFET)
Vth = 4.2;                                              % [V]
Rds_on = 1.7e-3;                                        % [Ohm]
g_fs = 500;                                            % [A/V]
Vdon_diode = 4.4;                                       % [V]
Vgamma = Vdon_diode;                                    % [V]
Rdon_diode = 0.85e-3;                                   % [Ohm]
Eon = 540e-3;                                           % [J] @ Tj = 125°C
Eoff = 370e-3;                                          % [J] @ Tj = 125°C
Eerr = 40e-3;                                           % [J] @ Tj = 125°C
Voff_sw_losses = 1500;                                  % [V]
Ion_sw_losses = 2000;                                   % [A]
JunctionTermalMass = 0.2;                               % [J/K]
Rtim = 0.01;                                            % [K/W]
Rth_mosfet_JC = 20/1000;                                % [K/W]
Rth_mosfet_CH = 6/1000;                                 % [K/W]
Rth_mosfet_JH = Rtim + Rth_mosfet_JC + Rth_mosfet_CH;   % [K/W]
Ciss = 190e-9;                                           % [F]
Coss = 4.1e-9;                                          % [F]
Crss = 0.2e-9;                                          % [F]
Cgs = Ciss - Crss;                                      % [F]
Cgd = Crss;                                             % [F]
Cds = Coss - Crss;                                      % [F]
Lstray_module = 10e-9;                                  % [H]
Ld = Lstray_module/2;                                   % [H]
RLd = 0;                                                % [Ohm]
Ls = Lstray_module/2;                                   % [H]
RLs = 0;                                                % [Ohm]
Irr = 1100;                                             % [A]
Rgate_internal = 1.1*1.75;                              % [Ohm]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------