function update_interleaved_boost_3legs()
%UPDATE_INTERLEAVED_BOOST_3LEGS  Build or update the library interleaved_boost_3legs.slx: block interleaved_boost_3legs_mod1,
%   one three-leg interleaved boost converter (power stage, modulator and control) in one block.
%
%   update_interleaved_boost_3legs
%
%   Same structure as interleaved_buck_3legs_mod1 (and afe_single_phase_ttype_mod1, cllc_dcx_mod1): the power stage is
%   the Simscape language component boost_ssc.interleaved_boost_3legs (../../foundation/pwr_electronics/+boost_ssc,
%   compiled into boost_ssc_lib.slx with "ssc_build boost_ssc" from that folder), the control and the interleaved PWM
%   are the MATLAB Function interleaved_boost_3legs_ctrl_pwm, whose source is private/interleaved_boost_3legs_ctrl_pwm.m.
%   Run this function (library on the path, any folder) to create the library from scratch or after editing the
%   source: when interleaved_boost_3legs.slx does not exist it is built next to this file, otherwise the source is
%   loaded into the block and the mask is refreshed; blocks, ports and lines are added only when missing, so the
%   function can be run again. Commit the source together with interleaved_boost_3legs.slx.
%
%   Build order (MATLAB, library on the path):
%       cd library/foundation/pwr_electronics
%       ssc_build boost_ssc                    % -> boost_ssc_lib.slx
%       cd ../../masked_models/interleaved_boost_3legs
%       update_interleaved_boost_3legs         % -> interleaved_boost_3legs.slx
%
%   Interface of interleaved_boost_3legs/interleaved_boost_3legs_mod1
%     physical  in+, in- (left, low-voltage input: the battery; the input capacitor is inside the block), dc+, dc-
%               (right, DC link: the regulated output, the DC-link capacitor is inside the block; in- is the negative
%               rail dc-); the model needs an Electrical Reference on the network of the block, a DC source (battery)
%               on in+/in- and a load on dc+/dc-
%     inputs    1 t_master   master time [s] (Clock of the model or the master time of a global timing block)
%     outputs   1 m          [10x1] measurements of the power stage in pu (M of the ssc block, not delayed):
%                            i_L1, i_L2, i_L3, i_sum, i_in, u_in, udc, i_dc, i_cin, i_cdc
%               2 ctrl_log   [30x1] control signals, indices in interleaved_boost_3legs_log_index.m
%     mask      p            parameter struct (p.hw, p.pwm, p.ctrl), e.g. interleaved_boost_3legs_param_example()
%   Inside: power_stage (ssc block, every parameter p.hw.<name>), interleaved_boost_3legs_ctrl_pwm (MATLAB Function,
%   discrete at p.pwm.tc, data p with scope Parameter), gates (Simulink-PS Converter, V), meas (PS-Simulink
%   Converter, dimensionless), meas_delay (Unit Delay of one p.pwm.tc on the measurements to the control: no
%   algebraic loop, as in the AFE blocks).

    lib    = 'interleaved_boost_3legs';
    sub    = 'interleaved_boost_3legs_mod1';
    blk    = [lib '/' sub];
    mfname = 'interleaved_boost_3legs_ctrl_pwm';
    mf     = [blk '/' mfname];
    sscpkg = 'boost_ssc';
    ssclib = [sscpkg '_lib'];
    here   = fileparts(mfilename('fullpath'));
    src    = fullfile(here, 'private', [mfname '.m']);
    assert(exist(src, 'file') == 2, 'update_interleaved_boost_3legs: %s not found', src);
    assert(exist(ssclib, 'file') == 4, ['update_interleaved_boost_3legs: %s.slx not found on the path: build the ' ...
        'Simscape component first (cd library/foundation/pwr_electronics; ssc_build %s)'], ssclib, sscpkg);

    % ---- the ssc block: the only block of the package library
    load_system(ssclib);
    ssc_blocks = find_system(ssclib, 'SearchDepth', 1, 'Type', 'block');
    assert(~isempty(ssc_blocks), 'update_interleaved_boost_3legs: no block found in %s', ssclib);
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
    hw_names = {'Vth', 'Ron', 'Goff', 'Cin', 'RCin', 'Vin0', 'L', 'RL', 'kL', 'kRL', 'Cdc', 'Rdc', 'Vdc0', ...
                'uin_nom', 'ibez', 'udc_nom'};
    for k = 1:numel(hw_names)
        set_param(ps, hw_names{k}, ['p.hw.' hw_names{k}]);
    end
    ph_ps = get_param(ps, 'PortHandles');
    assert(numel(ph_ps.LConn) == 3 && numel(ph_ps.RConn) == 3, ...
        'update_interleaved_boost_3legs: %s has %d left and %d right physical ports, 3 and 3 expected (in+, in-, G / dc+, dc-, M)', ...
        ps, numel(ph_ps.LConn), numel(ph_ps.RConn));

    % ---- control code: the inputs (M, t_master) and the outputs (G, ctrl_log) of the function are the ports of
    %      the MATLAB Function block, p is a parameter (mask variable)
    add_once(blk, mfname, 'simulink/User-Defined Functions/MATLAB Function', 'Position', [-20 150 110 250]);
    cfg = get_param(mf, 'MATLABFunctionConfiguration');
    cfg.FunctionScript = fileread(src);
    try
        cfg.UpdateMethod = 'Discrete';          % R2019b and later: sample time of the block
        cfg.SampleTime   = 'p.pwm.tc';
    catch
    end
    chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', mf);
    assert(~isempty(chart), 'update_interleaved_boost_3legs: chart of %s not found', mf);
    chart = chart(1);
    try
        chart.ChartUpdateMethod = 'DISCRETE';   % Stateflow API, same setting
        chart.SampleTime        = 'p.pwm.tc';
    catch
    end
    ensure_data(chart, 'M',        'Input',     1, '[10 1]');
    ensure_data(chart, 't_master', 'Input',     2, '');
    ensure_data(chart, 'p',        'Parameter', 0, '');
    ensure_data(chart, 'G',        'Output',    1, '[6 1]');
    ensure_data(chart, 'ctrl_log', 'Output',    2, '[30 1]');
    keep = {'M', 't_master', 'p', 'G', 'ctrl_log'};     % data of the default script (u, y) of a new block
    alld = find(chart, '-isa', 'Stateflow.Data');
    for k = 1:numel(alld)
        if ~any(strcmp(alld(k).Name, keep))
            delete(alld(k));
        end
    end
    ph_mf = get_param(mf, 'PortHandles');
    assert(numel(ph_mf.Inport) == 2 && numel(ph_mf.Outport) == 2, ...
        'update_interleaved_boost_3legs: %s has %d inputs and %d outputs, 2 and 2 expected', mf, numel(ph_mf.Inport), numel(ph_mf.Outport));

    % ---- converters, delay, ports
    gates = add_once(blk, 'gates', 'nesl_utility/Simulink-PS Converter', 'Position', [150 190 180 210]);
    set_param(gates, 'Unit', 'V', 'FilteringAndDerivatives', 'provide');
    meas = add_once(blk, 'meas', 'nesl_utility/PS-Simulink Converter', 'Position', [400 190 430 210]);
    set_param(meas, 'Unit', '1');
    dly = add_once(blk, 'meas_delay', 'built-in/UnitDelay', 'Position', [-20 300 10 330], 'Orientation', 'left');
    set_param(dly, 'SampleTime', 'p.pwm.tc', 'InitialCondition', 'zeros(10,1)');
    tin  = add_once(blk, 't_master', 'built-in/Inport',  'Port', '1', 'Position', [-105 218 -75 232]);
    mout = add_once(blk, 'm',        'built-in/Outport', 'Port', '1', 'Position', [480 193 510 207]);
    lout = add_once(blk, 'ctrl_log', 'built-in/Outport', 'Port', '2', 'Position', [480 233 510 247]);
    cpip = add_once(blk, 'in+', 'nesl_utility/Connection Port', 'Side', 'Left',  'Port', '1', 'Position', [150 123 180 137]);
    cpin = add_once(blk, 'in-', 'nesl_utility/Connection Port', 'Side', 'Left',  'Port', '2', 'Position', [150 153 180 167]);
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
    link_once(blk, ph_mf.Outport(2), port1(lout, 'Inport'));          % ctrl_log -> output
    link_once(blk, conn_port(cpip),  ph_ps.LConn(1));                 % in+
    link_once(blk, conn_port(cpin),  ph_ps.LConn(2));                 % in-
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
            'Value', 'interleaved_boost_3legs_param_example()');
    end
    mk.Type = 'Three-leg interleaved boost';
    mk.Display = sprintf([ ...
        'port_label(''LConn'', 1, ''in+'');\n' ...
        'port_label(''LConn'', 2, ''in-'');\n' ...
        'port_label(''RConn'', 1, ''dc+'');\n' ...
        'port_label(''RConn'', 2, ''dc-'');\n' ...
        'port_label(''input'', 1, ''t_master'');\n' ...
        'port_label(''output'', 1, ''m'');\n' ...
        'port_label(''output'', 2, ''ctrl_log'');']);
    mk.Description = sprintf(['Three-leg interleaved boost converter in one block: input capacitor across the battery, ' ...
        'three boost legs (two switch + antiparallel diode pairs each) with one inductor per leg from the input to the ' ...
        'leg midpoint and the DC-link capacitor as a Simscape language component (boost_ssc.interleaved_boost_3legs), ' ...
        'acquisitions, DC-link voltage loop, one PI per leg on the leg current sampled at the extremes of its own ' ...
        'carrier (reference i_ref/3: inherent current sharing) giving the duty of the lower switch, and interleaved ' ...
        'PWM in the buck convention on m = 1 - d (three triangle carriers shifted by 2*pi/3, control at the extremes ' ...
        'of carrier 1, shadow load of the duties of legs 2 and 3 at their own extremes) as one MATLAB Function ' ...
        '(interleaved_boost_3legs_ctrl_pwm, source private/interleaved_boost_3legs_ctrl_pwm.m of the library folder), ' ...
        'measurements to the control through a Unit Delay of one tc (no algebraic loop). Same hardware as ' ...
        'interleaved_buck_3legs_mod1 with the power flow reversed; compact version of interleaved_boost.slx of ' ...
        'pwr-control/modelization-and-control (foundations_of_power_electronics/interleaved_boost_converter). Ports: ' ...
        'in+, in- left (battery), dc+, dc- right (DC link, in- = dc-); t_master in, m (10x1 pu) and ctrl_log (30x1, ' ...
        'interleaved_boost_3legs_log_index.m) out. p.ctrl.mode: 0 DC-link voltage loop (p.ctrl.udc_ref ramped with ' ...
        'p.ctrl.u_ref_slew from p.ctrl.udc_ref_init, the precharged link), 1 total input current reference ' ...
        '(p.ctrl.i_ref from p.ctrl.t_ref with the slew p.ctrl.i_ref_slew; negative = buck direction). Parameter p: ' ...
        'struct of interleaved_boost_3legs_param_example.m (p.hw = parameters of the ssc block; p.pwm; p.ctrl), or ' ...
        'param.boost of the init of the model.']);

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
    assert(numel(hs) == 1, 'update_interleaved_boost_3legs: Connection Port block with %d physical ports', numel(hs));
    h = hs(1);
end

% ------------------------------------------------------------------------------------------------------
function link_once(sys, src_h, dst_h)
%LINK_ONCE  add_line(sys, src_h, dst_h) unless the destination port already has a line (signal or physical).
    if get_param(dst_h, 'Line') == -1
        add_line(sys, src_h, dst_h, 'autorouting', 'on');
    end
end
