function k = afe_uvw_ctrl_test_log_index()
%AFE_UVW_CTRL_TEST_LOG_INDEX  Columns of the log of the test bench (50 signals).
%
%   k = afe_uvw_ctrl_test_log_index
%
%   The same order in the Mux "log" of test_afe_uvw_ctrl.slx (To Workspace tb_log, N x 50) and in the
%   matrix returned by afe_uvw_ctrl_test_loop. Vector signals keep the order of the block outputs:
%   v_seq_avg and i_seq_avg [pos_xi pos_eta neg_xi neg_eta], i_grid_ref and i_stack_ref
%   [pos_eta neg_xi neg_eta], u_abg [alpha beta gamma], is_xe [xi eta], frt_log and idet_log as in the
%   help of frt_vde4110 and islanding_detector.
%
%   See also afe_uvw_ctrl_test_run, afe_uvw_ctrl_test_loop.

    k.v_seq_avg      = 1:4;
    k.i_grid_ref     = 5:7;
    k.frt_active     = 8;
    k.pwr_lim_enable = 9;
    k.frt_log        = 10:19;
    k.i_stack_ref    = 20:22;
    k.i_seq_avg      = 23:26;
    k.u_abg          = 27:29;
    k.i_abc_ref      = 30:32;
    k.is_xe          = 33:34;
    k.is_abc         = 35:37;
    k.island         = 38;
    k.crit           = 39;
    k.idet_log       = 40:47;
    k.theta          = 48;
    k.omega_pu       = 49;
    k.i_xi_ref       = 50;
    k.n              = 50;
end
