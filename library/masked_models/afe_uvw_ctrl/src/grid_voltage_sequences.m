function [v_seq_avg, v_seq, ug_ab] = grid_voltage_sequences(ug_abc, theta, omega_pu, p)
%GRID_VOLTAGE_SEQUENCES  Positive and negative sequence of the grid voltage (xi, eta frames).
%
%   [v_seq_avg, v_seq, ug_ab] = grid_voltage_sequences(ug_abc, theta, omega_pu, p)
%
%   MATLAB Function version of the subsystem grid_voltage_sequences of the model afe_uvw_three_phase
%   (afe_uvw_ctrl.slx, pwr-control/modelization-and-control). Three steps:
%     1. Clarke transformation abc -> alpha, beta (amplitude invariant, factor 2/3);
%     2. rotation with the PLL angle into the positive-sequence frame and into the negative-sequence
%        frame (xi, eta);
%     3. moving average of the four components over a window that follows the grid frequency.
%
%   Inputs
%     ug_abc    [3x1] grid phase voltages [pu]
%     theta     grid angle of the PLL [rad]              (phase_grid_pll in the model)
%     omega_pu  grid pulsation of the PLL [pu of p.omega_nom] (omega_grid_pll_pu in the model)
%     p         parameter struct, see afe_uvw_ctrl_param_example.m: p.ts, p.omega_nom, p.vseq.*
%
%   Outputs
%     v_seq_avg [4x1] [pos_xi; pos_eta; neg_xi; neg_eta] after the moving average
%                     (v_grid_pos_xi_avg, v_grid_pos_eta_avg, v_grid_neg_xi_avg, v_grid_neg_eta_avg)
%     v_seq     [4x1] the same components before the average
%     ug_ab     [2x1] [alpha; beta] of the grid voltage [pu] (ug_alpha_pu, ug_beta_pu)
%
%   Frames (convention of the model)
%     positive: xi =  alpha*cos(theta) + beta*sin(theta),   eta = -alpha*sin(theta) + beta*cos(theta)
%     negative: xi =  alpha*cos(theta) - beta*sin(theta),   eta =  alpha*sin(theta) + beta*cos(theta)
%   With theta locked to the positive sequence, the positive sequence is a constant vector in the
%   positive frame and a vector rotating at 2*omega in the negative frame (and the other way round for
%   the negative sequence): the moving average over half a grid period (p.vseq.avg_order = 2) removes
%   the 2*omega term exactly, over a full period (avg_order = 1) it removes every harmonic as well.
%
%   Discrete time
%     The function runs once per control period p.ts (inside the triggered control subsystem, or with
%     the block sample time set to p.ts). Averaging window T = 2*pi/(p.omega_nom*p.vseq.avg_order*w),
%     with w = |omega_pu| limited to [p.vseq.omega_pu_min, p.vseq.omega_pu_max]. N = T/p.ts is not an
%     integer: the window holds floor(N) whole samples plus the next older one with the fractional
%     weight (see moving_average_frac at the end of this file). Before p.vseq.t_enable the averages are
%     zero (as the dmavg_flt blocks of the model); from then on they are the mean of the samples
%     received so far, until the window is full.
%
%   States (persistent)
%     buf       [4 x N_BUF] circular buffer of the last samples of v_seq
%     idx       position of the newest sample in buf
%     n_filled  number of valid samples in buf (saturates at N_BUF)
%     n_call    number of calls since the start (start-up delay t_enable = n_call*ts)
%
%   See also grid_current_sequences_q_ctrl, frt_vde4110, afe_uvw_ctrl_param_example.

    N_BUF = 4096;                    % buffer length [samples]; must be >= the longest window + 1
                                     % (window at omega_pu_min: 2*pi/(omega_nom*avg_order*omega_pu_min)/ts)

    persistent buf idx n_filled n_call
    if isempty(buf)
        buf = zeros(4, N_BUF);
        idx = 0;
        n_filled = 0;
        n_call = 0;
    end

    % ---- 1. Clarke transformation, amplitude invariant
    alpha = 2/3*(ug_abc(1) - 0.5*ug_abc(2) - 0.5*ug_abc(3));
    beta  = 1/sqrt(3)*(ug_abc(2) - ug_abc(3));
    ug_ab = [alpha; beta];

    % ---- 2. rotation into the positive and the negative sequence frame
    c = cos(theta);
    s = sin(theta);
    pos_xi  =  alpha*c + beta*s;
    pos_eta = -alpha*s + beta*c;
    neg_xi  =  alpha*c - beta*s;
    neg_eta =  alpha*s + beta*c;
    v_seq = [pos_xi; pos_eta; neg_xi; neg_eta];

    % ---- 3. moving average over T = 2*pi/(avg_order*omega) with the measured grid pulsation
    w = min(max(abs(omega_pu), p.vseq.omega_pu_min), p.vseq.omega_pu_max);
    T_avg = 2*pi/(p.omega_nom*p.vseq.avg_order*w);           % [s] averaging window
    n_win = min(T_avg/p.ts, N_BUF - 1);                       % [samples], not an integer

    n_call = n_call + 1;
    if (n_call - 1)*p.ts >= p.vseq.t_enable - 0.5*p.ts        % t = (n_call-1)*ts >= t_enable
        [v_seq_avg, buf, idx, n_filled] = moving_average_frac(v_seq, n_win, buf, idx, n_filled);
    else
        v_seq_avg = zeros(4, 1);                              % start-up: averages off (as the model)
    end
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
