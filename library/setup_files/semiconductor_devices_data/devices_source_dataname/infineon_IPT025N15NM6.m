
%% IPT025N15NM6 (MOSFET), Infineon OptiMOS 6, 150 V, PG-HSOF-8 (TOLL), single device
% Datasheet values (typ, Tj = 25 degC) are marked "ds". The other values are estimates for the
% synchronous rectifier of a CLLC-DCX (ZVS / ZCS): check them before using the switching losses.
% For a bank of n devices in parallel use device_mosfet_parallel(dev, n, fpwm, udc).
device_name = 'infineon_IPT025N15NM6';
device_type = 'Si MOSFET';

Vth = 3.5;                                              % [V] ds
Rds_on = 3.2e-3;                                        % [Ohm] hot (~110 degC): ds 2.5 mOhm typ / 2.9 mOhm max at 25 degC, x 1.3
g_fs = 200;                                             % [A/V] ds
Vdon_diode = 0.7;                                       % [V] body diode knee (ds VSD = 0.86 V @ 120 A)
Vgamma = Vdon_diode;                                    % [V]
Rdon_diode = 1.3e-3;                                    % [Ohm] (0.86 - 0.7) V / 120 A
Eon = 50e-6;                                            % [J] estimate, hard switching @ 75 V, 60 A
Eoff = 40e-6;                                           % [J] estimate, hard switching @ 75 V, 60 A
Err = 3.5e-6;                                           % [J] ~ Qrr*V/4, ds Qrr = 184 nC @ 75 V, 500 A/us
Voff_sw_losses = 75;                                    % [V]
Ion_sw_losses = 60;                                     % [A]
JunctionTermalMass = 0.02;                              % [J/K] estimate, single die
Rtim = 0.2;                                             % [K/W] estimate, TIM under the IMS
Rth_mosfet_JC = 0.38;                                   % [K/W] ds typ
Rth_mosfet_CH = 0.3;                                    % [K/W] estimate, IMS board to cold plate
Rth_mosfet_JH = Rtim + Rth_mosfet_JC + Rth_mosfet_CH;   % [K/W]
Lstray_module = 1e-9;                                   % [H] estimate, package + local loop
Lstray_d = Lstray_module/2;                             % [H]
RLd = 0;                                                % [Ohm]
Lstray_s = Lstray_module/2;                             % [H]
RLs = 0;                                                % [Ohm]
Ciss = 7.5e-9;                                          % [F] ds @ 75 V
Coss = 2.3e-9;                                          % [F] ds @ 75 V (Qoss = 310 nC)
Crss = 25e-12;                                          % [F] ds @ 75 V
Cgs = Ciss - Crss;                                      % [F]
Cgd = Crss;                                             % [F]
Cds = Coss - Crss;                                      % [F]
Rgate_internal = 1.06;                                  % [Ohm] ds
Irr = 9.2;                                              % [A] ~ 2*Qrr/trr, ds trr = 40 ns
Csnubber = 12e-12;                                      % [F]
Rsnubber = 2200;                                        % [Ohm]
% ------------------------------------------------------------