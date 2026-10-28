
%% FF450R17ME4 (IGBT) (Tj = 125 degC)
% Infineon EconoDUAL 3 half bridge, 1700 V / 450 A (ICRM 900 A), Trench/Fieldstop IGBT4 +
% emitter controlled 3 diode + NTC, Tvj,op max = 150 degC.
% Source: datasheet Rev. 1.00, 2025-05-28 (device_datasheets/infineon_IGBT_FF450R17ME4.pdf).
% Typical values at Tvj = 125 degC unless noted; the 150 degC value follows in brackets.
device_name = 'infineon_FF450R17ME4';
device_type = 'Si-IGBT';

% Conduction: the models use v = Vce_sat + Rce_on*i (knee + slope), so the pairs below are a
% linear fit of the typical output characteristics at 125 degC over 150-750 A for the IGBT
% (VGE = 15 V) and 150-600 A for the diode (error < 0.06 V in the fitted range, the diode curve
% bends above 600 A: +0.25 V at 900 A). Datasheet check at 450 A: VCEsat = 2.35 V (fit 2.33 V),
% VF = 1.90 V (fit 1.87 V). At 250 A the fit gives 1.72 V (IGBT) and 1.44 V (diode).
Vth = 5.8;                                              % [V] VGEth typ, Tvj = 25 degC, IC = 18 mA (5.2 min, 6.4 max)
Rce_on = 3.05e-3;                                       % [Ohm] slope, fit 125 degC (150 degC: 3.4 mOhm)
Vce_sat = 0.96;                                         % [V] knee, fit 125 degC (150 degC: 0.89 V)
Vdon_diode = 0.90;                                      % [V] knee, fit 125 degC (150 degC: 0.83 V)
Rdon_diode = 2.15e-3;                                   % [Ohm] slope, fit 125 degC (150 degC: 2.4 mOhm)

% Switching energies: IC = 450 A, VCC = 900 V, VGE = +/-15 V, Lsigma = 35 nH, RGon = RGoff = 3.3 Ohm
% (di/dt = 3900 A/us and dv/dt = 3000 V/us at 150 degC). Erec at IF = 450 A, VCC = 900 V, RG = 3.3 Ohm.
Eon = 135e-3;                                           % [J] @ Tj = 125 degC (150 degC: 145 mJ; 25 degC: 105 mJ)
Eoff = 155e-3;                                          % [J] @ Tj = 125 degC (150 degC: 170 mJ; 25 degC: 98 mJ)
Erec = 110e-3;                                          % [J] @ Tj = 125 degC (150 degC: 125 mJ; 25 degC: 60 mJ)
Voff_sw_losses = 900;                                   % [V]
Ion_sw_losses = 450;                                    % [A]

% Thermal. Rth values per switch; RthCH with lambda_grease = 1 W/(m K); RthJC are maximum values.
% JunctionTermalMass: single-pole equivalent of the Foster ZthJC (C = t63/RthJC, t63 = 49 ms);
% the same criterion gives 0.39 J/K for the diode (t63 = 39 ms).
JunctionTermalMass = 0.81;                              % [J/K]
Rtim = 4.0/1000;                                        % [K/W] extra TIM allowance (not in datasheet)
Rth_switch_JC = 60.0/1000;                              % [K/W] RthJC max per IGBT
Rth_switch_CH = 29.0/1000;                              % [K/W] RthCH typ per IGBT
Rth_switch_JH = Rtim + Rth_switch_JC + Rth_switch_CH;   % [K/W]
Rth_diode_JC = 100.0/1000;                              % [K/W] RthJC max per diode
Rth_diode_CH = 48.0/1000;                               % [K/W] RthCH typ per diode
Rth_diode_JH = Rtim + Rth_diode_JC + Rth_diode_CH;      % [K/W]

% Parasitics, gate, switching times (IC = 450 A, VCC = 900 V, VGE = +/-15 V, RGon = RGoff = 3.3 Ohm).
% Capacitances at VCE = 25 V, VGE = 0 V, f = 1 MHz, Tvj = 25 degC.
Lstray_module = 20e-9;                                  % [H] LsCE
Irr = 550;                                              % [A] IRM @ Tj = 125 degC (150 degC: 585 A; 25 degC: 480 A)
Cies = 36e-9;                                           % [F]
Cres = 1.15e-9;                                         % [F]
Rgate_internal = 1.7;                                   % [Ohm] RGint
td_on = 0.260e-6;                                       % [s] (150 degC: 0.260 us; 25 degC: 0.210 us)
trise = 0.120e-6;                                       % [s] (150 degC: 0.120 us; 25 degC: 0.110 us)
td_off = 0.950e-6;                                      % [s] (150 degC: 1.000 us; 25 degC: 0.800 us)
tfall = 0.500e-6;                                       % [s] (150 degC: 0.600 us; 25 degC: 0.300 us)
Csnubber = 12e-12;                                      % [F] numerical snubber
Rsnubber = 2200;                                        % [Ohm] numerical snubber
gate_charge = 4.6e-6;                                   % [C] QG, Tvj = 25 degC

% ------------------------------------------------------------
% igbt_dyn parameters (switching-dynamics model), read by device_igbt_setting: PARTIAL set.
% The datasheet has no gate-charge curve and no Coes, so the Miller and output capacitances
% (Cgc0, Vjc, mc, Cce0, Vjo, mo) and the tail (ftail, tauT) are not characterized: they stay NaN
% and has_dyn_param is false. Only the entries that the datasheet supports are given.
% [DS] datasheet table, [FIT] fitted on a datasheet curve.
igbt_dyn_param.Vth   = 4.6;      % [V]     [FIT] transfer char. 125 degC (VCE = 20 V), Ic = Kp/2*(Vge-Vth)^2
igbt_dyn_param.Kp    = 36;       % [A/V^2] [FIT] over 150-900 A, error < 40 A (25 degC: 5.5 V, 58 A/V^2;
igbt_dyn_param.lam   = 0;        % [1/V]   150 degC: 4.4 V, 32 A/V^2). Output conductance not needed
igbt_dyn_param.Cge   = 35e-9;    % [F]     [DS] Cies - Cres at VCE = 25 V
igbt_dyn_param.Rg    = 1.7;      % [Ohm]   [DS] RGint
igbt_dyn_param.dsm   = 0.1;      % [V]     numerics

% ------------------------------------------------------------
% Additional datasheet data: not used by the models, kept in dev.extra
Rgate_on = 3.3;                                         % [Ohm] external RGon of the Eon/Eoff/td data
Rgate_off = 3.3;                                        % [Ohm] external RGoff of the Eon/Eoff/td data
Qrr = 170e-6;                                           % [C] Qr @ Tj = 125 degC (150 degC: 190 uC; 25 degC: 95 uC)
Tvj_op_max = 150;                                       % [degC]
Vces = 1700;                                            % [V] VCES, Tvj = 25 degC
Ic_nom = 450;                                           % [A] IC nom (ICDC = 450 A at TC = 100 degC, 600 A at TC = 25 degC)
Ic_rm = 900;                                            % [A] ICRM (IFRM 900 A, tp = 1 ms)
Isc = 2300;                                             % [A] ISC, VGE <= 15 V, VCC = 1000 V, tP <= 10 us, Tvj = 150 degC
I2t_diode = 20000;                                      % [A^2 s] tP = 10 ms, VR = 0 V, Tvj = 125 degC
Rcc_ee = 1.1e-3;                                        % [Ohm] module lead resistance, terminals - chip, per switch, TC = 25 degC
Rth_module_CH = 9.0/1000;                               % [K/W] RthCH of the whole module, lambda_grease = 1 W/(m K)
ntc_R25 = 5e3;                                          % [Ohm] NTC rated resistance at 25 degC (R100 = 493 Ohm +/-5 %)
ntc_B25_50 = 3375;                                      % [K] B-values: R2 = R25*exp(B*(1/T2 - 1/298.15))
ntc_B25_80 = 3411;                                      % [K]
ntc_B25_100 = 3433;                                     % [K]
% Foster network ZthJC = sum(r.*(1 - exp(-t./tau))), from the datasheet tables
Zth_switch_r   = [2.0 9.2 42.6 6.3]/1000;               % [K/W]
Zth_switch_tau = [0.0008 0.013 0.05 0.6];               % [s]
Zth_diode_r    = [6.3 23.8 62.9 7.0]/1000;              % [K/W]
Zth_diode_tau  = [0.0008 0.013 0.05 0.6];               % [s]
% Switching energies vs current, read from the typical curves (VCC = 900 V, RGon = RGoff = 3.3 Ohm),
% for a future lookup-table loss model: the linear scaling of the loss models from the 450 A point
% underestimates Erec at low current (85 mJ at 250 A on the curve against 61 mJ scaled). [A], [J]
I_sw_table     = [ 50 150 300 450 600 750 900];
Eon_table_125  = [ 20  45  85 135 200 295 430]*1e-3;
Eoff_table_125 = [ 25  55 105 155 205 250 300]*1e-3;
Erec_table_125 = [ 37  65  90 110 127 140 150]*1e-3;
Eon_table_150  = [ 22  50  92 145 215 325 470]*1e-3;
Eoff_table_150 = [ 28  65 120 170 222 275 330]*1e-3;
Erec_table_150 = [ 45  78 103 125 143 158 167]*1e-3;
% ------------------------------------------------------------
