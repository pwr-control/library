function p = cllc_dcx_param_example(tc)
%CLLC_DCX_PARAM_EXAMPLE  Parameter struct p of cllc_dcx/cllc_dcx_mod1: the 800 V -> 800 V, 50 kW DCX of the SST.
%
%   p = cllc_dcx_param_example()        tc = 50 ns
%   p = cllc_dcx_param_example(tc)      other sample time of the block (= step of the Simscape local solver)
%
%   Same numbers as sst_cllc_dcx_800V_800V_50kW/private/cllc_dcx_param.m of pwr-control/solid-state-transformers
%   (sizing in cllc_dcx_sizing.md of that folder): fn = fs/fr = 0.95 (fs = 50 kHz, fr = 52.6 kHz), Lr = 12 uH,
%   Cr = 0.762 uF, Lm = 400 uH (Im = 10 A peak, ZVS of the driving bridge within the 300 ns dead time), 1:1
%   transformer with 11 turns (three stacked UU93/152/30 sets), Q = 0.38, Ln = 33, DC links 500 uF, chokes
%   250 uH, Wolfspeed CAB006M12GM3 half-bridge modules on both bridges (1200 V, Rds_on 5.3 mOhm typical, Coss
%   0.79 nF, Vgs_th 2.5 V). Open-loop DCX (mode 0): bridge 1 in PWM at 50 %, bridge 2 as synchronous rectifier
%   on i_r2 with the thresholds 0.08 / 0.03 pu (5 A / 1.9 A). For power from side 2 to side 1 swap the roles:
%   p.ctrl.sr_mode_1 = 1, p.ctrl.sr_mode_2 = 0. The gains of the loops (modes 1 and 2) are conservative starting
%   values, to be tuned on the model. The 35 kHz variant (790 V -> 700 V, 9:8) is in cllc_dcx_param_example_35kHz.m.
%
%   p.hw    parameters of the Simscape block cllc_ssc.cllc_dcx_single_phase, same names and units; the options
%           coss_on, cap_dc1, ind_dc1, cap_dc2, ind_dc2 are 0/1 here, the mask of the block turns them into
%           cllc_ssc.onoff values
%   p.pwm   carriers and gates, p.ctrl control: see the header of private/cllc_dcx_ctrl_pwm.m

    if nargin < 1
        tc = 50e-9;
    end

    % ------------------------------------------------------------------ operating point
    pwr_nom = 50e3;                             % [W]  nominal power
    udc1    = 800;                              % [V]  DC link of the SST module (side 1)
    n1      = 11;                               %      turns, 1:1 transformer
    n2      = 11;
    udc2    = udc1*n2/n1;                       % [V]  800 V, isolated DC link (side 2)
    idc1    = pwr_nom/udc1;                     % [A]  62.5 A, base current
    fpwm    = 50e3;                             % [Hz] switching frequency
    fres    = fpwm/0.95;                        % [Hz] series resonance, 52.6 kHz (fn = 0.95)
    n12     = n1/n2;

    % ------------------------------------------------------------------ p.hw: power stage (cllc_ssc.cllc_dcx_single_phase)
    % switches: numerical switch + antiparallel diode, Ron = Rds_on of the module (conduction drop only)
    p.hw.Vth      = 2.5;                        % [V]
    p.hw.Ron      = 6e-3;                       % [Ohm] 5.3 mOhm typical at 25 degC plus the package resistance
    p.hw.Goff     = 1e-6;                       % [1/Ohm]
    p.hw.coss_on  = 1;                          % Coss across each switch: ZVS transitions driven by the tank current
    p.hw.Coss     = 0.79e-9;                    % [F]
    p.hw.tau_coss = 10e-9;                      % [s] series resistance of Coss = tau_coss/Coss (numerical damping)
    % side 1: DC link and choke
    p.hw.cap_dc1  = 1;
    p.hw.Cdc1     = 500e-6;                     % [F]  film bank (TBC)
    p.hw.Rdc1     = 1e-3;                       % [Ohm] ESR of the bank (TBC)
    p.hw.Vdc10    = udc1;                       % [V]  initial voltage: the run starts near the steady state
    p.hw.ind_dc1  = 1;
    p.hw.Ldc1     = 250e-6;                     % [H]  450 Hz with 500 uF (TBC)
    p.hw.RLdc1    = 157*0.05*250e-6;            % [Ohm] 2 mOhm (TBC)
    % resonant tank, side 1
    p.hw.Lr1      = 12e-6;                      % [H]  transformer leakage (3-5 uH) + discrete inductor
    p.hw.Rr1      = 6e-3;                       % [Ohm] winding + inductor + terminations
    p.hw.Cr1      = 1/((2*pi*fres)^2*p.hw.Lr1); % [F]  0.762 uF
    % transformer
    p.hw.n1       = n1;
    p.hw.n2       = n2;
    p.hw.Lm       = 400e-6;                     % [H]  Im peak = udc1/(4 Lm fs) = 10 A
    p.hw.Rfe      = udc1^2/60;                  % [Ohm] 10.7 kOhm: 60 W core losses at 800 V square wave
    % resonant tank, side 2 (symmetrical, referred to the secondary)
    p.hw.Lr2      = p.hw.Lr1/n12^2;             % [H]
    p.hw.Rr2      = p.hw.Rr1/n12^2;             % [Ohm]
    p.hw.Cr2      = p.hw.Cr1*n12^2;             % [F]
    % side 2: DC link and choke
    p.hw.cap_dc2  = 1;
    p.hw.Cdc2     = 500e-6;                     % [F]  (TBC)
    p.hw.Rdc2     = 1e-3;                       % [Ohm] (TBC)
    p.hw.Vdc20    = udc2;                       % [V]
    p.hw.ind_dc2  = 1;
    p.hw.Ldc2     = 250e-6;                     % [H]  (TBC)
    p.hw.RLdc2    = 157*0.05*250e-6;            % [Ohm] (TBC)
    % normalization of the measurements
    p.hw.udc_nom  = udc1;                       % [V]
    p.hw.idc_nom  = idc1;                       % [A]

    % ------------------------------------------------------------------ p.pwm: carriers and gates
    p.pwm.tc            = tc;                   % [s]  sample time of the block = local solver step
    p.pwm.fpwm          = fpwm;                 % [Hz]
    p.pwm.phase         = 0;                    % [rad] phase of carrier 1
    p.pwm.double_update = 0;                    %      control once per period (TRGO at the carrier bottom)
    p.pwm.dead_time     = 300e-9;               % [s]  ZVS of the driving leg: 2*Coss*udc1/Im = 126 ns < dead time
    p.pwm.gate_on       = 18;                   % [V]
    p.pwm.gate_off      = -3;                   % [V]
    p.pwm.t_enable      = 0;                    % [s]  gates enabled from the start (DC links at their initial voltage)
    % soft start (frequency sweep), off: give both fields to switch it on, e.g. 3*fpwm -> fpwm in 20 ms
    % p.pwm.f_start = 3*fpwm;                   % [Hz]
    % p.pwm.t_soft  = 20e-3;                    % [s]

    % ------------------------------------------------------------------ p.ctrl: control
    p.ctrl.ts             = 1/fpwm;             % [s]  control period (1/(2*fpwm) with double_update = 1)
    p.ctrl.k_time         = 1;                  %      local clock = master time
    p.ctrl.kp_align       = 0;                  %      alignment PI of the local clock, off
    p.ctrl.ki_align       = 0;
    p.ctrl.lim_up_align   = 0;
    p.ctrl.lim_down_align = 0;
    p.ctrl.adc_q          = 1/4096;             % [pu] 12-bit ADC
    % operating mode
    p.ctrl.mode           = 0;                  %      0 open-loop DCX, 1 current loop, 2 voltage loop
    p.ctrl.phi0           = 0;                  % [rad] phase of bridge 2 in mode 0
    p.ctrl.sr_mode_1      = 0;                  %      bridge 1 in PWM (power from side 1 to side 2)
    p.ctrl.sr_mode_2      = 1;                  %      bridge 2 synchronous rectifier on i_r2
    p.ctrl.sr_i_on        = 0.08;               % [pu] 5 A: turn-on threshold of the synchronous rectifiers
    p.ctrl.sr_i_off       = 0.03;               % [pu] 1.9 A: turn-off threshold, body diodes below it
    p.ctrl.side           = 2;                  %      regulated side (modes 1 and 2)
    % current loop (mode 1 and inner loop of mode 2): plant about 13 pu/rad of phase at fn = 0.95 (with the
    % fundamentals P = 640 kW sin(phi), 50 kW at 4.5 deg, i_dc2 in pu of idc_nom); kp_i gives a loop gain
    % of 0.25, the integral corner is at ki_i/kp_i = 1000 rad/s
    p.ctrl.i_ref          = 1;                  % [pu] 62.5 A rectified into DC link 2
    p.ctrl.kp_i           = 0.02;               % [rad/pu]
    p.ctrl.ki_i           = 20;                 % [rad/(pu s)]
    p.ctrl.phi_max        = 0.5;                % [rad] limit of the phase (29 deg), far from the switching level
    p.ctrl.clip_release   = 100;                % [1/s] leak of the integrators while clipped
    % voltage loop (mode 2): DC link 2 time constant Cdc2*udc_nom/idc_nom = 6.4 ms, kp_u = 1 gives a crossover
    % of 156 rad/s (25 Hz), the integral corner is at ki_u/kp_u = 50 rad/s
    p.ctrl.u_ref          = 1;                  % [pu] 800 V
    p.ctrl.kp_u           = 1;                  % [pu/pu]
    p.ctrl.ki_u           = 50;                 % [1/s]
    p.ctrl.i_lim          = 1.2;                % [pu] limit of the current reference (75 A)
end
