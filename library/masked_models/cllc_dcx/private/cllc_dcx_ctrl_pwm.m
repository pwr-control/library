function [G, ctrl_log] = cllc_dcx_ctrl_pwm(M, t_master, p)
%CLLC_DCX_CTRL_PWM  Modulator, synchronous rectifiers and control of one CLLC-DCX stage in a single MATLAB Function block.
%#codegen
%
%   [G, ctrl_log] = cllc_dcx_ctrl_pwm(M, t_master, p)
%
%   Source of the MATLAB Function cllc_dcx_ctrl_pwm of cllc_dcx/cllc_dcx_mod1: ../update_cllc_dcx.m loads this
%   file into the block (edit here, then run it).
%
%   Compact version of the control of sst_cllc_dcx.slx (pwr-control/solid-state-transformers, folder
%   theory_analysis_solid_state_transformer/sst_cllc_dcx_800V_800V_50kW): the modulator of the two full bridges
%   (both at 50 % duty, bridge 2 shifted by the angle phi), the synchronous-rectifier logic of the two bridges
%   (sr_gate_logic and sr1_gate_logic of the model) and the DC current / voltage PI of the stage, written as one
%   function so that the control of one DCX counts as ONE nonvirtual block (MATLAB Home licence: 1000 nonvirtual
%   blocks per model, referenced models and library links included). The block runs at the fixed sample time
%   p.pwm.tc, the step of the Simscape local solver; the control runs on the rising edge of the TRGO flag derived
%   from the carrier of the local clock, the modulator and the synchronous rectifiers run every step.
%
%   Inputs
%     M        measurement vector [15x1] in pu of the block cllc_ssc.cllc_dcx_single_phase, one tc behind (Unit
%              Delay meas_delay, no algebraic loop): M(1) u_dc1, M(2) i_dc1 (positive into dc1+), M(3) u_dc2,
%              M(4) i_dc2 (positive out of dc2+), M(5) i_r1, M(6) i_r2 (tank currents), M(7:8) u_b1, u_b2 (bridge
%              voltages), M(9:10) u_cr1, u_cr2, M(11:12) DC buses of the bridges, M(13) i_m, M(14) i_c1, M(15) i_c2
%              (DC-link capacitor currents, (+) -> (-))
%     t_master master time [s]: the Clock of the model, or the master time of the models with a global timing block
%     p        parameter struct, scope "Parameter" in the Symbols pane of the block: p.hw (the parameters of the
%              ssc block, read here only for the sign of the tank reactance), p.pwm and p.ctrl, see below and
%              ../cllc_dcx_param_example.m
%   Outputs
%     G        gate commands [8x1] in V, order [1a+; 1a-; 1b+; 1b-; 2a+; 2a-; 2b+; 2b-] (input G of the ssc
%              block), levels p.pwm.gate_on / p.pwm.gate_off (18 V / -3 V against Vth = 2.5 V)
%     ctrl_log control signals [24x1], indices in ../cllc_dcx_log_index.m (held between two triggers; the
%              carriers, TRGO, the bridge states and the tank currents are updated every step)
%
%   Chain (names of the blocks of sst_cllc_dcx.slx in brackets)
%     every step tc
%       local clock    t_loc = t_master*k_time*(1 + corr)                               [global timing]
%       carrier 1      ramp1 = asin(sin(ang - phase - pi/2))/pi + 1/2, triangle 0..1, ang = 2*pi*fpwm*t_loc
%                      (with the soft start below ang = 2*pi*integral of the swept frequency)  [modulator]
%       TRGO           ramp1 <= 2*f*tc (carrier bottom) or, with double_update, also ramp1 >= 1 - 2*f*tc
%       carrier 2      ramp2 = carrier 1 delayed by phi (bridge 2 lags bridge 1 for phi > 0); phi changes at
%                      the trigger, where ramp2 = |phi|/pi is far from the switching level 1/2 for |phi| < pi/2
%       acquisitions   average of u_dc1, i_dc1, u_dc2, i_dc2, i_c1, i_c2 over the control period (the 2*fpwm
%                      ripple of the DC quantities averages out, as with an anti-aliasing filter or ADC
%                      oversampling), quantized with adc_q at the trigger                 [acquisitions]
%       gates          bridge k in PWM: a+ and b- on while ramp >= 1/2 + dead_time*f, a- and b+ on while
%                      ramp <= 1/2 - dead_time*f (50 % duty, dead time around both edges)   [modulator]
%                      bridge k as synchronous rectifier: pair (a+, b-) on while the current entering midpoint
%                      a is above sr_i_on, pair (a-, b+) while it is below -sr_i_on, both off (body diodes)
%                      once |i| < sr_i_off, held in between (hysteresis); the current entering midpoint 2a is
%                      i_r2 = M(6), the one entering midpoint 1a is -i_r1 = -M(5)  [sr_gate_logic, sr1_gate_logic]
%     on the rising edge of TRGO (no trigger on the first evaluation, as the Trigger block)
%       alignment      PI of (t_master - t_loc), saturated, back-calculation anti-windup, output corr applied
%                      from the next step (zero gains: free-running local clock = master time)
%       mode 0         phi = phi0: open-loop DC transformer, the design use of the stage (DCX at fixed ratio,
%                      bridge 2 as synchronous rectifier; phi0 = 0 when bridge 2 is in PWM as well)
%       mode 1         current loop: PI of (i_ref - i_meas) -> phi, limited to +-phi_max, clip flag and
%                      integrator release while clipped (as the dq vector PI of the AFE blocks)
%       mode 2         voltage loop: PI of (u_ref - u_meas) -> i_ref, limited to +-i_lim, then the current loop
%                      of mode 1 (cascade)
%       i_meas, u_meas side 2 (p.ctrl.side = 2, default): u_meas = u_dc2, i_meas = i_dc2 + i_c2, the current that
%                      bridge 2 rectifies into DC link 2 (terminal current plus capacitor current); side 1:
%                      u_meas = u_dc1, i_meas = i_c1 - i_dc1, the current that bridge 1 rectifies into DC link 1.
%                      The terminal current alone is set by the load, not by the converter.
%       phi sign       with the fundamentals, the power from bridge 1 to bridge 2 is P = |V1||V2'| sin(phi)/X,
%                      X the series reactance of the tank at the switching frequency: phi > 0 carries power
%                      1 -> 2 above resonance (X > 0, inductive) and 2 -> 1 below it (X < 0, capacitive). The
%                      loops command phi = phi_sign*pdir*phi_pi with pdir = +1 (side 2 regulated: power towards
%                      side 2 for a positive phi_pi) or -1 (side 1), phi_sign = sign(X) from p.hw (both tanks
%                      referred to the primary, Lm neglected) or p.ctrl.phi_sign when given. Near resonance X is
%                      small (0.8 Ohm at fn = 0.95 for the 800 V / 50 kW stage: 50 kW at phi = 2.3 deg), so the
%                      gains of the current loop must be small; the loops are an option, mode 0 the normal use.
%
%   Parameters (all required unless marked optional)
%     p.pwm.tc            [s]   sample time of the block = Simscape local solver step (50e-9)
%     p.pwm.fpwm          [Hz]  switching frequency (50e3)
%     p.pwm.phase         [rad] phase of carrier 1 (0)
%     p.pwm.double_update       0: TRGO at the carrier bottom, 1: bottom and top
%     p.pwm.dead_time     [s]   dead time of each leg in PWM (300e-9); the SR logic adds no dead time, its
%                               hysteresis sr_i_off..sr_i_on plays that role
%     p.pwm.gate_on/off   [V]   gate levels (18 / -3)
%     p.pwm.t_enable      [s]   optional: all gates off and the PI at rest while t_master < t_enable (0)
%     p.pwm.f_start,      [Hz], [s] optional soft start: the switching frequency sweeps linearly from f_start
%     p.pwm.t_soft              down to fpwm in t_soft (above resonance the gain of the tank is low: the empty
%                               DC link of the other side charges without inrush); absent: no sweep
%     p.ctrl.ts           [s]   control period, 1/fpwm (1/(2*fpwm) with double update)
%     p.ctrl.k_time             local clock factor (1)
%     p.ctrl.kp_align, ki_align, lim_up_align, lim_down_align   alignment PI of the local clock (0, 0, 0, 0)
%     p.ctrl.adc_q        [pu]  quantization step of the acquisitions (1/4096)
%     p.ctrl.mode               0 open loop, 1 current loop, 2 voltage loop
%     p.ctrl.phi0         [rad] phase of bridge 2 in mode 0 (0)
%     p.ctrl.sr_mode_1          bridge 1: 0 PWM, 1 synchronous rectifier on -i_r1, 2 all gates off (diodes)
%     p.ctrl.sr_mode_2          bridge 2: 0 PWM (carrier 2), 1 synchronous rectifier on i_r2, 2 all gates off
%     p.ctrl.sr_i_on      [pu]  turn-on threshold of the synchronous rectifiers, |i| in pu of idc_nom (0.08)
%     p.ctrl.sr_i_off     [pu]  turn-off threshold, < sr_i_on (0.03)
%     p.ctrl.side               optional: regulated side, 2 (default) or 1
%     p.ctrl.phi_sign           optional: +1 / -1, overrides the sign computed from p.hw
%     p.ctrl.i_ref        [pu]  current reference of mode 1
%     p.ctrl.kp_i [rad/pu], ki_i [rad/(pu s)], phi_max [rad], clip_release [1/s]   current loop
%     p.ctrl.u_ref        [pu]  voltage reference of mode 2
%     p.ctrl.kp_u [pu/pu], ki_u [1/s], i_lim [pu]                                  voltage loop
%
%   Differences from the block diagram of sst_cllc_dcx.slx: the switching instants are quantized to tc (the
%   local solver samples the gates at tc anyway), the acquisitions are period averages instead of samples at
%   the trigger, double precision throughout, no device model (the losses of the switches are Ron only, no
%   thermal model).

NLOG = 24;

persistent initialized trgo_z corr_z x_align acc n_acc sr1_s sr2_s phi_z x_u clip_u_z x_i clip_i_z logv

if isempty(initialized)
    initialized = true;
    trgo_z   = true;                 % Trigger block "compatibility (no trigger on first evaluation)"
    corr_z   = 0;                    % local time correction (Unit Delay of "global timing")
    x_align  = 0;                    % integrator of the alignment PI
    acc      = zeros(6,1);           % accumulators of the acquisitions over the control period
    n_acc    = 0;
    sr1_s    = 0;                    % bridge states: +1 pair (a+, b-) on, -1 pair (a-, b+) on, 0 both off
    sr2_s    = 0;
    phi_z    = 0;                    % phase of bridge 2 (output of the last control step)
    if p.ctrl.mode == 0
        phi_z = p.ctrl.phi0;         % mode 0: the phase is applied from the first step
    end
    x_u = 0; clip_u_z = 0;           % voltage loop PI
    x_i = 0; clip_i_z = 0;           % current loop PI
    logv     = zeros(NLOG,1);
end

m = M(:);

% ------------------------------------------------------------------ optional fields of p
t_en = 0;
if isfield(p.pwm, 't_enable')
    t_en = p.pwm.t_enable;
end
f_end  = p.pwm.fpwm;
f0     = f_end;
t_soft = 0;
if isfield(p.pwm, 'f_start') && isfield(p.pwm, 't_soft')
    f0     = p.pwm.f_start;
    t_soft = p.pwm.t_soft;
end
side = 2;
if isfield(p.ctrl, 'side')
    side = p.ctrl.side;
end
if isfield(p.ctrl, 'phi_sign')
    phi_sign = p.ctrl.phi_sign;
else
    % sign of the series reactance of the two tanks referred to the primary, at the switching frequency
    w  = 2*pi*f_end;
    k2 = (p.hw.n1/p.hw.n2)^2;
    X  = w*(p.hw.Lr1 + k2*p.hw.Lr2) - (1/p.hw.Cr1 + k2/p.hw.Cr2)/w;
    if X >= 0
        phi_sign = 1;
    else
        phi_sign = -1;
    end
end
if side == 1
    pdir = -1;
else
    pdir = 1;
end
enable = t_master >= t_en;

% ------------------------------------------------------------------ every step: local clock, carriers, TRGO
t_loc = t_master*p.ctrl.k_time*(1 + corr_z);
if t_soft > 0 && t_loc < t_soft
    f_c = f0 + (f_end - f0)*t_loc/t_soft;                        % linear sweep f_start -> fpwm
    ang = 2*pi*(f0*t_loc + (f_end - f0)*t_loc^2/(2*t_soft));     % 2*pi * integral of f_c
else
    f_c = f_end;
    ang = 2*pi*((f0 + f_end)*t_soft/2 + f_end*(t_loc - t_soft));
end
ramp1 = asin(sin(ang - p.pwm.phase - pi/2))/pi + 1/2;
ramp2 = asin(sin(ang - p.pwm.phase - phi_z - pi/2))/pi + 1/2;
th_trgo = 2*f_c*p.pwm.tc;
if p.pwm.double_update ~= 0
    trgo = (ramp1 >= 0 && ramp1 <= th_trgo) || (ramp1 <= 1 && ramp1 >= 1 - th_trgo);
else
    trgo = (ramp1 >= 0 && ramp1 <= th_trgo);
end

% ---- acquisitions: the DC quantities are accumulated every step, the average is taken at the trigger
acc = acc + [m(1); m(2); m(3); m(4); m(14); m(15)];
n_acc = n_acc + 1;

if trgo && ~trgo_z
    % ============================================================== control step (triggered subsystem)
    ts = p.ctrl.ts;
    q  = p.ctrl.adc_q;
    a  = q*round(acc/(q*n_acc));                       % period average, quantized (ADC)
    acc(:) = 0;
    n_acc  = 0;
    u_dc1 = a(1);
    i_dc1 = a(2);
    u_dc2 = a(3);
    i_dc2 = a(4);
    i_c1  = a(5);
    i_c2  = a(6);
    if side == 1
        u_meas = u_dc1;
        i_meas = i_c1 - i_dc1;                         % current rectified by bridge 1 into DC link 1
    else
        u_meas = u_dc2;
        i_meas = i_dc2 + i_c2;                         % current rectified by bridge 2 into DC link 2
    end

    % ---- alignment of the local clock to the master time (as the AFE blocks)
    e_al = t_master - t_loc;
    P_al = p.ctrl.kp_align*e_al;
    y_al = P_al + p.ctrl.ki_align*ts*e_al + x_align;
    y_al = min(max(y_al, p.ctrl.lim_down_align), p.ctrl.lim_up_align);
    x_align = y_al - P_al;                             % back-calculation anti-windup
    corr_z  = y_al;                                    % applied from the next step

    % ---- loops
    i_ref  = 0;
    u_ref  = 0;
    clip_u = 0;
    phi_pi = 0;
    clip_i = 0;
    if ~enable || p.ctrl.mode == 0
        x_u = 0; clip_u_z = 0;                         % PI at rest
        x_i = 0; clip_i_z = 0;
        phi = p.ctrl.phi0;
    else
        if p.ctrl.mode == 2
            u_ref = p.ctrl.u_ref;
            [i_ref, clip_u, x_u] = pi_clip(u_ref - u_meas, x_u, clip_u_z, ...
                p.ctrl.kp_u, p.ctrl.ki_u*ts, p.ctrl.clip_release*ts, p.ctrl.i_lim);
        else
            i_ref = p.ctrl.i_ref;
        end
        clip_u_z = clip_u;
        [phi_pi, clip_i, x_i] = pi_clip(i_ref - i_meas, x_i, clip_i_z, ...
            p.ctrl.kp_i, p.ctrl.ki_i*ts, p.ctrl.clip_release*ts, p.ctrl.phi_max);
        clip_i_z = clip_i;
        phi = phi_sign*pdir*phi_pi;
    end
    phi_z = phi;

    % ---- log (indices: cllc_dcx_log_index.m)
    logv(4)  = corr_z;
    logv(6)  = phi;
    logv(10) = u_dc1;
    logv(11) = i_dc1;
    logv(12) = u_dc2;
    logv(13) = i_dc2;
    logv(14) = u_meas;
    logv(15) = i_meas;
    logv(16) = u_ref;
    logv(17) = i_ref;
    logv(18) = clip_u;
    logv(19) = phi_pi;
    logv(20) = clip_i;
    logv(21) = p.ctrl.mode;
end
trgo_z = trgo;

% ------------------------------------------------------------------ every step: gate commands
gon  = p.pwm.gate_on;
goff = p.pwm.gate_off;
dtf  = p.pwm.dead_time*f_c;                            % dead time as a fraction of the carrier period
G = goff*ones(8,1);
if enable
    % bridge 1: the current entering midpoint 1a is -i_r1 (i_r1 leaves 1a into the tank)
    [g1, sr1_s] = bridge_gates(p.ctrl.sr_mode_1, ramp1, -m(5), sr1_s, dtf, p.ctrl.sr_i_on, p.ctrl.sr_i_off, gon, goff);
    % bridge 2: the current entering midpoint 2a is i_r2
    [g2, sr2_s] = bridge_gates(p.ctrl.sr_mode_2, ramp2,  m(6), sr2_s, dtf, p.ctrl.sr_i_on, p.ctrl.sr_i_off, gon, goff);
    G(1:4) = g1;
    G(5:8) = g2;
else
    sr1_s = 0;
    sr2_s = 0;
end

logv(1)  = t_loc;
logv(2)  = ramp1;
logv(3)  = double(trgo);
logv(5)  = f_c;
logv(7)  = ramp2;
logv(8)  = sr1_s;
logv(9)  = sr2_s;
logv(22) = double(enable);
logv(23) = m(5);
logv(24) = m(6);
ctrl_log = logv;

end

% ======================================================================================================
function [Gb, s] = bridge_gates(mode, ramp, i_in, s, dtf, i_on, i_off, gon, goff)
%BRIDGE_GATES  Gate commands [a+; a-; b+; b-] and state of one full bridge.
%   mode 0  PWM at 50 % duty on the carrier ramp (0..1): a+ and b- on while ramp >= 1/2 + dtf, a- and b+ on
%           while ramp <= 1/2 - dtf (dtf = dead_time*f: dead time around both edges)
%   mode 1  synchronous rectifier on i_in, the current entering midpoint a (pu): s = +1 (a+, b- on) when
%           i_in > i_on, s = -1 (a-, b+ on) when i_in < -i_on, s = 0 (all off, body diodes) once |i_in| < i_off,
%           held between i_off and i_on (hysteresis)
%   mode 2  all gates off (diode rectifier)
%   s       bridge state: +1 pair (a+, b-) on, -1 pair (a-, b+) on, 0 both pairs off
    Gb = goff*ones(4,1);
    if mode == 1
        if i_in > i_on
            s = 1;
        elseif i_in < -i_on
            s = -1;
        elseif abs(i_in) < i_off
            s = 0;
        end
    elseif mode == 0
        s = 0;
        if ramp >= 0.5 + dtf
            s = 1;
        elseif ramp <= 0.5 - dtf
            s = -1;
        end
    else
        s = 0;
    end
    if s > 0
        Gb(1) = gon;                                   % a+
        Gb(4) = gon;                                   % b-
    elseif s < 0
        Gb(2) = gon;                                   % a-
        Gb(3) = gon;                                   % b+
    end
end

% ======================================================================================================
function [y, clip, x] = pi_clip(e, x, clip_z, kp, ki_ts, rel_ts, lim)
%PI_CLIP  PI with output limiter +-lim, clip flag and integrator release while clipped: the scalar version of
%   dq_vector_pi of the AFE blocks (pi_ctrl of the library with CTRPIFF_CLIP_RELEASE).
%   e        error (reference - measure)
%   x        integrator state
%   clip_z   clip flag of the previous step
%   kp       proportional gain, ki_ts integral gain already multiplied by the sample time
%   rel_ts   clip_release*ts, leak of the integrator while clipped (the input is then ignored)
%   lim      limit of the output, also the threshold of the clip flag
    if clip_z > 0.5
        x_new = x - rel_ts*x;
        y = kp*e + x;
    else
        x_new = x + ki_ts*e;
        y = kp*e + x_new;
    end
    x = x_new;
    if abs(y) >= lim
        clip = 1;
        if y > 0
            y = lim;
        else
            y = -lim;
        end
    else
        clip = 0;
    end
end
