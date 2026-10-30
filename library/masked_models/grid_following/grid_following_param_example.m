function p = grid_following_param_example(tc)
%GRID_FOLLOWING_PARAM_EXAMPLE  Example parameter structure of the block grid_following_dqctrl_mod1.
%
%   p = grid_following_param_example        400 V, 250 kW, 50 Hz grid, 4 kHz PWM with double update, tc = 0.625 us
%   p = grid_following_param_example(tc)    same, with the given step tc of the block [s]
%
%   The structure has the three fields read by the block: p.hw (Simscape component afe_ssc.afe_two_level_lcl),
%   p.pwm (carrier and gates) and p.ctrl (control). The numbers are those of the study model grid_follower_dq.slx
%   of pwr-control/modelization-and-control, from which the block was built, with the two sign fields
%   seq_gain = +1/2 and pll_err_sign = +1 (the study model has -1/2 and -1: the two signs cancel and the PLL
%   locks on the true grid angle either way). They are the example values of the note
%   library/documentation/grid_forming_following_afe (Section 7), the Help of the block. Copy this file next to
%   your model, change the numbers, keep the field names.
%
%   tc must be the step of the Simscape local solver of the model (Solver Configuration block): the MATLAB
%   Function and the Unit Delay of the measurements run at p.pwm.tc. The control period is
%   p.ctrl.ts = 1/(2*fpwm) with double update, 1/fpwm otherwise.
%
%   See also grid_forming_param_example.

    if nargin < 1
        tc = 0.625e-6;                          % [s] ts/200 at 4 kHz with double update
    end

    % ---- power stage: afe_ssc.afe_two_level_lcl (names of the parameters of the component)
    hw.Vth  = 2.5;                              % [V] gate threshold: a switch is on when its gate is above Vth
    hw.Ron  = 1e-3;                             % [Ohm] on resistance of switch and diode
    hw.Goff = 1e-6;                             % [1/Ohm] off conductance
    hw.Cdc  = 7.2e-3;                           % [F] DC-link capacitor
    hw.Rdc  = 2e-3;                             % [Ohm] its series resistance
    hw.L1p  = 330e-6;                           % [H] converter-side inductor, positive sequence
    hw.L10  = 330e-6;                           % [H] zero sequence (L10 = L1p: three independent phases)
    hw.R1   = 157*0.05*hw.L1p;                  % [Ohm] 5 % of the reactance at 25 Hz (rule of the library data sets)
    hw.Lls1 = 6e-6;                             % [H] leakage
    hw.Cf   = 360e-6;                           % [F] filter capacitor per phase, floating star
    hw.Rcf  = 50e-3;                            % [Ohm] its series resistance
    hw.L2p  = 80e-6;                            % [H] grid-side inductor, positive sequence
    hw.L20  = 80e-6;                            % [H] zero sequence
    hw.R2   = 157*0.05*hw.L2p;                  % [Ohm]
    hw.Lls2 = 5e-6;                             % [H] leakage
    hw.ubez    = 326.6;                         % [V] base voltage: peak phase voltage, 400*sqrt(2/3)
    hw.ibez    = 566.7;                         % [A] base current: peak phase current, 250e3/sqrt(3)/400/0.9*sqrt(2)
    hw.udc_nom = 660;                           % [V] base (nominal) DC-link voltage
    p.hw = hw;

    % ---- carrier and gates
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
    omega = 2*pi*50;                            % [rad/s] nominal grid pulsation

    ctrl.ts     = ts;                           % [s] control period
    ctrl.ts_int = ts;                           % [s] sample time of the PI integrators (same value)

    % local clock and alignment to the master time
    ctrl.k_time         = 1;                    % [-] local clock ratio (1: ideal clock)
    ctrl.kp_align       = 0.25;
    ctrl.ki_align       = 18;                   % [1/s]
    ctrl.lim_up_align   = 0.05;
    ctrl.lim_down_align = -0.05;

    % acquisitions
    ctrl.adc_q = 2^-11;                         % [pu] quantization step (12-bit converter on +/-1 pu)

    % first harmonic tracker of the terminal voltage (alpha and beta channels)
    ctrl.fht_omega   = omega;                   % [rad/s] tracked pulsation
    ctrl.fht_delta   = 0.05;                    % [-] damping of the resonant model
    [ctrl.fht_l1, ctrl.fht_l2] = fht_gains(ts, omega, ctrl.fht_delta, [-1 -4]);   % observer gains, poles [-1 -4]*omega
    ctrl.fht_t_reset = 1e-3;                    % [s] the tracker is held at zero until this time

    % positive sequence and PLL
    ctrl.seq_gain     = 0.5;                    % [-] gain of the positive sequence (u_hat +/- v_hat): +1/2 with pll_err_sign = +1
    ctrl.pll_err_sign = 1;                      % [-] sign of the PLL error u_eta/|u| (-1/2 and -1 in the study model)
    ctrl.u_mag_min    = 0.02;                   % [pu] lower limit of |u| in the normalization 1/|u|
    ctrl.pll_p        = 1;                      % [pu of omega_nom per pu of error]
    ctrl.pll_i1       = 80;                     % [1/s]
    ctrl.omega_nom    = omega;                  % [rad/s] nominal pulsation: omega = omega_nom*(1 + PI output)

    % double integrator observer on the PLL angle (frequency estimate for the log only)
    ctrl.obs_A = [1 ts; 0 1];                   % forward Euler of [0 1; 0 0]
    ctrl.obs_C = [1 0];
    ctrl.obs_L = observer_gains(ctrl.obs_A, exp(ts*[-1 -4]*omega));   % [2x1], poles [-1 -4]*omega

    % DC-link voltage loop
    ctrl.udc_t_step   = 1e-3;                   % [s] time of the reference step
    ctrl.udc_norm_ref = 1;                      % [pu of hw.udc_nom] reference after the step
    ctrl.udc_tau      = 20e-3;                  % [s] low-pass filter of the reference
    ctrl.kp_udc       = 0.85;                   % [pu/pu]
    ctrl.ki_udc       = 35;                     % [1/s]
    ctrl.ixi_lim      = 1.65;                   % [pu] limit of the current reference (xi axis)
    ctrl.ieta_ref     = 0;                      % [pu] reactive current reference (eta axis)

    % current loop: dq vector PI on the converter current
    ctrl.kp_i         = 0.75;                   % [pu/pu] modulation index per pu of current
    ctrl.ki_i         = 35;                     % [1/s]
    ctrl.u_lim        = 1;                      % [pu] radius of the voltage reference (unit circle)
    ctrl.clip_release = 0.001;                  % [1/s] leak of the integrators while the limiter clips

    % zero-sequence current loop and its path to the modulator
    ctrl.iz_ref      = 0;                       % [pu]
    ctrl.kp_iz       = 0.5;                     % [pu/pu]
    ctrl.ki_iz       = 18;                      % [1/s]
    ctrl.iz_lim      = 1;                       % [pu] saturation of the PI
    ctrl.iz_out_gain = 1;                       % [-] gain from the PI output to u_gamma
    ctrl.u_cm        = 0;                       % [-] factor of u_gamma in the modulator (0: standard SVPWM, k_offset = 0.5,
                                                %     the zero-sequence loop does not act; 1: k_offset = (u_gamma + 1)/2)
    p.ctrl = ctrl;
end

% --------------------------------------------------------------------------------------------------------------
function [l1, l2] = fht_gains(ts, omega, delta, poles_norm)
%FHT_GAINS  Observer gains of the first harmonic tracker, with the state matrix the block uses.
%   Resonant model x' = A*x, A = [0 1; -omega^2 -delta*omega], output C = [1 0], discretized with the second-order
%   Taylor series of expm(A*ts) as in first_harmonic_tracker_init of the library C code; observer poles
%   exp(ts*poles_norm*omega).
    a  = -omega^2;
    b  = -delta*omega;
    Ad = [1 + 0.5*a*ts^2,       ts + 0.5*b*ts^2; ...
          a*ts + 0.5*a*b*ts^2,  1 + b*ts + 0.5*(a + b^2)*ts^2];
    L  = observer_gains(Ad, exp(ts*poles_norm*omega));
    l1 = L(1);
    l2 = L(2);
end

function L = observer_gains(Ad, pd)
%OBSERVER_GAINS  L (2x1) such that eig(Ad - L*C) = pd with C = [1 0]: closed-form Ackermann for two states,
%   det(zI - (Ad - L*C)) = z^2 - (a11 - l1 + a22)*z + (a11 - l1)*a22 - a12*(a21 - l2).
    a1 = -(pd(1) + pd(2));
    a0 = pd(1)*pd(2);
    l1 = Ad(1,1) + Ad(2,2) + a1;
    l2 = Ad(2,1) + (a0 - (Ad(1,1) - l1)*Ad(2,2))/Ad(1,2);
    L  = [l1; l2];
end
