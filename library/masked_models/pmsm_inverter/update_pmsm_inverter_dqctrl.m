function update_pmsm_inverter_dqctrl()
%UPDATE_PMSM_INVERTER_DQCTRL  Load private/pmsm_dq_ctrl_pwm.m into the library block
%   pmsm_inverter_dqctrl/pmsm_inverter_dqctrl_mod1.
%
%   update_pmsm_inverter_dqctrl
%
%   private/pmsm_dq_ctrl_pwm.m is the source of the MATLAB Function pmsm_dq_ctrl_pwm of the block: edit it
%   there, run this function (library on the path, any folder) and commit the source together with
%   pmsm_inverter_dqctrl.slx, which this function saves. The function also checks the interface of the
%   MATLAB Function (inputs M, t_master, ref, enc, outputs G, ctrl_log, parameter p of the mask), keeps the
%   fixed size of ref ([2 1]) and the sample time p.pwm.tc of the three Unit Delays (meas_delay, ref_delay,
%   enc_delay; the MATLAB Function itself runs at p.pwm.tc, set in the block). The mask, the ports and the
%   layout are not touched.
%
%   The library was made without MATLAB by tools/make_pmsm_inverter_dqctrl.py (python3) from
%   ../grid_forming/grid_forming_dqctrl.slx: the power stage (Simscape component afe_ssc.afe_two_level_lcl),
%   the gates, the measurements and the clock are those of grid_forming_dqctrl, only the control is new.
%   The Python script makes the whole library again and overwrites what was changed here in MATLAB: use it
%   only for a change of the ports or of the power stage of grid_forming_dqctrl.
%
%   Interface
%     inputs    1 t_master   master time [s]
%               2 ref        [2x1] [enable; reference], see private/pmsm_dq_ctrl_pwm.m
%               3 enc        electrical rotor angle [rad] (ground it without encoder)
%     outputs   1 m          [17x1] measurements of the power stage (pu of p.hw.ubez, p.hw.ibez, udc_nom)
%               2 ctrl_log   [44x1] control signals, indices in pmsm_inverter_log_index.m
%     physical  Udc(+), Udc(-) (left), u, v, w (right, to the machine)
%
%   See also pmsm_inverter_param_example, pmsm_inverter_log_index, update_grid_forming_dqctrl.

    lib  = 'pmsm_inverter_dqctrl';
    blk  = [lib '/pmsm_inverter_dqctrl_mod1'];
    mf   = [blk '/pmsm_dq_ctrl_pwm'];
    here = fileparts(mfilename('fullpath'));
    src  = fullfile(here, 'private', 'pmsm_dq_ctrl_pwm.m');
    assert(exist(src, 'file') == 2, 'update_pmsm_inverter_dqctrl: %s not found', src);

    load_system(lib);
    set_param(lib, 'Lock', 'off');

    % ---- control code: the inputs (M, t_master, ref, enc) and the outputs (G, ctrl_log) of the function are
    %      the ports of the MATLAB Function block, p stays a parameter of the mask
    cfg = get_param(mf, 'MATLABFunctionConfiguration');
    cfg.FunctionScript = fileread(src);
    chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', mf);
    assert(~isempty(chart), 'update_pmsm_inverter_dqctrl: chart of %s not found', mf);
    pdata = find(chart, '-isa', 'Stateflow.Data', 'Name', 'p');
    assert(~isempty(pdata), 'update_pmsm_inverter_dqctrl: data p not found in %s', mf);
    pdata.Scope = 'Parameter';
    rdata = find(chart, '-isa', 'Stateflow.Data', 'Name', 'ref');
    assert(~isempty(rdata), 'update_pmsm_inverter_dqctrl: input ref not found in %s (old source?)', mf);
    rdata.Props.Array.Size = '[2 1]';           % fixed size: a grounded (unconnected) ref is 2x1 as well
    ph = get_param(mf, 'PortHandles');
    assert(numel(ph.Inport) == 4 && numel(ph.Outport) == 2, ...
        'update_pmsm_inverter_dqctrl: %s has %d inputs and %d outputs, 4 and 2 expected', ...
        mf, numel(ph.Inport), numel(ph.Outport));

    % ---- delays of the measurements, of ref and of enc: one step tc of the mask parameter
    for d = {'meas_delay', 'ref_delay', 'enc_delay'}
        set_param([blk '/' d{1}], 'SampleTime', 'p.pwm.tc');
    end

    save_system(lib);
    fprintf('%s: control code from %s, saved %s\n', blk, src, get_param(lib, 'FileName'));
end
