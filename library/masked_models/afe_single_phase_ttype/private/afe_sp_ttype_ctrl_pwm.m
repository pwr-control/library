function [G, ctrl_log, sync_out] = afe_sp_ttype_ctrl_pwm(M, t_master, sync, p)
%AFE_SP_TTYPE_CTRL_PWM  Control and three-level PWM of one single-phase T-type AFE in a single MATLAB Function block.
%#codegen
%
%   [G, ctrl_log, sync_out] = afe_sp_ttype_ctrl_pwm(M, t_master, sync, p)
%
%   Source of the MATLAB Function afe_sp_ttype_ctrl_pwm of afe_single_phase_ttype/afe_single_phase_ttype_mod1:
%   ../update_afe_single_phase_ttype.m loads this file into the block (edit here, then run it).
%
%   Compact version of "single phase inverter control" of single_phase_inverter_modA/B of sst_cllc_ttype_inv.slx
%   (pwr-control/solid-state-transformers, folder sst_based_on_full_bridge_ttype_inverter/
%   sst_single_phase_cllc_single_phase_ttype_inv): the acquisitions, the single-phase PLL (single_phase_pll:
%   Park PLL with the virtual quadrature component, double integrator observer), the current loop
%   (single_phase_current_control: first harmonic tracker on the current, dq vector PI with the DC-link
%   feed-forward, dq -> alpha) and the modulator single_phase_three_levels_PWM_generator_with_global_TRGO
%   (carrier, TRGO, gate commands of the two T-type legs), written as one function so that the control of one
%   converter counts as ONE nonvirtual block (MATLAB Home licence: 1000 nonvirtual blocks per model, referenced
%   models and library links included). Same structure as afe_dq_ctrl_pwm.m (grid_forming), afe_follower_ctrl_pwm
%   (grid_following) and cllc_dcx_ctrl_pwm.m (cllc_dcx): the block runs at the fixed sample time p.pwm.tc, the step
%   of the Simscape local solver; the control runs on the rising edge of the TRGO flag derived from the carrier
%   of the local clock, the gate commands are computed every step.
%
%   Inputs
%     M        measurement vector [13x1] in pu of the block afe_ttype_ssc.afe_single_phase_ttype, one tc behind
%              (Unit Delay meas_delay, no algebraic loop): M(1) i_s converter current (inductor of line a, positive
%              out of the bridge), M(2) i_a terminal current, M(3) u_ac terminal voltage a - b, M(4) u_s bridge
%              voltage, M(5) udc, M(6) udc_p (dc+ - np), M(7) udc_n (np - dc-), M(8) i_dc (into dc+), M(9) i_np,
%              M(10:11) bank currents, M(12) i_cf, M(13) i_s2 (inductor of line b)
%     t_master master time [s]: the Clock of the model, or the master time of the models with a global timing block
%     sync     [3x1] [theta_hat; m_d; m_q] of the master (its output sync_out), read only in slave mode; on a
%              master leave it unconnected or grounded
%     p        parameter struct, scope "Parameter" in the Symbols pane of the block: p.hw (the parameters of the
%              ssc block, read here for ubez/udc_nom only), p.pwm and p.ctrl, see below and
%              ../afe_single_phase_ttype_param_example.m
%   Outputs
%     G        gate commands [8x1] in V, order [Q1u; Q2u; Q3u; Q4u; Q1v; Q2v; Q3v; Q4v] (input G of the ssc block),
%              levels p.pwm.gate_on / p.pwm.gate_off (15 V / -10 V against Vth = 2.5 V)
%     ctrl_log control signals [32x1], indices in ../afe_single_phase_ttype_log_index.m (held between two
%              triggers; t_loc, ramp, trgo, m and enable are updated every step)
%     sync_out [3x1] [theta_hat; m_d; m_q] of the last control step (held between two triggers): connect it to
%              the sync input of the slave(s)
%
%   Master/slave (p.ctrl.slave = 1): modules in series on one line, as the two modules of the SST bench (module B
%   applies the voltage command udq_ctrl_out_modA of module A with its own PLL angle). The master runs the whole
%   chain below; a slave runs its acquisitions, its PLL and its FHT (for the log), skips the loops and applies
%   m_d, m_q of the master (input sync) rotated with its own PLL angle, so that identical modules in series
%   produce the same voltage. Master and slaves need the same clock (k_time, carrier phase, double update): the
%   master runs before the slave in the same tc step (data dependency), so the slave uses the command of the
%   same trigger.
%
%   Chain (names of the blocks of sst_cllc_ttype_inv.slx in brackets)
%     every step tc
%       local clock    t_loc = t_master*k_time*(1 + corr)                               [global timing]
%       carrier        ramp = asin(sin(2*pi*fpwm*t_loc - phase - pi/2))/pi + 1/2, triangle 0..1
%                      [pwm modulator/ramp_up_down]
%       TRGO           ramp <= 2*fpwm*tc (carrier bottom) or, with double_update, also ramp >= 1 - 2*fpwm*tc
%       gates          three-level modulation of leg u with the reference m and of leg v with -m, each leg as
%                      modulator_p1/n1 (modulator_p2/n2) of the library block: m >= 0: Q2 on, Q1 on while
%                      ramp < m - dead_time*fpwm (duty m), Q3 on while ramp >= m + dead_time*fpwm; m < 0: Q3 on,
%                      Q4 on while ramp > 1 + m + dead_time*fpwm (duty -m), Q2 on while ramp <= 1 + m - dead_time*fpwm.
%                      m saturated in [m_low, m_up]. The leg output averages m*udc/2 against the neutral point,
%                      the bridge voltage m*udc. All gates off until the first control step with
%                      t_master >= t_enable.   [gate commands]
%     on the rising edge of TRGO (no trigger on the first evaluation, as the Trigger block)
%       acquisitions   quantizer (adc_q) and one-step delay of i_s (with the optional Gaussian noise i_noise_std,
%                      the Band-Limited White Noise of the model), u_ac, udc, udc_p, udc_n
%                      [acquisition_and_scaling_*, Zero-Order Hold + Unit Delay of single_phase_inverter_ctrl]
%       alignment      PI of (t_master - t_loc), saturated, back-calculation anti-windup, output corr applied
%                      from the next step (zero gains: free-running local clock = master time)
%       PLL            [single_phase_pll] on ug = u_ac/ug_nom (pu of the nominal grid amplitude, as ugrid_pu of
%                      the model): alpha = ug, beta = virtual quadrature component of the previous step;
%                      xi/eta with the PLL angle theta; first-order low pass (tau = pll_tau) of xi and eta, the
%                      filtered vector rotated back to alpha/beta gives the virtual beta of the next step
%                      [uxi_pll_flt, ueta_pll_flt, xieta2alphabeta]; PI on eta (pll_kp, pll_ki, limit +-pll_lim,
%                      back-calculation) [pi-ctrl]; theta += omega_nom*ts*(1 + PI), wrapped to [-pi, pi)
%                      [omega_int_ts, bounder2]; double integrator observer on theta (obs_l1, obs_l2) gives
%                      theta_hat, the angle of the control, and omega_hat [double_integrator_observer]
%       FHT            first harmonic tracker on the acquired current: x(k+1) = Ad*x + Ld*(i - x1), with
%                      Ad = I + [0 1; -w^2 -delta*w]*ts (forward Euler, as the Simulink block FHTalpha of the
%                      model; the C code of the library uses a second-order discretization), i_alpha = x1,
%                      i_beta = -x2/w: fundamental of the current and its quadrature  [i2alphabeta/FHTalpha]
%       references     mode 0: i_d_ref steps to i_ref at t_ref with the slew i_ref_slew (Step + Rate Limiter of
%                      inverter_current_output_pu_reference), i_q_ref = iq_ref; positive i_d: current out of the
%                      bridge in phase with the terminal voltage, power from the DC link to the AC side
%                      mode 1: DC-link voltage loop: udc_ref reached through a first-order low pass (udc_tau)
%                      from the voltage measured at the first trigger, PI (kp_udc, ki_udc) on udc_ref - udc_f
%                      (udc_f = udc averaged over one grid period, udc_ma: rejects the 2*fgrid ripple of the
%                      single-phase DC link and the fgrid ripple that a DC offset of the current produces, which
%                      through the loop would feed the offset back; then the optional low pass udc_meas_tau),
%                      saturation +-i_lim with back-calculation, i_d_ref = -y (current INTO the bridge when the
%                      DC link must charge, as grid_following), i_q_ref = iq_ref
%       current loop   i_d, i_q = alpha/beta -> dq with theta_hat [alphabeta2dq]; dq vector PI (kp_i, ki_i, limiter
%                      u_lim with clip flag and integrator release while clipped, outputs divided by the
%                      acquired udc saturated at udc_min: DC-link feed-forward of the library block dq_vector_pi)
%                      -> m_d, m_q [dq_vector_pi]; m = m_d*cos(theta_hat) - m_q*sin(theta_hat), the alpha
%                      component [dq2alphabeta]; a slave takes m_d, m_q from sync(2:3)
%
%   Parameters (all required unless marked optional)
%     p.hw.ubez, p.hw.udc_nom  [V]  bases of the ssc block (read for the log only)
%     p.pwm.tc            [s]   sample time of the block = Simscape local solver step
%     p.pwm.fpwm          [Hz]  carrier frequency (4e3)
%     p.pwm.phase         [rad] phase of the carrier (0)
%     p.pwm.double_update       0: TRGO at the carrier bottom, 1: bottom and top (control at 2*fpwm)
%     p.pwm.dead_time     [s]   dead time of the complementary pairs Q1/Q3 and Q4/Q2 (300e-9)
%     p.pwm.gate_on/off   [V]   gate levels (15 / -10)
%     p.pwm.m_up, m_low         limits of the modulation index (1, -1)
%     p.pwm.t_enable      [s]   optional: all gates off and the loops at rest while t_master < t_enable (0)
%     p.ctrl.ts           [s]   control period, 1/fpwm (1/(2*fpwm) with double update)
%     p.ctrl.k_time             local clock factor (1)
%     p.ctrl.kp_align, ki_align, lim_up_align, lim_down_align   alignment PI of the local clock (0, 0, 0, 0)
%     p.ctrl.adc_q        [pu]  quantization step of the acquisitions (1/2048)
%     p.ctrl.i_noise_std  [pu]  optional: rms of the Gaussian noise added to the current sample (0)
%     p.ctrl.omega_nom    [rad/s] nominal grid pulsation
%     p.ctrl.ug_nom       [pu]  nominal grid amplitude in pu of ubez (normalization of the PLL input)
%     p.ctrl.pll_kp, pll_ki, pll_lim   PI of the PLL on eta, output in pu of omega_nom (1, 0, 2)
%     p.ctrl.pll_tau      [s]   time constant of the low pass of xi and eta (2/omega_nom)
%     p.ctrl.obs_l1, obs_l2     gains of the double integrator observer (poles [-1 -4]*omega_nom)
%     p.ctrl.fht_omega    [rad/s], fht_delta, fht_l1, fht_l2   first harmonic tracker of the current
%     p.ctrl.mode               0 current references from p.ctrl, 1 DC-link voltage loop
%     p.ctrl.slave              optional: 1 = slave of the block wired to sync (0)
%     p.ctrl.i_ref        [pu]  current reference of mode 0 (pu of ibez), t_ref [s], i_ref_slew [pu/s]
%     p.ctrl.iq_ref       [pu]  reactive current reference (0)
%     p.ctrl.udc_ref      [pu]  DC-link voltage reference of mode 1, kp_udc [pu/pu], ki_udc [1/s], i_lim [pu],
%                               udc_tau [s] (reference low pass), udc_ma (optional: 1 = moving average of the
%                               measurement over one grid period, the default), udc_meas_tau [s] (measurement low
%                               pass after the average, 0 = none)
%     p.ctrl.kp_i [pu/pu], ki_i [1/s], u_lim [pu], clip_release [1/s], udc_min [pu]   current loop
%
%   Differences from the block diagram of sst_cllc_ttype_inv.slx: the switching instants are quantized to tc (the
%   local solver samples the gates at tc anyway), no 1/(tc*s + 1) filters on the modulation index, no 2*dead_time
%   blanking of the "always on" neutral switch at the carrier extremes (the library modulator switches Q2 off
%   around the carrier top in the positive half-wave and Q3 off around the carrier bottom in the negative one),
%   the PLL reads the terminal voltage of the block (the model reads the line EMF), double precision throughout,
%   no device model (the losses of the switches are Ron only, no thermal model). At the enable instant the
%   integrators of the current PI are pre-loaded with the terminal voltage (bumpless start: the bridge starts at
%   the grid voltage, no inrush), where the model runs its loop from t = 0 with the grid starting from zero.
%   The DC-link voltage loop (mode 1) is not in the model (its DC link is fed by the DCX): it is the loop of
%   grid_following with the moving average on the measurement.

NLOG = 32;
NBUF = 1024;                                      % moving average buffer: ts >= 20 us at 50 Hz

persistent initialized trgo_z corr_z x_align is_z uac_z udc_z udcp_z udcn_z ...
           th ubeta_z xi_in_z eta_in_z xi_f eta_f x_pll x_obs fht_x ...
           ref_z udc_ref_f udc_f udc_buf buf_k x_udc xd_i xq_i clip_i_z enable_z m_z sync_z logv

if isempty(initialized)
    initialized = true;
    trgo_z   = true;                 % Trigger block "compatibility (no trigger on first evaluation)"
    corr_z   = 0;                    % local time correction (Unit Delay of "global timing")
    x_align  = 0;                    % integrator of the alignment PI
    is_z = 0; uac_z = 0; udc_z = 0; udcp_z = 0; udcn_z = 0;   % one-step delays of the acquisitions
    th       = 0;                    % PLL angle (Unit Delay1 of single_phase_pll)
    ubeta_z  = 0;                    % virtual quadrature component (ubeta_pll)
    xi_in_z = 0; eta_in_z = 0;       % inputs of the low-pass filters, one step behind
    xi_f = 0; eta_f = 0;             % outputs of the low-pass filters
    x_pll    = 0;                    % integrator of the PLL PI
    x_obs    = zeros(2,1);           % double integrator observer state [theta; omega]
    fht_x    = zeros(2,1);           % first harmonic tracker state
    ref_z    = 0;                    % rate-limited current reference (mode 0)
    udc_ref_f = -1;                  % filtered DC-link reference (mode 1), set at the first trigger
    udc_f    = -1;                   % filtered DC-link measurement, set at the first trigger
    udc_buf  = zeros(NBUF,1);        % samples of the last grid period (moving average of the DC-link voltage)
    buf_k    = 0;                    % index of the last sample written
    x_udc    = 0;                    % integrator of the DC-link PI
    xd_i = 0; xq_i = 0; clip_i_z = 0;      % current loop PI
    enable_z = false;                % enable state of the last control step: gates and bumpless start of the PI
    m_z      = 0;                    % modulation index (held between two triggers)
    sync_z   = zeros(3,1);           % [theta_hat; m_d; m_q] of the last trigger (output sync_out)
    logv     = zeros(NLOG,1);
end

m = M(:);

% ------------------------------------------------------------------ optional fields of p
t_en = 0;
if isfield(p.pwm, 't_enable')
    t_en = p.pwm.t_enable;
end
slave = false;
if isfield(p.ctrl, 'slave')
    slave = p.ctrl.slave ~= 0;
end
i_noise = 0;
if isfield(p.ctrl, 'i_noise_std')
    i_noise = p.ctrl.i_noise_std;
end
udc_ma = true;
if isfield(p.ctrl, 'udc_ma')
    udc_ma = p.ctrl.udc_ma ~= 0;
end
enable = t_master >= t_en;

% ------------------------------------------------------------------ every step: local clock, carrier, TRGO
t_loc = t_master*p.ctrl.k_time*(1 + corr_z);
ramp  = asin(sin(2*pi*p.pwm.fpwm*t_loc - p.pwm.phase - pi/2))/pi + 1/2;
th_trgo = 2*p.pwm.fpwm*p.pwm.tc;
if p.pwm.double_update ~= 0
    trgo = (ramp >= 0 && ramp <= th_trgo) || (ramp <= 1 && ramp >= 1 - th_trgo);
else
    trgo = (ramp >= 0 && ramp <= th_trgo);
end

if trgo && ~trgo_z
    % ============================================================== control step (triggered subsystem)
    ts = p.ctrl.ts;
    q  = p.ctrl.adc_q;

    % ---- acquisitions: the control uses the samples of the previous trigger (Zero-Order Hold + Unit Delay),
    %      the delay states take the samples of this trigger
    isd   = is_z;
    uacd  = uac_z;
    udcd  = udc_z;
    udcpd = udcp_z;
    udcnd = udcn_z;
    i_raw = m(1);
    if i_noise > 0
        i_raw = i_raw + i_noise*randn;             % Band-Limited White Noise of acquisition_and_scaling_current
    end
    is_z   = q*round(i_raw/q);
    uac_z  = q*round(m(3)/q);
    udc_z  = q*round(m(5)/q);
    udcp_z = q*round(m(6)/q);
    udcn_z = q*round(m(7)/q);
    if udc_ref_f < 0                               % first trigger: the DC-link filters start from the measurement
        udc_ref_f = udc_z;
        udc_f     = udc_z;
        udc_buf(:) = udc_z;
    end

    % ---- alignment of the local clock to the master time (as the AFE blocks)
    e_al = t_master - t_loc;
    P_al = p.ctrl.kp_align*e_al;
    y_al = P_al + p.ctrl.ki_align*ts*e_al + x_align;
    y_al = min(max(y_al, p.ctrl.lim_down_align), p.ctrl.lim_up_align);
    x_align = y_al - P_al;                         % back-calculation anti-windup
    corr_z  = y_al;                                % applied from the next step

    % ---- single-phase PLL (single_phase_pll): Park PLL with the virtual quadrature component
    ug    = uacd/p.ctrl.ug_nom;                    % pu of the nominal grid amplitude (ugrid_pu of the model)
    theta = th;                                    % Unit Delay1: angle of this step
    a_pll = ts/p.ctrl.pll_tau;                     % discrete-time-low-pass-filter: y(k) = ts/tau*x(k-1) + (1 - ts/tau)*y(k-1)
    xi_f  = a_pll*xi_in_z  + (1 - a_pll)*xi_f;
    eta_f = a_pll*eta_in_z + (1 - a_pll)*eta_f;
    ubeta = xi_f*sin(theta) + eta_f*cos(theta);    % xieta2alphabeta: beta of the filtered vector (ubeta_pll)
    u_xi  =  ug*cos(theta) + ubeta*sin(theta);     % alphabeta2xieta with alpha = ug, beta = ubeta
    u_eta = -ug*sin(theta) + ubeta*cos(theta);
    xi_in_z  = u_xi;                               % inputs of the filters for the next step
    eta_in_z = u_eta;
    ubeta_z  = ubeta;
    P_pll = p.ctrl.pll_kp*u_eta;                   % pi-ctrl: x = -eta, xref = 0 -> e = eta
    y_pll = P_pll + p.ctrl.pll_ki*ts*u_eta + x_pll;
    y_pll = min(max(y_pll, -p.ctrl.pll_lim), p.ctrl.pll_lim);
    x_pll = y_pll - P_pll;                         % back-calculation anti-windup
    omega_pll_pu = 1 + y_pll;                      % Sum1: PI output + 1
    th = wrap_pi(theta + p.ctrl.omega_nom*ts*omega_pll_pu);     % omega_int_ts, Sum, bounder2 -> Unit Delay1
    % double integrator observer on the PLL angle: theta_hat is the angle of the control
    theta_hat = wrap_pi(x_obs(1));                 % Gain2 (Cso), bounder2
    e_obs = wrap_pi(theta - theta_hat);            % Sum (-+), bounder1
    omega_hat = x_obs(2);                          % Selector (index 2) of the Unit Delay output
    x1n = wrap_pi(x_obs(1) + ts*x_obs(2) + p.ctrl.obs_l1*e_obs);   % Adso*x + Ldso*e (Adso = [1 ts; 0 1]); the
    x2n = x_obs(2) + p.ctrl.obs_l2*e_obs;                          % angle state is wrapped (the output is wrapped anyway)
    x_obs = [x1n; x2n];
    omega_hat_pu = omega_hat/p.ctrl.omega_nom;     % kp3 (1/omega_grid_nom)

    % ---- first harmonic tracker on the current (i2alphabeta/FHTalpha): fundamental and quadrature
    w  = p.ctrl.fht_omega;
    dl = p.ctrl.fht_delta;
    i_alpha = fht_x(1);                            % Selector 1 of the Unit Delay output
    i_beta  = -fht_x(2)/w;                         % Gain3: -1/omega_base
    e_fht = isd - fht_x(1);                        % Sum (-+): u - Cfht*x
    f1n = fht_x(1) + ts*fht_x(2) + p.ctrl.fht_l1*e_fht;                       % Ad_fht = I + Afht*ts
    f2n = -w*w*ts*fht_x(1) + (1 - dl*w*ts)*fht_x(2) + p.ctrl.fht_l2*e_fht;
    fht_x = [f1n; f2n];
    i_d =  i_alpha*cos(theta_hat) + i_beta*sin(theta_hat);          % alphabeta2dq
    i_q = -i_alpha*sin(theta_hat) + i_beta*cos(theta_hat);

    % ---- references
    udc_ref = 0;
    e_udc   = 0;
    sat_udc = 0;
    i_q_ref = p.ctrl.iq_ref;
    if p.ctrl.mode == 1
        % DC-link voltage loop: filtered reference, filtered measurement, PI with back-calculation
        a_r = ts/p.ctrl.udc_tau;
        udc_ref_f = udc_ref_f + a_r*(p.ctrl.udc_ref - udc_ref_f);
        udc_ref = udc_ref_f;
        udc_m = udcd;
        if udc_ma                                  % moving average over one grid period (N samples)
            N = min(max(round(2*pi/(p.ctrl.omega_nom*ts)), 1), NBUF);
            buf_k = buf_k + 1;
            if buf_k > N
                buf_k = 1;
            end
            udc_buf(buf_k) = udcd;
            acc = 0;
            for k = 1:N
                acc = acc + udc_buf(k);
            end
            udc_m = acc/N;
        end
        if p.ctrl.udc_meas_tau > 0
            a_m = ts/p.ctrl.udc_meas_tau;
            udc_f = udc_f + a_m*(udc_m - udc_f);
        else
            udc_f = udc_m;
        end
        if enable && ~slave
            e_udc = udc_ref - udc_f;
            P_udc = p.ctrl.kp_udc*e_udc;
            y_udc = P_udc + p.ctrl.ki_udc*ts*e_udc + x_udc;
            y_sat = min(max(y_udc, -p.ctrl.i_lim), p.ctrl.i_lim);
            x_udc = y_sat - P_udc;
            sat_udc = double(y_sat ~= y_udc);
            i_d_ref = -y_sat;                      % current INTO the bridge charges the DC link
        else
            x_udc = 0;
            i_d_ref = 0;
        end
        ref_z = i_d_ref;
    else
        % current reference: step at t_ref, rate limiter i_ref_slew
        target = 0;
        if t_master >= p.ctrl.t_ref
            target = p.ctrl.i_ref;
        end
        dref = min(max(target - ref_z, -p.ctrl.i_ref_slew*ts), p.ctrl.i_ref_slew*ts);
        ref_z = ref_z + dref;
        i_d_ref = ref_z;
        if ~enable
            ref_z = 0;
            i_d_ref = 0;
        end
    end

    % ---- current loop (dqpi_current_controller): dq vector PI with the DC-link feed-forward
    clip_i = 0;
    if ~enable
        xd_i = 0; xq_i = 0;                        % PI at rest
        m_d = 0;
        m_q = 0;
    elseif slave
        m_d = sync(2);                             % voltage command of the master (udq_ctrl_out_ref of module B)
        m_q = sync(3);
    else
        if ~enable_z
            % first control step after the enable: the integrators of the PI pre-loaded with the terminal
            % voltage, so that the bridge starts at the grid voltage (bumpless start, no inrush); the PI
            % output is a voltage in pu of udc_nom (the feed-forward divides it by udc). The PLL frame lags
            % the grid vector by one control step (the acquisition delay) and the modulator holds the index
            % for half a step more, so (u_xi, u_eta) is rotated by 1.5*omega*ts
            k_ff = p.ctrl.ug_nom*p.hw.ubez/p.hw.udc_nom;
            dth  = 1.5*p.ctrl.omega_nom*omega_pll_pu*ts;
            xd_i = k_ff*(u_xi*cos(dth) - u_eta*sin(dth));
            xq_i = k_ff*(u_xi*sin(dth) + u_eta*cos(dth));
        end
        udc_ff = max(udcd, p.ctrl.udc_min);        % Saturation of dq_vector_pi (lower limit 0.25)
        [m_d, m_q, clip_i, xd_i, xq_i] = dq_vector_pi( ...
            i_d_ref - i_d, i_q_ref - i_q, xd_i, xq_i, clip_i_z, ...
            p.ctrl.kp_i, p.ctrl.ki_i*ts, p.ctrl.clip_release*ts, p.ctrl.u_lim, udc_ff);
    end
    clip_i_z = clip_i;
    m_z = m_d*cos(theta_hat) - m_q*sin(theta_hat);  % dq2alphabeta: alpha component -> modulation index

    % ---- log (indices: afe_single_phase_ttype_log_index.m)
    logv(4)  = corr_z;
    logv(5)  = theta;
    logv(6)  = theta_hat;
    logv(7)  = omega_hat_pu;
    logv(8)  = uacd;
    logv(9)  = isd;
    logv(10) = udcd;
    logv(11) = udcpd;
    logv(12) = udcnd;
    logv(13) = u_xi;
    logv(14) = u_eta;
    logv(15) = ubeta;
    logv(16) = i_alpha;
    logv(17) = i_beta;
    logv(18) = i_d;
    logv(19) = i_q;
    logv(20) = i_d_ref;
    logv(21) = i_q_ref;
    logv(22) = m_d;
    logv(23) = m_q;
    logv(24) = clip_i;
    logv(26) = udc_ref;
    logv(27) = e_udc;
    logv(28) = sat_udc;
    logv(30) = p.ctrl.mode;
    logv(31) = double(slave);
    logv(32) = udc_f;

    % ---- command for the slave(s)
    sync_z = [theta_hat; m_d; m_q];
    enable_z = enable;
end
trgo_z = trgo;

% ------------------------------------------------------------------ every step: gate commands
% The gates follow the enable state of the last control step (enable_z), not t_master directly: the bridge
% starts switching at the first enabled control step, with the pre-loaded modulation index, and not between two
% triggers with the stale one (a zero index against the grid voltage for up to one control period).
gon  = p.pwm.gate_on;
goff = p.pwm.gate_off;
dtf  = p.pwm.dead_time*p.pwm.fpwm;                 % dead time as a fraction of the carrier period
mi   = min(max(m_z, p.pwm.m_low), p.pwm.m_up);     % Saturation m_low..m_up of the modulator
G = goff*ones(8,1);
if enable_z
    G(1:4) = ttype_leg_gates( mi, ramp, dtf, gon, goff);   % leg u: +m
    G(5:8) = ttype_leg_gates(-mi, ramp, dtf, gon, goff);   % leg v: -m
end

logv(1)  = t_loc;
logv(2)  = ramp;
logv(3)  = double(trgo);
logv(25) = mi;
logv(29) = double(enable_z);
ctrl_log = logv;
sync_out = sync_z;

end

% ======================================================================================================
function Gl = ttype_leg_gates(mk, ramp, dtf, gon, goff)
%TTYPE_LEG_GATES  Gate commands [Q1; Q2; Q3; Q4] of one T-type leg with the reference mk in [-1, 1] on the
%   carrier ramp (0..1): modulator_p1 and modulator_n1 of single_phase_three_levels_PWM_modulator.
%   mk >= 0   Q2 on (neutral path ready), Q1 on while ramp < mk - dtf (duty mk), Q3 on while ramp >= mk + dtf
%   mk < 0    Q3 on, Q4 on while ramp > 1 + mk + dtf (duty -mk), Q2 on while ramp <= 1 + mk - dtf
%   dtf = dead_time*fpwm: dead time between Q1 and Q3 (Q4 and Q2) around both edges
    Gl = goff*ones(4,1);
    if mk >= 0
        Gl(2) = gon;
        if ramp < mk - dtf
            Gl(1) = gon;
        end
        if ramp >= mk + dtf
            Gl(3) = gon;
        end
    else
        Gl(3) = gon;
        if ramp > 1 + mk + dtf
            Gl(4) = gon;
        end
        if ramp <= 1 + mk - dtf
            Gl(2) = gon;
        end
    end
end

% ======================================================================================================
function y = wrap_pi(u)
%WRAP_PI  Port of the MATLAB Function "bounder" of the model: y = -pi + mod(u + 3*pi, 2*pi), i.e. [-pi, pi).
    y = -pi + mod(u + 3*pi, 2*pi);
end

% ======================================================================================================
function [md_sat, mq_sat, clip, xd, xq] = dq_vector_pi(ed, eq, xd, xq, clip_z, kp, ki_ts, rel_ts, lim, udc)
%DQ_VECTOR_PI  dq vector PI of the library block dq_vector_pi (pi_d, pi_q, "vector lenght", bounder1/2, switch)
%   with the DC-link feed-forward: the PI outputs are divided by udc (acquired DC-link voltage in pu, saturated
%   by the caller) before the vector-length limiter, so that the outputs are modulation indices.
%   ed, eq      errors (reference - measure)
%   xd, xq      integrator states (Unit Delay2 of pi_d, pi_q)
%   clip_z      clip flag of the previous step (Unit Delay1 of pi_d, pi_q)
%   kp, ki_ts   proportional gain and integral gain already multiplied by the sample time
%   rel_ts      CTRPIFF_CLIP_RELEASE*ts, leak of the integrator while clipped (the input is then ignored)
%   lim         radius of the output limiter, also the threshold of the clip flag (lim_ctrl_out)
    if clip_z > 0.5
        xd_new = xd - rel_ts*xd;                   % Sum2: x - rel*ts*x
        md = kp*ed + xd;                           % Sum5 = P + Sum4, Sum4 = x + 0
        xq_new = xq - rel_ts*xq;
        mq = kp*eq + xq;
    else
        xd_new = xd + ki_ts*ed;                    % Sum4 = x + ki*ts*e
        md = kp*ed + xd_new;
        xq_new = xq + ki_ts*eq;
        mq = kp*eq + xq_new;
    end
    xd = xd_new;
    xq = xq_new;
    md = md/udc;                                   % Divide by udc (DC-link feed-forward)
    mq = mq/udc;
    mag = sqrt(md^2 + mq^2);                       % "vector lenght"
    if mag >= lim                                  % bounder1/2: Switch1 (u2 >= Threshold)
        md_sat = md/mag*lim;
        mq_sat = mq/mag*lim;
        clip = 1;                                  % Switch (u2 >= Threshold) with the same threshold
    else
        md_sat = md;
        mq_sat = mq;
        clip = 0;
    end
end
