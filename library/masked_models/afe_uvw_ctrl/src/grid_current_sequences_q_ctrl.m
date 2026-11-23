function [i_stack_ref, i_seq_avg, i_seq] = grid_current_sequences_q_ctrl(ig_abc, theta, omega_pu, i_grid_ref, p)
%GRID_CURRENT_SEQUENCES_Q_CTRL  Sequences of the grid current and control of its reactive components.
%
%   [i_stack_ref, i_seq_avg, i_seq] = grid_current_sequences_q_ctrl(ig_abc, theta, omega_pu, i_grid_ref, p)
%
%   MATLAB Function version of the subsystem grid_current_sequences_and_reactive_pwr_ctrl of the model
%   afe_uvw_three_phase (afe_uvw_ctrl.slx, pwr-control/modelization-and-control), without the
%   Simulink / C-Caller selector. Two parts:
%     1. sequences of the grid current, exactly as grid_voltage_sequences does for the voltage:
%        Clarke, rotation into the positive and the negative frame with the PLL angle, moving average
%        over a window that follows the grid frequency;
%     2. three PI controllers that make the averaged grid current follow its references
%        (positive-sequence eta, negative-sequence xi and eta) by moving the references of the
%        stack (converter) current, which the inner current controller then tracks.
%   The positive-sequence xi (active) current is not controlled here: its reference comes from the
%   DC-link voltage controller.
%
%   Inputs
%     ig_abc      [3x1] grid phase currents [pu]
%     theta       grid angle of the PLL [rad]
%     omega_pu    grid pulsation of the PLL [pu of p.omega_nom]
%     i_grid_ref  [3x1] grid current references [pos_eta; neg_xi; neg_eta] [pu] (from frt_vde4110)
%     p           parameter struct, see afe_uvw_ctrl_param_example.m: p.ts, p.omega_nom, p.iseq.*
%
%   Outputs
%     i_stack_ref [3x1] stack current references [pos_eta; neg_xi; neg_eta] [pu]
%                       (i_stack_pos_eta_ref, i_stack_neg_xi_ref, i_stack_neg_eta_ref of the model)
%     i_seq_avg   [4x1] [pos_xi; pos_eta; neg_xi; neg_eta] averaged grid current
%                       (i_grid_pos_xi_avg ... i_grid_neg_eta_avg of the model)
%     i_seq       [4x1] the same before the average
%
%   Sign of the error. The model measures the grid current towards the converter and the stack
%   current out of the converter, so a grid eta current above its reference asks for MORE stack eta
%   current: the PI works on e = p.iseq.err_sign*(reference - measured) with err_sign = -1 (the model
%   has a Sum ref - meas followed by a gain -1). Set err_sign = +1 if the grid current of your model
%   is measured in the direction of the stack current.
%
%   PI controller (pi_clamped at the end of this file): u = kp*e + ui, ui = ui + ki*ts*e (backward
%   Euler), output limited to +-lim and the integral state clamped to u_lim - kp*e, which is the
%   anti-windup of the Simulink PI (unit delay fed with saturation - P). Gains and limits:
%   p.iseq.kp_pos, ki_pos, lim_pos_eta for the positive sequence; kp_neg, ki_neg, lim_neg_xi,
%   lim_neg_eta for the negative one (the model uses the positive limit for the negative xi too:
%   lim_neg_xi = ieta_pos_ref_lim, lim_neg_eta = ieta_neg_ref_lim).
%
%   Discrete time: one call per control period p.ts. Averaging window T = 2*pi/(p.omega_nom*
%   p.iseq.avg_order*w), w = |omega_pu| limited to [p.iseq.omega_pu_min, p.iseq.omega_pu_max];
%   averages zero before p.iseq.t_enable (as the dmavg_flt blocks of the model).
%
%   States (persistent)
%     buf, idx, n_filled, n_call   moving average, see grid_voltage_sequences
%     ui                           [3x1] integral states of the three PIs [pos_eta; neg_xi; neg_eta]
%
%   See also grid_voltage_sequences, frt_vde4110, current_ctrl_uvw, afe_uvw_ctrl_param_example.

    N_BUF = 4096;                    % buffer length [samples]; must be >= the longest window + 1

    persistent buf idx n_filled n_call ui
    if isempty(buf)
        buf = zeros(4, N_BUF);
        idx = 0;
        n_filled = 0;
        n_call = 0;
        ui = zeros(3, 1);
    end

    % ---- 1. sequences of the grid current
    alpha = 2/3*(ig_abc(1) - 0.5*ig_abc(2) - 0.5*ig_abc(3));
    beta  = 1/sqrt(3)*(ig_abc(2) - ig_abc(3));
    c = cos(theta);
    s = sin(theta);
    i_seq = [ alpha*c + beta*s;        % positive sequence xi
             -alpha*s + beta*c;        % positive sequence eta
              alpha*c - beta*s;        % negative sequence xi
              alpha*s + beta*c];       % negative sequence eta

    w = min(max(abs(omega_pu), p.iseq.omega_pu_min), p.iseq.omega_pu_max);
    T_avg = 2*pi/(p.omega_nom*p.iseq.avg_order*w);           % [s] averaging window
    n_win = min(T_avg/p.ts, N_BUF - 1);                       % [samples], not an integer

    n_call = n_call + 1;
    if (n_call - 1)*p.ts >= p.iseq.t_enable - 0.5*p.ts
        [i_seq_avg, buf, idx, n_filled] = moving_average_frac(i_seq, n_win, buf, idx, n_filled);
    else
        i_seq_avg = zeros(4, 1);
    end

    % ---- 2. reactive current control: averaged grid current -> stack current references
    e_pos_eta = p.iseq.err_sign*(i_grid_ref(1) - i_seq_avg(2));
    e_neg_xi  = p.iseq.err_sign*(i_grid_ref(2) - i_seq_avg(3));
    e_neg_eta = p.iseq.err_sign*(i_grid_ref(3) - i_seq_avg(4));

    [u_pos_eta, ui(1)] = pi_clamped(e_pos_eta, ui(1), p.iseq.kp_pos, p.iseq.ki_pos*p.ts, p.iseq.lim_pos_eta);
    [u_neg_xi,  ui(2)] = pi_clamped(e_neg_xi,  ui(2), p.iseq.kp_neg, p.iseq.ki_neg*p.ts, p.iseq.lim_neg_xi);
    [u_neg_eta, ui(3)] = pi_clamped(e_neg_eta, ui(3), p.iseq.kp_neg, p.iseq.ki_neg*p.ts, p.iseq.lim_neg_eta);

    i_stack_ref = [u_pos_eta; u_neg_xi; u_neg_eta];
end


function [u, ui] = pi_clamped(e, ui, kp, ki_ts, lim)
%PI_CLAMPED  PI controller with the integrator clamped to the output limit (anti-windup).
%   ui is the integral state; ki_ts = ki*ts. Backward Euler: the integral includes the present error.
    up = kp*e;
    ui = ui + ki_ts*e;
    u = min(max(up + ui, -lim), lim);
    ui = u - up;                      % when limited, the integral keeps what the limit leaves to it
end


function [y, buf, idx, n_filled] = moving_average_frac(u, n_win, buf, idx, n_filled)
%MOVING_AVERAGE_FRAC  Moving average of the column vector u over a window of n_win samples (real).
%   The newest sample u is written into the circular buffer buf (one row per channel), idx is moved
%   to it. The window holds n_whole = floor(n_win) samples, the newest first, plus the next older one
%   with the weight frac = n_win - n_whole, so that the window length follows the grid period without
%   jumps. During the start-up (fewer samples than the window) the mean of the stored samples is used.
    n_buf = size(buf, 2);

    idx = idx + 1;
    if idx > n_buf
        idx = 1;
    end
    buf(:, idx) = u;
    n_filled = min(n_filled + 1, n_buf);

    n_whole = floor(n_win);
    frac = n_win - n_whole;
    if n_filled <= n_whole                 % not enough samples yet for the whole window
        n_whole = n_filled;
        frac = 0;
    end

    acc = zeros(size(u));
    j = idx;
    for k = 1:n_whole                      % the n_whole newest samples
        acc = acc + buf(:, j);
        j = j - 1;
        if j < 1
            j = n_buf;
        end
    end
    acc = acc + frac*buf(:, j);            % the next older sample, fractional weight
    y = acc/(n_whole + frac);
end
