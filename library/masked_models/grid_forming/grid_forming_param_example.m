function p = grid_forming_param_example(tc)
%GRID_FORMING_PARAM_EXAMPLE  Example parameter structure of the block grid_forming_dqctrl_mod1.
%
%   p = grid_forming_param_example        400 V, 250 kW, 50 Hz, 4 kHz PWM with double update, tc = 0.625 us
%   p = grid_forming_param_example(tc)    same, with the given step tc of the block [s]
%
%   The structure has the three fields read by the block: p.hw (Simscape component afe_ssc.afe_two_level_lcl),
%   p.pwm (carrier and gates) and p.ctrl (control). The numbers are those of the study model grid_forming_dq.slx
%   of pwr-control/modelization-and-control (foundations_of_power_electronics/grid_forming/single_phase_load),
%   from which the block was built, and are the example values of the note
%   library/documentation/grid_forming_following_afe (Section 7), the Help of the block. Copy this file next to
%   your model, change the numbers, keep the field names.
%
%   tc must be the step of the Simscape local solver of the model (Solver Configuration block): the MATLAB
%   Function and the Unit Delay of the measurements run at p.pwm.tc. The control period is
%   p.ctrl.ts = 1/(2*fpwm) with double update, 1/fpwm otherwise.
%
%   See also grid_following_param_example, update_grid_forming_dqctrl.

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
    omega = 2*pi*50;                            % [rad/s] pulsation of the formed grid

    ctrl.ts     = ts;                           % [s] control period
    ctrl.ts_int = ts;                           % [s] sample time of the PI integrators (same value)

    % local clock and alignment to the master time
    ctrl.k_time         = 1;                    % [-] local clock ratio (the study model uses 1.0002 to test the alignment)
    ctrl.kp_align       = 0.25;
    ctrl.ki_align       = 18;                   % [1/s]
    ctrl.lim_up_align   = 0.05;
    ctrl.lim_down_align = -0.05;

    % acquisitions
    ctrl.adc_q = 2^-11;                         % [pu] quantization step (12-bit converter on +/-1 pu)

    % phase generator
    ctrl.fgrid  = 50;                           % [Hz] frequency of the formed grid
    ctrl.theta0 = 0;                            % [rad] initial angle

    % first harmonic tracker of the terminal voltage (alpha and beta channels)
    ctrl.fht_omega   = omega;                   % [rad/s] tracked pulsation
    ctrl.fht_delta   = 0.05;                    % [-] damping of the resonant model
    [ctrl.fht_l1, ctrl.fht_l2] = fht_gains(ts, omega, ctrl.fht_delta, [-1 -4]);   % observer gains, poles [-1 -4]*omega
    ctrl.fht_t_reset = 1e-3;                    % [s] the tracker is held at zero until this time

    % voltage loop: dq vector PI on the positive sequence of the terminal voltage
    ctrl.ug_ref      = 1;                       % [pu] amplitude of the formed voltage (xi axis)
    ctrl.ueta_ref    = 0;                       % [pu] eta axis
    ctrl.kp_ug       = 0.5;                     % [pu/pu]
    ctrl.ki_ug       = 18;                      % [1/s]
    ctrl.ixi_lim     = 1.65;                    % [pu] radius of the current reference
    ctrl.clip_thr_ug = 1.65;                    % [pu] threshold of the clip flag (= radius)

    % current loop: dq vector PI on the converter current
    ctrl.kp_i  = 0.75;                          % [pu/pu] modulation index per pu of current
    ctrl.ki_i  = 35;                            % [1/s]
    ctrl.u_lim = 1;                             % [pu] radius of the voltage reference (unit circle)

    % leak of the integrators while the limiter clips, common-mode factor of the modulator
    ctrl.clip_release = 0.001;                  % [1/s]
    ctrl.u_cm         = 0;                      % [-] factor of u_gamma in the modulator (0: standard SVPWM, k_offset = 0.5)

    % master/slave and negative-sequence compensator (optional fields: absent = master, compensator off)
    ctrl.slave      = 0;                        % 1 in a slave: angle and current references from the input sync
    ctrl.nsc_enable = 0;                        % 1 switches the compensator on (same value in master and slaves)
    ctrl.nsc_kp_ug  = 0.5;                      % [pu/pu] voltage PI of the compensator (negative frame)
    ctrl.nsc_ki_ug  = 18;                       % [1/s]
    ctrl.nsc_i_lim  = 1.65;                     % [pu] radius and clip threshold of its current reference
    ctrl.nsc_kr_i   = 2*ctrl.ki_i;              % [1/s] resonant gain of the current loop at 2*fgrid (rule kr = 2*ki_i)
    p.ctrl = ctrl;
end

% --------------------------------------------------------------------------------------------------------------
function [l1, l2] = fht_gains(ts, omega, delta, poles_norm)
%FHT_GAINS  Observer gains of the first harmonic tracker, with the state matrix the block uses.
%   Resonant model x' = A*x, A = [0 1; -omega^2 -delta*omega], output C = [1 0], discretized with the second-order
%   Taylor series of expm(A*ts) as in first_harmonic_tracker_init of the library C code; observer poles
%   exp(ts*poles_norm*omega). Closed-form Ackermann for two states:
%   det(zI - (Ad - L*C)) = z^2 - (a11 - l1 + a22)*z + (a11 - l1)*a22 - a12*(a21 - l2).
    a  = -omega^2;
    b  = -delta*omega;
    Ad = [1 + 0.5*a*ts^2,       ts + 0.5*b*ts^2; ...
          a*ts + 0.5*a*b*ts^2,  1 + b*ts + 0.5*(a + b^2)*ts^2];
    pd = exp(ts*poles_norm*omega);
    a1 = -(pd(1) + pd(2));
    a0 = pd(1)*pd(2);
    l1 = Ad(1,1) + Ad(2,2) + a1;
    l2 = Ad(2,1) + (a0 - (Ad(1,1) - l1)*Ad(2,2))/Ad(1,2);
end
