function nfail = test_lit_18_pulse(tol)
%TEST_LIT_18_PULSE  Simscape check of lit_18_pulse in an 18-pulse diode rectifier.
%
%   nfail = lit_18_pulse.test_lit_18_pulse        (library on the path, any folder)
%   nfail = lit_18_pulse.test_lit_18_pulse(tol)   relative tolerance on the currents, default 5e-3
%
%   A model is built in memory with Simscape Component blocks on the source files, so no ssc_build is
%   needed: an ideal three-phase source at 13.8 kV, 60 Hz (star, neutral on the reference), lit_18_pulse
%   with its default parameters, three six-pulse bridges of crowbar.diode_fn diodes (Vf 0, Ron 1 mOhm,
%   Goff 1 nS, from library/foundation/nonlinear_loads) with their DC terminals in parallel, and a
%   current-stiff DC side, 0.5 H in series with 95 Ohm. The model runs 12 periods with Simscape logging.
%   On the last period the DC current, the DC current of each bridge (sum of its upper diodes), the line
%   current of line a (fundamental, rms, harmonics 17 and 19), the phase of the bridge currents of line a
%   (bridges 1 and 2 against bridge 3) and the conduction angle of the upper diode of bridge 3 on line a
%   are compared with the values of check_lit_18_pulse.py, part D: the same circuit integrated with
%   backward Euler at 1.04 us, with the equations read from lit_18_pulse.ssc. The 5th, 7th, 11th and 13th
%   harmonics of the line current must stay below 0.2 % of the fundamental (cancelled by the 18-pulse
%   connection). One line per check is printed; the function returns the number of failed checks.
%
%   The source phase differs from the Python run (sine here, cosine there): the transients of the start
%   decay in a few milliseconds (DC side L/R = 5.3 ms) and the compared quantities do not depend on the
%   phase of the source.

    if nargin < 1
        tol = 5e-3;
    end
    % check_lit_18_pulse.py, part D
    ref = struct('Id', 177.85, 'Id1', 59.198, 'Id2', 59.344, 'Id3', 59.305, 'IL1', 126.96, 'ILrms', 127.2, ...
                 'h17', 4.6239, 'h19', 3.8772, 'sh1', 20.027, 'sh2', -19.958, 'cond', 169.25);
    V1 = 13.8e3;  fr = 60;  periods = 12;  Rdc = 95;  Ldc = 0.5;

    mdl = 'test_lit_18_pulse_mdl';
    if bdIsLoaded(mdl)
        close_system(mdl, 0);
    end
    new_system(mdl);
    cleanup = onCleanup(@() close_system(mdl, 0));
    set_param(mdl, 'StopTime', num2str(periods/fr, 17), 'Solver', 'ode23t', 'RelTol', '1e-7', ...
        'MaxStep', num2str(1/(fr*4000), 17));
    build_model(mdl, V1, fr, Rdc, Ldc);
    set_param(mdl, 'SimscapeLogType', 'all', 'SimscapeLogName', 'simlog', 'SimscapeLogLimitData', 'off');
    fprintf('\ntest_lit_18_pulse: %g kV, %g Hz, DC side %g H + %g Ohm, %d periods\n', V1/1e3, fr, Ldc, Rdc, periods);
    out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
    log = out.simlog;

    % last period, resampled on a uniform grid
    N = 8192;
    t0 = (periods - 1)/fr;
    tt = t0 + (0:N - 1)'/(N*fr);
    g = @(series) resample_series(series, tt, t0);
    i_lit = zeros(N, 3);
    for j = 1:3
        i_lit(:, j) = g(log.lit.(sprintf('i%da', j)).series);      % line a to bridge j
    end
    iLa = sum(i_lit, 2);
    Id = g(log.Rdc.i.series);
    idc = zeros(1, 3);
    for j = 1:3
        for k = 'abc'
            idc(j) = idc(j) + mean(g(log.(sprintf('D%d%s_p', j, k)).i.series));
        end
    end
    id3a = g(log.D3a_p.i.series);
    H = dft(iLa, [1 5 7 11 13 17 19]);
    I1 = abs(H(1));
    F = zeros(1, 3);
    for j = 1:3
        F(j) = dft(i_lit(:, j), 1);
    end
    got = struct('Id', mean(Id), 'Id1', idc(1), 'Id2', idc(2), 'Id3', idc(3), 'IL1', I1/sqrt(2), ...
                 'ILrms', sqrt(mean(iLa.^2)), 'h17', 100*abs(H(6))/I1, 'h19', 100*abs(H(7))/I1, ...
                 'sh1', wrap(rad2deg(angle(F(1)/F(3)))), 'sh2', wrap(rad2deg(angle(F(2)/F(3)))), ...
                 'cond', 360*mean(id3a > 1e-3*max(id3a)));

    nfail = 0;
    nfail = nfail + chk('DC current [A]', got.Id, ref.Id, tol*ref.Id);
    nfail = nfail + chk('DC current of bridge 1 [A]', got.Id1, ref.Id1, tol*ref.Id1);
    nfail = nfail + chk('DC current of bridge 2 [A]', got.Id2, ref.Id2, tol*ref.Id2);
    nfail = nfail + chk('DC current of bridge 3 [A]', got.Id3, ref.Id3, tol*ref.Id3);
    nfail = nfail + chk('sum of the bridges = DC current [A]', sum(idc), got.Id, 1e-3*ref.Id);
    nfail = nfail + chk('line current a, fundamental [A rms]', got.IL1, ref.IL1, tol*ref.IL1);
    nfail = nfail + chk('line current a, rms [A]', got.ILrms, ref.ILrms, tol*ref.ILrms);
    nfail = nfail + chk('harmonic 17 [% of the fundamental]', got.h17, ref.h17, 0.03*ref.h17);
    nfail = nfail + chk('harmonic 19 [% of the fundamental]', got.h19, ref.h19, 0.03*ref.h19);
    hs = [5 7 11 13];
    for m = 1:numel(hs)
        nfail = nfail + chk(sprintf('harmonic %d [%% of the fundamental] < 0.2', hs(m)), ...
            100*abs(H(m + 1))/I1, 0, 0.2);
    end
    nfail = nfail + chk('phase(i a1) - phase(i a3) [deg]', got.sh1, ref.sh1, 0.2);
    nfail = nfail + chk('phase(i a2) - phase(i a3) [deg]', got.sh2, ref.sh2, 0.2);
    nfail = nfail + chk('conduction of the upper diode a, bridge 3 [deg]', got.cond, ref.cond, 1.0);
    if nfail == 0
        fprintf('ALL CHECKS PASSED\n');
    else
        fprintf('%d CHECK(S) FAILED\n', nfail);
    end
    clear cleanup
end

% ================================================================================================ model
function build_model(mdl, V1, fr, Rdc, Ldc)
    fl = 'fl_lib/Electrical/Electrical ';
    comp = library_block('nesl_utility', '^Simscape\s+Component$');
    sc = add_block('nesl_utility/Solver Configuration', [mdl '/solver'], 'Position', [40 520 80 550]);
    gnd = add_block([fl 'Elements/Electrical Reference'], [mdl '/ground'], 'Position', [120 600 140 620]);
    hg = pconn(gnd);
    add_line(mdl, pconn(sc), hg, 'autorouting', 'on');

    lit = [mdl '/lit'];
    add_block(comp, lit, 'Position', [300 40 460 520]);
    set_component(lit, 'lit_18_pulse.lit_18_pulse', 'electrical_machines');
    ph = get_param(lit, 'PortHandles');
    assert(numel(ph.LConn) == 3 && numel(ph.RConn) == 10, ...
        'test_lit_18_pulse: lit_18_pulse has %d left and %d right ports, 3 and 10 expected', ...
        numel(ph.LConn), numel(ph.RConn));

    % source: star, neutral on the reference
    names = 'ABC';
    for k = 1:3
        v = add_block([fl 'Sources/AC Voltage Source'], [mdl '/V' names(k)], 'Position', [150 60*k 190 60*k + 40], ...
            'amp', num2str(V1*sqrt(2/3), 17), 'shift', num2str(-120*(k - 1), 17), 'frequency', num2str(fr, 17));
        hv = get_param(v, 'PortHandles');
        add_line(mdl, hv.LConn(1), ph.LConn(k), 'autorouting', 'on');
        add_line(mdl, hv.RConn(1), hg, 'autorouting', 'on');
    end

    % bridges: right ports 1..9 of the LIT are a1 b1 c1 a2 b2 c2 a3 b3 c3; DC rails P and N
    hp = [];
    hn = [];
    lines = 'abc';
    for j = 1:3
        for k = 1:3
            term = ph.RConn(3*(j - 1) + k);
            y = 40 + 50*(3*(j - 1) + k);
            up = add_diode(mdl, sprintf('D%d%s_p', j, lines(k)), comp, [560 y 600 y + 20]);
            dn = add_diode(mdl, sprintf('D%d%s_n', j, lines(k)), comp, [660 y 700 y + 20]);
            add_line(mdl, term, up.LConn(1), 'autorouting', 'on');     % anode of the upper diode
            add_line(mdl, dn.RConn(1), term, 'autorouting', 'on');     % cathode of the lower diode
            if isempty(hp)
                hp = up.RConn(1);
                hn = dn.LConn(1);
            else
                add_line(mdl, up.RConn(1), hp, 'autorouting', 'on');
                add_line(mdl, dn.LConn(1), hn, 'autorouting', 'on');
            end
        end
    end

    % DC side: P - Rdc - Ldc - N
    r = add_block([fl 'Elements/Resistor'], [mdl '/Rdc'], 'R', num2str(Rdc, 17), 'Position', [800 200 840 220]);
    l = add_block([fl 'Elements/Inductor'], [mdl '/Ldc'], 'l', num2str(Ldc, 17), 'Position', [800 300 840 320]);
    pr = get_param(r, 'PortHandles');
    pl = get_param(l, 'PortHandles');
    add_line(mdl, hp, pr.LConn(1), 'autorouting', 'on');
    add_line(mdl, pr.RConn(1), pl.LConn(1), 'autorouting', 'on');
    add_line(mdl, pl.RConn(1), hn, 'autorouting', 'on');
end

function ph = add_diode(mdl, name, comp, pos)
%ADD_DIODE  crowbar.diode_fn (A left, K right), ideal: Vf 0, Ron 1 mOhm, Goff 1 nS.
    blk = [mdl '/' name];
    add_block(comp, blk, 'Position', pos);
    set_component(blk, 'crowbar.diode_fn', 'nonlinear_loads');
    set_param(blk, 'Vf', '0', 'Ron', '1e-3', 'Goff', '1e-9');
    ph = get_param(blk, 'PortHandles');
end

function set_component(blk, comp, folder)
    try
        set_param(blk, 'ComponentPath', comp);
    catch
        try
            set_param(blk, 'SourceFile', comp);
        catch ME
            error('test_lit_18_pulse: cannot load %s (%s); put library/foundation/%s on the MATLAB path', ...
                comp, ME.message, folder);
        end
    end
end

% ============================================================================================= helpers
function y = resample_series(series, tt, t0)
    t = series.time;
    v = series.values('A');                       % every compared series is a current
    assert(t(1) <= t0 + 1e-12 && t(end) >= tt(end), 'test_lit_18_pulse: the log does not cover the last period');
    [t, iu] = unique(t, 'last');                  % zero-crossing events can repeat a time
    y = interp1(t, v(iu), tt, 'linear');
end

function X = dft(y, hs)
%DFT  Peak phasors of the harmonics hs of y, sampled uniformly over one period.
    N = numel(y);
    n = (0:N - 1)';
    X = zeros(1, numel(hs));
    for m = 1:numel(hs)
        X(m) = 2/N*sum(y(:).*exp(-1j*2*pi*hs(m)*n/N));
    end
end

function a = wrap(a)
    a = mod(a + 180, 360) - 180;
end

function f = chk(label, got, expected, tol)
    ok = abs(got - expected) <= tol;
    if ok
        s = 'OK';
    else
        s = 'FAIL';
    end
    fprintf('  %-52s got %10.5g, expected %10.5g (+- %.3g)  %s\n', label, got, expected, tol, s);
    f = ~ok;
end

function h = pconn(blk)
%PCONN  First physical port of a block (one-port blocks: Solver Configuration, Reference).
    ph = get_param(blk, 'PortHandles');
    h = [ph.LConn, ph.RConn];
    h = h(1);
end

function src = library_block(lib, name_regexp)
%LIBRARY_BLOCK  Path of the block of lib whose name matches name_regexp (names of nesl_utility have line breaks).
    load_system(lib);
    b = find_system(lib, 'Regexp', 'on', 'Name', name_regexp);
    b = b(~strcmp(b, lib));
    assert(~isempty(b), 'test_lit_18_pulse: no block matching %s in %s', name_regexp, lib);
    src = b{1};
end
