%% test_semiconductors_bridges_run - simulate the 18 bridges and check the results
% Runs test_semiconductors_bridges.slx with the parameters of test_semiconductors_bridges_param
% and checks, for every bridge, the fundamental of the load current and of the output voltage
% against the values expected from the modulation, plus the losses and the junction temperature
% rises of the IGBT / MOSFET bridges. Prints a table and returns the struct res (one row per
% bridge) with a PASS/FAIL verdict; res and the simulation output out stay in the workspace.
%
% Requirements on the MATLAB path: library/masked_models/semiconductors_bridges (with its
% subfolders), library/masked_models/modulators, library/foundation/semiconductors (the compiled
% igbt_simple_2th_lib.slx and mos_simple_2th_lib.slx).
%
% Usage:  test_semiconductors_bridges_run

mdl = 'test_semiconductors_bridges';
test_semiconductors_bridges_param;                        % creates tb

topologies = {'half_bridge', 'full_bridge', 'three_phase_bridge'};
levels     = {'', '_ttype'};
families   = {'ideal_switch', 'igbt_simple_2th', 'mos_simple_2th'};
tol_fund   = 0.06;      % relative tolerance on the fundamental amplitudes (dead time, device drops)

fprintf('Simulating %s (t_stop = %g s, tc = %g s) ...\n', mdl, tb.t_stop, tb.tc);
load_system(mdl);
tic;
out = sim(mdl, 'StopTime', num2str(tb.t_stop), 'ReturnWorkspaceOutputs', 'on');
fprintf('done in %.0f s\n\n', toc);

w  = 2*pi*tb.f_out;
Z  = abs(tb.load.R + 1j*w*tb.load.L);
T1 = 1/tb.f_out;

rows = {};
fprintf('%-44s %8s %8s %6s  %8s %8s %6s  %8s %7s  %s\n', 'bridge', 'I1 exp', 'I1 sim', 'err%', ...
        'U1 exp', 'U1 sim', 'err%', 'Ploss W', 'dTj K', 'verdict');
for it = 1:numel(topologies)
    for il = 1:numel(levels)
        for ifam = 1:numel(families)
            name = [topologies{it} levels{il} '_' families{ifam}];
            r = struct('name', name, 'I1_exp', NaN, 'I1', NaN, 'U1_exp', NaN, 'U1', NaN, ...
                       'Ploss', NaN, 'dTj_max', NaN, 'pass', false, 'note', '');
            i_ts = local_get(out, [name '_i']);
            u_ts = local_get(out, [name '_u']);
            m_ts = local_get(out, [name '_m']);
            % --- expected fundamentals -------------------------------------------------
            switch topologies{it}
                case 'half_bridge'          % output measured against the dc midpoint
                    U1_exp = tb.m_amp*tb.Vdc/2;  Uph = U1_exp;
                case 'full_bridge'          % differential output, legs modulated with +m and -m
                    U1_exp = tb.m_amp*tb.Vdc;    Uph = U1_exp;
                case 'three_phase_bridge'   % logged voltage is line-to-line u-v, current is phase u
                    Uph = tb.m_amp*tb.Vdc/2;     U1_exp = sqrt(3)*Uph;
            end
            I1_exp = Uph/Z;
            % --- measured fundamentals over the last period -----------------------------
            [I1, ok_i] = local_fundamental(i_ts, tb.f_out, tb.t_stop - T1, tb.t_stop);
            [U1, ok_u] = local_fundamental(u_ts, tb.f_out, tb.t_stop - T1, tb.t_stop);
            err_i = abs(I1 - I1_exp)/I1_exp;
            err_u = abs(U1 - U1_exp)/U1_exp;
            pass = ok_i && ok_u && err_i < tol_fund && err_u < tol_fund;
            if ~(ok_i && ok_u), r.note = 'missing or non-finite log; '; end
            % --- losses and temperatures of the thermal bridges ---------------------------
            Ploss = NaN; dTj = NaN;
            if ~strcmp(families{ifam}, 'ideal_switch') && isstruct(m_ts)
                [Ploss, dTj, okp, note] = local_thermal(m_ts, tb.t_stop - T1, tb.t_stop);
                pass = pass && okp;
                r.note = [r.note note];
            end
            r.I1_exp = I1_exp; r.I1 = I1; r.U1_exp = U1_exp; r.U1 = U1;
            r.Ploss = Ploss; r.dTj_max = dTj; r.pass = pass;
            rows{end+1} = r; %#ok<AGROW>
            if pass, verdict = 'PASS'; else, verdict = 'FAIL'; end
            fprintf('%-44s %8.1f %8.1f %6.1f  %8.1f %8.1f %6.1f  %8.1f %7.2f  %s %s\n', name, ...
                    I1_exp, I1, 100*err_i, U1_exp, U1, 100*err_u, Ploss, dTj, verdict, r.note);
        end
    end
end
res = [rows{:}];
npass = sum([res.pass]);
fprintf('\n%d of %d bridges PASS\n', npass, numel(res));

% --- plots: load current and voltage of every bridge, one figure per topology ----------------
for it = 1:numel(topologies)
    figure('Name', ['semiconductors_bridges test: ' topologies{it}], 'NumberTitle', 'off');
    k = 0;
    for il = 1:numel(levels)
        for ifam = 1:numel(families)
            k = k + 1;
            name = [topologies{it} levels{il} '_' families{ifam}];
            i_ts = local_get(out, [name '_i']);  u_ts = local_get(out, [name '_u']);
            subplot(2, 3, k);
            if isa(i_ts, 'timeseries') && isa(u_ts, 'timeseries')
                yyaxis left;  plot(i_ts.Time, i_ts.Data); ylabel('i_{load} [A]');
                yyaxis right; plot(u_ts.Time, u_ts.Data); ylabel('u_{load} [V]');
                xlim([tb.t_stop - T1, tb.t_stop]);
            end
            title(strrep(name, '_', '\_'), 'FontSize', 8); xlabel('t [s]'); grid on;
        end
    end
end

% ================================================================================================
function v = local_get(out, name)
% returns the logged variable (timeseries, or struct of timeseries for a bus) or []
v = [];
try
    if isprop(out, name) || any(strcmp(out.who, name))
        v = out.get(name);
        return;
    end
catch
end
try
    v = evalin('base', name);
catch
end
end

function [A1, ok] = local_fundamental(ts, f, t0, t1)
% amplitude of the component at f of the timeseries ts over [t0, t1] (projection on exp(-j w t))
A1 = NaN; ok = false;
if ~isa(ts, 'timeseries'), return; end
t = ts.Time(:); x = ts.Data(:);
sel = t >= t0 & t <= t1;
t = t(sel); x = x(sel);
if numel(t) < 10 || any(~isfinite(x)), return; end
A1 = 2*abs(trapz(t, x.*exp(-1j*2*pi*f*t)))/(t(end) - t(1));
ok = true;
end

function [Ploss, dTj, ok, note] = local_thermal(m, t0, t1)
% total mean losses [W] and maximum junction temperature rise [K] over [t0, t1]
Ploss = 0; dTj = 0; ok = true; note = '';
names = fieldnames(m);
for k = 1:numel(names)
    ts = m.(names{k});
    if ~isa(ts, 'timeseries'), continue; end
    sel = ts.Time >= t0 & ts.Time <= t1;
    x = ts.Data(sel);
    if any(~isfinite(x)), ok = false; note = [note names{k} ' not finite; ']; continue; end
    if contains(names{k}, '_ploss_')
        Ploss = Ploss + mean(x);
    elseif contains(names{k}, '_JH_temp_')
        dTj = max(dTj, max(x));
    end
end
if ~(Ploss > 0), ok = false; note = [note 'no losses; ']; end
if ~(dTj > 0),   ok = false; note = [note 'no temperature rise; ']; end
end
