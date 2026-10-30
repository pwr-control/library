function nfail = test_super_transformer(tol)
%TEST_SUPER_TRANSFORMER  Simscape check of super_transformer against the library transformers it stands for.
%
%   nfail = super_transformer.test_super_transformer          (library on the path, any folder)
%   nfail = super_transformer.test_super_transformer(tol)     largest relative difference accepted, default 1e-3
%
%   For each case a model is built in memory with two copies of the same circuit, one with a library
%   transformer and one with super_transformer set up as that transformer (Simscape Component blocks on the
%   source files, so no ssc_build is needed), and simulated with Simscape logging. The two copies run in the
%   same model, on the same time steps; the currents of their sources and loads are compared sample by
%   sample. The three-phase cases run three periods and are compared from t = 0, magnetizing inrush
%   included. The cases with two primaries run 20 periods and are compared over the last one: the current
%   that circulates between primary 1 and primary 2 (i1 = -n2*i2, no net mmf) is free when the simulation
%   starts, because the coil currents have no initial target (priority none), and the consistent initial
%   state computed by Simscape gives it different values in the two copies (R2026b, cases 9, 10 and 12: up
%   to about 3 kA at t = 0; about zero in the super copy of case 12). This difference decays with
%   tau = (L1 + L2')/(R1 + R2'), 56 ms here, still 4 % of it after three periods. After 20 periods what is
%   left is a constant offset of about 1e-4 of the peak: the two primaries have different X/R, so the
%   decaying circulating current leaves a flux offset on the core, about 2.6e-5 V*s per ampere at t = 0,
%   which decays with the magnetizing time constant Lm/(R1 || R2'), about 8 minutes:
%
%     case   library transformer                        super_transformer
%     1-4    transformer_Dyn, clock 11, 1, 5, 7          one primary, delta; secondary star, clock3 = clock
%     5-6    transformer_Yyn, clock 0, 6                 one primary, star; secondary star
%     7-8    transformer_Dd, clock 0, 6                  one primary, delta; secondary delta
%     9-11   tri_monophase_transformer, ws [1 -1 0],     two primaries, star, clock2 0; secondary
%            [1 -1/2 -1/2], [1 0 0]                      single-phase, same ws
%     12     tri_monophase_transformer, ws [1 -1 0]      two primaries, star, clock2 0; secondary star with
%                                                        the load across a-b, coils of half the r3 and l3
%                                                        (the TELEMA bench)
%
%   Circuits: ideal three-phase source on the primary (a second one at 98.5 % and -2 deg on primary 2: two
%   grid formers that do not match), primary neutrals open, unbalanced RL load in star on a, b, c with the
%   star point on n and earthed (the delta secondary: star point earthed), single-phase RL load on s1-s2
%   (a-b) with s2 (b) earthed. The case passes when the largest difference of the currents in the compared
%   periods is below tol times their peak in the same periods; the function prints one line per case and
%   returns the number of failed cases.
%   The phasor check of the same equations, with closed-form expectations for the configurations no library
%   block has, is check_super_transformer.py in this folder.

    if nargin < 1
        tol = 1e-3;
    end
    base3 = struct('Sr', 630e3, 'V1', 690, 'V2', 400, 'fr', 50, 'r1', 0.004, 'l1', 0.028, 'r2', 0.006, ...
                   'l2', 0.022, 'lm', 150, 'lm0', 0.6, 'rfe', 400);
    base1 = struct('Sr', 450e3, 'V1', 380, 'V2', 390, 'V3', 1000, 'fr', 50/3, 'r1', 0.004, 'l1', 0.032, ...
                   'r2', 0.006, 'l2', 0.027, 'r3', 0.005, 'l3', 0.030, 'lm', 120, 'lm0', 0.5, 'rfe', 600);
    cases = {};
    for clock = [11 1 5 7]
        cases{end+1} = three_phase_case('transformer_Dyn', 'delta', 'star', clock, base3); %#ok<AGROW>
    end
    for clock = [0 6]
        cases{end+1} = three_phase_case('transformer_Yyn', 'star', 'star', clock, base3); %#ok<AGROW>
    end
    for clock = [0 6]
        cases{end+1} = three_phase_case('transformer_Dd', 'delta', 'delta', clock, base3); %#ok<AGROW>
    end
    ws_list = {[1 -1 0], [1 -1/2 -1/2], [1 0 0]};
    for k = 1:numel(ws_list)
        cases{end+1} = tri_mono_case(base1, ws_list{k}, false); %#ok<AGROW>
    end
    cases{end+1} = tri_mono_case(base1, [1 -1 0], true);

    nfail = 0;
    fprintf('\ntest_super_transformer: %d cases, tolerance %g of the peak current\n', numel(cases), tol);
    for k = 1:numel(cases)
        c = cases{k};
        try
            [err, ipk] = run_case(c);
            ok = err <= tol;
            fprintf('  %2d  %-62s  %-11s  max |diff| %.2e of %.4g A peak  %s\n', k, c.title, ...
                window_text(c), err, ipk, pass_text(ok));
        catch ME
            ok = false;
            fprintf('  %2d  %-62s  ERROR: %s\n', k, c.title, ME.message);
        end
        nfail = nfail + ~ok;
    end
    if nfail == 0
        fprintf('ALL CASES PASSED\n');
    else
        fprintf('%d CASE(S) FAILED\n', nfail);
    end
end

% ================================================================================================= cases
function c = three_phase_case(comp, conn1, sec, clock, p)
    c.title = sprintf('%s clock %d = super %s / %s, clock3 %d', comp, clock, conn1, sec, clock);
    c.fr = p.fr;
    c.periods = 3;                                  % simulated periods
    c.last = 3;                                     % last periods compared: all, inrush included
    c.ref.comp = ['three_phase_transformer.' comp];
    c.ref.par = {'Sr', p.Sr, 'V1', p.V1, 'V2', p.V2, 'fr', p.fr, 'clock_number', clock, 'r1', p.r1, ...
                 'l1', p.l1, 'r2', p.r2, 'l2', p.l2, 'lm', p.lm, 'lm0', p.lm0, 'rfe', p.rfe};
    c.ref.left = {'A1', 'B1', 'C1'};
    if strcmp(conn1, 'star')
        c.ref.left{end+1} = 'N1';
    end
    c.ref.right = {'a', 'b', 'c'};
    if strcmp(sec, 'star')
        c.ref.right{end+1} = 'n';
    end
    c.ref.right = [c.ref.right, {'psi_a', 'psi_b', 'psi_c'}];
    c.sup.comp = 'super_transformer.super_transformer';
    c.sup.par = {'primaries', 'super_transformer.n_primaries.one', ...
                 'conn1', ['super_transformer.connection.' conn1], ...
                 'secondary', ['super_transformer.secondary_winding.' sec], 'clock3', clock, ...
                 'Sr', p.Sr, 'V1', p.V1, 'V3', p.V2, 'fr', p.fr, 'r1', p.r1, 'l1', p.l1, 'r3', p.r2, ...
                 'l3', p.l2, 'lm', p.lm, 'lm0', p.lm0, 'rfe', p.rfe};
    c.sup.left = c.ref.left;
    c.sup.right = c.ref.right;
    Zb = p.V2^2/p.Sr;                               % star base of the secondary
    c.V1 = p.V1;
    c.V2 = [];                                      % no second source
    c.load = 'star';                                % unbalanced RL star on a, b, c
    c.Zload = Zb*[1 + 0.2i, 0.6 + 0.5i, 2.0 + 0.02i];   % per phase, Ohm (R + j X at fr; X > 0 for the Inductor block)
    c.star_to_n = strcmp(sec, 'star');
end

function c = tri_mono_case(p, ws, star_secondary)
    c.fr = p.fr;
    c.periods = 20;                                 % the circulating current of the start decays (tau 56 ms)
    c.last = 1;
    c.ref.comp = 'tri_monophase_transformer.tri_monophase_transformer';
    names = {'Sr', 'V1', 'V2', 'V3', 'fr', 'r1', 'l1', 'r2', 'l2', 'r3', 'l3', 'lm', 'lm0', 'rfe'};
    vals = cellfun(@(f) p.(f), names, 'UniformOutput', false);
    c.ref.par = [reshape([names; vals], 1, []), {'ws', ws}];
    c.ref.left = {'A1', 'B1', 'C1', 'N1', 'A2', 'B2', 'C2', 'N2'};
    c.ref.right = {'s1', 's2', 'psi_a', 'psi_b', 'psi_c'};
    c.sup.comp = 'super_transformer.super_transformer';
    c.sup.par = [{'primaries', 'super_transformer.n_primaries.two', ...
                  'conn1', 'super_transformer.connection.star', 'conn2', 'super_transformer.connection.star', ...
                  'clock2', 0}, reshape([names; vals], 1, [])];
    c.sup.left = c.ref.left;
    if star_secondary
        % same turns per coil: line-to-line V3 of the star = single-phase V3 (ws [1 -1 0]), each coil half
        % of the r3, l3 of the single-phase winding; the load across a-b, coil c idle
        c.title = 'tri_monophase ws [1 -1 0] = super star secondary loaded a-b';
        c.sup.par = [c.sup.par, {'secondary', 'super_transformer.secondary_winding.star', 'clock3', 0, ...
                     'r3', p.r3/2, 'l3', p.l3/2}];
        c.sup.right = {'a', 'b', 'c', 'n', 'psi_a', 'psi_b', 'psi_c'};
        c.sup.map = struct('s1', 'a', 's2', 'b');   % load terminals of the super copy
    else
        c.title = sprintf('tri_monophase ws %s = super single-phase', mat2str(ws, 3));
        c.sup.par = [c.sup.par, {'secondary', 'super_transformer.secondary_winding.single_phase', 'ws', ws}];
        c.sup.right = c.ref.right;
    end
    c.V1 = p.V1;
    c.V2 = p.V2;
    c.load = 'single';
    c.Zload = p.V3^2/p.Sr*(0.85 + 0.3i);
    c.star_to_n = false;
end

% ============================================================================================ simulation
function [err, ipk] = run_case(c)
    mdl = 'test_super_transformer_mdl';
    if bdIsLoaded(mdl)
        close_system(mdl, 0);
    end
    new_system(mdl);
    cleanup = onCleanup(@() close_system(mdl, 0));
    set_param(mdl, 'StopTime', num2str(c.periods/c.fr, 17), 'Solver', 'ode23t', 'RelTol', '1e-7', ...
        'MaxStep', num2str(1/(c.fr*500)));
    build_copy(mdl, c, 'ref', 0);
    build_copy(mdl, c, 'sup', 600);
    % the Simscape logging parameters exist only once the model has a Simscape block; the whole run is
    % logged (no limit on the number of points)
    set_param(mdl, 'SimscapeLogType', 'all', 'SimscapeLogName', 'simlog', 'SimscapeLogLimitData', 'off');
    out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
    log = out.simlog;
    names = current_blocks(c);
    t0 = (c.periods - c.last)/c.fr;                 % start of the compared periods
    err = 0;
    ipk = 0;
    for k = 1:numel(names)
        sref = log.([names{k} '_ref']).i.series;
        t = sref.time;
        assert(t(1) <= t0 + 1e-9/c.fr, 'test_super_transformer: the log of %s starts at %g s, after %g s', ...
            names{k}, t(1), t0);
        w = t >= t0 - 1e-9/c.fr;
        iref = sref.values('A');
        isup = log.([names{k} '_sup']).i.series.values('A');
        ipk = max(ipk, max(abs(iref(w))));
        err = max(err, max(abs(iref(w) - isup(w))));
    end
    err = err/ipk;
    clear cleanup
end

function names = current_blocks(c)
%CURRENT_BLOCKS  Blocks whose current is compared: the sources and the load resistors.
    names = {'VA1', 'VB1', 'VC1'};
    if ~isempty(c.V2)
        names = [names, {'VA2', 'VB2', 'VC2'}];
    end
    if strcmp(c.load, 'star')
        names = [names, {'Ra', 'Rb', 'Rc'}];
    else
        names = [names, {'Rs'}];
    end
end

function build_copy(mdl, c, which, y0)
%BUILD_COPY  One copy of the circuit (which = 'ref' or 'sup'), placed at the vertical offset y0.
    fl = 'fl_lib/Electrical/Electrical ';
    sfx = ['_' which];
    tc = c.(which);
    tr = [mdl '/trafo' sfx];
    add_block(library_block('nesl_utility', '^Simscape\s+Component$'), tr, 'Position', [400 y0 + 50 560 y0 + 400]);
    try
        set_param(tr, 'ComponentPath', tc.comp);
    catch
        set_param(tr, 'SourceFile', tc.comp);
    end
    par = tc.par;
    for k = 1:2:numel(par)                          % configuration first: it decides the ports and parameters
        if ischar(par{k + 1}) && contains(par{k + 1}, 'super_transformer.')
            set_param(tr, par{k}, par{k + 1});
        end
    end
    for k = 1:2:numel(par)
        if ~ischar(par{k + 1})
            set_param(tr, par{k}, mat2str(par{k + 1}, 17));
        end
    end
    ph = get_param(tr, 'PortHandles');
    assert(numel(ph.LConn) == numel(tc.left) && numel(ph.RConn) == numel(tc.right), ...
        '%s: %d left and %d right ports, %d and %d expected (%s / %s)', tr, numel(ph.LConn), ...
        numel(ph.RConn), numel(tc.left), numel(tc.right), strjoin(tc.left, ' '), strjoin(tc.right, ' '));
    port = containers.Map();
    for k = 1:numel(tc.left)
        port(tc.left{k}) = ph.LConn(k);
    end
    for k = 1:numel(tc.right)
        port(tc.right{k}) = ph.RConn(k);
    end

    % solver and reference of the network of this copy
    sc = add_block('nesl_utility/Solver Configuration', [mdl '/solver' sfx], 'Position', [40 y0 + 420 80 y0 + 450]);
    gnd = add_block([fl 'Elements/Electrical Reference'], [mdl '/ground' sfx], 'Position', [120 y0 + 500 140 y0 + 520]);
    hg = pconn(gnd);
    add_line(mdl, pconn(sc), hg, 'autorouting', 'on');

    % sources: primary 1 at V1, primary 2 (tri-monophase) at 98.5 % of V2 and -2 deg
    src = {'A1', 'B1', 'C1'; 'A2', 'B2', 'C2'};
    amp = [c.V1, 0.985*c.V2]*sqrt(2/3);
    shift = [0, -2];
    nsrc = 1 + ~isempty(c.V2);
    for s = 1:nsrc
        for j = 1:3
            name = ['V' src{s, j} sfx];
            y = y0 + 60*(3*(s - 1) + j);
            v = add_block([fl 'Sources/AC Voltage Source'], [mdl '/' name], 'Position', [150 y 190 y + 40], ...
                'amp', num2str(amp(s), 17), 'shift', num2str(shift(s) - 120*(j - 1), 17), ...
                'frequency', num2str(c.fr, 17));
            hv = get_param(v, 'PortHandles');
            add_line(mdl, hv.LConn(1), port(src{s, j}), 'autorouting', 'on');
            add_line(mdl, hv.RConn(1), hg, 'autorouting', 'on');
        end
    end
    % loads, R + L per branch at the reactance of c.Zload at fr
    w = 2*pi*c.fr;
    if strcmp(c.load, 'star')
        star = 'n';
        if ~c.star_to_n
            star = '';                              % delta secondary: star point on the reference
        end
        ph_names = {'a', 'b', 'c'};
        for j = 1:3
            Z = c.Zload(j);
            [r, l] = add_rl(mdl, sfx, ph_names{j}, real(Z), imag(Z)/w, y0 + 60*j);
            add_line(mdl, port(ph_names{j}), r, 'autorouting', 'on');
            if isempty(star)
                add_line(mdl, l, hg, 'autorouting', 'on');
            else
                add_line(mdl, l, port(star), 'autorouting', 'on');
            end
        end
        if ~isempty(star)
            add_line(mdl, port(star), hg, 'autorouting', 'on');
        end
    else
        t1 = 's1';
        t2 = 's2';
        if isfield(tc, 'map')
            t1 = tc.map.s1;
            t2 = tc.map.s2;
        end
        [r, l] = add_rl(mdl, sfx, 's', real(c.Zload), imag(c.Zload)/w, y0 + 60);
        add_line(mdl, port(t1), r, 'autorouting', 'on');
        add_line(mdl, l, port(t2), 'autorouting', 'on');
        add_line(mdl, port(t2), hg, 'autorouting', 'on');
    end

    % electrical ports still free (primary neutrals, the idle c and n of a star secondary loaded a-b): Open
    % Circuit blocks; the psi outputs stay unconnected
    free = [tc.left, tc.right];
    free = free(~startsWith(free, 'psi'));
    for k = 1:numel(free)
        if get_param(port(free{k}), 'Line') == -1
            oc = add_block([fl 'Elements/Open Circuit'], [mdl '/open_' free{k} sfx], ...
                'Position', [330 y0 + 20*k 350 y0 + 20*k + 10]);
            add_line(mdl, pconn(oc), port(free{k}), 'autorouting', 'on');
        end
    end
end

function [hr, hl] = add_rl(mdl, sfx, ph, R, L, y)
%ADD_RL  Series R - L, returns the free port of R (left) and of L (right).
    fl = 'fl_lib/Electrical/Electrical ';
    r = add_block([fl 'Elements/Resistor'], [mdl '/R' ph sfx], 'R', num2str(R, 17), 'Position', [700 y 740 y + 20]);
    l = add_block([fl 'Elements/Inductor'], [mdl '/L' ph sfx], 'l', num2str(L, 17), 'Position', [800 y 840 y + 20]);
    pr = get_param(r, 'PortHandles');
    pl = get_param(l, 'PortHandles');
    add_line(mdl, pr.RConn(1), pl.LConn(1), 'autorouting', 'on');
    hr = pr.LConn(1);
    hl = pl.RConn(1);
end

function h = pconn(blk)
%PCONN  First physical port of a block (one-port blocks: Solver Configuration, Reference, Open Circuit).
    ph = get_param(blk, 'PortHandles');
    h = [ph.LConn, ph.RConn];
    h = h(1);
end

function src = library_block(lib, name_regexp)
%LIBRARY_BLOCK  Path of the block of lib whose name matches name_regexp (names of nesl_utility have line breaks).
    load_system(lib);
    b = find_system(lib, 'Regexp', 'on', 'Name', name_regexp);
    b = b(~strcmp(b, lib));
    assert(~isempty(b), 'test_super_transformer: no block matching %s in %s', name_regexp, lib);
    src = b{1};
end

function s = window_text(c)
%WINDOW_TEXT  Periods compared, e.g. 'periods 1-3' or 'period 20'.
    p1 = c.periods - c.last + 1;
    if p1 == c.periods
        s = sprintf('period %d', p1);
    else
        s = sprintf('periods %d-%d', p1, c.periods);
    end
end

function s = pass_text(ok)
    if ok
        s = 'OK';
    else
        s = 'FAIL';
    end
end
