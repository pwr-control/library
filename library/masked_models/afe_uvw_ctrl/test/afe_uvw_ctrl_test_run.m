%% afe_uvw_ctrl_test_run - run the test bench of the afe_uvw_ctrl blocks and check it
% Runs test_afe_uvw_ctrl.slx (the five library blocks in the chain of the model afe_uvw_three_phase, a
% test source and an RL plant, scenario of afe_uvw_ctrl_test_param.m) and the same functions in a MATLAB
% loop (afe_uvw_ctrl_test_loop.m), compares the two and checks the behaviour of the blocks. Prints a
% table of checks with PASS / FAIL; chk (the table), t, lg (the log of the model, N x 50, columns in
% afe_uvw_ctrl_test_log_index), t_loop, lg_loop and out stay in the workspace. One figure.
%
% Checks
%   blocks = functions   the log of the model and the log of the loop differ by less than 1e-6 (the same
%                        code runs in the blocks and in the loop; only the rounding of the generated
%                        code could differ)
%   FRT                  the fault is detected within 10 ms of the dip start, the detector is released
%                        within 20 ms of the dip end, the power limitation flag is set during the dip,
%                        the FRT reactive current reference during the dip is i_react_pos + k_frt_ref *
%                        (dip_pos - 1) = -0.8 pu (within 0.05)
%   Q loops              before the dip the averaged positive-sequence eta grid current follows the
%                        reference 0.1 pu within 0.01 and the negative-sequence currents stay below 0.01;
%                        at the end of the dip all three follow the FRT references within 0.05
%   current control      the xi (active) stack current follows the reference -0.85 pu within 0.05 before
%                        the dip; the zero-sequence current is below 2e-3 pu (the plant has a 0.02 pu
%                        DC offset that the zero-sequence PI has to cancel)
%   islanding            no trip before the frequency ramp (the dip must not trip it), trip within 0.35 s
%                        of the ramp start, with the ROCOF or the over-frequency criterion
%
% Requirements on the MATLAB path: library/masked_models/afe_uvw_ctrl with src/ and test/
% (e.g. addpath(genpath(fullfile(library_root, 'masked_models', 'afe_uvw_ctrl')))).
%
% Usage:  afe_uvw_ctrl_test_run

[p, tb] = afe_uvw_ctrl_test_param();
k = afe_uvw_ctrl_test_log_index();
mdl = 'test_afe_uvw_ctrl';

% ---- the functions in a loop
fprintf('MATLAB loop of the functions, %.2f s of simulated time ... ', tb.t_end);
t0 = tic;
[t_loop, lg_loop] = afe_uvw_ctrl_test_loop(p, tb);
fprintf('%.0f s\n', toc(t0));

% ---- the model
load_system(mdl);
in = Simulink.SimulationInput(mdl);
in = in.setVariable('p', p);
in = in.setVariable('tb', tb);
fprintf('%s, %.2f s of simulated time ... ', mdl, tb.t_end);
t0 = tic;
out = sim(in);
fprintf('%.0f s\n', toc(t0));
t = out.tout(:);
lg = out.tb_log;
if ndims(lg) == 3                   % Array format of a 50 x 1 column signal: 50 x 1 x N (the explicit
    lg = reshape(lg, size(lg, 1), []).';   % [N 1] port sizes of the blocks make the Mux output a column)
end
if size(lg, 1) ~= numel(t)
    lg = lg.';
end

% ---- checks
chk = {};
if numel(t) == numel(t_loop)
    d_max = max(abs(lg - lg_loop), [], 1);
    [d_worst, c_worst] = max(d_max);
    chk(end+1, :) = {sprintf('blocks = functions: largest difference (column %d)', c_worst), d_worst, 1e-6};
else
    chk(end+1, :) = {sprintf('blocks = functions: %d samples in the model, %d in the loop', numel(t), ...
                             numel(t_loop)), inf, 1e-6};
end
frt = lg(:, k.frt_active) > 0.5;
t_on = t(find(frt, 1, 'first'));
if isempty(t_on), t_on = inf; end
t_off = t(find(~frt & t > t_on, 1, 'first'));          % first release after the detection
if isempty(t_off), t_off = inf; end
chk(end+1, :) = {'FRT: detection delay after the dip start [s]', t_on - tb.t_dip(1), 0.010};
chk(end+1, :) = {'FRT: release delay after the dip end [s]', t_off - tb.t_dip(2), 0.020};
mid = t > tb.t_dip(1) + 0.05 & t < tb.t_dip(2) - 0.01;
chk(end+1, :) = {'FRT: power limitation flag during the dip (1 - mean)', 1 - mean(lg(mid, k.pwr_lim_enable)), 1e-9};
w_dip = t > tb.t_dip(2) - 0.05 & t < tb.t_dip(2);
i_frt = tb.i_react_pos + p.frt.k_frt_ref*(tb.dip_pos - 1);
i_frt = min(max(i_frt, -p.frt.lim_pos_eta), p.frt.lim_pos_eta);
chk(end+1, :) = {sprintf('FRT: pos_eta reference during the dip - expected %.2f [pu]', i_frt), ...
                 abs(mean(lg(w_dip, k.i_grid_ref(1))) - i_frt), 0.05};
pre = t > tb.t_dip(1) - 0.1 & t < tb.t_dip(1);
chk(end+1, :) = {'Q loop: pos_eta grid current - reference before the dip [pu]', ...
                 max(abs(lg(pre, k.i_seq_avg(2)) - lg(pre, k.i_grid_ref(1)))), 0.01};
chk(end+1, :) = {'Q loop: negative-sequence grid current before the dip [pu]', ...
                 max(max(abs(lg(pre, k.i_seq_avg(3:4))))), 0.01};
chk(end+1, :) = {'Q loop: pos_eta grid current - FRT reference at the end of the dip [pu]', ...
                 abs(mean(lg(w_dip, k.i_seq_avg(2)) - lg(w_dip, k.i_grid_ref(1)))), 0.05};
chk(end+1, :) = {'Q loop: neg_xi grid current - FRT reference at the end of the dip [pu]', ...
                 abs(mean(lg(w_dip, k.i_seq_avg(3)) - lg(w_dip, k.i_grid_ref(2)))), 0.05};
chk(end+1, :) = {'Q loop: neg_eta grid current - FRT reference at the end of the dip [pu]', ...
                 abs(mean(lg(w_dip, k.i_seq_avg(4)) - lg(w_dip, k.i_grid_ref(3)))), 0.05};
chk(end+1, :) = {'current control: xi stack current - reference before the dip [pu]', ...
                 abs(mean(lg(pre, k.is_xe(1))) - tb.i_xi_ref), 0.05};
iz = mean(lg(:, k.is_abc), 2);
chk(end+1, :) = {'current control: zero-sequence stack current before the dip [pu]', abs(mean(iz(pre))), 2e-3};
isl = lg(:, k.island) > 0.5;
t_isl = t(find(isl, 1, 'first'));
if isempty(t_isl), t_isl = inf; end
chk(end+1, :) = {'islanding: trips before the frequency ramp (0 = no)', double(any(isl & t < tb.t_drift)), 0.5};
chk(end+1, :) = {'islanding: detection delay after the ramp start [s]', t_isl - tb.t_drift, 0.35};
crit_end = lg(end, k.crit);
chk(end+1, :) = {'islanding: ROCOF (16) or over-frequency (8) in crit at the end (0 = yes)', ...
                 double(~(bitand(crit_end, 16) > 0 || bitand(crit_end, 8) > 0)), 0.5};

pass = true;
fprintf('\n%-78s %10s  %-10s  %s\n', 'check', 'value', 'limit', 'verdict');
for r = 1:size(chk, 1)
    ok = isfinite(chk{r, 2}) && chk{r, 2} <= chk{r, 3};
    pass = pass && ok;
    fprintf('%-78s %10.4g  %-10.3g  %s\n', chk{r, 1}, chk{r, 2}, chk{r, 3}, local_verdict(ok));
end
fprintf('\n%s: %s\n', mdl, local_verdict(pass));

% ---- figure
figure('Name', mdl, 'NumberTitle', 'off');
ax(1) = subplot(5, 1, 1);
plot(t, lg(:, k.v_seq_avg)); grid on; ylabel('v_{seq,avg} [pu]');
legend('pos \xi', 'pos \eta', 'neg \xi', 'neg \eta', 'Location', 'best');
title(strrep(mdl, '_', '\_'));
ax(2) = subplot(5, 1, 2);
plot(t, lg(:, k.i_grid_ref), t, lg(:, k.frt_active)*0.1 - 1, 'k--'); grid on; ylabel('i_{grid,ref} [pu]');
legend('pos \eta', 'neg \xi', 'neg \eta', 'frt\_active (0.1)', 'Location', 'best');
ax(3) = subplot(5, 1, 3);
plot(t, lg(:, k.i_seq_avg(2:4)), t, lg(:, k.i_grid_ref), '--'); grid on; ylabel('grid current [pu]');
legend('pos \eta', 'neg \xi', 'neg \eta', 'references', 'Location', 'best');
ax(4) = subplot(5, 1, 4);
plot(t, lg(:, k.is_xe), t, lg(:, k.i_xi_ref), '--', t, iz); grid on; ylabel('stack current [pu]');
legend('\xi', '\eta', '\xi reference', 'zero sequence', 'Location', 'best');
ax(5) = subplot(5, 1, 5);
plot(t, lg(:, k.idet_log(5))*tb.f_nom, t, lg(:, k.idet_log(6)), t, lg(:, k.island)*10, 'k--'); grid on;
ylabel('islanding'); xlabel('t [s]');
legend('f [Hz]', 'ROCOF [Hz/s]', 'island (x10)', 'Location', 'best');
linkaxes(ax, 'x');

% ------------------------------------------------------------------------------------------------------
function s = local_verdict(ok)
    if ok
        s = 'PASS';
    else
        s = 'FAIL';
    end
end
