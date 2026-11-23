%% pmsm_inverter_test_run - simulate the cases of test_pmsm_inverter.slx and check them
% Runs test_pmsm_inverter.slx (block pmsm_inverter_dqctrl_mod1 between a DC source and the library PMSM,
% shaft on a velocity source) for the cases of pmsm_inverter_test_param.m, checks the results and plots
% each case. Prints a table; res (one row per case) and out (last simulation) stay in the workspace.
%
% Checks
%   generator cases   in the last 0.1 s (1 pu speed): angle error of the selected observer against the
%                     encoder below 3 deg; machine torque = torque reference within 0.03 pu; torque
%                     reference = torque curve at 1 pu within 0.05 pu; DC-link voltage within 5 %
%   torque steps      at the end of each step (last 20 ms): machine torque = reference within 0.03 pu
%   all               current vector below p.ctrl.i_lim + 0.1 pu after the start (t > t_enable + 20 ms)
%
% Requirements on the MATLAB path: library/masked_models/pmsm_inverter (with private/ and test/),
% library/masked_models/electrical_machines (permanent_magnet_synchronous_machine.slx) and the compiled
% Simscape libraries afe_ssc_lib (library/foundation/pwr_electronics) and pmsm_uvw_with_harmonics_lib
% (library/foundation/electrical_machines). The custom Simscape unit 'percent' of the machine model is
% registered by pmsm_inverter_test_param (pm_addunit('percent', 0.01, '1')).
%
% Usage:  pmsm_inverter_test_run

mdl   = 'test_pmsm_inverter';
cases = {'generator_bemf', 'generator_ekf', 'torque_steps_lc'};
k     = pmsm_inverter_log_index;
load_system(mdl);

res = struct('name', {}, 'checks', {}, 'pass', {}, 't_run', {});
for c = 1:numel(cases)
    [tb, p_inv, mach] = pmsm_inverter_test_param(cases{c});
    in = Simulink.SimulationInput(mdl);
    in = in.setVariable('tb', tb);
    in = in.setVariable('p_inv', p_inv);
    in = in.setVariable('mach', mach);
    in = in.setModelParameter('StopTime', num2str(tb.t_stop));
    fprintf('%-16s simulating %.2f s ... ', cases{c}, tb.t_stop);
    t0 = tic;
    out = sim(in);
    t_run = toc(t0);
    fprintf('%.0f s\n', t_run);

    % ---- signals: control log, measurements, machine (pu)
    [t, lg]  = local_data(out.ctrl_log, k.n);
    [tm, mm] = local_data(out.mach_log, 5);           % phase_elec, omega_elec, torque, id, iq
    [tv, mv] = local_data(out.m_log, 17);
    psi_b  = p_inv.hw.ubez/p_inv.ctrl.omega_b;        % [Vs] flux base
    tau_b  = 3/2*mach.pp*psi_b*p_inv.hw.ibez;         % [Nm] torque base
    T_mach = mm(:, 3)/tau_b;
    w_mach = mm(:, 2)/p_inv.ctrl.omega_b;
    i_mach = hypot(mm(:, 4), mm(:, 5))/p_inv.hw.ibez;
    T_ref  = interp1(t, lg(:, k.T_ref), tm);
    vdc    = mv(:, 13);

    % ---- checks
    chk = {};
    switch cases{c}
        case {'generator_bemf', 'generator_ekf'}
            win  = t > tb.t_stop - 0.1;
            winm = tm > tb.t_stop - 0.1;
            if p_inv.ctrl.angle_src == 1
                err = lg(win, k.bemf_err);
            else
                err = lg(win, k.ekf_err);
            end
            chk(end+1, :) = {'angle error of the observer [deg]', max(abs(err))*180/pi, 3};
            chk(end+1, :) = {'torque - reference [pu]', abs(mean(T_mach(winm)) - mean(T_ref(winm))), 0.03};
            T_curve = -interp1(p_inv.ctrl.curve_w, p_inv.ctrl.curve_T, 1);
            chk(end+1, :) = {'reference - torque curve at 1 pu [pu]', abs(mean(T_ref(winm)) - T_curve), 0.05};
            chk(end+1, :) = {'DC-link voltage error [pu]', abs(mean(vdc(tv > tb.t_stop - 0.1)) - tb.Vdc/p_inv.hw.udc_nom), 0.05};
        case 'torque_steps_lc'
            t_end = [tb.steps.t(2:end) tb.t_stop];
            for s = 1:numel(tb.steps.t)
                winm = tm > t_end(s) - 0.02 & tm <= t_end(s);
                chk(end+1, :) = {sprintf('torque - reference at %.2f s (ref %+.1f) [pu]', t_end(s), tb.steps.ref(s)), ...
                                 abs(mean(T_mach(winm)) - tb.steps.ref(s)), 0.03}; %#ok<SAGROW>
            end
    end
    chk(end+1, :) = {'largest current after the start [pu]', max(i_mach(tm > p_inv.ctrl.t_enable + 0.02)), ...
                     p_inv.ctrl.i_lim + 0.1};
    pass = all(cellfun(@(v, lim) isfinite(v) && v <= lim, chk(:, 2), chk(:, 3)));
    res(c) = struct('name', cases{c}, 'checks', {chk}, 'pass', pass, 't_run', t_run);
    for r = 1:size(chk, 1)
        fprintf('   %-52s %8.4f  (limit %.3g)  %s\n', chk{r, 1}, chk{r, 2}, chk{r, 3}, ...
                local_verdict(chk{r, 2} <= chk{r, 3}));
    end

    % ---- plot
    figure('Name', [mdl ': ' cases{c}], 'NumberTitle', 'off');
    ax(1) = subplot(5, 1, 1);
    plot(tm, w_mach, t, lg(:, k.omega), '--'); grid on; ylabel('speed [pu]');
    legend('machine', 'control', 'Location', 'best'); title(strrep(cases{c}, '_', '\_'));
    ax(2) = subplot(5, 1, 2);
    plot(tm, T_mach, t, lg(:, k.T_ref), '--'); grid on; ylabel('torque [pu]');
    legend('machine', 'reference', 'Location', 'best');
    ax(3) = subplot(5, 1, 3);
    plot(tm, mm(:, 4)/p_inv.hw.ibez, tm, mm(:, 5)/p_inv.hw.ibez, t, lg(:, k.id_ref), '--', t, lg(:, k.iq_ref), '--');
    grid on; ylabel('current [pu]'); legend('i_d', 'i_q', 'i_d ref', 'i_q ref', 'Location', 'best');
    ax(4) = subplot(5, 1, 4);
    plot(t, lg(:, k.bemf_err)*180/pi, t, lg(:, k.ekf_err)*180/pi); grid on; ylabel('angle error [deg]');
    legend('back-EMF observer', 'EKF', 'Location', 'best'); ylim([-10 10]);
    ax(5) = subplot(5, 1, 5);
    plot(tv, vdc); grid on; ylabel('v_{dc} [pu]'); xlabel('t [s]');
    linkaxes(ax, 'x');
end

fprintf('\n%-16s %s\n', 'case', 'verdict');
for c = 1:numel(res)
    fprintf('%-16s %s\n', res(c).name, local_verdict(res(c).pass));
end

% ------------------------------------------------------------------------------------------------------
function [t, x] = local_data(ts, n)
%LOCAL_DATA  Time and samples (rows) of a To Workspace timeseries of width n (1-D or n x 1 signal).
    t = ts.Time(:);
    x = squeeze(ts.Data);
    if size(x, 1) == n && size(x, 2) == numel(t) && numel(t) ~= n
        x = x.';
    end
end

function s = local_verdict(ok)
    if ok
        s = 'PASS';
    else
        s = 'FAIL';
    end
end
