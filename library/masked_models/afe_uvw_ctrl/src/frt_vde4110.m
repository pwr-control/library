function [i_grid_ref, frt_active, pwr_lim_enable, frt_log] = frt_vde4110(v_seq_avg, i_react_ref, enable, reset, p)
%FRT_VDE4110  Fault ride-through (VDE-AR-N 4110): fault detection and reactive current references.
%
%   [i_grid_ref, frt_active, pwr_lim_enable, frt_log] = frt_vde4110(v_seq_avg, i_react_ref, enable, reset, p)
%
%   MATLAB Function version of the subsystem FRT-VDE4110 of the model afe_uvw_three_phase
%   (afe_uvw_ctrl.slx, pwr-control/modelization-and-control). Two parts:
%
%   A. Fault detection (the LVRT_detector of the model, plus its two voltage-rate observers).
%      State machine IDLE -> ACTIVE -> EXCEEDED:
%      - IDLE -> ACTIVE when the positive-sequence voltage leaves the band [v_pos_low, v_pos_high]
%        or the negative sequence exceeds v_neg_max, AND one of the two voltages is changing faster
%        than v_dot_max [pu/s], AND the detector has been idle for more than t_rearm;
%      - ACTIVE -> IDLE when the positive sequence is back inside the band narrowed by v_hyst;
%      - ACTIVE -> EXCEEDED after t_hold_max in ACTIVE (fault too long); EXCEEDED -> IDLE on reset.
%      In ACTIVE the power limitation flag is set when v_pos < pwrlim_v_pos or v_neg > pwrlim_v_neg
%      and released with hysteresis; the reduced dynamic support flag (red_dyn) is set when
%      p.frt.reddyn_enabled and the voltage is below reddyn_v_pos or the negative sequence above
%      reddyn_v_neg (the model has this input at 0).
%      The voltage rates are the velocity states of two linear double-integrator observers
%      (x' = v + kx*(u - x), v' = kv*(u - x), forward Euler, held at zero before t_obs_release):
%      the same algorithm as linear_double_integrator_observer_ccaller of the library.
%
%   B. Reactive current references (FRT-PosNegReactiveCurrentReferences of the model).
%      The pre-fault voltages are moving averages over t_avg_prefault (0.5 s) that are FROZEN while
%      the fault is active and start only at t_avg_start, when the sequence averages are valid (the
%      model's averages start at zero and take the start-up transient in); dv = v_seq_avg - v_prefault. During the fault
%          i_pos_eta = i_react_ref(1) + k_frt_ref*dv_pos_xi
%          i_neg_eta = i_react_ref(2) - k_frt_ref*dv_neg_xi
%          i_neg_xi  =                 k_frt_ref*dv_neg_eta
%      (the negative-sequence current is the negative-sequence voltage change turned by 90 degrees:
%      reactive current against the unbalance); outside the fault the first two are the inputs and
%      the third is zero. Each reference is limited to +-lim (the reduced limits lim_*_red when
%      red_dyn is active) and smoothed by a first-order low pass at f_lpf_ref (y = g0*u + g1*y,
%      g0 = 2*pi*f*ts, g1 = 1 - g0, as the u_161Hz_flt blocks of the model).
%
%   Inputs
%     v_seq_avg    [4x1] averaged grid voltage sequences [pos_xi; pos_eta; neg_xi; neg_eta] [pu]
%                        (output v_seq_avg of grid_voltage_sequences)
%     i_react_ref  [2x1] reactive current references in normal operation [pos; neg] [pu]
%                        (i_react_pos_ref, i_react_neg_ref of the model)
%     enable       > 0.5: detector enabled (the model: a step at settle_time when the FRT test is on)
%     reset        > 0.5: leaves the EXCEEDED state (the model: 1 for the first 25 ms)
%     p            parameter struct, see afe_uvw_ctrl_param_example.m: p.ts, p.frt.*
%
%   Outputs
%     i_grid_ref      [3x1] grid current references [pos_eta; neg_xi; neg_eta] [pu]
%                           (the bus i_grid_seq_ref of the model) -> grid_current_sequences_q_ctrl
%     frt_active      1 while the fault is detected
%     pwr_lim_enable  1 when the active power has to be limited (read by the DC-link controller)
%     frt_log         [10x1] [frt_state (0 idle, 1 active, 2 exceeded); frt_exceeded; red_dyn_active;
%                     vxi_p_dot; vxi_n_dot; v_prefault(4); |v_neg|]
%
%   States (persistent)
%     obs_x, obs_v  [2x1] observer states (position, velocity) for the positive and the negative xi
%     buf, idx, n_filled, acc   moving averages of the pre-fault voltages (4 channels, running sum)
%     y_lpf         [3x1] low-pass states of the three references
%     state, pwr_lim, n_active, n_idle   state machine, power-limit flag, sample counters
%     n_call        number of calls (time since the start = n_call*ts)
%
%   See also grid_voltage_sequences, grid_current_sequences_q_ctrl, afe_uvw_ctrl_param_example.

    N_BUF = 8192;                    % buffer of the pre-fault averages [samples] >= t_avg_prefault/ts

    IDLE = 0;  ACTIVE = 1;  EXCEEDED = 2;

    persistent obs_x obs_v buf idx n_filled acc y_lpf state pwr_lim n_active n_idle n_call
    if isempty(state)
        obs_x = zeros(2, 1);
        obs_v = zeros(2, 1);
        buf = zeros(4, N_BUF);
        idx = 0;
        n_filled = 0;
        acc = zeros(4, 1);
        y_lpf = zeros(3, 1);
        state = IDLE;
        pwr_lim = 0;
        n_active = 0;
        n_idle = 0;
        n_call = 0;
    end
    ts = p.ts;
    n_call = n_call + 1;
    t_now = (n_call - 1)*ts;

    v_pos_xi = v_seq_avg(1);
    v_neg_xi = v_seq_avg(3);
    v_neg_eta = v_seq_avg(4);
    v_neg = sqrt(v_neg_xi^2 + v_neg_eta^2);

    % ---- A1. voltage rate observers on the positive and the negative xi component
    if t_now < p.frt.t_obs_release - 0.5*ts       % observers held at zero at the start
        obs_x = zeros(2, 1);
        obs_v = zeros(2, 1);
    end
    u_obs = [v_pos_xi; v_neg_xi];
    e_obs = u_obs - obs_x;
    obs_x = obs_x + ts*(obs_v + p.frt.obs_kx*e_obs);
    obs_v = obs_v + ts*p.frt.obs_kv*e_obs;
    vxi_p_dot = abs(obs_v(1));
    vxi_n_dot = abs(obs_v(2));

    % ---- A2. fault detection state machine
    n_rearm = round(p.frt.t_rearm/ts);
    n_hold_max = round(p.frt.t_hold_max/ts);
    frt_exceeded = 0;
    red_dyn_active = 0;
    if enable > 0.5
        if state == IDLE
            out_of_band = v_pos_xi > p.frt.v_pos_high || v_pos_xi < p.frt.v_pos_low || v_neg > p.frt.v_neg_max;
            fast_change = vxi_p_dot > p.frt.v_pos_dot_max || vxi_n_dot > p.frt.v_neg_dot_max;
            if out_of_band && fast_change && n_idle > n_rearm
                state = ACTIVE;
            end
            frt_active = 0;
            n_active = 0;
            pwr_lim = 0;
            n_idle = n_idle + 1;

        elseif state == ACTIVE
            n_idle = 0;
            if v_pos_xi >= p.frt.v_pos_low + p.frt.v_hyst && v_pos_xi < p.frt.v_pos_high - p.frt.v_hyst
                state = IDLE;                       % voltage back in the band: fault over
            elseif n_active >= n_hold_max
                state = EXCEEDED;                   % fault too long
            end
            % power limitation
            if v_pos_xi < p.frt.pwrlim_v_pos || v_neg > p.frt.pwrlim_v_neg
                pwr_lim = 1;
            elseif v_pos_xi > p.frt.pwrlim_v_pos + p.frt.pwrlim_hyst && v_neg < p.frt.pwrlim_v_neg_release
                pwr_lim = 0;
            end
            % reduced dynamic grid support
            if p.frt.reddyn_enabled > 0.5 && (v_pos_xi < p.frt.reddyn_v_pos || v_neg > p.frt.reddyn_v_neg)
                red_dyn_active = 1;
            end
            frt_active = 1;
            n_active = n_active + 1;

        else                                            % EXCEEDED
            if reset > 0.5
                state = IDLE;
            end
            frt_exceeded = 1;
            frt_active = 0;
        end
        pwr_lim_enable = pwr_lim;
    else
        state = IDLE;
        frt_active = 0;
        pwr_lim_enable = 0;
    end
    frt_state = state;

    % ---- B1. pre-fault voltages: moving averages over t_avg_prefault, frozen during the fault
    n_avg = min(round(p.frt.t_avg_prefault/ts), N_BUF);
    if frt_active == 0 && t_now >= p.frt.t_avg_start - 0.5*ts   % not during the fault, not at the start
        [buf, idx, n_filled, acc] = moving_sum_push(v_seq_avg, n_avg, buf, idx, n_filled, acc);
    end
    if n_filled > 0
        v_prefault = acc/n_filled;
    else
        v_prefault = v_seq_avg;                              % nothing stored yet: no fault contribution
    end
    dv = v_seq_avg - v_prefault;

    % ---- B2. reactive current references
    if frt_active == 1
        i_pos_eta = i_react_ref(1) + p.frt.k_frt_ref*dv(1);
        i_neg_eta = i_react_ref(2) - p.frt.k_frt_ref*dv(3);
        i_neg_xi  =                  p.frt.k_frt_ref*dv(4);
    else
        i_pos_eta = i_react_ref(1);
        i_neg_eta = i_react_ref(2);
        i_neg_xi  = 0;
    end
    if red_dyn_active == 1
        lim = [p.frt.lim_pos_eta_red; p.frt.lim_neg_xi_red; p.frt.lim_neg_eta_red];
    else
        lim = [p.frt.lim_pos_eta; p.frt.lim_neg_xi; p.frt.lim_neg_eta];
    end
    i_raw = [i_pos_eta; i_neg_xi; i_neg_eta];
    i_raw = min(max(i_raw, -lim), lim);

    g0 = 2*pi*p.frt.f_lpf_ref*ts;                        % first-order low pass, forward Euler
    y_lpf = g0*i_raw + (1 - g0)*y_lpf;
    i_grid_ref = y_lpf;

    frt_log = [frt_state; frt_exceeded; red_dyn_active; vxi_p_dot; vxi_n_dot; v_prefault; v_neg];
end


function [buf, idx, n_filled, acc] = moving_sum_push(u, n_win, buf, idx, n_filled, acc)
%MOVING_SUM_PUSH  Push the sample u into the circular buffer and keep acc = sum of the last n_win.
%   buf [n_ch x n_buf], idx = position of the newest sample, n_filled = samples in the window
%   (at most n_win). The average is acc/n_filled.
    n_buf = size(buf, 2);
    idx = idx + 1;
    if idx > n_buf
        idx = 1;
    end
    if n_filled >= n_win                   % window full: the oldest sample leaves
        j = idx - n_win;
        if j < 1
            j = j + n_buf;
        end
        acc = acc - buf(:, j);
    else
        n_filled = n_filled + 1;
    end
    buf(:, idx) = u;
    acc = acc + u;
end
