

%% SKM1700MB20R4S2I4 (MOSFET)
device_name = 'infineon_SKM1700MB20R4S2I4';

Vth = 5.5;                                              % [V]
Rds_on = 1.04e-3;                                       % [Ohm]
g_fs = 900;                                             % [A/V]
Vdon_diode = 4;                                         % [V]
Vgamma = 4;                                             % [V]
Rdon_diode = 1.85e-3;                                   % [Ohm]
Eon = 77e-3;                                            % [J] @ Tj = 125°C
Eoff = 108e-3;                                          % [J] @ Tj = 125°C
Eerr = 9.7e-3;                                          % [J] @ Tj = 125°C
Voff_sw_losses = 1300;                                  % [V]
Ion_sw_losses = 1000;                                   % [A]
JunctionTermalMass = 0.2;                               % [J/K]
Rtim = 0.01;                                            % [K/W]
Rth_mosfet_JC = 19/1000;                                % [K/W]
Rth_mosfet_CH = 6/1000;                                 % [K/W]
Rth_mosfet_JH = Rtim + Rth_mosfet_JC + Rth_mosfet_CH;   % [K/W]
Lstray_module = 12e-9;                                  % [H]
Lstray_d = Lstray_module/2;                                   % [H]
RLd = 0;                                                % [Ohm]
Lstray_s = Lstray_module/2;                                   % [H]
RLs = 0;                                                % [Ohm]
Ciss = 184e-9;                                          % [F]
Coss = 3.28e-9;                                         % [F]
Crss = 0.14e-9;                                         % [F]
Cgs = Ciss - Crss;                                      % [F]
Cgd = Crss;                                             % [F]
Cds = Coss - Crss;                                      % [F]
Rgate_internal = 0.6*1.75;                              % [Ohm]
Irr = 475;                                              % [A]
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------