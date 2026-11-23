function results = test_power_supply_emulators_mfcn(varargin)
%TEST_POWER_SUPPLY_EMULATORS_MFCN  Compare the two grid emulators of power_supply_emulators
%with their MATLAB Function copies (*_mfcn.slx) and count the non-virtual blocks.
%
%   results = test_power_supply_emulators_mfcn
%   results = test_power_supply_emulators_mfcn('MaxStep', 1e-6, 'Plot', true)
%
%   For each scenario a temporary model holds the original block and its copy with the same
%   numeric mask values. The two output buses are logged at the same time steps and
%   compared element by element: phase and sequence voltages in pu of the peak phase
%   voltage Vnom*sqrt(2/3), the angle in rad, the angular frequency in pu of 2*pi*50 rad/s.
%   The element names of the two buses must be the same, in the same order.
%
%   Tolerance: 1e-4 pu. With voltage ramps (FRT active and t_ramp > 0) the Rate Limiter
%   blocks of the original run one solver step ahead of the exact ramp of the copy, so the
%   tolerance is max(1e-3, 3*slew*MaxStep) pu, slew = Vemu_ref_norm/t_ramp [pu/s].
%
%   Options (name/value pairs):
%     'MaxStep'  [s]  maximum step size (default 1e-5)
%     'StopTime' [s]  simulated time (default 0.2)
%     'Solver'        variable-step solver (default 'ode45')
%     'RelTol'        relative tolerance (default 1e-6)
%     'Plot'          true to plot the phase voltages and the differences (default false)
%
%   results: struct array (scenario, max_error, worst_element, tol, pass, errors).
%   Without output arguments the function stops with an error if a scenario fails.

opt = struct('MaxStep', 1e-5, 'StopTime', 0.2, 'Solver', 'ode45', 'RelTol', 1e-6, ...
    'Plot', false);
for k = 1:2:numel(varargin)
    if ~isfield(opt, varargin{k})
        error('test_power_supply_emulators_mfcn: unknown option ''%s''.', varargin{k});
    end
    opt.(varargin{k}) = varargin{k + 1};
end

here = fileparts(mfilename('fullpath'));
libdir = fileparts(here);
addpath(libdir);
pairs = { ...
    'three_phase_voltage_emulator', 'three_phase_voltage_emulator_mfcn', ...
    'three_phase_voltage_source_emulator'; ...
    'three_phase_voltage_with_frt_emulator', 'three_phase_voltage_with_frt_emulator_mfcn', ...
    'three_phase_voltage_source_with_frt_emulator'};
for k = 1:size(pairs, 1)
    for j = 1:2
        load_system(fullfile(libdir, [pairs{k, j} '.slx']));
    end
end

% --- non-virtual blocks, counted as non_virtual_blocks_counting.m does for a model
fprintf('\nNon-virtual blocks (find_system LookUnderMasks all, FollowLinks on, Virtual off):\n');
for k = 1:size(pairs, 1)
    for j = 1:2
        nnv = numel(find_system(pairs{k, j}, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
            'Virtual', 'off'));
        fprintf('  %-46s %4d\n', pairs{k, j}, nnv);
    end
end

% --- scenarios
tau = 1/(2*pi*50);                          % filters.afe.SOF_50Hz.ss_c of the models
sof.A = [-2/tau, -1/tau^2; 1, 0];
sof.B = [1; 0];
sof.C = [0, 1/tau^2];
wf = 2*pi*100;                              % first-order filter at 100 Hz
fof.A = -wf;
fof.B = 1;
fof.C = wf;
w2 = 2*pi*80;                               % second-order filter at 80 Hz, zeta 0.7, in a
A2 = [-2*0.7*w2, -w2^2; 1, 0];              % non-companion realization
B2 = [1; 0];
C2 = [0, w2^2];
T = [1, 0.3; -0.2/w2, 0.8/w2];
nc.A = T\A2*T;
nc.B = T\B2;
nc.C = C2*T;

base = struct('freq', 50, 'ugrid_nom', 690, 'vp_xi_pu', 1, 'vp_eta_pu', 0, ...
    'vn_xi_pu', 0, 'vn_eta_pu', 0, 'fcut_lvrt', 50);
frt0 = struct('nominal_frequency_m', 50, 'nominal_voltage_m', 690, 'Vemu_ref_norm_m', 1, ...
    'vp_xi_pu_m', 1, 'vp_eta_pu_m', 0.05, 'vn_xi_pu_m', 0.04, 'vn_eta_pu_m', -0.03, ...
    'Am', sof.A, 'Bm', sof.B, 'Cm', sof.C, 'enable_frt_1_m', 0, 'enable_frt_2_m', 0, ...
    'start_time_LVRT_m', 0.05, 'end_time_LVRT_m', 0.12, 'deepPOSxi_m', 0.6, ...
    'deepPOSeta_m', -0.4, 'deepNEGxi_m', 0.4, 'deepNEGeta_m', 0.4, 'Amplitude_U_m', 0.25, ...
    'Amplitude_V_m', 0.6, 'Amplitude_W_m', 0.6, 't_ramp_m', 0.02, 'Phase_shift_m', -0.3);

scen = { ...
    'base: default mask values', 1, base; ...
    'base: 60 Hz, unbalanced, 20 Hz LVRT filter', 1, with(base, 'freq', 60, ...
        'ugrid_nom', 400, 'vp_xi_pu', 0.9, 'vp_eta_pu', 0.1, 'vn_xi_pu', 0.05, ...
        'vn_eta_pu', -0.04, 'fcut_lvrt', 20); ...
    'FRT: no FRT (enable_frt_1 = enable_frt_2 = 0)', 2, frt0; ...
    'FRT 2: dips on the sequence references', 2, with(frt0, 'enable_frt_2_m', 1); ...
    'FRT 1: dips on the phase amplitudes + phase shift', 2, with(frt0, 'enable_frt_1_m', 1); ...
    'FRT 1: t_ramp = 0, first-order filter', 2, with(frt0, 'enable_frt_1_m', 1, ...
        't_ramp_m', 0, 'Am', fof.A, 'Bm', fof.B, 'Cm', fof.C); ...
    'FRT 2: non-companion second-order filter, 60 Hz', 2, with(frt0, 'enable_frt_2_m', 1, ...
        'nominal_frequency_m', 60, 'Am', nc.A, 'Bm', nc.B, 'Cm', nc.C, 't_ramp_m', 0.01, ...
        'start_time_LVRT_m', 0.04)};

results = struct('scenario', {}, 'max_error', {}, 'worst_element', {}, 'tol', {}, ...
    'pass', {}, 'errors', {});
fprintf('\nOriginal vs copy, %s, MaxStep %g s, RelTol %g, StopTime %g s:\n', opt.Solver, ...
    opt.MaxStep, opt.RelTol, opt.StopTime);
for s = 1:size(scen, 1)
    r = run_case(pairs(scen{s, 2}, :), scen{s, 1}, scen{s, 3}, opt);
    results(end + 1) = r; %#ok<AGROW>
    fprintf('  %s  %-52s max %.2e (%s), tolerance %.1e\n', pass_str(r.pass), r.scenario, ...
        r.max_error, r.worst_element, r.tol);
end
nfail = sum(~[results.pass]);
if nfail == 0
    fprintf('All %d scenarios passed.\n', numel(results));
else
    fprintf('%d of %d scenarios failed.\n', nfail, numel(results));
end
if nargout == 0
    if nfail > 0
        error('test_power_supply_emulators_mfcn: %d scenario(s) failed.', nfail);
    end
    clear results
end
end


function r = run_case(pair, scenario, prm, opt)
mdl = 'tmp_test_power_supply_emulators_mfcn';
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
new_system(mdl);
cleanup = onCleanup(@() close_system(mdl, 0));
set_param(mdl, 'SolverType', 'Variable-step', 'Solver', opt.Solver, ...
    'StopTime', num2str(opt.StopTime), 'MaxStep', num2str(opt.MaxStep), ...
    'RelTol', num2str(opt.RelTol), 'SignalLogging', 'on', 'SignalLoggingName', 'logsout', ...
    'ReturnWorkspaceOutputs', 'on', 'SaveOutput', 'off', 'SaveState', 'off', ...
    'SaveTime', 'off', 'SaveFormat', 'Dataset');
tags = {'original', 'copy'};
f = fieldnames(prm);
for j = 1:2
    blk = [mdl '/' tags{j}];
    y0 = 100 + 200*(j - 1);
    add_block([pair{j} '/' pair{3}], blk, 'Position', [100, y0, 270, y0 + 116]);
    for i = 1:numel(f)
        set_param(blk, f{i}, mat2str(prm.(f{i}), 17));
    end
    add_block('simulink/Sinks/Terminator', [mdl '/term_' tags{j}], ...
        'Position', [400, y0 + 48, 420, y0 + 68]);
    add_line(mdl, [tags{j} '/1'], ['term_' tags{j} '/1']);
    ph = get_param(blk, 'PortHandles');
    set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', ...
        'DataLoggingName', tags{j});
end
out = sim(mdl);
yo = out.logsout.get('original').Values;
yc = out.logsout.get('copy').Values;
names = fieldnames(yo);
if ~isequal(names, fieldnames(yc))
    error('test_power_supply_emulators_mfcn: the two buses have different elements.');
end

if isfield(prm, 'ugrid_nom')
    kv = prm.ugrid_nom*sqrt(2/3);
else
    kv = prm.nominal_voltage_m*sqrt(2/3);
end
tol = 1e-4;
if isfield(prm, 't_ramp_m') && prm.t_ramp_m > 0 && (prm.enable_frt_1_m || prm.enable_frt_2_m)
    tol = max(1e-3, 3*prm.Vemu_ref_norm_m/prm.t_ramp_m*opt.MaxStep);
end

r = struct('scenario', scenario, 'max_error', 0, 'worst_element', '', 'tol', tol, ...
    'pass', false, 'errors', struct());
for i = 1:numel(names)
    to = yo.(names{i}).Time;
    a = squeeze(yo.(names{i}).Data);
    b = squeeze(yc.(names{i}).Data);
    tc = yc.(names{i}).Time;
    if ~isequal(to, tc)
        b = interp1(tc, b, to);
    end
    d = b - a;
    if startsWith(names{i}, 'gamma')
        e = max(abs(mod(d + pi, 2*pi) - pi));            % rad
    elseif startsWith(names{i}, 'omega')
        e = max(abs(d))/(2*pi*50);
    else
        e = max(abs(d))/kv;                               % pu
    end
    r.errors.(names{i}) = e;
    if e >= r.max_error
        r.max_error = e;
        r.worst_element = names{i};
    end
end
r.pass = r.max_error <= tol;

if opt.Plot
    figure('Name', scenario, 'NumberTitle', 'off');
    ph = {'ua_grid_emu', 'ub_grid_emu', 'uc_grid_emu'};
    subplot(2, 1, 1);
    hold on;
    for i = 1:3
        plot(yo.(ph{i}).Time, squeeze(yo.(ph{i}).Data)/kv, 'LineWidth', 2);
    end
    set(gca, 'ColorOrderIndex', 1);
    for i = 1:3
        plot(yc.(ph{i}).Time, squeeze(yc.(ph{i}).Data)/kv, '--k');
    end
    grid on;
    ylabel('phase voltages [pu]');
    title(scenario, 'Interpreter', 'none');
    legend([strcat(ph, ' original'), {'copy'}], 'Interpreter', 'none');
    subplot(2, 1, 2);
    hold on;
    for i = 1:3
        b = squeeze(yc.(ph{i}).Data);
        if ~isequal(yo.(ph{i}).Time, yc.(ph{i}).Time)
            b = interp1(yc.(ph{i}).Time, b, yo.(ph{i}).Time);
        end
        plot(yo.(ph{i}).Time, (b - squeeze(yo.(ph{i}).Data))/kv);
    end
    grid on;
    xlabel('t [s]');
    ylabel('copy - original [pu]');
    legend(ph, 'Interpreter', 'none');
end
clear cleanup
end


function s = with(s, varargin)
% copy of the struct s with some fields changed
for k = 1:2:numel(varargin)
    s.(varargin{k}) = varargin{k + 1};
end
end


function str = pass_str(ok)
if ok
    str = 'PASS';
else
    str = 'FAIL';
end
end
