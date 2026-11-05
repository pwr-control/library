function res = grid_forming_droop_test_run(cases, do_plot)
%GRID_FORMING_DROOP_TEST_RUN  Droop mode of grid_forming_dqctrl: three modules on an averaged plant, MATLAB loop.
%
%   res = grid_forming_droop_test_run                    all cases, with plots
%   res = grid_forming_droop_test_run(cases, do_plot)    cases: cell array of names (see below), do_plot: 0/1
%
%   The control code of the block (private/afe_dq_ctrl_pwm.m) is called one step tc at a time for each of three
%   modules, in the droop mode (p.ctrl.droop = 1), on an averaged model of the power stage: per module the LCL
%   filter of afe_ssc.afe_two_level_lcl (L1 + R1, Cf + Rcf, L2 + R2) fed by the average bridge voltage (the
%   modulation index of the log, u_alpha, u_beta, times udc/sqrt(3)), the three L2 on one bus with a local load
%   (R in parallel with L + R, constant impedance, given in pu of the module at 1 pu of voltage) and a grid (R + L
%   behind a source of 1 pu at 50 Hz) through a breaker. Space vectors in pu of the module, steps integrated
%   exactly with the voltages held (expm). No switching, no DC link (udc = udc_nom): the test checks the control
%   code (signs, frames, start, droops, virtual impedance, limits), the Simscape model checks the rest.
%
%   The function keeps its states in persistent variables, one set per call site, so the three modules need
%   three copies: they are written to a folder in tempdir (afe_dq_ctrl_pwm_m1/2/3.m) and that folder is put on
%   the path for the run.
%
%   Cases (690 V module of 250 kW, Sb = 277.8 kVA: L1 500 uH, Cf 200 uF, L2 80 uH, udc 1070 V; grid 10 % on 1 MVA):
%     start_grid   the modules synchronize to the bus energized by the grid (droop_t_sync), then P* = 0.4 pu
%     T1           on the grid: P* of module 1 from 0.4 to 0.8 pu at 0.6 s (sync(2) of module 1)
%     T2           600 kW + 200 kvar on the bus, modules at P* = 0.4 pu, the breaker opens at 1.0 s
%     T3           as T2, then +150 kW at 1.5 s in the island
%     T5           450 kW + 150 kvar, island at 1.0 s, trip of module 3 at 1.5 s
%     black        no grid: black start of the three modules on 600 kW + 200 kvar
%   Checks (window: last 0.2 s): equal sharing (P within 0.01 pu, Q within 0.02 pu among the running modules),
%   frequency = 50*(1 + mp*(P* - P)) within 0.01 Hz, peak-to-peak of the filtered P below 0.01 pu (damped; the
%   unfiltered p on the stiff grid carries the noise of the ADC quantization, about 0.01 pu), converter current
%   below droop_i_max + 0.05 pu after the start; on the grid P = P* within 0.01 pu (T1: module 1 at 0.8 pu).
%
%   Requirements on the MATLAB path: library/masked_models/grid_forming (grid_forming_param_example.m).
%   See also grid_forming_param_example, update_grid_forming_dqctrl.

    if nargin < 1 || isempty(cases)
        cases = {'start_grid', 'T1', 'T2', 'T3', 'T5', 'black'};
    end
    if nargin < 2
        do_plot = true;
    end
    here = fileparts(mfilename('fullpath'));
    src  = fullfile(fileparts(here), 'private', 'afe_dq_ctrl_pwm.m');
    tmp  = fullfile(tempdir, 'grid_forming_droop_test');
    if ~exist(tmp, 'dir')
        mkdir(tmp);
    end
    code = fileread(src);
    for k = 1:3
        name = sprintf('afe_dq_ctrl_pwm_m%d', k);
        f = fopen(fullfile(tmp, [name '.m']), 'w');
        fwrite(f, regexprep(code, '^function \[G, ctrl_log, sync_out\] = afe_dq_ctrl_pwm\(', ...
            sprintf('function [G, ctrl_log, sync_out] = %s(', name), 'once', 'lineanchors'));
        fclose(f);
    end
    addpath(tmp);
    cleanup = onCleanup(@() rmpath(tmp));
    rehash;

    res = struct('name', {}, 'checks', {}, 'pass', {});
    for c = 1:numel(cases)
        tb = local_case(cases{c});
        p  = local_param(tb.tc);
        fprintf('%-11s %.2f s ... ', tb.name, tb.t_end);
        t0 = tic;
        [t, lg, pl] = local_loop(p, tb);
        fprintf('%.0f s wall\n', toc(t0));
        [chk, pass] = local_checks(t, lg, pl, p, tb);
        res(end + 1) = struct('name', tb.name, 'checks', {chk}, 'pass', pass); %#ok<AGROW>
        for j = 1:size(chk, 1)
            fprintf('    %-52s %s\n', chk{j, 1}, chk{j, 2});
        end
        if do_plot
            local_plot(t, lg, pl, tb);
        end
    end
    fprintf('\n%-11s %s\n', 'case', 'result');
    for c = 1:numel(res)
        fprintf('%-11s %s\n', res(c).name, local_tf(res(c).pass));
    end
end

% ------------------------------------------------------------------------------------------------------
function tb = local_case(name)
%LOCAL_CASE  Test bench of one case (pu of the module unless stated).
    tb.name    = name;
    tb.tc      = 12.5e-6;                     % [s] step: ts/10 (4 kHz, double update)
    tb.t_end   = 2.0;
    tb.load    = [2.16 0.72];                 % [P Q] of the local load at 1 pu (600 kW + 200 kvar)
    tb.grid    = true;                        % grid connected at the start
    tb.t_open  = inf;                         % [s] opening of the breaker
    tb.p_ref   = 0.4;                         % [pu] droop_p_ref of the three modules
    tb.dP1     = [inf 0];                     % [t value]: sync(2) of module 1 from t on
    tb.t_step  = inf; tb.d_load = [0 0];      % load step
    tb.t_trip  = inf;                         % trip of module 3
    tb.xg      = 0.1*250/0.9/1000;            % [pu] grid reactance: 10 % on 1 MVA
    tb.t_win   = 0.2;                         % [s] window of the checks at the end
    switch name
        case 'start_grid'
            tb.t_end = 0.8;
        case 'T1'
            tb.t_end = 1.4; tb.dP1 = [0.6 0.4];
        case 'T2'
            tb.t_open = 1.0;
        case 'T3'
            tb.t_end = 2.5; tb.t_open = 1.0; tb.t_step = 1.5; tb.d_load = [0.54 0];
        case 'T5'
            tb.t_end = 2.5; tb.load = [1.62 0.54]; tb.t_open = 1.0; tb.t_trip = 1.5;
        case 'black'
            tb.t_end = 1.0; tb.grid = false;
        otherwise
            error('grid_forming_droop_test_run: unknown case %s', name);
    end
end

% ------------------------------------------------------------------------------------------------------
function p = local_param(tc)
%LOCAL_PARAM  690 V module (Sb = 250 kW/0.9) with the droop mode on, from grid_forming_param_example.
    p = grid_forming_param_example(tc);
    p.hw.L1p = 500e-6; p.hw.L10 = 500e-6; p.hw.R1 = 157*0.05*500e-6;
    p.hw.Cf  = 200e-6; p.hw.Rcf = 50e-3;
    p.hw.L2p = 80e-6;  p.hw.L20 = 80e-6;  p.hw.R2 = 157*0.05*80e-6;
    p.hw.ubez = 690*sqrt(2/3);
    p.hw.ibez = 250e3/sqrt(3)/690/0.9*sqrt(2);
    p.hw.udc_nom = 1070;
    p.ctrl.droop = 1;
end

% ------------------------------------------------------------------------------------------------------
function [t, lg, pl] = local_loop(p, tb)
%LOCAL_LOOP  Three modules (copies of the control function) on the averaged plant, one step tc at a time.
    clear afe_dq_ctrl_pwm_m1 afe_dq_ctrl_pwm_m2 afe_dq_ctrl_pwm_m3
    ctrl = {@afe_dq_ctrl_pwm_m1, @afe_dq_ctrl_pwm_m2, @afe_dq_ctrl_pwm_m3};
    hw = p.hw;
    wb = 2*pi*p.ctrl.fgrid;
    zb = hw.ubez/hw.ibez;
    pu.x1 = wb*hw.L1p/zb; pu.r1 = hw.R1/zb; pu.b = wb*hw.Cf*zb; pu.rcf = hw.Rcf/zb;
    pu.x2 = wb*hw.L2p/zb; pu.r2 = hw.R2/zb; pu.wb = wb;
    pu.xg = tb.xg; pu.rg = tb.xg/10;
    kmod = hw.udc_nom/(sqrt(3)*hw.ubez);              % bridge voltage [pu] per unit of modulation index
    n  = round(tb.t_end/tb.tc);
    nr = 8;                                           % record every nr steps
    t  = zeros(floor(n/nr), 1);
    lg = zeros(floor(n/nr), 55, 3);
    pl = zeros(floor(n/nr), 5);                       % |u_bus|, |i_grid|, |is1|, |is2|, |is3|
    alive = [true true true];
    grid_on = tb.grid;
    load = tb.load;
    [Ad, Bd, cb] = local_plant(pu, load, grid_on, alive, tb.tc);
    x = zeros(12, 1);                                 % [is uc io]x3, i_L, i_g, grid source
    if grid_on
        x(11) = -(load(1) - 1j*load(2));              % the grid supplies the load
        x(10) = -1j*load(2);
        x(12) = 1;
        for k = 1:3
            x(3*k - 1) = 1;                           % capacitors at the bus voltage
        end
    end
    p.ctrl.droop_p_ref = tb.p_ref;
    v = zeros(3, 1);
    lgk = zeros(55, 3);
    stepped = false;
    r = 0;
    for s = 0:n - 1
        tt = s*tb.tc;
        chg = false;
        if grid_on && tt >= tb.t_open
            grid_on = false; x(11) = 0; chg = true;
        end
        if ~stepped && tt >= tb.t_step
            load = load + tb.d_load; stepped = true; chg = true;
        end
        if alive(3) && tt >= tb.t_trip
            alive(3) = false; x(7:9) = 0; v(3) = 0; chg = true;
        end
        if chg
            [Ad, Bd, cb] = local_plant(pu, load, grid_on, alive, tb.tc);
        end
        ub = cb*x;
        for k = 1:3
            if ~alive(k)
                continue
            end
            is = x(3*k - 2); uc = x(3*k - 1) + pu.rcf*(x(3*k - 2) - x(3*k)); io = x(3*k);
            M = [abc(is); abc(uc); abc(io); abc(ub); 1; 0; 0; 0; 0];
            sync = zeros(5, 1);
            if k == 1 && tt >= tb.dP1(1)
                sync(2) = tb.dP1(2);
            end
            [~, lgk(:, k)] = ctrl{k}(M, tt, sync, p);
            v(k) = (lgk(29, k) + 1j*lgk(30, k))*kmod;
        end
        if mod(s, nr) == 0 && r < numel(t)
            r = r + 1;
            t(r) = tt;
            lg(r, :, :) = reshape(lgk, 1, 55, 3);
            pl(r, :) = [abs(ub) abs(x(11)) abs(x(1)) abs(x(4)) abs(x(7))];
        end
        x = Ad*x + Bd*v;
    end
end

% ------------------------------------------------------------------------------------------------------
function [Ad, Bd, cb] = local_plant(pu, load, grid_on, alive, tc)
%LOCAL_PLANT  dx/dt = A x + B v of the averaged plant, discretized exactly over tc (v held).
%   x = [is1 uc1 io1 is2 uc2 io2 is3 uc3 io3 iL ig sg]; u_bus = cb*x = R_L*(sum io - iL - ig) (parallel R
%   of the load; the bus has no capacitor); iL: inductive part of the load (L + R, X/R = 10); ig: grid
%   current from the bus to the grid (R + L), sg: grid source (1 pu at 50 Hz, d sg/dt = j*wb*sg).
    wb = pu.wb;
    RL = 1/max(load(1), 1e-3);
    XL = 1/max(load(2), 1e-6);
    A = zeros(12); B = zeros(12, 3);
    cb = zeros(1, 12);
    for k = 1:3
        if alive(k)
            cb(3*k) = RL;
        end
    end
    cb(10) = -RL;
    if grid_on
        cb(11) = -RL;
    end
    for k = 1:3
        if ~alive(k)
            continue
        end
        i_s = 3*k - 2; u_c = 3*k - 1; i_o = 3*k;
        ucv = zeros(1, 12); ucv(u_c) = 1; ucv(i_s) = pu.rcf; ucv(i_o) = -pu.rcf;   % capacitor node voltage
        A(i_s, :) = -wb/pu.x1*ucv; A(i_s, i_s) = A(i_s, i_s) - wb/pu.x1*pu.r1; B(i_s, k) = wb/pu.x1;
        A(u_c, i_s) = wb/pu.b; A(u_c, i_o) = -wb/pu.b;
        A(i_o, :) = wb/pu.x2*(ucv - cb); A(i_o, i_o) = A(i_o, i_o) - wb/pu.x2*pu.r2;
    end
    A(10, :) = wb/XL*cb; A(10, 10) = A(10, 10) - wb/XL*(XL/10);
    if grid_on
        A(11, :) = wb/pu.xg*cb; A(11, 11) = A(11, 11) - wb/pu.xg*pu.rg; A(11, 12) = -wb/pu.xg;
    end
    A(12, 12) = 1j*wb;
    E = expm([A B; zeros(3, 15)]*tc);
    Ad = E(1:12, 1:12);
    Bd = E(1:12, 13:15);
end

% ------------------------------------------------------------------------------------------------------
function y = abc(x)
%ABC  Phase values of the space vector x (amplitude-invariant transform).
    a = exp(2j*pi/3);
    y = [real(x); real(x/a); real(x*a)];
end

% ------------------------------------------------------------------------------------------------------
function [chk, pass] = local_checks(t, lg, pl, p, tb)
%LOCAL_CHECKS  Checks of one case in the window at the end (see the header).
    c = p.ctrl;
    run_k = 1:3;
    if tb.t_trip < tb.t_end
        run_k = 1:2;
    end
    w = t > tb.t_end - tb.t_win;
    P = squeeze(mean(lg(w, 44, :), 1));
    Q = squeeze(mean(lg(w, 45, :), 1));
    f = 50*squeeze(mean(lg(w, 48, :), 1));
    pref = tb.p_ref*ones(3, 1);
    if tb.t_end > tb.dP1(1)
        pref(1) = pref(1) + tb.dP1(2);
    end
    chk = {};
    island = ~tb.grid || tb.t_open < tb.t_end;
    if island
        chk(end + 1, :) = local_check(sprintf('P sharing (spread %.4f pu)', max(P(run_k)) - min(P(run_k))), ...
            max(P(run_k)) - min(P(run_k)) < 0.01);
        chk(end + 1, :) = local_check(sprintf('Q sharing (spread %.4f pu)', max(Q(run_k)) - min(Q(run_k))), ...
            max(Q(run_k)) - min(Q(run_k)) < 0.02);
    else
        chk(end + 1, :) = local_check(sprintf('P = P* on the grid (max error %.4f pu)', max(abs(P - pref))), ...
            max(abs(P - pref)) < 0.01);
    end
    f_law = 50*(1 + c.droop_mp*(pref(run_k) - P(run_k)) - c.droop_md*0);
    chk(end + 1, :) = local_check(sprintf('f = 50(1 + mp(P* - P)) (f %.3f Hz, error %.4f Hz)', mean(f(run_k)), ...
        max(abs(f(run_k) - f_law))), max(abs(f(run_k) - f_law)) < 0.01);
    pp = max(max(lg(w, 46, run_k)) - min(lg(w, 46, run_k)));
    chk(end + 1, :) = local_check(sprintf('damped: peak-to-peak of P_f %.4f pu', pp), pp < 0.01);
    a = t > c.droop_t_sync + 0.02;
    imax = max(max(pl(a, 3:5)));
    chk(end + 1, :) = local_check(sprintf('converter current below i_max + 0.05 (max %.3f pu)', imax), ...
        imax < c.droop_i_max + 0.05);
    chk(end + 1, :) = local_check(sprintf('end: f %.3f Hz, P %s, Q %s, |u| %.3f pu', mean(f(run_k)), ...
        mat2str(P', 3), mat2str(Q', 3), mean(pl(w, 1))), true);
    pass = all(strcmp(chk(:, 2), 'pass'));
end

function c = local_check(text, ok)
    c = {text, local_tf(ok)};
end

function s = local_tf(ok)
    if ok
        s = 'pass';
    else
        s = 'FAIL';
    end
end

% ------------------------------------------------------------------------------------------------------
function local_plot(t, lg, pl, tb)
%LOCAL_PLOT  Frequency, powers, voltage and currents of one case.
    figure('Name', ['droop test ' tb.name], 'Color', 'w');
    subplot(4, 1, 1); plot(t, 50*squeeze(lg(:, 48, :))); grid on; ylabel('f [Hz]'); title(tb.name, 'Interpreter', 'none');
    subplot(4, 1, 2); plot(t, squeeze(lg(:, 46, :))); grid on; ylabel('P_f [pu]');
    subplot(4, 1, 3); plot(t, squeeze(lg(:, 47, :))); grid on; ylabel('Q_f [pu]');
    subplot(4, 1, 4); plot(t, pl(:, 1), t, pl(:, 3:5)); grid on; ylabel('|u_{bus}|, |i_s| [pu]'); xlabel('t [s]');
end
