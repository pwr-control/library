function [G, ctrl_log] = pmsm_dq_ctrl_pwm(M, t_master, ref, enc, p)
%PMSM_DQ_CTRL_PWM  Field-oriented control and PWM of one PMSM inverter in a single MATLAB Function block.
%#codegen
%
%   [G, ctrl_log] = pmsm_dq_ctrl_pwm(M, t_master, ref, enc, p)
%
%   Source of the MATLAB Function pmsm_dq_ctrl_pwm of pmsm_inverter_dqctrl/pmsm_inverter_dqctrl_mod1:
%   ../update_pmsm_inverter_dqctrl.m loads this file into the block (edit here, then run it).
%
%   The block drives a permanent magnet synchronous machine (PMSM) that is OUTSIDE the block: the power
%   stage is the Simscape component afe_ssc.afe_two_level_lcl (two-level bridge, DC-link capacitor, LCL
%   filter), the same as grid_forming_dqctrl. Output filter:
%     L filter (normal case): L1 = filter inductor, Rcf very high (e.g. 1e5 Ohm, the capacitor branch
%                carries a few mA), L2 = small leakage only (L2p = L20 = 0, Lls2 > 0)
%     LC filter:  L1 = filter inductor, Cf/Rcf = filter capacitor, L2 = small leakage only
%   The control is the field-oriented control of the study model inv_psm of pwr-control/
%   modelization-and-control (foundations_of_power_electronics/inv_psm), written again as one function, with
%   the corrections listed in the README of this folder. The function runs at the fixed sample time
%   p.pwm.tc (step of the Simscape local solver); the control runs on the rising edge of the TRGO flag of
%   the carrier of the local clock, exactly as grid_forming_dqctrl (same clock, carrier, TRGO and gates).
%
%   Inputs
%     M        measurements [17x1] in pu of afe_ssc.afe_two_level_lcl (bases p.hw.ubez, p.hw.ibez,
%              p.hw.udc_nom): M(1:3) i1 converter current (out of the bridge), M(4:6) filter capacitor
%              voltage, M(7:9) i2 output current (towards the machine), M(10:12) machine terminal voltage
%              without zero sequence, M(13) vdc/udc_nom, M(14) DC-link capacitor current, M(15:17) filter
%              capacitor currents
%     t_master master time [s] (simulation time)
%     ref      [2x1] [enable; reference]
%                enable    > 0.5: the bridge may switch (and t_master >= p.ctrl.t_enable), otherwise all
%                          gates are off and the observers follow the machine on the measured terminal
%                          voltage (flying start)
%                reference p.ctrl.mode = 0: torque [pu of the torque base]
%                          p.ctrl.mode = 1: speed [pu of p.ctrl.omega_b, electrical = mechanical in pu]
%                          p.ctrl.mode = 2: scale of the torque curve p.ctrl.curve_w/curve_T (1 = curve as
%                                           given), generator: the torque brakes the rotation
%     enc      electrical rotor angle from an encoder [rad] (angle of the magnet flux, d axis, from the
%              axis of phase a); ground it when the machine has no encoder
%     p        parameter struct (mask parameter): p.hw (power stage, bases), p.pwm (carrier and gates),
%              p.ctrl (control), see pmsm_inverter_param_example.m
%   Outputs
%     G        gate commands [6x1] in V, order [a+; a-; b+; b-; c+; c-], p.pwm.gate_on / p.pwm.gate_off
%     ctrl_log control signals [44x1] (held between two triggers; t_loc, ramp and trgo every step):
%                1 t_loc, 2 ramp, 3 trgo, 4 clock correction, 5 bridge on, 6 angle source in use (0 encoder,
%                1 back-EMF observer, 2 EKF), 7 angle used [rad], 8 speed used [pu], 9 filtered speed [pu],
%                10/11 encoder angle/speed, 12/13 back-EMF observer angle/speed, 14/15 EKF angle/speed,
%                16/17 active flux alpha/beta of the back-EMF observer [pu], 18/19 of the EKF,
%                20/21 feedback current alpha/beta [pu], 22/23 i_d/i_q in the control frame,
%                24 torque reference after limit and slew [pu], 25/26 i_d/i_q references,
%                27/28 u_d/u_q after the limiter [pu of ubez], 29 clip flag of the current PI,
%                30/31 u_alpha/u_beta to the modulator [pu of vdc/sqrt(3)], 32:34 duties,
%                35 vdc [pu of udc_nom], 36/37 voltage used by the observers alpha/beta [pu of ubez],
%                38 torque from the measured currents and the model [pu], 39 speed reference after its
%                filter [pu], 40/41 angle error of the back-EMF observer / of the EKF with respect to the
%                encoder [rad], 42/43 active flux magnitude of the EKF / of the back-EMF observer [pu],
%                44 magnitude of the EKF innovation [pu]
%              (indices also in ../pmsm_inverter_log_index.m)
%
%   Per unit: currents in pu of p.hw.ibez, voltages in pu of p.hw.ubez, flux in pu of
%   p.hw.ubez/p.ctrl.omega_b, speed in pu of p.ctrl.omega_b (electrical), torque in pu of
%   3/2*pole_pairs*(p.hw.ubez/p.ctrl.omega_b)*p.hw.ibez, so that torque = psi*i in pu. With the bases of
%   the machine (ubez = psi_m*omega_b) p.ctrl.psi_m = 1. Machine data p.ctrl.rs, ld, lq, psi_m in these
%   pu; the filter inductors and resistors are read from p.hw (L1p + Lls1, R1, L2p + Lls2, R2).
%
%   Timing (as grid_forming_dqctrl): the samples taken at a trigger are used at the next trigger (one
%   control period of computation), the duties computed at a trigger are applied from that trigger to the
%   next one. At trigger k the control uses the current sampled at t(k-1), the observers predict from
%   t(k-2) to t(k-1) with the voltage applied in that interval (computed at trigger k-2) and correct with the
%   sample at t(k-1); the voltage computed at trigger k is applied over [t(k), t(k+1)], whose middle is
%   1.5 periods after t(k-1): the inverse Park transformation uses theta + k_delay*omega*omega_b*ts with
%   k_delay = 1.5.
%
%   Chain (every control period, rising edge of TRGO)
%     acquisitions   quantizer p.ctrl.adc_q and one-trigger delay of i1, i2, terminal voltage, vdc, encoder
%     clock          alignment PI of the local clock to t_master (as grid_forming_dqctrl)
%     voltage        applied voltage, from the duties actually applied, the measured vdc and the dead-time
%                    model -sign(i)*dead_time*fpwm*vdc (sign of the reference current); with the gates off
%                    the measured terminal voltage
%     observers      all three run every period, p.ctrl.angle_src selects the one the control uses:
%       encoder      tracking loop (PLL, double integrator) on the encoder angle -> angle and speed
%       back-EMF     active-flux observer [1]: voltage model psi_a = int(u - R*i) - L*i with the filter
%                    inductors split (L1*i1 + (L2 + Lq)*i2, exact with an LC filter too), correction towards
%                    the model flux (psi_m + (Ld - Lq)*i_d) along the angle of its PLL with gain bemf_fb [2],
%                    optional leak bemf_leak (the emf_p of inv_psm; 0 = no angle error in steady state); PLL
%                    on atan2(psi_a). With the gates off the terminal voltage is the back-EMF itself: the PLL
%                    tracks its angle - 90 deg and the flux is set along the PLL angle
%       EKF          extended Kalman filter [3] on the active-flux model, states [i_alpha; i_beta;
%                    psi_a_alpha; psi_a_beta; omega] in pu, L = Lq + L1 + L2, prediction with the
%                    second-order Taylor series, Joseph update (as ekf_im_step of the library); the
%                    filter capacitor current is neglected (exact with the L filter)
%                    below p.ctrl.omega_th [pu] of encoder speed (if > 0) the encoder angle is used
%     torque         mode 0 torque reference, mode 1 speed PI (back-calculation anti-windup on the applied
%                    torque), mode 2 torque curve of the speed; limit torque_lim, slew torque_slew
%     currents       MTPA [4] (p.ctrl.mtpa = 1, id >= -id_max) or id = 0, current vector limit i_lim with
%                    priority to i_q
%     current loop   dq vector PI (dq_vector_pi of grid_forming_dqctrl: limiter radius u_lim of the
%                    modulator linear range, leak of the integrators while clipped), feed-forward of the
%                    back-EMF and of the cross-coupling (p.ctrl.ff = 1), vdc feed-forward (the output is
%                    divided by the measured vdc)
%     modulator      SVPWM (sv_pwm_cm of grid_forming_dqctrl), dead-time compensation [5] (p.ctrl.dt_comp)
%   With the gates off (enable = 0 or t_master < t_enable) the PIs and the torque are held at zero and
%   the observers follow the machine on the measured terminal voltage: when the gates go on, the control
%   starts on the angle of the selected observer with the back-EMF feed-forward (flying start). The
%   sensorless observers need speed: start the bridge above about 0.1 pu, or use the encoder
%   (angle_src = 0, or omega_th > 0) at standstill and low speed.
%
%   References
%     [1] I. Boldea, M. C. Paicu, G.-D. Andreescu, "Active flux concept for motion-sensorless unified AC
%         drives," IEEE Trans. Power Electron., vol. 23, no. 5, pp. 2612-2618, Sept. 2008.
%     [2] J. Hu, B. Wu, "New integration algorithms for estimating motor flux over a wide speed range,"
%         IEEE Trans. Power Electron., vol. 13, no. 5, pp. 969-977, Sept. 1998.
%     [3] S. Bolognani, R. Oboe, M. Zigliotto, "Sensorless full-digital PMSM drive with EKF estimation of
%         speed and rotor position," IEEE Trans. Ind. Electron., vol. 46, no. 1, pp. 184-191, Feb. 1999.
%     [4] S. Morimoto, Y. Takeda, T. Hirasa, K. Taniguchi, "Expansion of operating limits for permanent
%         magnet motor by current vector control considering inverter capacity," IEEE Trans. Ind. Appl.,
%         vol. 26, no. 5, pp. 866-871, Sept./Oct. 1990.
%     [5] T. Sukegawa, K. Kamiyama, K. Mizuno, T. Matsui, T. Okuyama, "Fully digital, vector-controlled PWM
%         VSI-fed ac drives with an inverter dead-time compensation strategy," IEEE Trans. Ind. Appl.,
%         vol. 27, no. 3, pp. 552-559, May/June 1991.

NLOG = 44;

persistent initialized trgo_z corr_z x_align n_trig ...
           i1_z i2_z ut_z udc_z enc_z i1_p i2_p ut_p ...
           u_k1 u_k2 on_k1 on_k2 on_z ...
           th_e w_e th_f w_f psi_f x_ekf P_ekf use_enc ...
           w_flt w_ref_f x_w T_rl xd xq clip_z d_abc logv

if isempty(initialized)
    initialized = true;
    trgo_z  = true;                  % Trigger block "compatibility (no trigger on first evaluation)"
    corr_z  = 0;                     % local time correction
    x_align = 0;                     % integrator of the alignment PI
    n_trig  = 0;                     % triggers since the start (up to 3): the observers need two samples
    i1_z  = zeros(3,1);              % one-trigger delays of the acquisitions
    i2_z  = zeros(3,1);
    ut_z  = zeros(3,1);
    udc_z = 0;
    enc_z = 0;
    i1_p  = zeros(2,1);              % alpha/beta of the samples used at the previous trigger
    i2_p  = zeros(2,1);
    ut_p  = zeros(2,1);
    u_k1  = zeros(2,1);              % applied voltage computed at the last trigger [pu of ubez]
    u_k2  = zeros(2,1);              % and at the trigger before
    on_k1 = false;                   % bridge on in the corresponding intervals
    on_k2 = false;
    on_z  = false;                   % bridge on now (gates)
    th_e  = 0;                       % encoder tracking loop: angle [rad], speed [pu]
    w_e   = 0;
    th_f  = 0;                       % back-EMF observer: PLL angle and speed, active flux
    w_f   = 0;
    psi_f = zeros(2,1);
    x_ekf = [0; 0; p.ctrl.psi_m; 0; p.ctrl.ekf_w0];   % EKF state (flux along alpha, speed ekf_w0)
    P_ekf = diag(p.ctrl.ekf_p0(:));
    use_enc = (p.ctrl.angle_src == 0);
    w_flt   = 0;                     % filtered speed [pu]
    w_ref_f = 0;                     % filtered speed reference [pu]
    x_w     = 0;                     % integrator of the speed PI
    T_rl    = 0;                     % torque reference after limit and slew [pu]
    xd = 0; xq = 0; clip_z = 0;      % current PI
    d_abc   = 0.5*ones(3,1);         % duties
    logv    = zeros(NLOG,1);
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
    % ============================================================== control step
    c   = p.ctrl;
    ts  = c.ts;                      % control period
    wb  = c.omega_b;                 % [rad/s] base pulsation (electrical)
    h   = wb*ts;                     % [rad] angle per control period at 1 pu speed

    % ---- filter of the power stage in pu (positive sequence: Lp + Lls)
    zb = p.hw.ubez/p.hw.ibez;        % [Ohm]
    lb = zb/wb;                      % [H]
    l1 = (p.hw.L1p + p.hw.Lls1)/lb;
    r1 = p.hw.R1/zb;
    l2 = (p.hw.L2p + p.hw.Lls2)/lb;
    r2 = p.hw.R2/zb;

    % ---- acquisitions: the control uses the samples of the previous trigger, the delays take the
    %      samples of this trigger
    i1d  = i1_z;
    i2d  = i2_z;
    utd  = ut_z;
    udcd = udc_z;
    encd = enc_z;
    q = c.adc_q;
    i1_z  = q*round(m(1:3)/q);
    i2_z  = q*round(m(7:9)/q);
    ut_z  = q*round(m(10:12)/q);
    udc_z = q*round(m(13)/q);
    enc_z = enc(1);
    n_trig = min(n_trig + 1, 3);

    % ---- alignment of the local clock to the master time (as grid_forming_dqctrl)
    e_al = t_master - t_loc;
    P_al = c.kp_align*e_al;
    y_al = P_al + c.ki_align*ts*e_al + x_align;
    y_al = min(max(y_al, c.lim_down_align), c.lim_up_align);
    x_align = y_al - P_al;
    corr_z  = y_al;

    i1ab = clarke(i1d);
    i2ab = clarke(i2d);
    utab = clarke(utd);

    % ---- voltage and model seen by the observers between t(k-2) and t(k-1)
    if on_k2
        u_o = u_k2;                  % applied by the bridge (duties, vdc, dead time)
        rf1 = r1;                    % back-EMF observer: drops of i1 and i2 apart
        lf1 = l1;
        rf2 = r2 + c.rs;
        lf2 = l2 + c.lq;
        r_e = c.rs + r1 + r2;        % EKF: one current (i1 = i2 with the L filter)
        l_e = c.lq + l1 + l2;
    else
        u_o = 0.5*(utab + ut_p);     % gates off: measured terminal voltage, machine only
        rf1 = 0;
        lf1 = 0;
        rf2 = c.rs;
        lf2 = c.lq;
        r_e = c.rs;
        l_e = c.lq;
    end

    innov = 0;
    if n_trig >= 3
        if on_k2
            % back-EMF (active flux) observer: voltage model, correction towards the model flux
            th_pf = wrap_pi(th_f + h*w_f);                     % PLL angle predicted to t(k-1)
            id_m  = i2ab(1)*cos(th_pf) + i2ab(2)*sin(th_pf);   % d current in that frame
            psi_mod = (c.psi_m + (c.ld - c.lq)*id_m)*[cos(th_pf); sin(th_pf)];
            psi_f = psi_f + h*(u_o - rf1*0.5*(i1ab + i1_p) - rf2*0.5*(i2ab + i2_p)) ...
                    - lf1*(i1ab - i1_p) - lf2*(i2ab - i2_p) ...
                    + h*c.bemf_fb*(psi_mod - psi_f) - h*c.bemf_leak*psi_f;
            [th_f, w_f] = pll(th_f, w_f, atan2(psi_f(2), psi_f(1)), c.pll_poles, ts, wb);
        else
            % gates off (no current): the measured terminal voltage is the back-EMF j*omega*psi_a, 90 deg
            % ahead of the flux (behind when the machine turns backwards): PLL on that angle, flux along the
            % PLL angle, so that the voltage model starts from the right flux when the gates go on
            s_w = 1;
            if w_f < 0
                s_w = -1;
            end
            [th_f, w_f] = pll(th_f, w_f, atan2(u_o(2), u_o(1)) - s_w*pi/2, c.pll_poles, ts, wb);
            id_m  = i2ab(1)*cos(th_f) + i2ab(2)*sin(th_f);
            psi_f = (c.psi_m + (c.ld - c.lq)*id_m)*[cos(th_f); sin(th_f)];
        end

        % extended Kalman filter
        [x_ekf, P_ekf, innov] = ekf_step(x_ekf, P_ekf, u_o, i2ab, r_e, l_e, h, c.ekf_q(:), c.ekf_r(:));

        % encoder tracking loop
        [th_e, w_e] = pll(th_e, w_e, encd, c.pll_poles, ts, wb);
    end
    th_k = atan2(x_ekf(4), x_ekf(3));

    % ---- angle source: encoder below omega_th (hysteresis 20 %), else the selected observer
    if c.angle_src == 0
        use_enc = true;
    elseif c.omega_th > 0
        if abs(w_e) < c.omega_th
            use_enc = true;
        elseif abs(w_e) > 1.2*c.omega_th
            use_enc = false;
        end
    else
        use_enc = false;
    end
    if use_enc && c.angle_src ~= 0 && n_trig >= 3
        % hand-over: while the encoder is used below omega_th, the selected sensorless observers are set to
        % the encoder angle and speed at every period, so that they take over from the right state
        psi_e = (c.psi_m + (c.ld - c.lq)*(i2ab(1)*cos(th_e) + i2ab(2)*sin(th_e)))*[cos(th_e); sin(th_e)];
        psi_f = psi_e;
        th_f  = th_e;
        w_f   = w_e;
        x_ekf = [i2ab; psi_e; w_e];
        th_k  = th_e;
    end
    if use_enc
        src   = 0;
        theta = th_e;
        omega = w_e;
    elseif c.angle_src == 1
        src   = 1;
        theta = th_f;
        omega = w_f;
    else
        src   = 2;
        theta = th_k;
        omega = x_ekf(5);
    end
    w_flt = w_flt + min(1, 2*pi*c.w_flt_fc*ts)*(omega - w_flt);

    % ---- bridge on/off, torque reference
    on  = (t_master >= c.t_enable) && (ref(1) > 0.5);
    P_w = 0;
    if ~on
        T_rl    = 0;
        x_w     = 0;
        w_ref_f = w_flt;             % the speed reference filter starts from the actual speed
    else
        if c.mode == 1               % speed PI
            g_r = 1;
            if c.w_ref_fc > 0
                g_r = min(1, 2*pi*c.w_ref_fc*ts);
            end
            w_ref_f = w_ref_f + g_r*(ref(2) - w_ref_f);
            e_w   = w_ref_f - w_flt;
            P_w   = c.kp_w*e_w;
            T_cmd = P_w + c.ki_w*ts*e_w + x_w;
        elseif c.mode == 2           % torque curve (generator)
            T_cmd = -sign(w_flt)*ref(2)*torque_curve(abs(w_flt), c.curve_w, c.curve_T);
        else                         % torque reference
            T_cmd = ref(2);
        end
        T_cmd = min(max(T_cmd, -c.torque_lim), c.torque_lim);
        dT    = c.torque_slew*ts;
        T_rl  = T_rl + min(max(T_cmd - T_rl, -dT), dT);
        if c.mode == 1
            x_w = T_rl - P_w;        % back-calculation: the integrator follows the applied torque
        end
    end
    [id_ref, iq_ref] = torque_to_current(T_rl, c);

    % ---- current loop on the output (machine) current, in the frame of theta (sample time t(k-1))
    iab = i2ab;
    cth = cos(theta);
    sth = sin(theta);
    i_d =  iab(1)*cth + iab(2)*sth;
    i_q = -iab(1)*sth + iab(2)*cth;
    udc_pu = max(udcd, 0.05);
    u_base = udc_pu*p.hw.udc_nom/(sqrt(3)*p.hw.ubez);  % [pu of ubez] of 1 pu of modulator voltage (vdc/sqrt(3))
    u_max  = c.u_lim*u_base;
    dtf    = p.pwm.dead_time*p.pwm.fpwm;               % dead time as a fraction of the carrier period
    clip_i = 0;
    u_d  = 0;
    u_q  = 0;
    u_al = 0;
    u_be = 0;
    u_new = zeros(2,1);
    if on
        if ~on_z                     % first period with the gates on: PI from zero
            xd = 0;
            xq = 0;
            clip_z = 0;
            if c.ff == 0
                xq = omega*c.psi_m;  % without feed-forward the q integrator starts at the back-EMF
            end
        end
        fd = 0;
        fq = 0;
        if c.ff ~= 0
            ld_t = c.ld + l1 + l2;
            lq_t = c.lq + l1 + l2;
            r_t  = c.rs + r1 + r2;
            fd = r_t*id_ref - omega*lq_t*iq_ref;
            fq = r_t*iq_ref + omega*(ld_t*id_ref + c.psi_m);
        end
        [u_d, u_q, clip_i, xd, xq] = dq_vector_pi(id_ref - i_d, iq_ref - i_q, xd, xq, clip_z, ...
            c.kp_i, c.ki_i*ts, c.clip_release*ts, u_max, u_max, fd, fq);
        clip_z = clip_i;

        th_u = theta + c.k_delay*h*omega;              % angle in the middle of the next period
        cu = cos(th_u);
        su = sin(th_u);
        u_al = (u_d*cu - u_q*su)/u_base;
        u_be = (u_d*su + u_q*cu)/u_base;
        [da, db, dc] = sv_pwm_cm(u_al*sqrt(3)/2, u_be*sqrt(3)/2, 0, true);

        % dead time: sign of the reference current at the voltage angle (band dt_band)
        ia_r = id_ref*cu - iq_ref*su;
        ib_r = id_ref*su + iq_ref*cu;
        i_r  = [ia_r; -0.5*ia_r + sqrt(3)/2*ib_r; -0.5*ia_r - sqrt(3)/2*ib_r];
        sg   = min(max(i_r/c.dt_band, -1), 1);
        d_cmd = [da; db; dc];
        if c.dt_comp ~= 0
            d_cmd = d_cmd - sg*dtf;
        end
        d_abc = d_cmd;
        d_sat = min(max(d_abc, p.pwm.m_low), p.pwm.m_up);
        v_leg = (1 - d_sat - sg*dtf)*udc_pu*p.hw.udc_nom/p.hw.ubez;  % leg voltages [pu of ubez]
        u_new = clarke(v_leg);
    else
        xd = 0;
        xq = 0;
        clip_z = 0;
        d_abc = 0.5*ones(3,1);
    end
    on_z = on;

    % ---- history: applied voltage and samples for the next trigger
    u_k2  = u_k1;
    on_k2 = on_k1;
    u_k1  = u_new;
    on_k1 = on;
    i1_p  = i1ab;
    i2_p  = i2ab;
    ut_p  = utab;

    % ---- log
    logv(4)  = corr_z;
    logv(5)  = double(on);
    logv(6)  = src;
    logv(7)  = theta;
    logv(8)  = omega;
    logv(9)  = w_flt;
    logv(10) = th_e;
    logv(11) = w_e;
    logv(12) = th_f;
    logv(13) = w_f;
    logv(14) = th_k;
    logv(15) = x_ekf(5);
    logv(16:17) = psi_f;
    logv(18:19) = x_ekf(3:4);
    logv(20:21) = iab;
    logv(22) = i_d;
    logv(23) = i_q;
    logv(24) = T_rl;
    logv(25) = id_ref;
    logv(26) = iq_ref;
    logv(27) = u_d;
    logv(28) = u_q;
    logv(29) = clip_i;
    logv(30) = u_al;
    logv(31) = u_be;
    logv(32:34) = d_abc;
    logv(35) = udcd;
    logv(36:37) = u_o;
    logv(38) = (c.psi_m + (c.ld - c.lq)*i_d)*i_q;
    logv(39) = w_ref_f;
    logv(40) = wrap_pi(th_f - th_e);
    logv(41) = wrap_pi(th_k - th_e);
    logv(42) = sqrt(x_ekf(3)^2 + x_ekf(4)^2);
    logv(43) = sqrt(psi_f(1)^2 + psi_f(2)^2);
    logv(44) = innov;
end
trgo_z = trgo;

% ------------------------------------------------------------------ every step: gate commands
dtf = p.pwm.dead_time*p.pwm.fpwm;
G = p.pwm.gate_off*ones(6,1);
if on_z
    for k = 1:3
        dk = min(max(d_abc(k), p.pwm.m_low), p.pwm.m_up);  % Saturation m_low..m_up
        if ramp >= dk + dtf                                % upper switch: (d + dead_time*f) <= ramp
            G(2*k-1) = p.pwm.gate_on;
        end
        if ramp <= dk - dtf                                % lower switch: ramp <= (d - dead_time*f)
            G(2*k) = p.pwm.gate_on;
        end
    end
end

logv(1) = t_loc;
logv(2) = ramp;
logv(3) = double(trgo);
ctrl_log = logv;

end

% ======================================================================================================
function y = clarke(x)
%CLARKE  abc -> alpha/beta, amplitude invariant (the zero sequence is dropped).
    y = [2/3*(x(1) - 0.5*x(2) - 0.5*x(3)); (x(2) - x(3))/sqrt(3)];
end

% ======================================================================================================
function y = wrap_pi(x)
%WRAP_PI  Angle in [-pi, pi].
    y = x - 2*pi*round(x/(2*pi));
end

% ======================================================================================================
function [th, w] = pll(th, w, th_meas, poles, ts, wb)
%PLL  Tracking loop of an angle: double integrator theta' = omega, filter form (the estimate at the sample
%   includes that sample). Error dynamics (I - L*C)*A with A = [1 ts; 0 1], C = [1 0]: the poles
%   z = exp(poles*ts) give the closed-form gains l1 = 1 - z1*z2, l2 = (1 - z1)*(1 - z2)/ts.
%   th [rad], w [pu of wb], poles [rad/s] (two real negative values, e.g. [-1 -4]*omega_b as inv_psm).
    z1 = exp(poles(1)*ts);
    z2 = exp(poles(2)*ts);
    l1 = 1 - z1*z2;
    l2 = (1 - z1)*(1 - z2)/ts;
    th_p = th + wb*ts*w;
    e  = wrap_pi(th_meas - th_p);
    th = wrap_pi(th_p + l1*e);
    w  = w + l2*e/wb;
end

% ======================================================================================================
function [x, P, innov] = ekf_step(x, P, u, y, r, l, h, q, rv)
%EKF_STEP  One step of the extended Kalman filter of the PMSM (active-flux model), time in units of
%   1/omega_b (h = omega_b*ts):
%     di/dt   = (u - r*i - j*omega*psi_a)/l      (j*: rotation by +90 degrees)
%     dpsi_a/dt = j*omega*psi_a,   domega/dt = 0
%   x = [i_alpha; i_beta; psi_a_alpha; psi_a_beta; omega], u voltage applied between the two samples,
%   y current measured at the new sample, q (5x1) and rv (2x1) variances of process and measurement
%   noise per step. Prediction with the second-order Taylor series, covariance with F = I + h*A, Joseph
%   update (as ekf_im_step of the library).
    ia = x(1);
    ib = x(2);
    pa = x(3);
    pb = x(4);
    om = x(5);
    f = [(u(1) - r*ia + om*pb)/l;
         (u(2) - r*ib - om*pa)/l;
         -om*pb;
          om*pa;
          0];
    A = [-r/l, 0,    0,     om/l,  pb/l;
          0,  -r/l, -om/l,  0,    -pa/l;
          0,   0,    0,    -om,   -pb;
          0,   0,    om,    0,     pa;
          0,   0,    0,     0,     0];
    xp = x + h*f + h*h/2*(A*f);
    F  = eye(5) + h*A;
    Pp = F*P*F' + diag(q);
    S  = Pp(1:2, 1:2) + diag(rv);
    K  = Pp(:, 1:2)/S;
    e  = y - xp(1:2);
    x  = xp + K*e;
    IKC = eye(5);
    IKC(:, 1:2) = IKC(:, 1:2) - K;
    P = IKC*Pp*IKC' + K*diag(rv)*K';
    P = (P + P')/2;
    innov = sqrt(e(1)^2 + e(2)^2);
end

% ======================================================================================================
function [id, iq] = torque_to_current(T, c)
%TORQUE_TO_CURRENT  Current references for the torque T [pu]: MTPA (c.mtpa = 1) with the d current limited
%   to [-id_max, id_max], or id = 0; current vector limit i_lim with priority to i_q.
%   torque = (psi_m + (ld - lq)*id)*iq, MTPA: id = a - sign(a)*sqrt(a^2 + iq^2), a = psi_m/(2*(lq - ld)),
%   iterated with iq = T/(psi_m + (ld - lq)*id).
    id = 0;
    iq = T/c.psi_m;
    dl = c.lq - c.ld;
    if c.mtpa ~= 0 && abs(dl) > 1e-6
        a = c.psi_m/(2*dl);
        for n = 1:4
            id = a - sign(a)*sqrt(a*a + iq*iq);
            id = min(max(id, -c.id_max), c.id_max);
            iq = T/(c.psi_m - dl*id);
        end
    end
    ilim = c.i_lim;
    id = min(max(id, -ilim), ilim);
    if id*id + iq*iq > ilim*ilim
        iq = sign(iq)*sqrt(ilim*ilim - id*id);
    end
end

% ======================================================================================================
function T = torque_curve(w, cw, cT)
%TORQUE_CURVE  Torque of the curve (cw increasing speeds [pu], cT torques [pu]) at the speed w >= 0:
%   linear interpolation, linear to zero below cw(1) (cut-in), cT(end) above cw(end).
    n = numel(cw);
    if w <= cw(1)
        T = cT(1)*w/cw(1);
    elseif w >= cw(n)
        T = cT(n);
    else
        T = cT(n);
        for k = 1:n-1
            if w < cw(k+1)
                T = cT(k) + (cT(k+1) - cT(k))*(w - cw(k))/(cw(k+1) - cw(k));
                break;
            end
        end
    end
end

% ======================================================================================================
function [md_sat, mq_sat, clip, xd, xq] = dq_vector_pi(ed, eq, xd, xq, clip_z, kp, ki_ts, rel_ts, lim, clip_thr, fd, fq)
%DQ_VECTOR_PI  dq vector PI of grid_forming_dqctrl (blocks pi_d, pi_q, "vector lenght", bounder1/2, switch).
%   ed, eq      errors (reference - measure)
%   xd, xq      integrator states
%   clip_z      clip flag of the previous step
%   kp, ki_ts   proportional gain and integral gain already multiplied by the sample time
%   rel_ts      clip_release*ts, leak of the integrator while clipped
%   lim         radius of the output limiter
%   clip_thr    radius at which the clip flag is raised
%   fd, fq      feed-forward added to the PI outputs before the limiter
    if clip_z > 0.5
        xd_new = xd - rel_ts*xd;
        md = kp*ed + xd;
        xq_new = xq - rel_ts*xq;
        mq = kp*eq + xq;
    else
        xd_new = xd + ki_ts*ed;
        md = kp*ed + xd_new;
        xq_new = xq + ki_ts*eq;
        mq = kp*eq + xq_new;
    end
    md = md + fd;
    mq = mq + fq;
    xd = xd_new;
    xq = xq_new;
    mag = sqrt(md^2 + mq^2);
    if mag >= lim
        md_sat = md/mag*lim;
        mq_sat = mq/mag*lim;
    else
        md_sat = md;
        mq_sat = mq;
    end
    if mag >= clip_thr
        clip = 1;
    else
        clip = 0;
    end
end

% ======================================================================================================
function [da, db, dc] = sv_pwm_cm(ualpha, ubeta, ugamma, enable)
%SV_PWM_CM  Port of sv_pwm_cm_process (library/user_defined_functions/ccaller/src/sv_pwm_cm.c), as in
%   grid_forming_dqctrl. Duties da, db, dc in [0, 1] are the switch-on instants on the carrier (0 = bottom,
%   1 = top): the upper switch is on while ramp >= d. k_offset = 0.5 is the standard SVPWM.
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
