function update_grid_forming_dqctrl()
%UPDATE_GRID_FORMING_DQCTRL  Load private/afe_dq_ctrl_pwm.m into the library block
%   grid_forming_dqctrl/grid_forming_dqctrl_mod1 and give the block the master/slave ports.
%
%   update_grid_forming_dqctrl
%
%   private/afe_dq_ctrl_pwm.m is the source of the MATLAB Function afe_dq_forming_ctrl_pwm of the block:
%   edit it there, run this function (library on the path, any folder) and commit the source together
%   with grid_forming_dqctrl.slx, which this function saves. It can be run again: the ports are added
%   and connected only when missing.
%
%   Interface after the update (2026-10-23, master/slave and negative-sequence compensator for the TELEMA VFC
%   test bench):
%     inputs    1 t_master   master time [s]
%               2 sync       [5x1] [theta; i_xi_ref; i_eta_ref; i_xi_n_ref; i_eta_n_ref] of the master, read in
%                            slave mode only
%     outputs   1 m          [14x1] measurements of the power stage (pu)
%               2 ctrl_log   [43x1] control signals (38:43 negative sequence: u_xi_n, u_eta_n, i_xi_n_ref,
%                            i_eta_n_ref, resonant terms r_d, r_q)
%               3 sync_out   [5x1] same layout as sync, values of the last control step, for the slave(s)
%     physical  ug_a, ug_b, ug_c (left), Udc(+), Udc(-) (right), unchanged
%   The slave mode is selected by p.ctrl.slave = 1 in the parameter struct of the mask, the negative-sequence
%   compensator by p.ctrl.nsc_enable = 1 (with nsc_kp_ug, nsc_ki_ug, nsc_i_lim, nsc_kr_i; see the header of
%   private/afe_dq_ctrl_pwm.m). Both fields are optional (default master, compensator off), so the structs of
%   the existing models keep working; models that do not use the new ports get an unconnected-port warning
%   (ground sync and terminate sync_out to silence it). The first version of the ports (earlier on
%   2026-10-23) carried [3x1]: a model that wires sync_out of one block to sync of another needs no change.

    lib  = 'grid_forming_dqctrl';
    blk  = [lib '/grid_forming_dqctrl_mod1'];
    mf   = [blk '/afe_dq_forming_ctrl_pwm'];
    here = fileparts(mfilename('fullpath'));
    src  = fullfile(here, 'private', 'afe_dq_ctrl_pwm.m');
    assert(exist(src, 'file') == 2, 'update_grid_forming_dqctrl: %s not found', src);

    load_system(lib);
    set_param(lib, 'Lock', 'off');

    % ---- control code: the inputs (M, t_master, sync) and the outputs (G, ctrl_log, sync_out) of the
    %      function become the ports of the MATLAB Function block, p stays a parameter of the mask
    cfg = get_param(mf, 'MATLABFunctionConfiguration');
    cfg.FunctionScript = fileread(src);
    chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', mf);
    assert(~isempty(chart), 'update_grid_forming_dqctrl: chart of %s not found', mf);
    pdata = find(chart, '-isa', 'Stateflow.Data', 'Name', 'p');
    assert(~isempty(pdata), 'update_grid_forming_dqctrl: data p not found in %s', mf);
    pdata.Scope = 'Parameter';
    sdata = find(chart, '-isa', 'Stateflow.Data', 'Name', 'sync');
    assert(~isempty(sdata), 'update_grid_forming_dqctrl: input sync not found in %s (old source?)', mf);
    sdata.Props.Array.Size = '[5 1]';           % fixed size: a grounded (unconnected) sync is 5x1 as well
    ph = get_param(mf, 'PortHandles');
    assert(numel(ph.Inport) == 3 && numel(ph.Outport) == 3, ...
        'update_grid_forming_dqctrl: %s has %d inputs and %d outputs, 3 and 3 expected', ...
        mf, numel(ph.Inport), numel(ph.Outport));

    % ---- ports of the masked subsystem (numbers after t_master and after m, ctrl_log)
    if isempty(find_system(blk, 'SearchDepth', 1, 'BlockType', 'Inport', 'Name', 'sync'))
        add_block('built-in/Inport', [blk '/sync'], 'Port', '2', 'Position', [-105 478 -75 492]);
    end
    if isempty(find_system(blk, 'SearchDepth', 1, 'BlockType', 'Outport', 'Name', 'sync_out'))
        add_block('built-in/Outport', [blk '/sync_out'], 'Port', '3', 'Position', [390 478 420 492]);
    end
    connect_once(blk, 'sync/1', 'afe_dq_forming_ctrl_pwm/3');
    connect_once(blk, 'afe_dq_forming_ctrl_pwm/3', 'sync_out/1');

    % ---- mask: port labels and description
    mk = Simulink.Mask.get(blk);
    mk.Display = sprintf([ ...
        'port_label(''LConn'', 1, ''ug_a'');\n' ...
        'port_label(''LConn'', 2, ''ug_b'');\n' ...
        'port_label(''LConn'', 3, ''ug_c'');\n' ...
        'port_label(''RConn'', 1, ''Udc(+)'');\n' ...
        'port_label(''RConn'', 2, ''Udc(-)'');\n' ...
        'port_label(''input'', 1, ''t_master'');\n' ...
        'port_label(''input'', 2, ''sync'');\n' ...
        'port_label(''output'', 1, ''m'');\n' ...
        'port_label(''output'', 2, ''ctrl_log'');\n' ...
        'port_label(''output'', 3, ''sync_out'');']);
    mk.Description = sprintf(['Grid-forming AFE in one block: ideal two-level bridge, DC-link capacitor and LCL filter ' ...
        'as a Simscape language component (afe_ssc.afe_two_level_lcl), control and PWM as one MATLAB Function ' ...
        '(afe_dq_ctrl_pwm, source private/afe_dq_ctrl_pwm.m of the library folder), measurements to the control ' ...
        'through a Unit Delay of one tc (no algebraic loop). Interface of afe_dq_mod1 of grid_forming_dq.slx: ' ...
        'ug_a/b/c left, Udc(+)/Udc(-) right, t_master in, M (14x1 pu) and ctrl_log (43x1) out. ' ...
        'Master/slave: sync in and sync_out out, [theta; i_xi_ref; i_eta_ref; i_xi_n_ref; i_eta_n_ref]; with ' ...
        'p.ctrl.slave = 1 the block runs its current loop with the angle and the current references of the ' ...
        'master (sync_out of the master to sync of the slave), with p.ctrl.slave = 0 or absent it is a master ' ...
        'and ignores sync. Negative-sequence compensator: p.ctrl.nsc_enable = 1 (same value in master and ' ...
        'slaves) regulates the negative sequence of the terminal voltage to zero (PI in the negative frame, ' ...
        'resonant term at 2*fgrid in the current loop); absent or 0, off. ' ...
        'Parameter p: struct of private/afe_module_param.m, e.g. param.afe_mod(1).']);

    save_system(lib);
    fprintf('%s: control code from %s, ports sync (input 2, 5x1) and sync_out (output 3), saved %s\n', ...
        blk, src, get_param(lib, 'FileName'));
end

% ------------------------------------------------------------------------------------------------------
function connect_once(sys, src, dst)
%CONNECT_ONCE  add_line(sys, src, dst) unless the destination input port already has a line.
    [dst_name, rest] = strtok(dst, '/');
    ph = get_param([sys '/' dst_name], 'PortHandles');
    n = str2double(rest(2:end));
    if get_param(ph.Inport(n), 'Line') == -1
        add_line(sys, src, dst, 'autorouting', 'on');
    end
end
