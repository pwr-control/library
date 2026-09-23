
%% FF2000XTR17IE5 (IGBT) (Tj = 125 degC)
% Infineon PrimePACK 3+ B-series half bridge, 1700 V / 2000 A,
% Trench/Fieldstop IGBT5 + emitter controlled 5 diode, Tvj,op max = 175 degC.
% Source: datasheet Rev. 1.00, 2023-05-31 (device_datasheets/infineon_IGBT_FF2000XTR17IE5.pdf).
% Typical values at Tvj = 125 degC unless noted; the 175 degC value follows in brackets.
device_name = 'infineon_FF2000XTR17IE5';
device_type = 'Si-IGBT';

% Conduction: the models use v = Vce_sat + Rce_on*i (knee + slope), so the pairs below
% are a linear fit of the typical curves at 125 degC over 500-3000 A (error < 0.1 V).
% Datasheet check at 2000 A: VCEsat = 2.30 V (fit 2.27 V), VF = 2.05 V (fit 2.01 V).
Vth = 5.80;                                             % [V] VGEth typ, Tvj = 25 degC, IC = 72 mA
Rce_on = 0.60e-3;                                       % [Ohm] slope, fit 125 degC (175 degC: 0.68 mOhm)
Vce_sat = 1.07;                                         % [V] knee, fit 125 degC (175 degC: 1.07 V)
Vdon_diode = 1.13;                                      % [V] knee, fit 125 degC (175 degC: 1.04 V)
Rdon_diode = 0.44e-3;                                   % [Ohm] slope, fit 125 degC (175 degC: 0.46 mOhm)

% Switching energies: IC = 2000 A, VCC = 900 V, VGE = +/-15 V, Lsigma = 30 nH,
% RGon = 0.3 Ohm, RGoff = 1.1 Ohm.
Eon = 485e-3;                                           % [J] @ Tj = 125 degC (175 degC: 575 mJ)
Eoff = 590e-3;                                          % [J] @ Tj = 125 degC (175 degC: 690 mJ)
Erec = 390e-3;                                          % [J] @ Tj = 125 degC (175 degC: 525 mJ)
Voff_sw_losses = 900;                                   % [V]
Ion_sw_losses = 2000;                                   % [A]

% Thermal. Rth values per switch; RthCH with lambda_grease = 1 W/(m K).
% JunctionTermalMass: single-pole equivalent of the Foster ZthJC (C = t63/RthJC,
% t63 = 52 ms); the same criterion gives 1.2 J/K for the diode.
JunctionTermalMass = 3.4;                               % [J/K]
Rtim = 4.0/1000;                                        % [K/W] extra TIM allowance (not in datasheet)
Rth_switch_JC = 15.0/1000;                              % [K/W] RthJC max per IGBT
Rth_switch_CH = 9.70/1000;                              % [K/W] RthCH typ per IGBT
Rth_switch_JH = Rtim + Rth_switch_JC + Rth_switch_CH;   % [K/W]
Rth_diode_JC = 38.6/1000;                               % [K/W] RthJC max per diode
Rth_diode_CH = 14.2/1000;                               % [K/W] RthCH typ per diode
Rth_diode_JH = Rtim + Rth_diode_JC + Rth_diode_CH;      % [K/W]

% Parasitics, gate, switching times (IC = 2000 A, VCC = 900 V, RGon = 0.3 Ohm,
% RGoff = 1.1 Ohm). Capacitances at VCE = 25 V, Tvj = 25 degC.
Lstray_module = 10e-9;                                  % [H] LsCE
Irr = 1760;                                             % [A] IRM @ Tj = 125 degC (175 degC: 1920 A)
Cies = 101e-9;                                          % [F]
Cres = 3.5e-9;                                          % [F]
Rgate_internal = 0.75;                                  % [Ohm] RGint
td_on = 0.300e-6;                                       % [s] (175 degC: 0.310 us)
trise = 0.175e-6;                                       % [s] (175 degC: 0.185 us)
td_off = 0.875e-6;                                      % [s] (175 degC: 0.925 us)
tfall = 0.270e-6;                                       % [s] (175 degC: 0.385 us)
Csnubber = 12e-12;                                      % [F] numerical snubber
Rsnubber = 2200;                                        % [Ohm] numerical snubber
gate_charge = 8.5e-6;                                   % [C] QG, VGE = +/-15 V, VCC = 900 V

% ------------------------------------------------------------
% igbt_dyn parameters (switching-dynamics model), read by device_igbt_setting.
% Fitted on the datasheet curves; capacitances taken as temperature independent.
% [DS] datasheet table, [FIT] fitted on a datasheet curve, [EST] estimate.
% Check in the DPT at the datasheet point: VCC = 900 V, IC = 2000 A,
% RGon = 0.3 Ohm, RGoff = 1.1 Ohm, Lsigma = 30 nH (125 degC: tdoff = 0.875 us,
% tf = 0.27 us, Eoff = 590 mJ). The model on-state voltage is the MOS channel
% only (about 0.9 V at 2000 A), not VCEsat: no loss fidelity.
igbt_dyn_param.Vth   = 5.48;     % [V]     [FIT] transfer char. 125 degC, Ic = Kp/2*(Vge-Vth)^2
igbt_dyn_param.Kp    = 235;      % [A/V^2] [FIT] 500-3000 A, error < 65 A (25 degC: 6.30 V, 384)
igbt_dyn_param.lam   = 0;        % [1/V]   output conductance not needed
igbt_dyn_param.Cge   = 124e-9;   % [F]     [FIT] gate charge curve (25 degC, 900 V, 2000 A):
igbt_dyn_param.Cgc0  = 89e-9;    % [F]     [FIT] plateau start 3.02 uC, end 7.10 uC and
igbt_dyn_param.Vjc   = 1;        % [V]     [FIT] QG(+15 V) = 8.50 uC reproduced. Cgc(25 V) =
igbt_dyn_param.mc    = 0.58;     % [-]     [FIT] 13 nF vs Cres 3.5 nF: plateau charge wins
igbt_dyn_param.Cce0  = 5.1e-9;   % [F]     [FIT] Coes - Cres over 5-100 V (error < 10 %):
igbt_dyn_param.Vjo   = 1;        % [V]     [FIT] Cce(25 V) = 1.15 nF, Cce(900 V) = 0.23 nF
igbt_dyn_param.mo    = 0.45;     % [-]     [FIT]
igbt_dyn_param.Rg    = 0.75;     % [Ohm]   [DS] RGint
igbt_dyn_param.ftail = 0.2;      % [-]     [EST] tf grows from 0.115 us (25 degC) to 0.27 us
igbt_dyn_param.tauT  = 0.4e-6;   % [s]     [EST] (125 degC): tail. Tune on tf and Eoff in the DPT
igbt_dyn_param.dsm   = 0.1;      % [V]     numerics

% ------------------------------------------------------------
% Additional datasheet data: not used by the models, kept in dev.extra
Coes = 4.5e-9;                                          % [F] read from C = f(VCE) at VCE = 25 V
Rgate_on = 0.3;                                         % [Ohm] external RGon of the Eon/Eoff/td data
Rgate_off = 1.1;                                        % [Ohm] external RGoff of the Eon/Eoff/td data
Qrr = 595e-6;                                           % [C] Qr @ Tj = 125 degC (175 degC: 510 uC as printed)
Tvj_op_max = 175;                                       % [degC]
% Foster network ZthJC = sum(r.*(1 - exp(-t./tau))), from the datasheet tables
Zth_switch_r   = [0.752 12.0 1.56 0.735]/1000;          % [K/W]
Zth_switch_tau = [0.0029 0.0432 0.196 1.59];            % [s]
Zth_diode_r    = [2.52 27.9 6.84 1.36]/1000;            % [K/W]
Zth_diode_tau  = [0.0034 0.0352 0.153 2.2];             % [s]
% Switching energies vs current, digitized from the typical curves (VCC = 900 V,
% RGon = 0.3 Ohm, RGoff = 1.1 Ohm), for a future lookup-table loss model. [A], [J]
I_sw_table     = [250 500 1000 1500 2000 2500 3000 3500 4000];
Eon_table_125  = [106 162  267  371  484  615  772  965 1202]*1e-3;
Eoff_table_125 = [ 99 172  305  441  593  765  955 1150 1329]*1e-3;
Erec_table_125 = [106 163  258  332  389  434  473  509  549]*1e-3;
Eon_table_175  = [127 193  316  439  578  747  962 1238 1586]*1e-3;
Eoff_table_175 = [124 212  368  520  688  883 1102 1339 1572]*1e-3;
Erec_table_175 = [159 235  360  454  524  578  622  664  711]*1e-3;
% ------------------------------------------------------------
