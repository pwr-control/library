function p = afe_single_phase_ttype_param_example(tc)
%AFE_SINGLE_PHASE_TTYPE_PARAM_EXAMPLE  Parameter struct p of afe_single_phase_ttype/afe_single_phase_ttype_mod1.
%
%   p = afe_single_phase_ttype_param_example()        tc = 500 ns
%   p = afe_single_phase_ttype_param_example(tc)      other sample time of the block (= step of the Simscape local solver)
%
%   The single-phase three-level T-type inverter of one module of the SST bench (sst_cllc_ttype_inv.slx of
%   pwr-control/solid-state-transformers, folder sst_based_on_full_bridge_ttype_inverter/
%   sst_single_phase_cllc_single_phase_ttype_inv, numbers in private/sst_cllc_ttype_param.m of that folder):
%   50 kW on an 800 V DC link, ubez = 0.9 udc = 720 V (end of the linear modulation range), is_nom = 125.5 A rms
%   (ibez = 177.5 A peak), fpwm = 4 kHz with double update (control at 8 kHz, ts = 125 us), dead time 300 ns,
%   split DC link 2 x 6 mF (3 mF in series: the 100 Hz pulsating power of a single-phase converter swings it by
%   about 66 V peak-peak at full load), output filter 2 x 250 uH + 50 uF/50 mOhm (1.0 kHz), Wolfspeed CAB006M12GM3
%   modules (Rds_on 5.3 mOhm typical), one phase of a 690 V three-phase system on the AC side (398.4 V rms,
%   563.4 V peak = 0.78 pu of ubez). Control as the bench: Park PLL with the virtual quadrature component and
%   double integrator observer, first harmonic tracker on the current, dq vector PI with the
%   DC-link feed-forward, with the gains re-tuned on the open-loop response of this filter (kp 0.1 / ki 20: the
%   bench values 0.5 / 45 are unstable with the 1.4 kHz resonance of the 500 uH / 50 uF filter, see below).
%   Mode 0 (default): current reference 1 pu from 0.35 s with 2 pu/s, as the bench; mode 1:
%   DC-link voltage loop with conservative starting gains (crossover about 50 rad/s), to be tuned on the model.
%   Values marked TBC are placeholders of the first bench run.
%
%   p.hw    parameters of the Simscape block afe_ttype_ssc.afe_single_phase_ttype, same names and units
%   p.pwm   carrier and gates, p.ctrl control: see the header of private/afe_sp_ttype_ctrl_pwm.m
%
%   The observer gains are closed-form (no Control System Toolbox): for the double integrator x(k+1) = A x + L e,
%   A = [1 ts; 0 1], C = [1 0] and for the first harmonic tracker A = I + [0 1; -w^2 -delta*w]*ts the gains that
%   place the observer poles at exp([-1 -4]*w*ts) (the "place" of the bench model), see obs_gains and fht_gains
%   at the end of this file.

    if nargin < 1
        tc = 500e-9;
    end

    % ------------------------------------------------------------------ operating point
    pwr_nom  = 50e3;                            % [W]  nominal power of the module
    udc_nom  = 800;                             % [V]  DC link
    ubez     = 0.9*udc_nom;                     % [V]  720 V peak, base of the AC voltages
    u_ll_ref = 690;                             % [V]  reference three-phase system, line to line
    ug_rms   = u_ll_ref/sqrt(3);                % [V]  398.4 V rms, AC voltage of the module
    ug_pk    = ug_rms*sqrt(2);                  % [V]  563.4 V peak
    is_nom   = pwr_nom/ug_rms;                  % [A]  125.5 A rms, line current at nominal power
    ibez     = is_nom*sqrt(2);                  % [A]  177.5 A peak, base of the currents
    f_nom    = 50;                              % [Hz]
    omega    = 2*pi*f_nom;                      % [rad/s]
    fpwm     = 4e3;                             % [Hz] carrier
    ts       = 1/(2*fpwm);                      % [s]  control period, double update

    % ------------------------------------------------------------------ p.hw: power stage (afe_ttype_ssc.afe_single_phase_ttype)
    % switches: numerical switch + antiparallel diode, Ron = Rds_on of the module (conduction drop only)
    p.hw.Vth     = 2.5;                         % [V]   gate threshold (CAB006M12GM3)
    p.hw.Ron     = 6e-3;                        % [Ohm] 5.3 mOhm typical at 25 degC plus the package resistance
    p.hw.Goff    = 1e-6;                        % [1/Ohm]
    % split DC link: CFi1 = CFi2 = 2 CFi of the bench, CFi = 3 mF the series value (dclink_for_three_levels)
    p.hw.Cdc1    = 6e-3;                        % [F]   upper bank, dc+ to np (TBC)
    p.hw.Rdc1    = 0.5e-3;                      % [Ohm] ESR of the bank (TBC)
    p.hw.Cdc2    = 6e-3;                        % [F]   lower bank, np to dc- (TBC)
    p.hw.Rdc2    = 0.5e-3;                      % [Ohm]
    p.hw.Vdc0    = udc_nom;                     % [V]   initial DC-link voltage (Vdc0/2 per bank): the run starts at the operating point
    % output filter: LFu = 500 uH of the bench in two halves (one per line), CFu + RCFu across the output
    p.hw.L1      = 250e-6;                      % [H]   line a (leg u): about 25 A peak-peak of ripple at 2 fpwm (TBC)
    p.hw.R1      = 157*0.05*p.hw.L1;            % [Ohm] 2 mOhm, library rule (TBC)
    p.hw.L2      = 250e-6;                      % [H]   line b (leg v)
    p.hw.R2      = 157*0.05*p.hw.L2;            % [Ohm]
    p.hw.Cf      = 50e-6;                       % [F]   1.0 kHz with L1 + L2; 6.3 A (5 %) of capacitive current at 398 V (TBC)
    p.hw.Rcf     = 50e-3;                       % [Ohm] damping of the filter capacitor (TBC)
    % normalization of the measurements
    p.hw.ubez    = ubez;                        % [V]
    p.hw.ibez    = ibez;                        % [A]
    p.hw.udc_nom = udc_nom;                     % [V]

    % ------------------------------------------------------------------ p.pwm: carrier and gates
    p.pwm.tc            = tc;                   % [s]   sample time of the block = local solver step. The switching instants
                                                %       are quantized to tc: with 500 ns the 300 ns dead time becomes 0 or
                                                %       500 ns (as in the bench model at the same step), use 100 ns for
                                                %       the losses
    p.pwm.fpwm          = fpwm;                 % [Hz]
    p.pwm.phase         = 0;                    % [rad] phase of the carrier (modules in series: same phase on all)
    p.pwm.double_update = 1;                    %       control at the bottom and at the top of the carrier (8 kHz)
    p.pwm.dead_time     = 300e-9;               % [s]   between Q1 and Q3 (Q4 and Q2) of each leg
    p.pwm.gate_on       = 15;                   % [V]
    p.pwm.gate_off      = -10;                  % [V]
    p.pwm.m_up          = 1;                    %       limits of the modulation index
    p.pwm.m_low         = -1;
    p.pwm.t_enable      = 0.1;                  % [s]   gates off and loops at rest while the PLL locks (about 3 grid periods)

    % ------------------------------------------------------------------ p.ctrl: control
    p.ctrl.ts             = ts;                 % [s]   control period, 1/(2*fpwm) with double update
    p.ctrl.k_time         = 1;                  %       local clock = master time
    p.ctrl.kp_align       = 0;                  %       alignment PI of the local clock, off
    p.ctrl.ki_align       = 0;
    p.ctrl.lim_up_align   = 0;
    p.ctrl.lim_down_align = 0;
    p.ctrl.adc_q          = 1/2^11;             % [pu]  11-bit quantization of the acquisitions (adc11_quantization of the bench)
    p.ctrl.i_noise_std    = 0.01;               % [pu]  rms of the Gaussian noise on the current sample (0 to switch it off)
    % PLL (single_phase_pll of the bench) and double integrator observer
    p.ctrl.omega_nom      = omega;              % [rad/s]
    p.ctrl.ug_nom         = ug_pk/ubez;         % [pu]  0.78: nominal grid amplitude in pu of ubez (ugrid_pu of the bench)
    p.ctrl.pll_kp         = 1;                  %       PI of the PLL on eta, output in pu of omega_nom
    p.ctrl.pll_ki         = 0;                  % [1/s]
    p.ctrl.pll_lim        = 2;                  % [pu]  limit of the PI output
    p.ctrl.pll_tau        = 2/omega;            % [s]   6.4 ms: low pass of xi and eta (virtual quadrature component)
    [p.ctrl.obs_l1, p.ctrl.obs_l2] = obs_gains(omega, ts);          % poles at exp([-1 -4]*omega*ts): 0.184, 44.8
    % first harmonic tracker on the current (FHTalpha of the bench), poles at exp([-1 -4]*omega*ts)
    p.ctrl.fht_omega      = omega;              % [rad/s]
    p.ctrl.fht_delta      = 0.05;               %       damping of the resonator
    [p.ctrl.fht_l1, p.ctrl.fht_l2] = fht_gains(omega, p.ctrl.fht_delta, ts);   % 0.182, 29.6
    % operating mode and references
    p.ctrl.mode           = 0;                  %       0 current references below, 1 DC-link voltage loop
    p.ctrl.slave          = 0;                  %       1: slave of the block wired to sync (modules in series)
    p.ctrl.i_ref          = 1;                  % [pu]  mode 0: i_d reference (ibez, positive out of the bridge: DC to AC)
    p.ctrl.t_ref          = 0.35;               % [s]   step time of the reference
    p.ctrl.i_ref_slew     = 2;                  % [pu/s] rate limiter: 1 pu reached 0.5 s after the step
    p.ctrl.iq_ref         = 0;                  % [pu]  reactive current reference
    % DC-link voltage loop (mode 1): plant udc' = -(ug_pk*ibez/2)/(Cdc*udc_nom^2)*i_d = -26 1/s per pu of i_d with
    % Cdc = 3 mF (the series of the two banks); kp_udc = 2 gives a crossover of 52 rad/s (8 Hz), the integral corner
    % is at ki_udc/kp_udc = 10 rad/s. The measurement is averaged over one grid period (udc_ma): the 100 Hz ripple
    % of the single-phase DC link (about 4 % peak-peak at full load) and the 50 Hz ripple of a DC offset of the
    % current do not reach the loop (a first-order low pass lets them through and the offset becomes unstable);
    % the average costs 10 ms of delay, 30 deg at the crossover, phase margin about 45 deg
    p.ctrl.udc_ref        = 1;                  % [pu]  800 V
    p.ctrl.kp_udc         = 2;                  % [pu/pu]
    p.ctrl.ki_udc         = 20;                 % [1/s]
    p.ctrl.i_lim          = 1.2;                % [pu]  limit of the current reference (213 A peak)
    p.ctrl.udc_tau        = 20e-3;              % [s]   low pass of the reference (from the first measured udc)
    p.ctrl.udc_ma         = 1;                  %       moving average of the measurement over one grid period
    p.ctrl.udc_meas_tau   = 0;                  % [s]   low pass of the measurement after the average (0: none)
    % current loop (dq vector PI of the bench): plant (L1 + L2) di/dt = u_s - u_ac, 9.0e3 pu/s per pu of PI output
    % (udc_nom/ibez/(L1 + L2)); the feedback is the fundamental of the current from the FHT, a low pass of about
    % 1.2 krad/s on the loop, and the filter resonates at 1/sqrt((L1 + L2) || L_line * Cf) = 1.4 kHz with 0.5 mH of
    % line. Open-loop response (PI, one-step acquisition delay, ZOH plant, FHT): kp_i = 0.1, ki_i = 20 give a
    % crossover of 510 rad/s (80 Hz) with 53 deg of phase margin and a loop gain of 0.37 at the filter resonance;
    % kp_i = 0.15, ki_i = 20: 710 rad/s, 50 deg, 0.56; the gains of the bench model (0.5, 45) give 15 deg at
    % 1.7 krad/s and 1.9 at the resonance (unstable with this filter)
    p.ctrl.kp_i           = 0.1;                % [pu/pu]
    p.ctrl.ki_i           = 20;                 % [1/s]
    p.ctrl.u_lim          = 1;                  % [pu]  radius of the limiter of (m_d, m_q)
    p.ctrl.clip_release   = 0.001;              % [1/s] CTRPIFF_CLIP_RELEASE of the bench: leak of the integrators while clipped
    p.ctrl.udc_min        = 0.25;               % [pu]  lower limit of the DC-link feed-forward (dq_vector_pi)
end

% ------------------------------------------------------------------------------------------------------
function [l1, l2] = obs_gains(omega, ts)
%OBS_GAINS  Gains of the double integrator observer x(k+1) = A x + L (y - C x), A = [1 ts; 0 1], C = [1 0],
%   with the poles at z = exp([-1 -4]*omega*ts): det(zI - A + L C) = z^2 - (2 - l1) z + (1 - l1) + ts l2.
    z1 = exp(-omega*ts);
    z2 = exp(-4*omega*ts);
    l1 = 2 - (z1 + z2);
    l2 = (z1*z2 - (1 - l1))/ts;
end

% ------------------------------------------------------------------------------------------------------
function [l1, l2] = fht_gains(omega, delta, ts)
%FHT_GAINS  Gains of the first harmonic tracker x(k+1) = A x + L (y - C x), A = I + [0 1; -omega^2 -delta*omega]*ts,
%   C = [1 0], with the poles at z = exp([-1 -4]*omega*ts):
%   det(zI - A + L C) = z^2 - (2 - l1 - delta*omega*ts) z + (1 - l1)(1 - delta*omega*ts) + ts^2 omega^2 + ts l2.
    z1 = exp(-omega*ts);
    z2 = exp(-4*omega*ts);
    d  = delta*omega*ts;
    l1 = 2 - d - (z1 + z2);
    l2 = (z1*z2 - (1 - l1)*(1 - d) - ts^2*omega^2)/ts;
end
