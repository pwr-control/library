function [ug_abc, theta, omega_pu, enable, reset, i_xi_ref, i_react_ref] = afe_uvw_ctrl_test_source(t, tb)
%AFE_UVW_CTRL_TEST_SOURCE  Grid voltage, PLL angle and references of the test bench, closed form of the time.
%
%   [ug_abc, theta, omega_pu, enable, reset, i_xi_ref, i_react_ref] = afe_uvw_ctrl_test_source(t, tb)
%
%   MATLAB Function of test_afe_uvw_ctrl.slx (and of afe_uvw_ctrl_test_loop.m). The grid is an ideal
%   source: positive sequence 1 pu (tb.dip_pos during the dip), negative sequence tb.dip_neg during the
%   dip, 5th and 7th harmonics, frequency tb.f_pu until tb.t_drift and then a ramp of tb.df_pu_dt
%   capped at tb.f_pu_max. theta is the angle of the positive sequence, as an ideal PLL would give it,
%   omega_pu its pulsation in pu. No states: everything is a function of t.
%
%   Outputs  ug_abc [3x1] pu, theta [rad] in [0, 2 pi), omega_pu [pu], enable and reset (0/1) for
%   frt_vde4110 (enable also for islanding_detector), i_xi_ref [pu], i_react_ref [2x1] [pos; neg] pu.
%
%   See also afe_uvw_ctrl_test_param, afe_uvw_ctrl_test_plant.

    % ---- frequency and angle
    if t <= tb.t_drift
        omega_pu = tb.f_pu;
        th = tb.f_pu*t;
    else
        tau = t - tb.t_drift;
        tau_cap = (tb.f_pu_max - tb.f_pu)/tb.df_pu_dt;          % the ramp reaches the cap after this time
        if tau <= tau_cap
            omega_pu = tb.f_pu + tb.df_pu_dt*tau;
            th = tb.f_pu*t + 0.5*tb.df_pu_dt*tau^2;
        else
            omega_pu = tb.f_pu_max;
            th = tb.f_pu*(tb.t_drift + tau_cap) + 0.5*tb.df_pu_dt*tau_cap^2 + tb.f_pu_max*(tau - tau_cap);
        end
    end
    theta = mod(tb.omega_nom*th, 2*pi);

    % ---- voltage: sequences and harmonics in alpha/beta, then abc (amplitude-invariant Clarke)
    if t >= tb.t_dip(1) && t < tb.t_dip(2)
        vp = tb.dip_pos;
        vn = tb.dip_neg;
    else
        vp = 1;
        vn = 0;
    end
    ua = vp*cos(theta) + vn*cos(-theta + tb.dip_neg_phase) ...
         + tb.h7*cos(7*theta + tb.h7_phase) + tb.h5*cos(-5*theta + tb.h5_phase);
    ub = vp*sin(theta) + vn*sin(-theta + tb.dip_neg_phase) ...
         + tb.h7*sin(7*theta + tb.h7_phase) + tb.h5*sin(-5*theta + tb.h5_phase);
    ug_abc = [ua; -0.5*ua + sqrt(3)/2*ub; -0.5*ua - sqrt(3)/2*ub];

    % ---- enables and references
    enable = double(t >= tb.t_enable);
    reset = double(t < tb.t_reset);
    i_xi_ref = tb.i_xi_ref*double(t >= tb.t_ctrl_on);
    i_react_ref = [tb.i_react_pos; tb.i_react_neg]*double(t >= tb.t_react);
end
