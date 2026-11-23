function [island, crit, idet_log] = islanding_detector(ug_ab, theta, omega_pu, enable, p)
%ISLANDING_DETECTOR  Passive islanding detection from the grid voltage and the PLL frequency.
%
%   [island, crit, idet_log] = islanding_detector(ug_ab, theta, omega_pu, enable, p)
%
%   New block for the model afe_uvw_three_phase (afe_uvw_ctrl.slx, pwr-control/modelization-and-
%   control), where islanding_mode_detector only measures the 7th harmonic of the grid voltage. The
%   detector is passive: it watches what the grid voltage at the point of connection does when the
%   grid is lost and the converter keeps feeding the local load. Six criteria, each with its own
%   threshold and its own on-delay (the condition must hold for the whole delay):
%     1. under-voltage        u1 < p.island.u_min                   for t_trip_u_min
%     2. over-voltage         u1 > p.island.u_max                   for t_trip_u_max
%     3. under-frequency      f  < p.island.f_min [pu]               for t_trip_f
%     4. over-frequency       f  > p.island.f_max [pu]               for t_trip_f
%     5. rate of change of frequency (ROCOF)  |df/dt| > rocof_max [Hz/s]  for t_trip_rocof
%     6. voltage harmonics    sqrt(u5^2 + u7^2)/u1 > h_max          for t_trip_h
%   u1 is the amplitude of the positive-sequence fundamental, u5 the negative-sequence 5th harmonic
%   and u7 the positive-sequence 7th harmonic of the grid voltage (the two harmonics that an inverter
%   with a dead-time or a non-linear local load produces most), each measured by turning alpha/beta
%   with the matching multiple of the PLL angle and averaging over one grid period (the same method
%   as the 7th harmonic measurement of the model). The frequency comes from the PLL pulsation,
%   low-pass filtered; the ROCOF from a double-integrator observer on it (as in frt_vde4110).
%   The frequency and harmonic criteria are blocked while u1 < p.island.u_valid (a PLL in a deep
%   voltage dip is not a frequency meter): a grid fault is handled by frt_vde4110, not here.
%   The output is latched (p.island.latch = 1) until enable goes to 0, or follows the criteria.
%
%   Limits of a passive detector: when the local load takes exactly the active and reactive power of
%   the converter, voltage and frequency do not move and only the harmonics can tell (non-detection
%   zone). The default thresholds are those of the network protection of VDE-AR-N 4105 / 4110
%   (47.5 - 51.5 Hz in 100 ms, 0.8 pu in 2.7 s, 1.15 pu in 100 ms) plus ROCOF 2.5 Hz/s and 10 %
%   harmonics. The slow under-voltage stage is what lets the converter ride through a grid fault
%   (frt_vde4110) without an islanding trip: the fault is a voltage dip too.
%
%   Inputs
%     ug_ab     [2x1] [alpha; beta] of the grid voltage [pu] (output ug_ab of grid_voltage_sequences)
%     theta     grid angle of the PLL [rad]
%     omega_pu  grid pulsation of the PLL [pu of p.omega_nom]
%     enable    > 0.5: detector armed (0 also resets the latch and the timers)
%     p         parameter struct, see afe_uvw_ctrl_param_example.m: p.ts, p.omega_nom, p.island.*
%
%   Outputs
%     island    1 when islanding is detected
%     crit      bit mask of the criteria that tripped: 1 under-voltage, 2 over-voltage,
%               4 under-frequency, 8 over-frequency, 16 ROCOF, 32 harmonics
%     idet_log  [8x1] [u1; u5; u7; harmonic ratio; f [pu]; ROCOF [Hz/s]; time of the longest
%               running criterion [s]; time since the detection [s]]
%
%   States (persistent)
%     buf, idx, n_filled   circular buffer of the six rotated components (3 frames x 2) for the
%                          moving averages
%     f_lpf                low-pass state of the frequency
%     obs_x, obs_v         observer states of the ROCOF
%     timers               [6x1] on-delay timers of the criteria [s]
%     latched, t_det       latched detection and its time
%     n_call               number of calls (for the start-up delay)
%
%   See also grid_voltage_sequences, frt_vde4110, afe_uvw_ctrl_param_example.

    N_BUF = 4096;                    % buffer length [samples] >= one grid period at omega_pu_min / ts

    persistent buf idx n_filled f_lpf obs_x obs_v timers latched t_det n_call
    if isempty(buf)
        buf = zeros(6, N_BUF);
        idx = 0;
        n_filled = 0;
        f_lpf = 1;
        obs_x = 1;
        obs_v = 0;
        timers = zeros(6, 1);
        latched = 0;
        t_det = 0;
        n_call = 0;
    end
    ts = p.ts;
    n_call = n_call + 1;
    t_now = (n_call - 1)*ts;
    alpha = ug_ab(1);
    beta = ug_ab(2);

    % ---- 1. fundamental (positive sequence), 5th (negative sequence) and 7th (positive sequence)
    %         harmonic in their own synchronous frames, then moving average over one grid period
    c1 = cos(theta);      s1 = sin(theta);
    c5 = cos(5*theta);    s5 = sin(5*theta);
    c7 = cos(7*theta);    s7 = sin(7*theta);
    comp = [ alpha*c1 + beta*s1;  -alpha*s1 + beta*c1;      % fundamental, positive frame
             alpha*c5 - beta*s5;   alpha*s5 + beta*c5;      % 5th harmonic, negative frame
             alpha*c7 + beta*s7;  -alpha*s7 + beta*c7];     % 7th harmonic, positive frame
    w = min(max(abs(omega_pu), p.island.omega_pu_min), p.island.omega_pu_max);
    n_win = min(2*pi/(p.omega_nom*p.island.h_avg_order*w)/ts, N_BUF - 1);
    [avg, buf, idx, n_filled] = moving_average_frac(comp, n_win, buf, idx, n_filled);
    u1 = sqrt(avg(1)^2 + avg(2)^2);
    u5 = sqrt(avg(3)^2 + avg(4)^2);
    u7 = sqrt(avg(5)^2 + avg(6)^2);
    h_ratio = sqrt(u5^2 + u7^2)/max(u1, p.island.u_valid);

    % ---- 2. frequency (low pass) and ROCOF (double-integrator observer on the PLL pulsation)
    g0 = ts/(p.island.tau_f + ts);
    f_lpf = f_lpf + g0*(omega_pu - f_lpf);                  % [pu]
    e_obs = omega_pu - obs_x;
    obs_x = obs_x + ts*(obs_v + p.island.obs_kx*e_obs);
    obs_v = obs_v + ts*p.island.obs_kv*e_obs;               % [pu/s]
    rocof = obs_v*p.omega_nom/(2*pi);                       % [Hz/s]

    % ---- 3. criteria with on-delays
    f_valid = u1 >= p.island.u_valid;
    cond = [u1 < p.island.u_min;
            u1 > p.island.u_max;
            f_valid && f_lpf < p.island.f_min;
            f_valid && f_lpf > p.island.f_max;
            f_valid && abs(rocof) > p.island.rocof_max;
            f_valid && h_ratio > p.island.h_max];
    t_trip = [p.island.t_trip_u_min; p.island.t_trip_u_max; p.island.t_trip_f; p.island.t_trip_f;
              p.island.t_trip_rocof; p.island.t_trip_h];
    armed = enable > 0.5 && t_now >= p.island.t_enable - 0.5*ts;
    crit = 0;
    for k = 1:6
        if armed && cond(k)
            timers(k) = timers(k) + ts;
        else
            timers(k) = 0;
        end
        if timers(k) >= t_trip(k) - 0.5*ts
            crit = crit + 2^(k - 1);
        end
    end

    % ---- 4. output, latched or not
    if ~armed
        latched = 0;
        t_det = 0;
    elseif crit > 0 && latched == 0
        latched = 1;
        t_det = t_now;
    end
    if p.island.latch > 0.5
        island = latched;
    else
        island = double(crit > 0);
    end
    if island > 0.5
        t_since = t_now - t_det;
    else
        t_since = 0;
    end

    idet_log = [u1; u5; u7; h_ratio; f_lpf; rocof; max(timers); t_since];
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
