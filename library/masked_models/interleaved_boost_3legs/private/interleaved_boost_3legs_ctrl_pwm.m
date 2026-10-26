function [G, ctrl_log] = interleaved_boost_3legs_ctrl_pwm(M, t_master, p)
%INTERLEAVED_BOOST_3LEGS_CTRL_PWM  Control and interleaved PWM of a three-leg boost converter in a single MATLAB Function block.
%#codegen
%
%   [G, ctrl_log] = interleaved_boost_3legs_ctrl_pwm(M, t_master, p)
%
%   Source of the MATLAB Function interleaved_boost_3legs_ctrl_pwm of interleaved_boost_3legs/interleaved_boost_3legs_mod1:
%   ../update_interleaved_boost_3legs.m loads this file into the block (edit here, then run it).
%
%   Compact version of dcdc_ctrl and tri-interleaved_buck_pwm of interleaved_boost.slx (pwr-control/modelization-and-control,
%   foundations_of_power_electronics/interleaved_boost_converter): the acquisitions, the DC-link voltage loop, the three
%   per-leg current loops and the interleaved modulator (three triangle carriers, TRGO of each carrier, gate commands of
%   the six switches), written as one function so that the control of one converter counts as ONE nonvirtual block
%   (MATLAB Home licence: 1000 nonvirtual blocks per model, referenced models and library links included). Same
%   structure as interleaved_buck_3legs_ctrl_pwm.m (interleaved_buck_3legs), of which this is the boost version: the
%   hardware is the one of the buck with the power flow reversed (battery on the inductor side, load on the DC link),
%   the control regulates the DC-link voltage with the input current, and the per-leg PI outputs the duty d_k of the
%   LOWER switch (the boost switch); the modulator is the one of the buck, driven with m_k = 1 - d_k. The block runs at
%   the fixed sample time p.pwm.tc, the step of the Simscape local solver; the control runs on the rising edge of the
%   TRGO flag of carrier 1, the gate commands are computed every step.
%
%   Inputs
%     M        measurement vector [10x1] in pu of the block boost_ssc.interleaved_boost_3legs, one tc behind (Unit Delay
%              meas_delay, no algebraic loop): M(1:3) inductor currents of legs 1, 2, 3 (pu of ibez, positive from the
%              battery into the leg = boost direction), M(4) their sum, M(5) input terminal current, M(6) u_in (pu of
%              uin_nom), M(7) udc (pu of udc_nom), M(8) i_dc (load current), M(9) i_cin, M(10) i_cdc
%     t_master master time [s]: the Clock of the model, or the master time of the models with a global timing block
%     p        parameter struct, scope "Parameter" in the Symbols pane of the block: p.hw (the parameters of the ssc
%              block, not read here), p.pwm and p.ctrl, see below and ../interleaved_boost_3legs_param_example.m
%   Outputs
%     G        gate commands [6x1] in V, order [Q1_1; Q2_1; Q1_2; Q2_2; Q1_3; Q2_3] (upper and lower switch of each
%              leg, input G of the ssc block), levels p.pwm.gate_on / p.pwm.gate_off (15 V / -10 V against Vth = 2.5 V)
%     ctrl_log control signals [30x1], indices in ../interleaved_boost_3legs_log_index.m (the loop signals are held
%              between two control steps; t_loc, the carriers, the TRGO flags, the applied duties and the held
%              samples are updated every step)
%
%   Chain (names of the blocks of interleaved_boost.slx in brackets)
%     every step tc
%       local clock    t_loc = t_master*k_time*(1 + corr)                                      [global timing]
%       carriers       ramp_k = asin(sin(2*pi*fpwm*t_loc - carrier_phase(k) - pi/2))/pi + 1/2, triangle 0..1, one per
%                      leg, carrier_phase = [0 2*pi/3 4*pi/3] for the interleaving      [ramp_up_down_1..3]
%       TRGO_k         ramp_k <= 2*fpwm*tc (carrier bottom) or, with double_update, also ramp_k >= 1 - 2*fpwm*tc
%                      (top)                                                                 [trgo_leg1..3]
%       sample/hold    on the rising edge of TRGO_k the current of leg k is sampled and quantized (adc_q): the leg
%                      current is at its average value at the extremes of its own carrier (the ON pulse of Q2_k, the
%                      boost switch, is centred on the top of the carrier and the one of Q1_k on the bottom), so the
%                      samples carry no ripple                                     [dcdc_ctrl/sample_hold_legs]
%       shadow load    on the rising edge of TRGO_k (k = 2, 3) the duty of leg k computed at the last control step is
%                      loaded into the modulator (the duty of leg 1 is loaded at the control step itself)
%                      [tri-interleaved_legs_modulator_with_TRGO/shadow_load]
%       gates          with m_k = 1 - d_k: Q1_k on while ramp_k <= m_k - dead_time*fpwm, Q2_k on while
%                      ramp_k >= m_k + dead_time*fpwm (dead time dead_time around both edges), m_k saturated in
%                      [m_low, m_up]; all gates off until the first control step with t_master >= t_enable
%                      [gate commands, polarity -1]
%     on the rising edge of TRGO_1 (no trigger on the first evaluation, as the Trigger block)
%       acquisitions   the control uses the samples of the previous control step (one-step delay): the held leg
%                      currents (leg 1 just sampled at this extreme, legs 2 and 3 up to 2/3 ts earlier at their own
%                      extremes), u_in and udc quantized with adc_q                    [boost_control/acquisitions]
%       alignment      PI of (t_master - t_loc), saturated, back-calculation anti-windup, output corr applied from the
%                      next step (zero gains: free-running local clock = master time)
%       reference      mode 0: udc_ref reached with the slew u_ref_slew (pu/s) from udc_ref_init (the precharged DC
%                      link, u_in/udc_nom; without this field the ramp starts from the acquired udc): the DC link
%                      cannot be regulated below the battery voltage; PI on udc_ref - udc (kp_u, ki_u), saturated at
%                      +-i_lim with back-calculation anti-windup -> total input current reference i_ref (pu of ibez;
%                      negative = buck direction, DC link to battery)                          [voltage_ctrl, pi_u]
%                      mode 1: i_ref steps to p.ctrl.i_ref at t_ref with the slew i_ref_slew, saturated at +-i_lim
%       current loops  one PI per leg (kp_i, ki_i) on i_ref/3 - i_Lk, output the duty d_k of the lower switch
%                      saturated in [m_low, m_up] with back-calculation anti-windup, m_k = 1 - d_k to the modulator
%                      [current_ctrl/pi/PId, one_minus_d]
%
%   Parameters (all required unless marked optional)
%     p.pwm.tc            [s]   sample time of the block = Simscape local solver step
%     p.pwm.fpwm          [Hz]  carrier frequency of each leg (3e3; the capacitors see 3*fpwm)
%     p.pwm.carrier_phase [rad] [3x1] or [1x3] phases of the three carriers ([0 2*pi/3 4*pi/3])
%     p.pwm.double_update       0: TRGO at the carrier bottom, 1: bottom and top (control at 2*fpwm)
%     p.pwm.dead_time     [s]   dead time between Q1_k and Q2_k (3e-6)
%     p.pwm.gate_on/off   [V]   gate levels (15 / -10)
%     p.pwm.m_up, m_low         limits of the duty d_k (0.98, 0.02; m_k = 1 - d_k stays in the same interval)
%     p.pwm.t_enable      [s]   optional: all gates off and the loops at rest while t_master < t_enable (0)
%     p.ctrl.ts           [s]   control period, 1/fpwm (1/(2*fpwm) with double update)
%     p.ctrl.k_time             local clock factor (1)
%     p.ctrl.kp_align, ki_align, lim_up_align, lim_down_align   optional: alignment PI of the local clock (0, 0, 0, 0)
%     p.ctrl.adc_q        [pu]  quantization step of the acquisitions (1/2048)
%     p.ctrl.mode               0 DC-link voltage loop, 1 total input current reference
%     p.ctrl.udc_ref      [pu]  DC-link voltage reference (pu of udc_nom), u_ref_slew [pu/s] ramp of the reference,
%                               udc_ref_init [pu] optional start of the ramp (uin_nom/udc_nom, the precharged link)
%     p.ctrl.kp_u [pu/pu], ki_u [1/s]   voltage PI (output in pu of ibez), i_lim [pu] its limit
%     p.ctrl.i_ref        [pu]  total current reference of mode 1 (pu of ibez), t_ref [s], i_ref_slew [pu/s]
%     p.ctrl.kp_i [pu/pu], ki_i [1/s]   per-leg current PI (output = duty of the lower switch)
%
%   Differences from the block diagram of interleaved_boost.slx: the switching instants are quantized to tc (the local
%   solver samples the gates at tc anyway), no 1/(tc*s + 1) filters on the duties, the PI integrators use the
%   back-calculation anti-windup (the model clamps the integrator states at the same limits), double precision
%   throughout, no device model (the losses of the switches are Ron only, no thermal model).

NLOG = 30;
NLEGS = 3;

persistent initialized trgo_z corr_z x_align is_hold is_z uin_z udc_z ref_z started x_u x_i d_cmd m_cmd m_apply enable_z logv

if isempty(initialized)
    initialized = true;
    trgo_z   = true(NLEGS,1);        % Trigger block "compatibility (no trigger on first evaluation)"
    corr_z   = 0;                    % local time correction (Unit Delay of "global timing")
    x_align  = 0;                    % integrator of the alignment PI
    is_hold  = zeros(NLEGS,1);       % leg currents held at the extremes of their own carriers (sample_hold_legs)
    is_z     = zeros(NLEGS,1);       % held currents at the previous control step (one-step delay of the acquisitions)
    uin_z    = 0;                    % acquired input voltage of the previous control step
    udc_z    = 0;                    % acquired DC-link voltage of the previous control step
    ref_z    = 0;                    % rate-limited reference (udc_ref in mode 0, i_ref in mode 1)
    started  = false;                % mode 0: the ramp of udc_ref has been initialized (first enabled control step)
    x_u      = 0;                    % integrator of the voltage PI
    x_i      = zeros(NLEGS,1);       % integrators of the per-leg current PIs
    d_cmd    = zeros(NLEGS,1);       % duties of the lower switches computed at the last control step
    m_cmd    = 1 - d_cmd;            % the same in the buck convention of the modulator, m = 1 - d
    m_apply  = ones(NLEGS,1);        % duties loaded into the modulator (shadow registers)
    enable_z = false;                % enable state of the last control step: gates on from there
    logv     = zeros(NLOG,1);
end

m = M(:);

% ------------------------------------------------------------------ optional fields of p
t_en = 0;
if isfield(p.pwm, 't_enable')
    t_en = p.pwm.t_enable;
end
kp_al = 0; ki_al = 0; lim_up_al = 0; lim_dn_al = 0;
if isfield(p.ctrl, 'kp_align')
    kp_al = p.ctrl.kp_align;
    ki_al = p.ctrl.ki_align;
    lim_up_al = p.ctrl.lim_up_align;
    lim_dn_al = p.ctrl.lim_down_align;
end
enable = t_master >= t_en;
q = p.ctrl.adc_q;

% ------------------------------------------------------------------ every step: local clock, carriers, TRGO flags
t_loc = t_master*p.ctrl.k_time*(1 + corr_z);
th_trgo = 2*p.pwm.fpwm*p.pwm.tc;
ramp = zeros(NLEGS,1);
trgo = false(NLEGS,1);
for k = 1:NLEGS
    ramp(k) = asin(sin(2*pi*p.pwm.fpwm*t_loc - p.pwm.carrier_phase(k) - pi/2))/pi + 1/2;
    if p.pwm.double_update ~= 0
        trgo(k) = (ramp(k) >= 0 && ramp(k) <= th_trgo) || (ramp(k) <= 1 && ramp(k) >= 1 - th_trgo);
    else
        trgo(k) = (ramp(k) >= 0 && ramp(k) <= th_trgo);
    end
end
rise = trgo & ~trgo_z;
trgo_z = trgo;

% ---- sample-and-hold of each leg current at the extremes of its own carrier (average value of the leg current)
for k = 1:NLEGS
    if rise(k)
        is_hold(k) = q*round(m(k)/q);
    end
end

if rise(1)
    % ============================================================== control step (triggered subsystem boost_control)
    ts = p.ctrl.ts;

    % ---- acquisitions: the control uses the samples of the previous control step (Zero-Order Hold + Unit Delay),
    %      the delay states take the samples of this step
    isd  = is_z;
    uind = uin_z;
    udcd = udc_z;
    is_z  = is_hold;
    uin_z = q*round(m(6)/q);
    udc_z = q*round(m(7)/q);

    % ---- alignment of the local clock to the master time (as the AFE blocks)
    e_al = t_master - t_loc;
    P_al = kp_al*e_al;
    y_al = P_al + ki_al*ts*e_al + x_align;
    y_al = min(max(y_al, lim_dn_al), lim_up_al);
    x_align = y_al - P_al;                         % back-calculation anti-windup
    corr_z  = y_al;                                % applied from the next step

    % ---- reference and voltage loop
    e_u   = 0;
    sat_u = 0;
    u_ref = 0;
    if p.ctrl.mode == 0
        % DC-link voltage loop: reference ramped with u_ref_slew from udc_ref_init (else from the acquired udc), PI with
        % back-calculation -> total input current reference
        if ~started
            if isfield(p.ctrl, 'udc_ref_init')
                ref_z = p.ctrl.udc_ref_init;
            else
                ref_z = udcd;
            end
            started = true;
        end
        dref  = min(max(p.ctrl.udc_ref - ref_z, -p.ctrl.u_ref_slew*ts), p.ctrl.u_ref_slew*ts);
        ref_z = ref_z + dref;
        u_ref = ref_z;
        e_u   = u_ref - udcd;
        P_u   = p.ctrl.kp_u*e_u;
        y_u   = P_u + p.ctrl.ki_u*ts*e_u + x_u;
        i_ref = min(max(y_u, -p.ctrl.i_lim), p.ctrl.i_lim);
        x_u   = i_ref - P_u;
        sat_u = double(i_ref ~= y_u);
    else
        % total input current reference: step at t_ref, rate limiter i_ref_slew (negative = buck direction)
        target = 0;
        if t_master >= p.ctrl.t_ref
            target = p.ctrl.i_ref;
        end
        dref  = min(max(target - ref_z, -p.ctrl.i_ref_slew*ts), p.ctrl.i_ref_slew*ts);
        ref_z = ref_z + dref;
        i_ref = min(max(ref_z, -p.ctrl.i_lim), p.ctrl.i_lim);
        x_u   = 0;
    end
    if ~enable
        ref_z   = 0;
        started = false;
        x_u     = 0;
        i_ref   = 0;
    end

    % ---- per-leg current loops: reference i_ref/3, output the duty of the lower switch of the leg, m = 1 - d to the
    %      modulator (the plant d_k -> i_Lk is the integrator udc/L, as the buck: a larger d_k raises the leg current)
    i_leg_ref = i_ref/NLEGS;
    for k = 1:NLEGS
        if enable
            e_i = i_leg_ref - isd(k);
            P_i = p.ctrl.kp_i*e_i;
            y_i = P_i + p.ctrl.ki_i*ts*e_i + x_i(k);
            d_k = min(max(y_i, p.pwm.m_low), p.pwm.m_up);
            x_i(k)   = d_k - P_i;                  % back-calculation anti-windup
            d_cmd(k) = d_k;
        else
            x_i(k)   = 0;
            d_cmd(k) = 0;
        end
        m_cmd(k) = 1 - d_cmd(k);
    end
    m_apply(1) = m_cmd(1);                         % leg 1 loads its duty at the control step (its own carrier extreme)

    % ---- log (indices: interleaved_boost_3legs_log_index.m)
    logv(8)  = corr_z;
    logv(9)  = isd(1);
    logv(10) = isd(2);
    logv(11) = isd(3);
    logv(12) = isd(1) + isd(2) + isd(3);
    logv(13) = uind;
    logv(14) = udcd;
    logv(15) = u_ref;
    logv(16) = e_u;
    logv(17) = i_ref;
    logv(18) = sat_u;
    logv(19) = i_leg_ref;
    logv(20) = d_cmd(1);
    logv(21) = d_cmd(2);
    logv(22) = d_cmd(3);
    logv(27) = p.ctrl.mode;
    enable_z = enable;
end

% ---- shadow load of the duties of legs 2 and 3 at the extremes of their own carriers
for k = 2:NLEGS
    if rise(k)
        m_apply(k) = m_cmd(k);
    end
end

% ------------------------------------------------------------------ every step: gate commands
% The gates follow the enable state of the last control step (enable_z): the legs start switching at the first
% enabled control step, with the duties of that step. Buck convention of the modulator on m_k = 1 - d_k: the ON pulse
% of the upper switch Q1_k (synchronous rectifier) is centred on the carrier bottom, the one of the lower switch Q2_k
% (boost switch, on for the fraction d_k of the period) on the carrier top.
gon  = p.pwm.gate_on;
goff = p.pwm.gate_off;
dtf  = p.pwm.dead_time*p.pwm.fpwm;                 % dead time as a fraction of the carrier period
G = goff*ones(2*NLEGS,1);
if enable_z
    for k = 1:NLEGS
        mk = min(max(m_apply(k), p.pwm.m_low), p.pwm.m_up);    % Saturation m_low..m_up of the modulator
        if ramp(k) <= mk - dtf
            G(2*k-1) = gon;                        % Q1_k, upper switch: synchronous rectification
        end
        if ramp(k) >= mk + dtf
            G(2*k) = gon;                          % Q2_k, lower switch: the boost switch
        end
    end
end

logv(1)  = t_loc;
logv(2)  = ramp(1);
logv(3)  = ramp(2);
logv(4)  = ramp(3);
logv(5)  = double(trgo(1));
logv(6)  = double(trgo(2));
logv(7)  = double(trgo(3));
logv(23) = m_apply(1);
logv(24) = m_apply(2);
logv(25) = m_apply(3);
logv(26) = double(enable_z);
logv(28) = is_hold(1);
logv(29) = is_hold(2);
logv(30) = is_hold(3);
ctrl_log = logv;

end
