function [G, ctrl_log, sync_out] = afe_dq_ctrl_pwm(M, t_master, sync, p)
%AFE_DQ_CTRL_PWM  Control and PWM of one grid-forming AFE in a single MATLAB Function block.
%#codegen
%
%   [G, ctrl_log, sync_out] = afe_dq_ctrl_pwm(M, t_master, sync, p)
%
%   Source of the MATLAB Function afe_dq_forming_ctrl_pwm of grid_forming_dqctrl/grid_forming_dqctrl_mod1:
%   ../update_grid_forming_dqctrl.m loads this file into the block (edit here, then run it).
%
%   Equivalent of afe_dq_mod1/AFE_control (triggered subsystem afe_control) plus afe/sv_pwm (carrier,
%   TRGO, gate commands) of grid_forming_dq.slx (R2026b), written as one function so that the control
%   of one AFE counts as ONE nonvirtual block (MATLAB Home licence: 1000 nonvirtual blocks per model,
%   referenced models and library links included). The block runs at the fixed sample time p.pwm.tc,
%   the step of the Simscape local solver; the control runs on the rising edge of the TRGO flag
%   derived from the carrier of the local clock, exactly as the triggered subsystem of the model.
%
%   Inputs
%     M        measurement vector [14x1] in pu of the block afe_ssc.afe_two_level_lcl:
%              M(1:3) is_abc converter current (positive out of the bridge), M(4:6) uc_abc filter
%              capacitor voltage, M(7:9) ig_abc grid current (positive towards the grid),
%              M(10:12) ug_abc grid voltage without zero sequence, M(13) vdc/udc_nom, M(14) ic/ibez
%     t_master master time [s] (Clock of "global timing"/time_afe3 with k = 1, i.e. simulation time)
%     sync     [3x1] [theta; i_xi_ref; i_eta_ref] of the master (its output sync_out), read only in
%              slave mode; on a master leave it unconnected or grounded
%     p        parameter struct, scope "Parameter" in the Symbols pane of the block, built by
%              private/afe_module_param.m (p.pwm.*, p.ctrl.*); p.ctrl.slave (optional, default 0)
%              selects the slave mode
%   Outputs
%     G        gate commands [6x1] in V, order [a+; a-; b+; b-; c+; c-] (Q1..Q6 of the PWM library
%              block and G of the ssc block), p.pwm.gate_on / p.pwm.gate_off (15 V / -10 V)
%     ctrl_log control signals [37x1], indices in afe_log_index.m (held between two triggers,
%              t_loc, ramp and trgo updated every step)
%     sync_out [3x1] [theta; i_xi_ref; i_eta_ref] of the last control step (held between two
%              triggers): connect it to the sync input of the slave(s)
%
%   Master/slave (p.ctrl.slave = 1): converters in parallel on one load, e.g. on separate primaries of
%   one transformer. The master runs the whole chain below and forms the voltage; a slave runs its
%   current loop with the angle and the current references of the master (input sync) instead of its
%   phase generator and voltage loop, so that identical converters carry the same current in pu of
%   their own ibez. The slave still runs its FHT and logs u_xi/u_eta in the frame of the master; its
%   voltage PI stays at rest and clip_u is 0. Master and slaves need the same clock (k_time, carrier
%   phase, double update): the master runs before the slave in the same tc step (data dependency), so
%   the slave uses the values of the same trigger; with a carrier phase shift it uses those of the
%   last trigger of the master.
%
%   Chain reproduced (names of the blocks of grid_forming_dq.slx in brackets):
%     every step tc
%       local clock    t_loc = t_master*k_time*(1 + corr)              [global timing/time_afe1]
%       carrier        ramp = asin(sin(2*pi*fpwm*t_loc - phase - pi/2))/pi + 1/2   [ramp_up_down]
%       TRGO           ramp <= 2*fpwm*tc or ramp >= 1 - 2*fpwm*tc (double update)  [trgo_gen]
%       gates          upper on: ramp >= d + dead_time*fpwm, lower on: ramp <= d - dead_time*fpwm,
%                      d saturated in [m_low, m_up]                    [gate commands]
%     on the rising edge of TRGO (no trigger on the first evaluation, as the Trigger block)
%       acquisitions   quantizer (adc_q) and one-step delay of ug, is, ig (ig with gain -1), udc
%                      [acquisitions/* quantizzation and one step delay]
%       alignment      PI of (t_master - t_loc), saturated, back-calculation anti-windup, output
%                      corr applied from the next step                [phase_compensation_1]
%       FHT            first harmonic tracker on ug_alpha and ug_beta (port of
%                      first_harmonic_tracker.c, reset while t_master < fht_t_reset), positive
%                      sequence with the 1/2 gains                     [filter_and_transformation]
%       phase          free-running phase generator theta              [phase-generator]
%       voltage loop   dq vector PI on (u_xi, u_eta), limiter ixi_lim, clip flag at clip_thr_ug,
%                      integrator release while clipped                [dq_vector_pi]
%       current loop   dq vector PI on (i_xi, i_eta), unit-circle limiter   [current_ctrl]
%       SVPWM          port of sv_pwm_cm.c (inputs scaled by sqrt(3)/2, k_offset = (ugamma + 1)/2)
%                      [space_vector]
%
%   Differences from the block diagram (see README.md):
%     - the duties change at the trigger step without the 1/(tc*s + 1) filters td2tc_1..3
%     - the switching instants are quantized to tc (the Simscape local solver samples the gates
%       at tc anyway); the ramp of the trigger step is used for the gates of that step
%     - double precision instead of the single precision of the C-Caller blocks
%   The code follows grid_forming_dq.slx at commit e61afe1 (PR #1): positive-sequence gains +1/2 and
%   clip threshold of the voltage loop equal to its limiter radius (clip_thr_ug = ixi_lim).

NLOG = 37;

persistent initialized trgo_z corr_z x_align ug_z is_z ig_z udc_z ...
           fht_s1 fht_s2 fht_out th xd_u xq_u clip_u_z xd_i xq_i clip_i_z d_abc logv sync_z

if isempty(initialized)
    initialized = true;
    trgo_z   = true;                 % Trigger block "compatibility (no trigger on first evaluation)"
    corr_z   = 0;                    % local time correction (Unit Delay of "global timing")
    x_align  = 0;                    % integrator of the alignment PI
    ug_z     = zeros(3,1);           % one-step delays of the acquisitions
    is_z     = zeros(3,1);
    ig_z     = zeros(3,1);
    udc_z    = 0;
    fht_s1   = zeros(2,1);           % FHT state 1, [alpha; beta]
    fht_s2   = zeros(2,1);           % FHT state 2
    fht_out  = zeros(2,1);           % FHT output (state 1 of the previous step)
    th       = mod(p.ctrl.theta0, 2*pi);   % phase generator
    xd_u = 0; xq_u = 0; clip_u_z = 0;      % voltage loop PI
    xd_i = 0; xq_i = 0; clip_i_z = 0;      % current loop PI
    d_abc    = zeros(3,1);           % duties before the first trigger (Outport initial output)
    logv     = zeros(NLOG,1);
    sync_z   = zeros(3,1);           % [theta; i_xi_ref; i_eta_ref] of the last trigger (output sync_out)
end

m = M(:);

% ------------------------------------------------------------------ every step: local clock, carrier, TRGO
t_loc = t_master*p.ctrl.k_time*(1 + corr_z);
ramp  = asin(sin(2*pi*p.pwm.fpwm*t_loc - p.pwm.phase - pi/2))/pi + 1/2;
th_trgo = p.pwm.fpwm*p.pwm.tc*2;
if p.pwm.double_update ~= 0
    trgo = (ramp >= 0 && ramp <= th_trgo) || (ramp <= 1 && ramp >= 1 - th_trgo);
else
    trgo = (ramp >= 0 && ramp <= th_trgo);
end

if trgo && ~trgo_z
    % ============================================================== control step (triggered subsystem)
    ts   = p.ctrl.ts;                % control sample time (ts_afe)
    ts_i = p.ctrl.ts_int;            % sample time of the PI integrators (ts_inv in the model, = ts_afe)
    slave = false;                   % p.ctrl.slave is optional: parameter structs of older models have none
    if isfield(p.ctrl, 'slave')
        slave = p.ctrl.slave ~= 0;
    end

    % ---- acquisitions: the control uses the samples of the previous trigger (Unit Delay after the
    %      Quantizer), the delay states take the samples of this trigger
    ugd  = ug_z;
    isd  = is_z;
    igd  = ig_z;
    udcd = udc_z;
    q = p.ctrl.adc_q;
    ug_z  = q*round(m(10:12)/q);
    is_z  = q*round(m(1:3)/q);
    ig_z  = -q*round(m(7:9)/q);      % Gain -1 after the delay ("ig afe quantizzation and one step delay")
    udc_z = q*round(m(13)/q);

    % ---- alignment of the local clock to the master time (phase_compensation_1/alignment_eval_afe1/pi)
    e_al = t_master - t_loc;         % u_ref - u with u_ref = 0, u = -(master - local)
    P_al = p.ctrl.kp_align*e_al;
    y_al = P_al + p.ctrl.ki_align*ts*e_al + x_align;
    y_al = min(max(y_al, p.ctrl.lim_down_align), p.ctrl.lim_up_align);
    x_align = y_al - P_al;           % Sum3 -> Unit Delay4 (back-calculation anti-windup)
    corr_z  = y_al;                  % Goto local_time_corr_afe1, applied from the next step

    % ---- grid voltage: abc -> alpha/beta (abc2alphabeta), FHT, positive sequence
    ug_alpha = 2/3*(ugd(1) - 1/2*ugd(2) - 1/2*ugd(3));
    ug_beta  = 1/sqrt(3)*(ugd(2) - ugd(3));
    reset = t_master < p.ctrl.fht_t_reset;             % Step block: 1 until fht_t_reset, then 0
    w  = p.ctrl.fht_omega;
    dl = p.ctrl.fht_delta;
    a_ = -w*w;
    b_ = -dl*w;
    a11 = 1 + 0.5*a_*ts*ts;                            % first_harmonic_tracker_init
    a12 = ts + 0.5*b_*ts*ts;
    a21 = a_*ts + 0.5*a_*b_*ts*ts;
    a22 = 1 + b_*ts + 0.5*(a_ + b_*b_)*ts*ts;
    l1 = p.ctrl.fht_l1;
    l2 = p.ctrl.fht_l2;
    u_in  = [ug_alpha; ug_beta];
    u_hat = zeros(2,1);
    v_hat = zeros(2,1);
    for ch = 1:2
        if reset                                       % reset reloads the instance: states and output to zero
            fht_s1(ch)  = 0;
            fht_s2(ch)  = 0;
            fht_out(ch) = 0;
        end
        err = u_in(ch) - fht_out(ch);                  % first_harmonic_tracker_process
        s1n = l1*err + a11*fht_s1(ch) + a12*fht_s2(ch);
        s2n = l2*err + a21*fht_s1(ch) + a22*fht_s2(ch);
        fht_out(ch) = fht_s1(ch);                      % output = c1*state1 before the update
        fht_s1(ch)  = s1n;
        fht_s2(ch)  = s2n;
        u_hat(ch) = fht_out(ch);                       % output_pu_hat
        v_hat(ch) = fht_s2(ch)/w;                      % output_pu_hat_dot * (1/omega_fht)
    end
    u_fhtsr_alpha = 1/2*(u_hat(1) + v_hat(2));         % Sum (++): u_fht_alpha + v_fht_beta, Gain 1/2 (was -1/2 before e61afe1)
    u_fhtsr_beta  = 1/2*(u_hat(2) - v_hat(1));         % Sum1 (-+): -v_fht_alpha + u_fht_beta, Gain 1/2
    u_grid_mag = sqrt(u_fhtsr_alpha^2 + u_fhtsr_beta^2);

    % ---- free-running phase generator (grid_phase_gen): output of this step, then advance; a slave
    %      takes the angle of the master and keeps its own generator aligned to it
    theta = th;
    if slave
        theta = sync(1);
    end
    th = mod(theta + 2*pi*p.ctrl.fgrid*ts, 2*pi);
    if th >= 2*pi
        th = 0;
    end

    % ---- positive sequence in the rotating frame (sequences/alphabeta2xieta)
    u_xi  =  u_fhtsr_alpha*cos(theta) + u_fhtsr_beta*sin(theta);
    u_eta = -u_fhtsr_alpha*sin(theta) + u_fhtsr_beta*cos(theta);

    % ---- voltage loop: dq vector PI -> current references (afe_control/dq_vector_pi); a slave takes
    %      the references of the master and leaves its PI at rest
    if slave
        i_xi_ref  = sync(2);
        i_eta_ref = sync(3);
        clip_u    = 0;
    else
        [i_xi_ref, i_eta_ref, clip_u, xd_u, xq_u] = dq_vector_pi( ...
            p.ctrl.ug_ref - u_xi, p.ctrl.ueta_ref - u_eta, xd_u, xq_u, clip_u_z, ...
            p.ctrl.kp_ug, p.ctrl.ki_ug*ts_i, p.ctrl.clip_release*ts_i, p.ctrl.ixi_lim, p.ctrl.clip_thr_ug);
    end
    clip_u_z = clip_u;                                 % Unit Delay1 of pi_d/pi_q

    % ---- current loop (current_ctrl): converter current in the rotating frame, dq vector PI
    i_alpha = 2/3*(isd(1) - 1/2*isd(2) - 1/2*isd(3));  % uvw2alphabeta
    i_beta  = 2/3*(sqrt(3)/2*(isd(2) - isd(3)));
    i_xi  =  i_alpha*cos(theta) + i_beta*sin(theta);   % alphabeta2xieta
    i_eta = -i_alpha*sin(theta) + i_beta*cos(theta);
    [m_d, m_q, clip_i, xd_i, xq_i] = dq_vector_pi( ...
        i_xi_ref - i_xi, i_eta_ref - i_eta, xd_i, xq_i, clip_i_z, ...
        p.ctrl.kp_i, p.ctrl.ki_i*ts_i, p.ctrl.clip_release*ts_i, p.ctrl.u_lim, p.ctrl.u_lim);
    clip_i_z = clip_i;
    u_alpha = m_d*cos(theta) - m_q*sin(theta);         % xi_eta_to_alpha_beta
    u_beta  = m_d*sin(theta) + m_q*cos(theta);
    u_gamma = 0;                                       % zero_current_ctrl: ugamma_ctrl_afe = 0

    % ---- space vector modulator (space_vector: gains sqrt(3)/2, u_cm_comp, C Caller sv_pwm_cm)
    [da, db, dc] = sv_pwm_cm(u_alpha*sqrt(3)/2, u_beta*sqrt(3)/2, u_gamma*p.ctrl.u_cm, true);
    d_abc = [da; db; dc];

    % ---- log (indices: afe_log_index.m)
    logv(4)  = corr_z;
    logv(5)  = theta;
    logv(6:8)   = ugd;
    logv(9:11)  = isd;
    logv(12:14) = igd;
    logv(15) = udcd;
    logv(16) = u_fhtsr_alpha;
    logv(17) = u_fhtsr_beta;
    logv(18) = u_grid_mag;
    logv(19) = u_xi;
    logv(20) = u_eta;
    logv(21) = i_xi_ref;
    logv(22) = i_eta_ref;
    logv(23) = clip_u;
    logv(24) = i_xi;
    logv(25) = i_eta;
    logv(26) = m_d;
    logv(27) = m_q;
    logv(28) = clip_i;
    logv(29) = u_alpha;
    logv(30) = u_beta;
    logv(31:33) = d_abc;
    logv(34) = u_hat(1);
    logv(35) = v_hat(1);
    logv(36) = u_hat(2);
    logv(37) = v_hat(2);

    % ---- references for the slave(s)
    sync_z = [theta; i_xi_ref; i_eta_ref];
end
trgo_z = trgo;

% ------------------------------------------------------------------ every step: gate commands
dtf = p.pwm.dead_time*p.pwm.fpwm;                      % dead time as a fraction of the carrier period
G = p.pwm.gate_off*ones(6,1);
for k = 1:3
    dk = min(max(d_abc(k), p.pwm.m_low), p.pwm.m_up);  % Saturation m_low..m_up
    if ramp >= dk + dtf                                % upper switch: (m + dead_time*f) <= ramp
        G(2*k-1) = p.pwm.gate_on;
    end
    if ramp <= dk - dtf                                % lower switch: ramp <= (m - dead_time*f)
        G(2*k) = p.pwm.gate_on;
    end
end

logv(1) = t_loc;
logv(2) = ramp;
logv(3) = double(trgo);
ctrl_log = logv;
sync_out = sync_z;

end

% ======================================================================================================
function [md_sat, mq_sat, clip, xd, xq] = dq_vector_pi(ed, eq, xd, xq, clip_z, kp, ki_ts, rel_ts, lim, clip_thr)
%DQ_VECTOR_PI  dq vector PI of the model: blocks pi_d, pi_q, "vector lenght", bounder1/2, switch.
%   ed, eq      errors (reference - measure)
%   xd, xq      integrator states (Unit Delay2 of pi_d, pi_q)
%   clip_z      clip flag of the previous step (Unit Delay1 of pi_d, pi_q)
%   kp, ki_ts   proportional gain and integral gain already multiplied by the sample time
%   rel_ts      CTRPIFF_CLIP_RELEASE*ts, leak of the integrator while clipped
%   lim         radius of the output limiter (Switch1 threshold and gain of the bounders)
%   clip_thr    radius at which the clip flag is raised (Switch threshold of the bounders)
    if clip_z > 0.5
        xd_new = xd - rel_ts*xd;                       % Sum2: x - rel*ts*x
        md = kp*ed + xd;                               % Sum5 = P + Sum4, Sum4 = x + 0
        xq_new = xq - rel_ts*xq;
        mq = kp*eq + xq;
    else
        xd_new = xd + ki_ts*ed;                        % Sum4 = x + ki*ts*e
        md = kp*ed + xd_new;
        xq_new = xq + ki_ts*eq;
        mq = kp*eq + xq_new;
    end
    xd = xd_new;
    xq = xq_new;
    mag = sqrt(md^2 + mq^2);                           % "vector lenght"
    if mag >= lim                                      % bounder1/2: Switch1 (u2 >= Threshold)
        md_sat = md/mag*lim;
        mq_sat = mq/mag*lim;
    else
        md_sat = md;
        mq_sat = mq;
    end
    if mag >= clip_thr                                 % bounder1/2: Switch (u2 >= Threshold), OR in "switch"
        clip = 1;
    else
        clip = 0;
    end
end

% ======================================================================================================
function [da, db, dc] = sv_pwm_cm(ualpha, ubeta, ugamma, enable)
%SV_PWM_CM  Port of sv_pwm_cm_process (library/user_defined_functions/ccaller/src/sv_pwm_cm.c).
%   Duties da, db, dc in [0, 1] are the switch-on instants on the carrier (0 = bottom, 1 = top):
%   the upper switch is on while ramp >= d. k_offset = 0.5 is the standard SVPWM, 0 only V0,
%   1 only V7. The overmodulation branch of the C code (t0 < 0) computes the same expressions
%   as the linear branch, so it is not repeated here.
    k_offset = (ugamma + 1)/2;
    sq3 = sqrt(3);
    if enable
        angle = atan2(ubeta, ualpha);
        if angle >= 0 && angle <= pi/3                 % sector 1
            t2 = ubeta*2/sq3;
            t1 = ualpha - ubeta/sq3;
            t0 = 1 - t2 - t1;
            da = t0*k_offset;
            db = t1 + da;
            dc = t2 + db;
        elseif angle >= pi/3 && angle <= 2*pi/3        % sector 2
            t1 = -ualpha + ubeta/sq3;
            t2 = ualpha + ubeta/sq3;
            t0 = 1 - t2 - t1;
            db = t0*k_offset;
            da = t1 + db;
            dc = t2 + da;
        elseif angle >= 2*pi/3 && angle <= pi          % sector 3
            t2 = -ubeta/sq3 - ualpha;
            t1 = ubeta*2/sq3;
            t0 = 1 - t2 - t1;
            db = t0*k_offset;
            dc = t1 + db;
            da = t2 + dc;
        elseif angle >= -pi && angle <= -2*pi/3        % sector 4
            t1 = -2/sq3*ubeta;
            t2 = ubeta/sq3 - ualpha;
            t0 = 1 - t2 - t1;
            dc = t0*k_offset;
            db = t1 + dc;
            da = t2 + db;
        elseif angle >= -2*pi/3 && angle <= -pi/3      % sector 5
            t2 = ualpha - ubeta/sq3;
            t1 = -ualpha - ubeta/sq3;
            t0 = 1 - t2 - t1;
            dc = t0*k_offset;
            da = t1 + dc;
            db = t2 + da;
        else                                           % sector 6
            t1 = ualpha + ubeta/sq3;
            t2 = -ubeta*2/sq3;
            t0 = 1 - t2 - t1;
            da = t0*k_offset;
            dc = t1 + da;
            db = t2 + dc;
        end
    else
        da = 0.5;
        db = 0.5;
        dc = 0.5;
    end
end
