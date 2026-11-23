function is_abc = afe_uvw_ctrl_test_plant(u_abg, ug_abc, tb)
%AFE_UVW_CTRL_TEST_PLANT  Three RL branches between the converter and the grid (pu), one step of tb.ts.
%
%   is_abc = afe_uvw_ctrl_test_plant(u_abg, ug_abc, tb)
%
%   MATLAB Function of test_afe_uvw_ctrl.slx (and of afe_uvw_ctrl_test_loop.m). The converter phase
%   voltages are the inverse Clarke transform of [u_alpha; u_beta] plus u_gamma (the zero sequence,
%   the same on the three phases) plus tb.k_ff times the measured grid voltage (the feed-forward of
%   a modulator). Each branch:
%       di/dt = omega_nom/x_l*(u - u_grid - r*i),   u_grid = ug_abc + tb.u0_dc
%   (the DC offset is in the branch voltage, not in the measurement, so the zero-sequence current
%   controller has to cancel it). The step is integrated exactly (voltages held during the step) and
%   the output is the current at the end of the step: the Unit Delay of the bench gives it to the
%   control at the next step, as a measurement taken at the start of the period.
%
%   State (persistent): i [3x1] branch currents [pu].
%
%   See also afe_uvw_ctrl_test_param, afe_uvw_ctrl_test_source.

    persistent i
    if isempty(i)
        i = zeros(3, 1);
    end
    u_abc = [u_abg(1); -0.5*u_abg(1) + sqrt(3)/2*u_abg(2); -0.5*u_abg(1) - sqrt(3)/2*u_abg(2)] ...
            + u_abg(3) + tb.k_ff*ug_abc;
    u_grid = ug_abc + tb.u0_dc;
    a = tb.r*tb.omega_nom/tb.x_l;                           % [1/s] pole of the branch
    e = exp(-a*tb.ts);
    i = e*i + (1 - e)/tb.r*(u_abc - u_grid);
    is_abc = i;
end
