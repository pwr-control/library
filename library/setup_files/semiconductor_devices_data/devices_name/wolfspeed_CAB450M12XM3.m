
%% CAB450M12XM3 (SiC MOSFET - assume Tj = 100 degC)

Vth = 2.5;                                              % [V]
Rds_on = 2.6e-3;                                          % [Ohm]
g_fs = 350;                                             % [A/V]
Vdon_diode = 4.5;                                         % [V]
Vgamma = Vdon_diode;                                    % [V]
Rdon_diode = 0.185e-3;                                  % [Ohm]
Eon = 24e-3;                                            % [J] @ Tj = 125°C
Eoff = 8e-3;                                           % [J] @ Tj = 125°C
Eerr = 1.1e-3;                                          % [J] @ Tj = 125°C
Voff_sw_losses = 600;                                   % [V]
Ion_sw_losses = 450;                                    % [A]
JunctionTermalMass = 0.2;                               % [J/K]
Rtim = 0.01;                                            % [K/W]
Rth_mosfet_JC = 94/1000;                                % [K/W]
Rth_mosfet_CH = 12/1000;                                % [K/W]
Rth_mosfet_JH = Rtim + Rth_mosfet_JC + Rth_mosfet_CH;   % [K/W]
Lstray_module = 7e-9;                                  % [H]
Ld = Lstray_module/2;                                   % [H]
RLd = 0;                                                % [Ohm]
Ls = Lstray_module/2;                                   % [H]
RLs = 0;                                                % [Ohm]
Irr = 195;                                              % [A]
Ciss = 38e-9;                                           % [F]
Coss = 1.5e-9;                                          % [F]
Crss = 90e-12;                                          % [F]
Cgs = Ciss - Crss;                                      % [F]
Cgd = Crss;                                             % [F]
Cds = Coss - Crss;                                      % [F]
Rgate_internal = 2.5*1.75;                              % [Ohm]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------