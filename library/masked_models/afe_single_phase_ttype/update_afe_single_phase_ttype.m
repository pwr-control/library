function update_afe_single_phase_ttype()
%UPDATE_AFE_SINGLE_PHASE_TTYPE  Build or update the library afe_single_phase_ttype.slx: block afe_single_phase_ttype_mod1,
%   one single-phase three-level T-type AFE (power stage, modulator and control) in one block.
%
%   update_afe_single_phase_ttype
%
%   Same structure as cllc_dcx_mod1 and grid_forming_dqctrl_mod1: the power stage is the Simscape language
%   component afe_ttype_ssc.afe_single_phase_ttype (../../foundation/pwr_electronics/+afe_ttype_ssc, compiled into
%   afe_ttype_ssc_lib.slx with "ssc_build afe_ttype_ssc" from that folder), the control and the three-level PWM
%   are the MATLAB Function afe_sp_ttype_ctrl_pwm, whose source is private/afe_sp_ttype_ctrl_pwm.m.
%   Run this function (library on the path, any folder) to create the library from scratch or after editing
%   the source: when afe_single_phase_ttype.slx does not exist it is built next to this file, otherwise the source
%   is loaded into the block and the mask is refreshed; blocks, ports and lines are added only when missing, so
%   the function can be run again. Commit the source together with afe_single_phase_ttype.slx.
%
%   Build order (MATLAB, library on the path):
%       cd library/foundation/pwr_electronics
%       ssc_build afe_ttype_ssc                % -> afe_ttype_ssc_lib.slx
%       cd ../../masked_models/afe_single_phase_ttype
%       update_afe_single_phase_ttype          % -> afe_single_phase_ttype.slx
%
%   Interface of afe_single_phase_ttype/afe_single_phase_ttype_mod1
%     physical  a, b (left, AC terminals after the LC filter), dc+, dc- (right, DC link); the DC link is inside
%               the block (split bank with its neutral point), the model needs an Electrical Reference on the
%               network of the block and a DC source or load on dc+/dc-
%     inputs    1 t_master   master time [s] (Clock of the model or the master time of a global timing block)
%               2 sync       [3x1] sync_out of the master block, read with p.ctrl.slave = 1; on a master a
%                            Constant zeros(3,1)
%     outputs   1 m          [13x1] measurements of the power stage in pu (M of the ssc block, not delayed):
%                            i_s, i_a, u_ac, u_s, udc, udc_p, udc_n, i_dc, i_np, i_c1, i_c2, i_cf, i_s2
%               2 ctrl_log   [32x1] control signals, indices in afe_single_phase_ttype_log_index.m
%               3 sync_out   [3x1] [theta_hat; m_d; m_q] of the last control step, for the sync input of the slave(s)
%     mask      p            parameter struct (p.hw, p.pwm, p.ctrl), e.g. afe_single_phase_ttype_param_example()
%   Inside: power_stage (ssc block, every parameter p.hw.<name>), afe_sp_ttype_ctrl_pwm (MATLAB Function,
%   discrete at p.pwm.tc, data p with scope Parameter), gates (Simulink-PS Converter, V), meas (PS-Simulink
%   Converter, dimensionless), meas_delay (Unit Delay of one p.pwm.tc on the measurements to the control: no
%   algebraic loop, as in the AFE blocks).

    lib    = 'afe_single_phase_ttype';
    sub    = 'afe_single_phase_ttype_mod1';
    blk    = [lib '/' sub];
    mfname = 'afe_sp_ttype_ctrl_pwm';
    mf     = [blk '/' mfname];
    sscpkg = 'afe_ttype_ssc';
    ssclib = [sscpkg '_lib'];
    here   = fileparts(mfilename('fullpath'));
    src    = fullfile(here, 'private', [mfname '.m']);
    assert(exist(src, 'file') == 2, 'update_afe_single_phase_ttype: %s not found', src);
    assert(exist(ssclib, 'file') == 4, ['update_afe_single_phase_ttype: %s.slx not found on the path: build the ' ...
        'Simscape component first (cd library/foundation/pwr_electronics; ssc_build %s)'], ssclib, sscpkg);

    % ---- the ssc block: the only block of the package library
    load_system(ssclib);
    ssc_blocks = find_system(ssclib, 'SearchDepth', 1, 'Type', 'block');
    assert(~isempty(ssc_blocks), 'update_afe_single_phase_ttype: no block found in %s', ssclib);
    ssc_src = ssc_blocks{1};

    % ---- library and masked subsystem
    created = exist(lib, 'file') ~= 4;
    if created
        new_system(lib, 'Library');
    else
        load_system(lib);
        set_param(lib, 'Lock', 'off');
    end
    if isempty(find_system(lib, 'SearchDepth', 1, 'Name', sub))
        add_block('built-in/SubSystem', blk, 'Position', [465 294 675 436]);
    end

    % ---- power stage: every parameter of the component from p.hw
    ps = add_once(blk, 'power_stage', ssc_src, 'Position', [230 150 360 250]);
    hw_names = {'Vth', 'Ron', 'Goff', 'Cdc1', 'Rdc1', 'Cdc2', 'Rdc2', 'Vdc0', ...
                'L1', 'R1', 'L2', 'R2', 'Cf', 'Rcf', 'ubez', 'ibez', 'udc_nom'};
    for k = 1:numel(hw_names)
        set_param(ps, hw_names{k}, ['p.hw.' hw_names{k}]);
    end
    ph_ps = get_param(ps, 'PortHandles');
    assert(numel(ph_ps.LConn) == 3 && numel(ph_ps.RConn) == 3, ...
        'update_afe_single_phase_ttype: %s has %d left and %d right physical ports, 3 and 3 expected (a, b, G / dc+, dc-, M)', ...
        ps, numel(ph_ps.LConn), numel(ph_ps.RConn));

    % ---- control code: the inputs (M, t_master, sync) and the outputs (G, ctrl_log, sync_out) of the function
    %      are the ports of the MATLAB Function block, p is a parameter (mask variable)
    add_once(blk, mfname, 'simulink/User-Defined Functions/MATLAB Function', 'Position', [-20 150 110 250]);
    cfg = get_param(mf, 'MATLABFunctionConfiguration');
    cfg.FunctionScript = fileread(src);
    try
        cfg.UpdateMethod = 'Discrete';          % R2019b and later: sample time of the block
        cfg.SampleTime   = 'p.pwm.tc';
    catch
    end
    chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', mf);
    assert(~isempty(chart), 'update_afe_single_phase_ttype: chart of %s not found', mf);
    chart = chart(1);
    try
        chart.ChartUpdateMethod = 'DISCRETE';   % Stateflow API, same setting
        chart.SampleTime        = 'p.pwm.tc';
    catch
    end
    ensure_data(chart, 'M',        'Input',     1, '[13 1]');
    ensure_data(chart, 't_master', 'Input',     2, '');
    ensure_data(chart, 'sync',     'Input',     3, '[3 1]');
    ensure_data(chart, 'p',        'Parameter', 0, '');
    ensure_data(chart, 'G',        'Output',    1, '[8 1]');
    ensure_data(chart, 'ctrl_log', 'Output',    2, '[32 1]');
    ensure_data(chart, 'sync_out', 'Output',    3, '[3 1]');
    keep = {'M', 't_master', 'sync', 'p', 'G', 'ctrl_log', 'sync_out'};   % data of the default script (u, y) of a new block
    alld = find(chart, '-isa', 'Stateflow.Data');
    for k = 1:numel(alld)
        if ~any(strcmp(alld(k).Name, keep))
            delete(alld(k));
        end
    end
    ph_mf = get_param(mf, 'PortHandles');
    assert(numel(ph_mf.Inport) == 3 && numel(ph_mf.Outport) == 3, ...
        'update_afe_single_phase_ttype: %s has %d inputs and %d outputs, 3 and 3 expected', mf, numel(ph_mf.Inport), numel(ph_mf.Outport));

    % ---- converters, delay, ports
    gates = add_once(blk, 'gates', 'nesl_utility/Simulink-PS Converter', 'Position', [150 190 180 210]);
    set_param(gates, 'Unit', 'V', 'FilteringAndDerivatives', 'provide');
    meas = add_once(blk, 'meas', 'nesl_utility/PS-Simulink Converter', 'Position', [400 190 430 210]);
    set_param(meas, 'Unit', '1');
    dly = add_once(blk, 'meas_delay', 'built-in/UnitDelay', 'Position', [-20 300 10 330], 'Orientation', 'left');
    set_param(dly, 'SampleTime', 'p.pwm.tc', 'InitialCondition', 'zeros(13,1)');
    tin  = add_once(blk, 't_master', 'built-in/Inport',  'Port', '1', 'Position', [-105 218 -75 232]);
    sin_ = add_once(blk, 'sync',     'built-in/Inport',  'Port', '2', 'Position', [-105 238 -75 252]);
    set_param(sin_, 'PortDimensions', '[3 1]');
    mout = add_once(blk, 'm',        'built-in/Outport', 'Port', '1', 'Position', [480 193 510 207]);
    lout = add_once(blk, 'ctrl_log', 'built-in/Outport', 'Port', '2', 'Position', [480 233 510 247]);
    sout = add_once(blk, 'sync_out', 'built-in/Outport', 'Port', '3', 'Position', [480 273 510 287]);
    cpa  = add_once(blk, 'a',   'nesl_utility/Connection Port', 'Side', 'Left',  'Port', '1', 'Position', [150 123 180 137]);
    cpb  = add_once(blk, 'b',   'nesl_utility/Connection Port', 'Side', 'Left',  'Port', '2', 'Position', [150 153 180 167]);
    cpp  = add_once(blk, 'dc+', 'nesl_utility/Connection Port', 'Side', 'Right', 'Port', '3', 'Position', [400 123 430 137]);
    cpn  = add_once(blk, 'dc-', 'nesl_utility/Connection Port', 'Side', 'Right', 'Port', '4', 'Position', [400 153 430 167]);

    % ---- lines (added only when the destination port is free)
    ph_g = get_param(gates, 'PortHandles');
    ph_m = get_param(meas,  'PortHandles');
    ph_d = get_param(dly,   'PortHandles');
    link_once(blk, ph_mf.Outport(1), ph_g.Inport(1));                 % G -> Simulink-PS
    link_once(blk, ph_g.RConn(1),    ph_ps.LConn(3));                 % -> G of the power stage
    link_once(blk, ph_ps.RConn(3),   ph_m.LConn(1));                  % M of the power stage -> PS-Simulink
    link_once(blk, ph_m.Outport(1),  ph_d.Inport(1));                 % -> Unit Delay
    link_once(blk, ph_m.Outport(1),  port1(mout, 'Inport'));          % -> output m
    link_once(blk, ph_d.Outport(1),  ph_mf.Inport(1));                % delayed measurements -> control
    link_once(blk, port1(tin,  'Outport'), ph_mf.Inport(2));          % t_master -> control
    link_once(blk, port1(sin_, 'Outport'), ph_mf.Inport(3));          % sync -> control
    link_once(blk, ph_mf.Outport(2), port1(lout, 'Inport'));          % ctrl_log -> output
    link_once(blk, ph_mf.Outport(3), port1(sout, 'Inport'));          % sync_out -> output
    link_once(blk, conn_port(cpa),   ph_ps.LConn(1));                 % a
    link_once(blk, conn_port(cpb),   ph_ps.LConn(2));                 % b
    link_once(blk, conn_port(cpp),   ph_ps.RConn(1));                 % dc+
    link_once(blk, conn_port(cpn),   ph_ps.RConn(2));                 % dc-

    % ---- mask: parameter p, port labels, description
    mk = Simulink.Mask.get(blk);
    if isempty(mk)
        mk = Simulink.Mask.create(blk);
    end
    try
        pp = mk.getParameter('p');
    catch
        pp = [];
    end
    if isempty(pp)
        mk.addParameter('Type', 'edit', 'Name', 'p', 'Prompt', 'Parameter struct p (p.hw, p.pwm, p.ctrl)', ...
            'Value', 'afe_single_phase_ttype_param_example()');
    end
    mk.Type = 'Single-phase T-type AFE';
    mk.Display = sprintf([ ...
        'port_label(''LConn'', 1, ''a'');\n' ...
        'port_label(''LConn'', 2, ''b'');\n' ...
        'port_label(''RConn'', 1, ''dc+'');\n' ...
        'port_label(''RConn'', 2, ''dc-'');\n' ...
        'port_label(''input'', 1, ''t_master'');\n' ...
        'port_label(''input'', 2, ''sync'');\n' ...
        'port_label(''output'', 1, ''m'');\n' ...
        'port_label(''output'', 2, ''ctrl_log'');\n' ...
        'port_label(''output'', 3, ''sync_out'');']);
    mk.Description = sprintf(['Single-phase three-level T-type AFE in one block: split DC link (two banks with the ' ...
        'neutral point), two T-type legs (Q1-Q4, Q5-Q8), LC output filter as a Simscape language component ' ...
        '(afe_ttype_ssc.afe_single_phase_ttype), acquisitions, single-phase PLL with double integrator observer, ' ...
        'first harmonic tracker, dq vector PI current loop with DC-link feed-forward, optional DC-link voltage loop ' ...
        'and three-level PWM as one MATLAB Function (afe_sp_ttype_ctrl_pwm, source private/afe_sp_ttype_ctrl_pwm.m ' ...
        'of the library folder), measurements to the control through a Unit Delay of one tc (no algebraic loop). ' ...
        'Compact version of single_phase_inverter_modA/B of sst_cllc_ttype_inv.slx of pwr-control/solid-state-transformers. ' ...
        'Ports: a, b left (AC terminals), dc+, dc- right (DC link); t_master and sync in, m (13x1 pu), ctrl_log ' ...
        '(32x1, afe_single_phase_ttype_log_index.m) and sync_out (3x1) out. p.ctrl.mode: 0 current references ' ...
        '(p.ctrl.i_ref from p.ctrl.t_ref with the slew p.ctrl.i_ref_slew, positive = power from the DC link to the ' ...
        'AC side), 1 DC-link voltage loop. p.ctrl.slave = 1: the block applies m_d, m_q of the master wired to ' ...
        'sync (modules in series on one line). Parameter p: struct of afe_single_phase_ttype_param_example.m ' ...
        '(p.hw = parameters of the ssc block; p.pwm; p.ctrl).']);

    if created
        save_system(lib, fullfile(here, [lib '.slx']));
    else
        save_system(lib);
    end
    fprintf('%s: control code from %s, saved %s\n', blk, src, get_param(lib, 'FileName'));
end

% ------------------------------------------------------------------------------------------------------
function h = add_once(sys, name, source, varargin)
%ADD_ONCE  Handle of the block sys/name, added from source with the given parameters when missing.
    path = [sys '/' name];
    if isempty(find_system(sys, 'LookUnderMasks', 'all', 'SearchDepth', 1, 'Name', name))
        h = add_block(source, path, varargin{:});
    else
        h = get_param(path, 'Handle');
    end
end

% ------------------------------------------------------------------------------------------------------
function ensure_data(chart, name, scope, port, sz)
%ENSURE_DATA  Data object "name" of the MATLAB Function chart with the given scope, port number and size.
    d = find(chart, '-isa', 'Stateflow.Data', 'Name', name);
    if isempty(d)
        d = Stateflow.Data(chart);
        d.Name = name;
    else
        d = d(1);
    end
    d.Scope = scope;
    if port > 0
        d.Port = port;
    end
    if ~isempty(sz)
        d.Props.Array.Size = sz;
    end
end

% ------------------------------------------------------------------------------------------------------
function h = port1(blk_h, kind)
%PORT1  First port of the given kind ('Inport' or 'Outport') of a block handle.
    ph = get_param(blk_h, 'PortHandles');
    h = ph.(kind)(1);
end

% ------------------------------------------------------------------------------------------------------
function h = conn_port(blk_h)
%CONN_PORT  The single physical port of a Connection Port block (on its right side when Side = Left and
%   the other way round).
    ph = get_param(blk_h, 'PortHandles');
    hs = [ph.LConn(:); ph.RConn(:)];
    assert(numel(hs) == 1, 'update_afe_single_phase_ttype: Connection Port block with %d physical ports', numel(hs));
    h = hs(1);
end

% ------------------------------------------------------------------------------------------------------
function link_once(sys, src_h, dst_h)
%LINK_ONCE  add_line(sys, src_h, dst_h) unless the destination port already has a line (signal or physical).
    if get_param(dst_h, 'Line') == -1
        add_line(sys, src_h, dst_h, 'autorouting', 'on');
    end
end
