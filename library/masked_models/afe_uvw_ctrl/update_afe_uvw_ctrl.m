function update_afe_uvw_ctrl()
%UPDATE_AFE_UVW_CTRL  Load the sources src/*.m into the five blocks of the library afe_uvw_ctrl.slx.
%
%   update_afe_uvw_ctrl
%
%   The MATLAB code of each block is a file of src/ (grid_voltage_sequences.m, frt_vde4110.m,
%   grid_current_sequences_q_ctrl.m, current_ctrl_uvw.m, islanding_detector.m): edit it there, run this
%   function (folder on the path, any current folder) and commit the source together with
%   afe_uvw_ctrl.slx, which this function saves. The function loads each file into the MATLAB Function
%   block afe_uvw_ctrl/<block>/<block>, keeps the mask parameter p a data of scope Parameter and checks
%   the number of ports. It also loads test/afe_uvw_ctrl_test_source.m and test/afe_uvw_ctrl_test_plant.m
%   into the two MATLAB Function blocks of the test bench test/test_afe_uvw_ctrl.slx (parameter tb).
%
%   The library and the test bench were made without MATLAB by tools/make_afe_uvw_ctrl.py (python3),
%   which embeds the same sources: run it instead of this function after a change of the ports, of the
%   masks or of the test bench wiring (it rewrites both files from scratch).
%
%   See also afe_uvw_ctrl_param_example, afe_uvw_ctrl_test_run.

    here = fileparts(mfilename('fullpath'));
    lib = 'afe_uvw_ctrl';
    blocks = {'grid_voltage_sequences', 'frt_vde4110', 'grid_current_sequences_q_ctrl', ...
              'current_ctrl_uvw', 'islanding_detector'};

    load_system(lib);
    set_param(lib, 'Lock', 'off');
    for b = blocks
        local_load([lib '/' b{1} '/' b{1}], fullfile(here, 'src', [b{1} '.m']), {'p'});
    end
    save_system(lib);
    fprintf('%s saved: %s\n', lib, get_param(lib, 'FileName'));

    mdl = 'test_afe_uvw_ctrl';
    if exist(fullfile(here, 'test', [mdl '.slx']), 'file') == 2
        load_system(mdl);
        local_load([mdl '/test_source'], fullfile(here, 'test', 'afe_uvw_ctrl_test_source.m'), {'tb'});
        local_load([mdl '/rl_plant'], fullfile(here, 'test', 'afe_uvw_ctrl_test_plant.m'), {'tb'});
        save_system(mdl);
        fprintf('%s saved: %s\n', mdl, get_param(mdl, 'FileName'));
    end
end


function local_load(mf, src, params)
%LOCAL_LOAD  Put the code of the file src into the MATLAB Function block mf; params are mask or
%   workspace parameters (scope Parameter), the other arguments of the function are the input ports.
    assert(exist(src, 'file') == 2, 'update_afe_uvw_ctrl: %s not found', src);
    code = fileread(src);
    cfg = get_param(mf, 'MATLABFunctionConfiguration');
    cfg.FunctionScript = code;
    chart = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', mf);
    assert(~isempty(chart), 'update_afe_uvw_ctrl: chart of %s not found', mf);
    for q = params
        d = find(chart, '-isa', 'Stateflow.Data', 'Name', q{1});
        assert(~isempty(d), 'update_afe_uvw_ctrl: data %s not found in %s', q{1}, mf);
        d.Scope = 'Parameter';
    end
    sig = regexp(code, '^function\s*\[?([^\]=]*)\]?\s*=\s*\w+\s*\(([^)]*)\)', 'tokens', 'once', 'lineanchors');
    n_out = numel(regexp(strtrim(sig{1}), '[\w]+', 'match'));
    n_in = numel(regexp(sig{2}, '[\w]+', 'match')) - numel(params);
    ph = get_param(mf, 'PortHandles');
    assert(numel(ph.Inport) == n_in && numel(ph.Outport) == n_out, ...
           'update_afe_uvw_ctrl: %s has %d inputs and %d outputs, the source %d and %d', ...
           mf, numel(ph.Inport), numel(ph.Outport), n_in, n_out);
    fprintf('%-60s <- %s\n', mf, src);
end
