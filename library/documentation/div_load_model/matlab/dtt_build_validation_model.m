function mdl = dtt_build_validation_model(run_it)
%DTT_BUILD_VALIDATION_MODEL  Build (and run) the Simscape validation circuit programmatically.
%   mdl = dtt_build_validation_model()       builds dtt_div_validation and runs it
%   mdl = dtt_build_validation_model(false)  builds only
%   Circuit (spec PSS-SPT-59401 Sec. 8.2, ideal crowbar):
%     EMF Table (Fig. 6 DIV3 x 1.84) -> DIV Coil (1.7 mH, 24.9 mOhm, no eddy loops)
%     -> L_cable 160 uH -> L_p 1.6 mH -> Current Sensor -> back to the coil (short circuit).
%   Expected result: spec Fig. 7 induced current (peak 10.9 kA @ 140 ms, 4.8 kA @ 300 ms).
%   NOTE: written without access to MATLAB; block/port names of the Foundation library
%   and the port order of the generated custom blocks may need small adjustments.
%   If a connection fails, the blocks are left in place for manual wiring.
if nargin < 1, run_it = true; end
par = dtt_div_params(); C = dtt_load_curves();
assignin('base','par',par); assignin('base','C',C);

% ---- build the custom library from ssc/+dtt (once)
sscdir = fullfile(fileparts(mfilename('fullpath')),'..','ssc');
addpath(sscdir);
here = pwd; cd(sscdir);            % ssc_build is incremental: run it every time
try
    ssc_build dtt
catch ME
    cd(here); rethrow(ME);
end
cd(here);

mdl = 'dtt_div_validation';
if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl); open_system(mdl);
set_param(mdl, 'StopTime', '0.3', 'Solver', 'ode23t', 'MaxStep', '5e-5', 'RelTol', '1e-5');

% ---- blocks
add_block('dtt_lib/EMF Table', [mdl '/EMF'], 'Position', [40 130 110 170], ...
    't_tab', 'C.t', 'e_tab', 'C.e_div3', 'k', num2str(par.enea.k_e), 't0', '0');
add_block('dtt_lib/DIV Coil', [mdl '/Coil'], 'Position', [200 110 300 190], ...
    'R0', 'par.div3.R0', 'L0', 'par.div3.L0', 'Lm1', '0', 'Lm2', '0', 'tau1', '1', 'tau2', '1', 'k_e', '1', 'i0', '0');
add_block('fl_lib/Electrical/Electrical Elements/Inductor', [mdl '/Lcable'], 'Position', [360 130 420 170], 'l', 'par.cable.L');
add_block('fl_lib/Electrical/Electrical Elements/Inductor', [mdl '/Lp'], 'Position', [480 130 540 170], 'l', 'par.div3.Lp');
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor', [mdl '/Isens'], 'Position', [600 130 660 170]);
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', [mdl '/Ref'], 'Position', [230 260 270 290]);
add_block('nesl_utility/Solver Configuration', [mdl '/Solver'], 'Position', [120 260 170 290]);
add_block('nesl_utility/PS-Simulink Converter', [mdl '/PS2S'], 'Position', [720 100 760 130]);
add_block('simulink/Sinks/To Workspace', [mdl '/ToWs'], 'Position', [800 100 860 130], 'VariableName', 'i_sim', 'SaveFormat', 'Array');

% ---- connections (Simscape ports LConnk / RConnk are numbered per side in declaration order,
%      physical-signal ports first as in the Foundation library)
%   DIV Coil : LConn1 = e (PS input), LConn2 = p, RConn1 = i_out (PS output), RConn2 = n
%   Inductor : LConn1 -> RConn1 ; Current Sensor : LConn1 = +, RConn1 = I (PS output), RConn2 = -
%   If in doubt check get_param([mdl '/Coil'],'PortHandles') and the block icon.
try
    add_line(mdl, 'EMF/RConn1',    'Coil/LConn1');   % e.m.f. into the coil
    add_line(mdl, 'Coil/RConn2',   'Lcable/LConn1'); % n -> cable
    add_line(mdl, 'Lcable/RConn1', 'Lp/LConn1');
    add_line(mdl, 'Lp/RConn1',     'Isens/LConn1');  % -> sensor +
    add_line(mdl, 'Isens/RConn2',  'Coil/LConn2');   % sensor - -> p: short circuit = ideal crowbar
    add_line(mdl, 'Coil/LConn2',   'Ref/LConn1');
    add_line(mdl, 'Solver/RConn1', 'Coil/LConn2');
    add_line(mdl, 'Isens/RConn1',  'PS2S/LConn1');   % measured current
    add_line(mdl, 'PS2S/1',        'ToWs/1');
catch ME
    warning('dtt:wiring', 'Automatic wiring failed (%s). Blocks are in place: complete the connections by hand.', ME.message);
    run_it = false;
end

if run_it
    out = sim(mdl);
    tt = out.tout; ii = out.i_sim;
    figure('Name', 'dtt_div_validation vs spec Fig. 7');
    plot(C.t*1e3, C.i_ind/1e3, 'k', 'LineWidth', 1.5); hold on; plot(tt*1e3, ii/1e3, 'r--'); grid on
    xlabel('t [ms]'); ylabel('i [kA]'); legend('spec Fig. 7 (digitised)', 'Simscape dtt.div_coil', 'Location', 'south');
    ir = interp1(C.t, C.i_ind, tt);
    [imax, k] = max(ii);
    fprintf('Simscape: peak %.2f kA @ %.0f ms, i(300 ms) %.2f kA, rms vs Fig. 7 %.0f A\n', imax/1e3, 1e3*tt(k), ii(end)/1e3, sqrt(mean((ii - ir).^2, 'omitnan')));
end
end
