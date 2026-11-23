function [t, lg] = afe_uvw_ctrl_test_loop(p, tb)
%AFE_UVW_CTRL_TEST_LOOP  The test bench as a MATLAB loop: the functions of the blocks, called one step at a time.
%
%   [t, lg] = afe_uvw_ctrl_test_loop(p, tb)
%
%   Same wiring as test_afe_uvw_ctrl.slx: test source -> grid_voltage_sequences -> frt_vde4110 ->
%   grid_current_sequences_q_ctrl (grid current = -stack current) -> current_ctrl_uvw -> RL plant, whose
%   output is the stack current measured at the next step (the Unit Delay of the model); the islanding
%   detector reads ug_ab. t is the time of the n = tb.t_end/tb.ts + 1 steps (as Simulink logs them), lg
%   the N x 50 log, columns in afe_uvw_ctrl_test_log_index. afe_uvw_ctrl_test_run compares lg with the
%   To Workspace log of the model: the library blocks are the functions, so the two must be equal.
%
%   The functions keep their states in persistent variables: they are cleared at the start, so that
%   the loop can run again in the same session.
%
%   See also afe_uvw_ctrl_test_run, afe_uvw_ctrl_test_param, afe_uvw_ctrl_test_log_index.

    clear grid_voltage_sequences frt_vde4110 grid_current_sequences_q_ctrl current_ctrl_uvw ...
          islanding_detector afe_uvw_ctrl_test_plant
    n = round(tb.t_end/tb.ts) + 1;
    t = (0:n - 1)'*tb.ts;
    lg = zeros(n, 50);
    is_meas = zeros(3, 1);                         % output of the Unit Delay (stack current of the last step)
    for k = 1:n
        [ug_abc, theta, omega_pu, en, rs, i_xi_ref, i_react_ref] = afe_uvw_ctrl_test_source(t(k), tb);
        [v_seq_avg, ~, ug_ab] = grid_voltage_sequences(ug_abc, theta, omega_pu, p);
        [i_grid_ref, frt_active, pwr_lim_enable, frt_log] = frt_vde4110(v_seq_avg, i_react_ref, en, rs, p);
        [i_stack_ref, i_seq_avg] = grid_current_sequences_q_ctrl(-is_meas, theta, omega_pu, i_grid_ref, p);
        [u_abg, i_abc_ref, is_xe] = current_ctrl_uvw(i_xi_ref, i_stack_ref, is_meas, theta, p);
        [island, crit, idet_log] = islanding_detector(ug_ab, theta, omega_pu, en, p);
        lg(k, :) = [v_seq_avg' i_grid_ref' frt_active pwr_lim_enable frt_log' i_stack_ref' i_seq_avg' ...
                    u_abg' i_abc_ref' is_xe' is_meas' island crit idet_log' theta omega_pu i_xi_ref];
        is_meas = afe_uvw_ctrl_test_plant(u_abg, ug_abc, tb);
    end
end
