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
%     M        measurement vector [17x1] in pu of the block afe_ssc.afe_two_level_lcl:
%              M(1:3) is_abc converter current (positive out of the bridge), M(4:6) uc_abc filter
%              capacitor voltage, M(7:9) ig_abc grid current (positive towards the grid),
%              M(10:12) ug_abc grid voltage without zero sequence, M(13) vdc/udc_nom, M(14) ic/ibez,
%              M(15:17) filter capacitor currents (added November 2026, not used here)
%     t_master master time [s] (Clock of "global timing"/time_afe3 with k = 1, i.e. simulation time)
%     sync     [5x1] [theta; i_xi_ref; i_eta_ref; i_xi_n_ref; i_eta_n_ref] of the master (its output
%              sync_out), read only in slave mode; on a master leave it unconnected or grounded. In the
%              droop mode it carries [unused; dP*; dQ*; dU*; dw*] instead (setpoint offsets, 0 when grounded)
%     p        parameter struct, scope "Parameter" in the Symbols pane of the block, built by
%              private/afe_module_param.m (p.pwm.*, p.ctrl.*); p.ctrl.slave (optional, default 0)
%              selects the slave mode, p.ctrl.nsc_* (optional, default off) the negative-sequence
%              compensator, p.ctrl.open_loop and ol_* (optional, default off) the open-loop V/f mode,
%              which also reads p.hw.ubez and p.hw.udc_nom (bases of M), p.ctrl.droop and droop_*
%              (optional, default off) the droop mode, which also reads p.hw.Cf, ubez, ibez, udc_nom
%   Outputs
%     G        gate commands [6x1] in V, order [a+; a-; b+; b-; c+; c-] (Q1..Q6 of the PWM library
%              block and G of the ssc block), p.pwm.gate_on / p.pwm.gate_off (15 V / -10 V)
%     ctrl_log control signals [55x1], indices in afe_log_index.m (held between two triggers,
%              t_loc, ramp and trgo updated every step); 38:43 are the negative-sequence signals,
%              44:55 the droop signals (0 out of the droop mode, w = 1)
%     sync_out [5x1] [theta; i_xi_ref; i_eta_ref; i_xi_n_ref; i_eta_n_ref] of the last control step
%              (held between two triggers): connect it to the sync input of the slave(s)
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
%   Negative-sequence compensator (p.ctrl.nsc_enable = 1; off when the field is absent or 0, and then the
%   block computes what it computed before): an unbalanced load, e.g. a single-phase load on a
%   transformer, draws a negative-sequence current (symmetrical components [1]) that the current loop,
%   whose references are DC in the positive frame, opposes with its whole PI gain, so the terminals get a
%   large negative-sequence voltage. With the compensator the FHT also gives the negative sequence of the
%   terminal voltage (same states, signs of the quadrature terms swapped: the positive/negative-sequence
%   calculation from quadrature signals of [2], with the FHT as the quadrature generator), the master
%   regulates it to zero with a dq vector PI in the negative frame (angle -theta; positive and negative
%   synchronous frames as in [3], [4]) whose outputs are negative-sequence current references, these are
%   rotated into the positive frame (angle -2*theta) and added to the references of the voltage loop, and
%   the current loop gets a resonant term at 2*fgrid on each axis (the negative sequence at fgrid seen in
%   the positive frame: PI plus resonant term in a rotating frame as in [5], resonant controllers [6],
%   discretization [7]) to track them without error. Unbalance (negative-sequence voltage) compensation in
%   voltage-source inverters: [8]; synchronization and control under unbalanced conditions: [9]. A slave
%   takes the negative-sequence references of the master from sync(4:5), so master and slaves still carry
%   the same current: they need the same nsc_enable. Fields (all needed when nsc_enable is present):
%   nsc_enable, nsc_kp_ug [pu/pu], nsc_ki_ug [1/s] (negative-sequence voltage PI, e.g. kp_ug / ki_ug),
%   nsc_i_lim [pu] (radius of its output limiter and clip threshold, e.g. ixi_lim), nsc_kr_i [1/s] (gain
%   kr of kr*s/(s^2 + (4*pi*fgrid)^2); 2*ki_i gives the envelope of the negative-sequence current the
%   convergence that ki_i gives the positive-sequence one).
%
%   Open-loop mode (p.ctrl.open_loop = 1; off when the field is absent or 0, and then the block computes what
%   it computed before): a V/f source without regulators, e.g. to compare a plain voltage source with the
%   loops. The phase generator gives the angle theta (a slave takes that of the master from sync(1)) and the
%   modulator gets the voltage [ug_ref; ueta_ref] (pu of ubez, peak phase) at the angle theta as the average
%   voltage of the bridge, i.e. the EMF behind the converter-side inductor (not the terminal voltage that the
%   voltage loop regulates): m = k_r*[ug_ref; ueta_ref]*ubez*sqrt(3)/(udc_nom*u_dc), the modulation index
%   whose unit circle (linear limit) gives udc/sqrt(3) peak phase, limited to the radius u_lim (clip flag
%   clip_i, log 28). The voltage loop, the compensator and the current loop are not computed: their states
%   stay at rest and the current references (log 21, 22, 40, 41 and sync_out) are 0; nsc_enable is ignored.
%   The FHT, the sequences of the terminal voltage and the converter current in the rotating frame are
%   computed and logged as in closed loop, so the log shows the positive and negative sequences that the load
%   gives. Fields (all needed when open_loop is present): open_loop; ol_udc_comp (1: u_dc is the acquired
%   DC-link voltage M(13), not below 0.5 pu, so that the amplitude does not follow the DC-link voltage and its
%   ripple; 0: u_dc = 1, the amplitude is proportional to the DC-link voltage); ol_t_ramp [s] (the amplitude
%   rises linearly, k_r = t_master/ol_t_ramp, to the full value at ol_t_ramp; 0: k_r = 1 from the start).
%   Master and slaves need the same open_loop: a slave forms its own voltage at the angle of the master, the
%   same as the master when the parameters are the same.
%
%   Droop mode (p.ctrl.droop = 1; off when the field is absent or 0, and then the block computes what it computed
%   before): power sharing among grid-forming modules in parallel, on the grid and in an island after the loss of
%   the grid, without communication (control V1 of the design note repos_doc/parallel_of_gfms of
%   pwr-control/repositories-documentation). Each module is a voltage source whose angle and amplitude follow its
%   own power. The active and reactive power p, q at the terminals (samples u_g, i_g of the previous trigger in the
%   frame theta, pu of the module) pass low-pass filters (droop_tau_p, droop_tau_q -> P_f, Q_f) and give
%     w = 1 + sync(5) + droop_mp*(P* - P_f) - droop_md*(p - P_f)    [pu of fgrid; the phase generator advances
%                                                                    by w*2*pi*fgrid*ts]
%     E = ug_ref + sync(4) + droop_nq*(Q* - Q_f)                    [pu, amplitude of the formed voltage]
%   with P* = droop_p_ref + sync(2), Q* = droop_q_ref + sync(3): a P-f droop with a low-pass filter, that is a
%   virtual synchronous machine with 2H = droop_tau_p/droop_mp and damping 1/droop_mp [11], with a lead term on the
%   unfiltered power (droop_md), and a Q-V droop. A virtual impedance on the voltage reference decouples the
%   modules [12], damps the electromagnetic modes and limits the current:
%     u_ref = E - (R_v + j*X_v)*i_o - droop_rt*(i_o - i_o,lp),   i_o,lp = low-pass of i_o (droop_tau_hp),
%     X_v = droop_xv + dx, R_v = droop_rv + dx/droop_x_r, dx = droop_kx*max(|i_o| - droop_i_thr, 0)
%   (quasi-static R_v, X_v in the frame; droop_rt is a transient resistance on the high-pass part of the output
%   current i_o, with no effect in steady state; dx is the threshold virtual impedance of [13]). A dq vector PI
%   (droop_kp_u, droop_ki_u) regulates the filter-capacitor voltage u_c (M(4:6), not the terminal voltage) to u_ref
%   with the feedforward of i_o and of j*b*u_c (the capacitor current at fgrid, b = 2*pi*fgrid*Cf*ubez/ibez); its
%   output, limited to the radius droop_i_max (clip flag at the same radius, integrators held while clipped), is
%   the reference of the current loop, and the current loop gets the feedforward of u_c as modulation index (the
%   scaling of the open-loop mode, acquired DC-link voltage not below 0.5 pu): the cascade of [10], [14].
%   Start: until droop_t_sync the module follows the terminal voltage (angle of the FHT output, when its magnitude
%   is at least 0.5 pu) with zero current reference, the power filters and the low-pass of i_o following their
%   inputs; at droop_t_sync the droop starts from there and the parameter parts of P* and Q* ramp from 0 in
%   droop_t_ramp. With a dead bus at droop_t_sync (FHT magnitude below 0.5 pu) the module
%   makes a black start: its angle runs free from theta0 and E ramps from 0 in droop_t_ramp. droop_t_sync must
%   leave the FHT time to lock after fht_t_reset (some 20 ms). The FHT, the sequences and the current loop run as
%   in closed loop; the slave mode, the compensator and the open-loop mode are ignored. Log 44:55: p, q, P_f,
%   Q_f, w, E, u_c and i_o in the frame (xi, eta), dx, state (0 synchronization, 1 droop, 2 black start).
%   Fields (all needed when droop is present): droop, droop_mp [pu/pu], droop_nq [pu/pu], droop_tau_p [s],
%   droop_tau_q [s], droop_md [pu/pu], droop_p_ref [pu], droop_q_ref [pu], droop_rv [pu], droop_xv [pu],
%   droop_rt [pu], droop_tau_hp [s], droop_i_thr [pu], droop_kx [pu/pu], droop_x_r [-], droop_i_max [pu],
%   droop_kp_u [pu/pu], droop_ki_u [1/s], droop_t_sync [s], droop_t_ramp [s] (0: no ramp). The tuning (Rev. 01
%   of the design note) comes from a discrete-time small-signal model with the one-step delay of the block.
%
%   References (negative-sequence compensator):
%     [1] C. L. Fortescue, "Method of symmetrical co-ordinates applied to the solution of polyphase
%         networks," Trans. AIEE, vol. 37, part II, pp. 1027-1140, 1918.
%     [2] P. Rodriguez, R. Teodorescu, I. Candela, A. V. Timbus, M. Liserre, F. Blaabjerg, "New
%         positive-sequence voltage detector for grid synchronization of power converters under faulty
%         grid conditions," 37th IEEE Power Electronics Specialists Conf. (PESC), Jeju, 2006,
%         pp. 1-7, doi:10.1109/PESC.2006.1712059.
%     [3] H.-S. Song, K. Nam, "Dual current control scheme for PWM converter under unbalanced input
%         voltage conditions," IEEE Trans. Ind. Electron., vol. 46, no. 5, pp. 953-959, Oct. 1999,
%         doi:10.1109/41.793344.
%     [4] P. Rodriguez, J. Pou, J. Bergas, J. I. Candela, R. P. Burgos, D. Boroyevich, "Decoupled double
%         synchronous reference frame PLL for power converters control," IEEE Trans. Power Electron.,
%         vol. 22, no. 2, pp. 584-592, Mar. 2007.
%     [5] M. Liserre, R. Teodorescu, F. Blaabjerg, "Multiple harmonics control for three-phase grid
%         converter systems with the use of PI-RES current controller in a rotating frame," IEEE Trans.
%         Power Electron., vol. 21, no. 3, pp. 836-841, May 2006, doi:10.1109/TPEL.2006.875566.
%     [6] R. Teodorescu, F. Blaabjerg, M. Liserre, P. C. Loh, "Proportional-resonant controllers and
%         filters for grid-connected voltage-source converters," IEE Proc. Electr. Power Appl., vol. 153,
%         no. 5, pp. 750-762, Sept. 2006, doi:10.1049/ip-epa:20060008.
%     [7] A. G. Yepes, F. D. Freijedo, J. Doval-Gandoy, O. Lopez, J. Malvar, P. Fernandez-Comesana,
%         "Effects of discretization methods on the performance of resonant controllers," IEEE Trans.
%         Power Electron., vol. 25, no. 7, pp. 1692-1712, July 2010 (correction: vol. 27, no. 12,
%         p. 4976, 2012).
%     [8] M. Savaghebi, A. Jalilian, J. C. Vasquez, J. M. Guerrero, "Secondary control scheme for voltage
%         unbalance compensation in an islanded droop-controlled microgrid," IEEE Trans. Smart Grid,
%         vol. 3, no. 2, pp. 797-807, 2012, doi:10.1109/TSG.2011.2181432.
%     [9] R. Teodorescu, M. Liserre, P. Rodriguez, "Grid Converters for Photovoltaic and Wind Power
%         Systems," Wiley-IEEE Press, 2011, ISBN 978-0-470-05751-3.
%
%   References (droop mode):
%     [10] N. Pogaku, M. Prodanovic, T. C. Green, "Modeling, analysis and testing of autonomous operation of an
%          inverter-based microgrid," IEEE Trans. Power Electron., vol. 22, no. 2, pp. 613-625, Mar. 2007,
%          doi:10.1109/TPEL.2006.890003.
%     [11] S. D'Arco, J. A. Suul, "Equivalence of virtual synchronous machines and frequency-droops for
%          converter-based microgrids," IEEE Trans. Smart Grid, vol. 5, no. 1, pp. 394-395, Jan. 2014,
%          doi:10.1109/TSG.2013.2288000.
%     [12] J. M. Guerrero, L. Garcia de Vicuna, J. Matas, M. Castilla, J. Miret, "Output impedance design of
%          parallel-connected UPS inverters with wireless load-sharing control," IEEE Trans. Ind. Electron.,
%          vol. 52, no. 4, pp. 1126-1135, Aug. 2005.
%     [13] A. D. Paquette, D. M. Divan, "Virtual impedance current limiting for inverters in microgrids with
%          synchronous generators," IEEE Trans. Ind. Appl., vol. 51, no. 2, pp. 1630-1638, Mar./Apr. 2015.
%     [14] S. D'Arco, J. A. Suul, O. B. Fosso, "A virtual synchronous machine implementation for distributed
%          control of power converters in SmartGrids," Electr. Power Syst. Res., vol. 122, pp. 180-197, 2015,
%          doi:10.1016/j.epsr.2015.01.001.
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
%       compensator    (nsc_enable) negative-sequence voltage PI, references in the positive frame,
%                      resonant term at 2*fgrid in the current loop         [not in the model]
%       open loop      (open_loop) in place of the voltage loop, the compensator and the current loop:
%                      [ug_ref; ueta_ref] at theta as modulation index, ramp, DC-link compensation, limiter
%                      u_lim                                                [not in the model]
%       droop          (droop) power of the terminals, P-f / Q-V droops, phase generator at w, virtual
%                      impedance, voltage PI on u_c with feedforward in place of the voltage loop, feedforward
%                      of u_c in the current loop                           [not in the model]
%       SVPWM         port of sv_pwm_cm.c (inputs scaled by sqrt(3)/2, k_offset = (ugamma + 1)/2)
%                      [space_vector]
%
%   Differences from the block diagram (see README.md):
%     - the duties change at the trigger step without the 1/(tc*s + 1) filters td2tc_1..3
%     - the switching instants are quantized to tc (the Simscape local solver samples the gates
%       at tc anyway); the ramp of the trigger step is used for the gates of that step
%     - double precision instead of the single precision of the C-Caller blocks
%   The code follows grid_forming_dq.slx at commit e61afe1 (PR #1): positive-sequence gains +1/2 and
%   clip threshold of the voltage loop equal to its limiter radius (clip_thr_ug = ixi_lim).

NLOG = 55;

persistent initialized trgo_z corr_z x_align ug_z is_z ig_z udc_z ...
           fht_s1 fht_s2 fht_out th xd_u xq_u clip_u_z xd_i xq_i clip_i_z d_abc logv sync_z ...
           xd_n xq_n clip_n_z res_d res_q uc_z dr_pf dr_qf dr_lpd dr_lpq dr_state

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
    sync_z   = zeros(5,1);           % [theta; i_xi_ref; i_eta_ref; i_xi_n_ref; i_eta_n_ref] of the last trigger (output sync_out)
    xd_n = 0; xq_n = 0; clip_n_z = 0;      % negative-sequence voltage PI (compensator)
    res_d = zeros(2,1);              % resonant term of the current loop at 2*fgrid, axis xi: [output; quadrature]
    res_q = zeros(2,1);              % axis eta
    uc_z     = zeros(3,1);           % one-step delay of the capacitor voltage (droop mode)
    dr_pf = 0; dr_qf = 0;            % droop mode: filtered active and reactive power
    dr_lpd = 0; dr_lpq = 0;          % low-pass of the output current (transient virtual resistance)
    dr_state = 0;                    % 0 synchronization, 1 droop, 2 droop after a black start
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
    nsc   = false;                   % negative-sequence compensator, optional as well (p.ctrl.nsc_*)
    kp_n  = 0;
    ki_n  = 0;
    lim_n = 0;
    kr_i  = 0;
    if isfield(p.ctrl, 'nsc_enable')
        nsc   = p.ctrl.nsc_enable ~= 0;
        kp_n  = p.ctrl.nsc_kp_ug;
        ki_n  = p.ctrl.nsc_ki_ug;
        lim_n = p.ctrl.nsc_i_lim;
        kr_i  = p.ctrl.nsc_kr_i;
    end
    ol    = false;                   % open-loop V/f mode, optional as well (p.ctrl.open_loop, ol_*)
    ol_dc = false;
    ol_tr = 0;
    if isfield(p.ctrl, 'open_loop')
        ol    = p.ctrl.open_loop ~= 0;
        ol_dc = p.ctrl.ol_udc_comp ~= 0;
        ol_tr = p.ctrl.ol_t_ramp;
    end
    if ol
        nsc = false;                 % no loops in open loop, the compensator included
    end
    dr = false;                      % droop mode, optional as well (p.ctrl.droop, droop_*)
    dr_mp = 0; dr_nq = 0; dr_tp = 1; dr_tq = 1; dr_md = 0; dr_p = 0; dr_q = 0; dr_rv = 0; dr_xv = 0;
    dr_rt = 0; dr_thp = 1; dr_ithr = 0; dr_kx = 0; dr_xr = 1; dr_imax = 0; dr_kpu = 0; dr_kiu = 0;
    dr_tsync = 0; dr_tramp = 0; b_cf = 0;
    if isfield(p.ctrl, 'droop')
        dr       = p.ctrl.droop ~= 0;
        dr_mp    = p.ctrl.droop_mp;
        dr_nq    = p.ctrl.droop_nq;
        dr_tp    = p.ctrl.droop_tau_p;
        dr_tq    = p.ctrl.droop_tau_q;
        dr_md    = p.ctrl.droop_md;
        dr_p     = p.ctrl.droop_p_ref;
        dr_q     = p.ctrl.droop_q_ref;
        dr_rv    = p.ctrl.droop_rv;
        dr_xv    = p.ctrl.droop_xv;
        dr_rt    = p.ctrl.droop_rt;
        dr_thp   = p.ctrl.droop_tau_hp;
        dr_ithr  = p.ctrl.droop_i_thr;
        dr_kx    = p.ctrl.droop_kx;
        dr_xr    = p.ctrl.droop_x_r;
        dr_imax  = p.ctrl.droop_i_max;
        dr_kpu   = p.ctrl.droop_kp_u;
        dr_kiu   = p.ctrl.droop_ki_u;
        dr_tsync = p.ctrl.droop_t_sync;
        dr_tramp = p.ctrl.droop_t_ramp;
        b_cf     = 2*pi*p.ctrl.fgrid*p.hw.Cf*p.hw.ubez/p.hw.ibez;   % filter capacitor at fgrid [pu]
    end
    if dr
        slave = false;               % the droop mode replaces the master/slave chain
        nsc   = false;
        ol    = false;
    end

    % ---- acquisitions: the control uses the samples of the previous trigger (Unit Delay after the
    %      Quantizer), the delay states take the samples of this trigger
    ugd  = ug_z;
    isd  = is_z;
    igd  = ig_z;
    udcd = udc_z;
    ucd  = uc_z;
    q = p.ctrl.adc_q;
    ug_z  = q*round(m(10:12)/q);
    is_z  = q*round(m(1:3)/q);
    ig_z  = -q*round(m(7:9)/q);      % Gain -1 after the delay ("ig afe quantizzation and one step delay")
    udc_z = q*round(m(13)/q);
    uc_z  = q*round(m(4:6)/q);

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
    u_n_alpha = 1/2*(u_hat(1) - v_hat(2));             % negative sequence: quadrature terms with the other sign
    u_n_beta  = 1/2*(u_hat(2) + v_hat(1));

    % ---- free-running phase generator (grid_phase_gen): output of this step, then advance; a slave
    %      takes the angle of the master and keeps its own generator aligned to it
    theta = th;
    if slave
        theta = sync(1);
    end
    if dr && dr_state == 0 && t_master < dr_tsync && u_grid_mag >= 0.5
        theta = mod(atan2(u_fhtsr_beta, u_fhtsr_alpha), 2*pi);   % droop mode, synchronization: follow ug
    end
    th = mod(theta + 2*pi*p.ctrl.fgrid*ts, 2*pi);       % droop mode: advanced again below with w
    if th >= 2*pi
        th = 0;
    end

    % ---- positive sequence in the rotating frame (sequences/alphabeta2xieta)
    u_xi  =  u_fhtsr_alpha*cos(theta) + u_fhtsr_beta*sin(theta);
    u_eta = -u_fhtsr_alpha*sin(theta) + u_fhtsr_beta*cos(theta);

    % ---- negative sequence in the negative frame (angle -theta): constant for a negative sequence at fgrid
    u_xi_n  = u_n_alpha*cos(theta) - u_n_beta*sin(theta);
    u_eta_n = u_n_alpha*sin(theta) + u_n_beta*cos(theta);

    % ---- droop mode: power at the terminals, droops, virtual impedance, voltage PI on the filter capacitor
    %      with feedforward (in place of the voltage loop below); feedforward of u_c for the current loop
    p_k = 0; q_k = 0; w_pu = 1; e_ref = 0; uc_xi = 0; uc_eta = 0; io_xi = 0; io_eta = 0; dx = 0;
    ffm_d = 0; ffm_q = 0;
    i_xi_ref = 0; i_eta_ref = 0; clip_u = 0;           % defined on every path (code generation)
    if dr
        c_th = cos(theta);
        s_th = sin(theta);
        uc_alpha = 2/3*(ucd(1) - 1/2*ucd(2) - 1/2*ucd(3));             % capacitor voltage (previous trigger)
        uc_beta  = 1/sqrt(3)*(ucd(2) - ucd(3));
        uc_xi  =  uc_alpha*c_th + uc_beta*s_th;
        uc_eta = -uc_alpha*s_th + uc_beta*c_th;
        io_alpha = -2/3*(igd(1) - 1/2*igd(2) - 1/2*igd(3));            % output current towards the grid: -igd
        io_beta  = -1/sqrt(3)*(igd(2) - igd(3));
        io_xi  =  io_alpha*c_th + io_beta*s_th;
        io_eta = -io_alpha*s_th + io_beta*c_th;
        ugs_xi  =  ug_alpha*c_th + ug_beta*s_th;                       % terminal voltage, sample (not the FHT)
        ugs_eta = -ug_alpha*s_th + ug_beta*c_th;
        p_k = ugs_xi*io_xi + ugs_eta*io_eta;                           % power at the terminals [pu]
        q_k = ugs_eta*io_xi - ugs_xi*io_eta;
        if dr_state == 0 && t_master >= dr_tsync
            if u_grid_mag >= 0.5
                dr_state = 1;                                          % energized bus: droop from the followed angle
            else
                dr_state = 2;                                          % dead bus: black start
            end
        end
        k_dr = 1;                                                      % start ramp of P*, Q* (and E after a black start)
        if dr_tramp > 0
            k_dr = min(max((t_master - dr_tsync)/dr_tramp, 0), 1);
        end
        if dr_state == 0
            % synchronization: zero current reference, voltage PI at rest; the power filters and the low-pass
            % of i_o follow their inputs, so that the droop starts from the operating point without a step (from
            % zero, the capacitor current that the bus supplies before the start passed whole through r_t)
            dr_pf = p_k; dr_qf = q_k; dr_lpd = io_xi; dr_lpq = io_eta;
            xd_u = 0; xq_u = 0;
            e_ref = u_grid_mag;
            i_xi_ref  = 0;
            i_eta_ref = 0;
            clip_u    = 0;
        else
            w_pu  = 1 + sync(5) + dr_mp*(dr_p*k_dr + sync(2) - dr_pf) - dr_md*(p_k - dr_pf);
            e_ref = p.ctrl.ug_ref + sync(4) + dr_nq*(dr_q*k_dr + sync(3) - dr_qf);
            if dr_state == 2
                e_ref = e_ref*k_dr;
            end
            dr_pf = dr_pf + ts/dr_tp*(p_k - dr_pf);
            dr_qf = dr_qf + ts/dr_tq*(q_k - dr_qf);
            dx  = dr_kx*max(sqrt(io_xi^2 + io_eta^2) - dr_ithr, 0);      % threshold virtual impedance
            r_v = dr_rv + dx/dr_xr;
            x_v = dr_xv + dx;
            u_ref_xi  = e_ref - (r_v*io_xi - x_v*io_eta) - dr_rt*(io_xi - dr_lpd);
            u_ref_eta =       - (r_v*io_eta + x_v*io_xi) - dr_rt*(io_eta - dr_lpq);
            dr_lpd = dr_lpd + ts/dr_thp*(io_xi - dr_lpd);
            dr_lpq = dr_lpq + ts/dr_thp*(io_eta - dr_lpq);
            [i_xi_ref, i_eta_ref, clip_u, xd_u, xq_u] = dq_vector_pi( ...
                u_ref_xi - uc_xi, u_ref_eta - uc_eta, xd_u, xq_u, clip_u_z, ...
                dr_kpu, dr_kiu*ts_i, p.ctrl.clip_release*ts_i, dr_imax, dr_imax, ...
                io_xi - b_cf*uc_eta, io_eta + b_cf*uc_xi);              % feedforward of i_o + j*b*u_c
        end
        th = mod(theta + 2*pi*p.ctrl.fgrid*w_pu*ts, 2*pi);             % phase generator at the droop frequency
        if th >= 2*pi
            th = 0;
        end
        k_ff = p.hw.ubez*sqrt(3)/(p.hw.udc_nom*max(udcd, 0.5));        % u_c as modulation index
        ffm_d = k_ff*uc_xi;
        ffm_q = k_ff*uc_eta;
    end

    % ---- voltage loop: dq vector PI -> current references (afe_control/dq_vector_pi); a slave takes
    %      the references of the master and leaves its PI at rest; none in open loop
    if dr
        % references from the droop branch above
    elseif ol
        i_xi_ref  = 0;
        i_eta_ref = 0;
        clip_u    = 0;
    elseif slave
        i_xi_ref  = sync(2);
        i_eta_ref = sync(3);
        clip_u    = 0;
    else
        [i_xi_ref, i_eta_ref, clip_u, xd_u, xq_u] = dq_vector_pi( ...
            p.ctrl.ug_ref - u_xi, p.ctrl.ueta_ref - u_eta, xd_u, xq_u, clip_u_z, ...
            p.ctrl.kp_ug, p.ctrl.ki_ug*ts_i, p.ctrl.clip_release*ts_i, p.ctrl.ixi_lim, p.ctrl.clip_thr_ug, 0, 0);
    end
    clip_u_z = clip_u;                                 % Unit Delay1 of pi_d/pi_q

    % ---- negative-sequence compensator: PI of the master on (u_xi_n, u_eta_n) with references 0 ->
    %      negative-sequence current references (negative frame); a slave takes those of the master
    i_xi_n_ref  = 0;
    i_eta_n_ref = 0;
    clip_n      = 0;
    if nsc
        if slave
            i_xi_n_ref  = sync(4);
            i_eta_n_ref = sync(5);
        else
            [i_xi_n_ref, i_eta_n_ref, clip_n, xd_n, xq_n] = dq_vector_pi( ...
                -u_xi_n, -u_eta_n, xd_n, xq_n, clip_n_z, ...
                kp_n, ki_n*ts_i, p.ctrl.clip_release*ts_i, lim_n, lim_n, 0, 0);
        end
    end
    clip_n_z = clip_n;

    % ---- current loop (current_ctrl): converter current in the rotating frame, dq vector PI; with the
    %      compensator the negative-sequence references, rotated into the positive frame (angle -2*theta),
    %      are added to those of the voltage loop and a resonant term at 2*fgrid on each axis tracks them
    i_alpha = 2/3*(isd(1) - 1/2*isd(2) - 1/2*isd(3));  % uvw2alphabeta
    i_beta  = 2/3*(sqrt(3)/2*(isd(2) - isd(3)));
    i_xi  =  i_alpha*cos(theta) + i_beta*sin(theta);   % alphabeta2xieta
    i_eta = -i_alpha*sin(theta) + i_beta*cos(theta);
    i_xi_r  = i_xi_ref;
    i_eta_r = i_eta_ref;
    r_d = 0;
    r_q = 0;
    if nsc
        c2 = cos(2*theta);
        s2 = sin(2*theta);
        i_xi_r  = i_xi_ref  + i_xi_n_ref*c2 + i_eta_n_ref*s2;
        i_eta_r = i_eta_ref - i_xi_n_ref*s2 + i_eta_n_ref*c2;
        w_res = 2*2*pi*p.ctrl.fgrid;
        [r_d, res_d] = resonant(i_xi_r - i_xi, res_d, kr_i, w_res, ts, p.ctrl.clip_release*ts_i, clip_i_z);
        [r_q, res_q] = resonant(i_eta_r - i_eta, res_q, kr_i, w_res, ts, p.ctrl.clip_release*ts_i, clip_i_z);
    end
    if ol
        % ---- open loop (V/f): the voltage [ug_ref; ueta_ref] at the angle theta as modulation index
        %      (unit circle = udc/sqrt(3) peak phase), with the start ramp and, with ol_udc_comp, divided by
        %      the acquired DC-link voltage (the floor 0.5 pu also covers the first trigger, udcd = 0);
        %      limiter of the current loop (radius u_lim, clip flag clip_i); the current PI stays at rest
        k_r = 1;
        if ol_tr > 0
            k_r = min(t_master/ol_tr, 1);
        end
        u_dc = 1;
        if ol_dc
            u_dc = max(udcd, 0.5);
        end
        k_ol = k_r*p.hw.ubez*sqrt(3)/(p.hw.udc_nom*u_dc);
        m_d = k_ol*p.ctrl.ug_ref;
        m_q = k_ol*p.ctrl.ueta_ref;
        mag = sqrt(m_d^2 + m_q^2);
        clip_i = 0;
        if mag >= p.ctrl.u_lim                         % as bounder1/2 of dq_vector_pi
            m_d = m_d/mag*p.ctrl.u_lim;
            m_q = m_q/mag*p.ctrl.u_lim;
            clip_i = 1;
        end
    else
        [m_d, m_q, clip_i, xd_i, xq_i] = dq_vector_pi( ...
            i_xi_r - i_xi, i_eta_r - i_eta, xd_i, xq_i, clip_i_z, ...
            p.ctrl.kp_i, p.ctrl.ki_i*ts_i, p.ctrl.clip_release*ts_i, p.ctrl.u_lim, p.ctrl.u_lim, ...
            r_d + ffm_d, r_q + ffm_q);                     % ffm: feedforward of u_c in the droop mode, else 0
    end
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
    logv(38) = u_xi_n;
    logv(39) = u_eta_n;
    logv(40) = i_xi_n_ref;
    logv(41) = i_eta_n_ref;
    logv(42) = r_d;
    logv(43) = r_q;
    logv(44) = p_k;                                    % droop mode (0 otherwise)
    logv(45) = q_k;
    logv(46) = dr_pf;
    logv(47) = dr_qf;
    logv(48) = w_pu;
    logv(49) = e_ref;
    logv(50) = uc_xi;
    logv(51) = uc_eta;
    logv(52) = io_xi;
    logv(53) = io_eta;
    logv(54) = dx;
    logv(55) = dr_state;

    % ---- references for the slave(s)
    sync_z = [theta; i_xi_ref; i_eta_ref; i_xi_n_ref; i_eta_n_ref];
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
function [md_sat, mq_sat, clip, xd, xq] = dq_vector_pi(ed, eq, xd, xq, clip_z, kp, ki_ts, rel_ts, lim, clip_thr, fd, fq)
%DQ_VECTOR_PI  dq vector PI of the model: blocks pi_d, pi_q, "vector lenght", bounder1/2, switch.
%   ed, eq      errors (reference - measure)
%   xd, xq      integrator states (Unit Delay2 of pi_d, pi_q)
%   clip_z      clip flag of the previous step (Unit Delay1 of pi_d, pi_q)
%   kp, ki_ts   proportional gain and integral gain already multiplied by the sample time
%   rel_ts      CTRPIFF_CLIP_RELEASE*ts, leak of the integrator while clipped
%   lim         radius of the output limiter (Switch1 threshold and gain of the bounders)
%   clip_thr    radius at which the clip flag is raised (Switch threshold of the bounders)
%   fd, fq      terms added to the PI outputs before the limiter (resonant part of the current loop
%               with the negative-sequence compensator, 0 otherwise)
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
    md = md + fd;
    mq = mq + fq;
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
function [y, x] = resonant(e, x, kr, wr, ts, rel_ts, clip_z)
%RESONANT  Resonant term kr*s/(s^2 + wr^2) of the current loop (negative-sequence compensator).
%   e        error (reference - measure)
%   x        states [output; quadrature]: x1' = kr*e - wr*x2, x2' = wr*x1
%   ts       period of the control step
%   rel_ts   leak of the states while the current loop clips (clip_z), as the integrators of
%            dq_vector_pi; the input is then ignored and the oscillator keeps turning
%   Semi-implicit Euler with a = 2*sin(wr*ts/2) in place of wr*ts: eigenvalues on the unit circle at the
%   angle wr*ts, i.e. the discrete oscillator resonates exactly at wr and keeps its amplitude (how the
%   discretization of a resonant term moves its resonance: reference [7] of the header).
    a = 2*sin(wr*ts/2);
    if clip_z > 0.5
        u = 0;
        k = 1 - rel_ts;
    else
        u = kr*e;
        k = 1;
    end
    x1 = k*x(1) + ts*u - a*x(2);
    x2 = k*x(2) + a*x1;
    x = [x1; x2];
    y = x1;
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
