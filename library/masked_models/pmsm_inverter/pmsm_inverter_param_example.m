function [p, mach] = pmsm_inverter_param_example(tc, filter)
%PMSM_INVERTER_PARAM_EXAMPLE  Example parameter structure of the block pmsm_inverter_dqctrl_mod1.
%
%   p = pmsm_inverter_param_example              inverter of inv_psm: one three-phase system of the 1.6 MW,
%                                                17.8 rpm, 104-pole wind generator WindGen (about 267 kW),
%                                                1070 V DC link, 230 uH output inductor (L filter), 4 kHz PWM
%                                                with double update, tc = 1 us
%   p = pmsm_inverter_param_example(tc)          same, with the given step tc of the block [s]
%   p = pmsm_inverter_param_example(tc, 'LC')    same with an LC output filter (230 uH, 75 uF, 0.5 Ohm)
%   [p, mach] = pmsm_inverter_param_example(...) also the machine data (struct mach), for the machine block
%                                                of the model (see test/pmsm_inverter_test_param.m)
%
%   The structure has the three fields read by the block: p.hw (Simscape component afe_ssc.afe_two_level_lcl,
%   same names as in grid_forming_param_example), p.pwm (carrier and gates) and p.ctrl (control). The numbers
%   are those of the study model inv_psm of pwr-control/modelization-and-control
%   (foundations_of_power_electronics/inv_psm), from which the control was taken. Copy this file next to your
%   model, change the numbers, keep the field names.
%
%   The machine is not in the block. The control works in the per unit of the measurements of the power
%   stage, so p.hw.ubez and p.hw.ibez are the bases of the MACHINE (peak phase voltage psi_m*omega_b and
%   peak rated current); the machine data p.ctrl.rs, ld, lq, psi_m are in these per unit, the filter data
%   are read from p.hw by the control.
%
%   Output filter (both with the same block):
%     'L'   (default) the filter capacitor is switched off with a very high series resistance:
%           hw.Rcf = 1e5 Ohm (a few mA through the branch), hw.Cf = 1 uF; the inductor is L1, and L2 is only a
%           small leakage (hw.L2p = hw.L20 = 0, hw.Lls2 = 1 uH; L2 must stay > 0)
%     'LC'  hw.Cf = 75 uF, hw.Rcf = 0.5 Ohm: resonance about 1.2 kHz with the 230 uH inductor and the machine
%
%   tc must be the step of the Simscape local solver of the model (Solver Configuration block): the MATLAB
%   Function and the Unit Delay of the measurements run at p.pwm.tc. The control period is
%   p.ctrl.ts = 1/(2*fpwm) with double update, 1/fpwm otherwise; ts/tc should be an integer.
%
%   See also grid_forming_param_example, update_pmsm_inverter_dqctrl, pmsm_inverter_log_index.

    if nargin < 1 || isempty(tc)
        tc = 1e-6;                              % [s] ts/125 at 4 kHz with double update (as inv_psm)
    end
    if nargin < 2 || isempty(filter)
        filter = 'L';
    end

    % ---- machine: one three-phase system of WindGen (inv_psm, private/psm_machine_param: the whole machine
    %      has six systems, 1.6 MW, 2062 A rms, Ld 1.04 mH, Lq 1.26 mH, eta 96 %; per system Rs, Ld, Lq times 6)
    mach.name     = 'WindGen, one of six systems';
    mach.poles    = 104;                        % number of poles (pole pairs 52)
    mach.rpm_nom  = 17.8;                       % [rpm] rated speed
    mach.i_nom    = 2062/6;                     % [A] rms rated current of one system
    mach.tau_nom  = 1600e3/(17.8/60*2*pi)/6;    % [Nm] rated torque of one system (143.1 kNm)
    mach.Rs       = 30.10e-3;                   % [Ohm] stator resistance (per system)
    mach.Ld       = 6.24e-3;                    % [H] d inductance
    mach.Lq       = 7.56e-3;                    % [H] q inductance
    mach.Lmu      = 5e-6;                       % [H] leakage of the Simscape machine block (makes its matrix invertible)
    mach.J        = 900e3/6/6;                  % [kg m^2] inertia of one system (Jm_m of inv_psm: 900e3/6 over 6 systems)
    mach.pp       = mach.poles/2;
    mach.ibez     = mach.i_nom*sqrt(2);         % [A] base current: peak rated current
    mach.psi_m    = mach.tau_nom/(3/2*mach.pp*mach.ibez);    % [Vs] magnet flux (peak), 3.774 Vs
    mach.omega_m_bez = mach.rpm_nom/60*2*pi;    % [rad/s] mechanical base
    mach.omega_b  = mach.omega_m_bez*mach.pp;   % [rad/s] electrical base, 96.93 rad/s (15.43 Hz)
    mach.ubez     = mach.psi_m*mach.omega_b;    % [V] base voltage: peak phase back-EMF at rated speed, 365.8 V
    mach.zbez     = mach.ubez/mach.ibez;        % [Ohm]
    mach.lbez     = mach.zbez/mach.omega_b;     % [H]

    % ---- power stage: afe_ssc.afe_two_level_lcl (names of the parameters of the component)
    hw.Vth  = 2.5;                              % [V] gate threshold: a switch is on when its gate is above Vth
    hw.Ron  = 1e-3;                             % [Ohm] on resistance of switch and diode
    hw.Goff = 1e-6;                             % [1/Ohm] off conductance
    hw.Cdc  = 7.2e-3;                           % [F] DC-link capacitor (2 x 14.4 mF in series, as inv_psm)
    hw.Rdc  = 1e-3;                             % [Ohm] its series resistance
    hw.L1p  = 230e-6;                           % [H] output inductor of inv_psm (LFi), positive sequence
    hw.L10  = 230e-6;                           % [H] zero sequence
    hw.R1   = 157*0.05*hw.L1p;                  % [Ohm] 1.8 mOhm, 5 % of the reactance at 25 Hz (library rule)
    hw.Lls1 = 0;                                % [H] leakage
    switch upper(filter)
        case 'L'
            hw.Cf  = 1e-6;                      % [F] capacitor branch switched off ...
            hw.Rcf = 1e5;                       % [Ohm] ... by its series resistance
        case 'LC'
            hw.Cf  = 75e-6;                     % [F] filter capacitor per phase, floating star
            hw.Rcf = 0.5;                       % [Ohm] damping resistor in series
        otherwise
            error('pmsm_inverter_param_example: filter must be ''L'' or ''LC''');
    end
    hw.L2p  = 0;                                % [H] no second inductor ...
    hw.L20  = 0;
    hw.R2   = 0;                                % [Ohm]
    hw.Lls2 = 1e-6;                             % [H] ... only a small leakage (connection to the machine, > 0)
    hw.ubez    = mach.ubez;                     % [V] bases of the measurements = bases of the machine
    hw.ibez    = mach.ibez;                     % [A]
    hw.udc_nom = 1070;                          % [V] nominal DC-link voltage (battery of inv_psm)
    p.hw = hw;

    % ---- carrier and gates (as grid_forming_param_example)
    pwm.tc            = tc;                     % [s] sample time of the block = step of the Simscape local solver
    pwm.fpwm          = 4e3;                    % [Hz] PWM frequency
    pwm.phase         = 0;                      % [rad] carrier phase
    pwm.double_update = 1;                      % 1: control at both ends of the carrier, 0: at the bottom only
    pwm.dead_time     = 3e-6;                   % [s] dead time between the two switches of a leg
    pwm.gate_on       = 15;                     % [V] gate voltage of a switch that is on (above hw.Vth)
    pwm.gate_off      = -10;                    % [V] gate voltage of a switch that is off
    pwm.m_low         = 0.02;                   % [-] lower limit of the duties
    pwm.m_up          = 0.98;                   % [-] upper limit of the duties
    p.pwm = pwm;

    % ---- control
    if pwm.double_update
        ts = 1/(2*pwm.fpwm);
    else
        ts = 1/pwm.fpwm;
    end
    ctrl.ts = ts;                               % [s] control period

    % local clock and alignment to the master time (as grid_forming_param_example)
    ctrl.k_time         = 1;
    ctrl.kp_align       = 0.25;
    ctrl.ki_align       = 18;                   % [1/s]
    ctrl.lim_up_align   = 0.05;
    ctrl.lim_down_align = -0.05;

    % acquisitions
    ctrl.adc_q = 2^-11;                         % [pu] quantization step (12-bit converter on +/-1 pu)

    % machine model of the control, pu of hw.ubez, hw.ibez, omega_b
    ctrl.omega_b = mach.omega_b;                % [rad/s] electrical base pulsation
    ctrl.rs      = mach.Rs/mach.zbez;           % 0.0400
    ctrl.ld      = (mach.Ld + mach.Lmu)/mach.lbez;   % 0.8043 (Lmu: leakage of the machine block)
    ctrl.lq      = (mach.Lq + mach.Lmu)/mach.lbez;   % 0.9743
    ctrl.psi_m   = mach.psi_m*mach.omega_b/mach.ubez;   % 1 with the bases of the machine

    % operation
    ctrl.mode      = 2;                         % 0 torque reference, 1 speed control, 2 torque curve (generator)
    ctrl.mtpa      = 1;                         % 1 MTPA, 0 id = 0
    ctrl.angle_src = 1;                         % 0 encoder, 1 back-EMF observer, 2 EKF
    ctrl.omega_th  = 0;                         % [pu] below this encoder speed the encoder is used (0: never)
    ctrl.t_enable  = 0.25;                      % [s] gates off before (flying start), with ref(1) > 0.5 after
    ctrl.k_delay   = 1.5;                       % [periods] angle advance of the voltage (delay compensation)

    % torque and current references
    ctrl.torque_lim  = 1.5;                     % [pu] limit of the torque reference
    ctrl.torque_slew = 2;                       % [pu/s] slew rate of the torque reference
    ctrl.i_lim       = 1.6;                     % [pu] limit of the current vector
    ctrl.id_max      = 0.35;                    % [pu] largest |id| of the MTPA (id_lim of inv_psm)

    % speed control (mode 1): PI of inv_psm, reference and feedback filters
    ctrl.kp_w     = 2.5;                        % [pu/pu]
    ctrl.ki_w     = 18;                         % [1/s]
    ctrl.w_ref_fc = 1;                          % [Hz] filter of the speed reference (0: none)
    ctrl.w_flt_fc = 10;                         % [Hz] filter of the estimated speed (speed PI and torque curve)

    % torque curve (mode 2) of inv_psm: speed in pu of the rated speed, torque in pu of the rated torque of one
    % system; ref(2) scales the torque (inv_psm: torque_overload_factor 1.15)
    rpm_base    = [6 7 8 9 10 11 12 13 14 15 16 17 17.8 18.0 18.2];        % [rpm]
    torque_base = 1e3/6*[50 75 100 125 150 175 200 225 275 350 450 600 750 885 885];   % [Nm] per system
    ctrl.curve_w = rpm_base/mach.rpm_nom;
    ctrl.curve_T = torque_base/mach.tau_nom;

    % current loop: crossover fc_i, PI zero at fc_i/8, plant L = Lq + L1 + L2 (pu)
    fc_i = 250;                                 % [Hz] (phase margin about 65 deg with 1.5 periods of delay)
    l_tot = ctrl.lq + (hw.L1p + hw.Lls1 + hw.L2p + hw.Lls2)/mach.lbez;
    ctrl.kp_i = 2*pi*fc_i*l_tot/mach.omega_b;   % [pu/pu] pu of ubez per pu of ibez
    ctrl.ki_i = ctrl.kp_i*2*pi*fc_i/8;          % [1/s]
    ctrl.u_lim = 1;                             % [pu of vdc/sqrt(3)] radius of the voltage (linear SVPWM)
    ctrl.clip_release = 0.001;                  % [1/s] leak of the integrators while clipped
    ctrl.ff        = 1;                         % 1: feed-forward of back-EMF and cross-coupling
    ctrl.dt_comp   = 1;                         % 1: dead-time compensation in the duties
    ctrl.dt_band   = 0.01;                      % [pu] current at which the dead-time sign saturates

    % observers
    ctrl.pll_poles = [-1 -4]*mach.omega_b;      % [rad/s] tracking loops (encoder, back-EMF observer), as inv_psm
    ctrl.bemf_fb   = 0.2;                       % [-] correction gain of the back-EMF observer (emf_fb_p of inv_psm)
    ctrl.bemf_leak = 0;                         % [-] leak (emf_p of inv_psm, 0.08 there: 4 deg of angle error)
    ctrl.ekf_q  = [1e-6; 1e-6; 1e-7; 1e-7; 1e-6];    % process noise variances per period
    ctrl.ekf_r  = [1e-5; 1e-5];                 % measurement noise variances
    ctrl.ekf_p0 = [1e-4; 1e-4; 1; 1; 1];        % initial variances
    ctrl.ekf_w0 = 0;                            % [pu] initial speed of the EKF
    p.ctrl = ctrl;
end
