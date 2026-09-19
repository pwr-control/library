%DTT_VALIDATE_ODE  Check of the load-model data and parameter sets without Simulink.
%   Reproduces the spec PSS-SPT-59401 Fig. 7 crowbar current from the digitised
%   Fig. 6 e.m.f. with the "ENEA-equivalent" settings (Sec. 8.2 circuit, k_e = 1.84),
%   compares the physical variants and the analytic e.m.f. model.
%   Run from the matlab/ folder (or with it on the path).
par = dtt_div_params();
C   = dtt_load_curves();
t = C.t; e3 = C.e_div3;
disp(C.info)

% ---- 1. Fig. 7 reproduction
L_tot = par.div3.L0 + par.cable.L + par.div3.Lp;           % 3.46 mH (spec Sec. 8.2 circuit)
i_S2  = dtt_sim_coil(t, e3, L_tot, par.div3.R0, [], [], par.enea.k_e, 0);
i_cal = dtt_sim_coil(t, e3, par.calib.L_total, par.calib.R_total, [], [], 1, 0);
i_ke1 = dtt_sim_coil(t, e3, L_tot, par.div3.R0, [], [], 1, 0);
rmsf = @(y) sqrt(mean((y - C.i_ind).^2));
[imax, ki] = max(C.i_ind);
fprintf('Fig. 7 reference     : peak %.2f kA @ %.0f ms, i(300 ms) %.2f kA\n', imax/1e3, 1e3*t(ki), C.i_ind(end)/1e3);
fprintf('S2 ENEA-equivalent   : peak %.2f kA, i(300) %.2f kA, rms %.0f A\n', max(i_S2)/1e3, i_S2(end)/1e3, rmsf(i_S2));
fprintf('calibrated R-L       : peak %.2f kA, i(300) %.2f kA, rms %.0f A\n', max(i_cal)/1e3, i_cal(end)/1e3, rmsf(i_cal));
fprintf('Sec. 8.2 circuit,k=1 : peak %.2f kA, i(300) %.2f kA, rms %.0f A  (Fig. 6 as is: does NOT reproduce Fig. 7)\n', max(i_ke1)/1e3, i_ke1(end)/1e3, rmsf(i_ke1));

% ---- 2. physical variants (what the spec says was left out of Fig. 7)
R_all = par.div3.R0 + par.cable.R + par.Rp_placeholder;
i_R   = dtt_sim_coil(t, e3, L_tot, R_all, [], [], par.enea.k_e, 0);
i_eddy = dtt_sim_coil(t, e3, L_tot, R_all, par.div3.Lm, par.div3.tau, par.enea.k_e, 0);
i_noLp = dtt_sim_coil(t, e3, par.div3.L0 + par.cable.L, par.div3.R0 + par.cable.R, [], [], par.enea.k_e, 0);
I2t = @(y) trapz(t, y.^2)/1e6;
fprintf('+ R_cable + R_p      : peak %.2f kA, I2t %.1f MA^2s (S2: %.1f)\n', max(i_R)/1e3, I2t(i_R), I2t(i_S2));
fprintf('+ eddy loops (Fig.3) : peak %.2f kA, I2t %.1f MA^2s\n', max(i_eddy)/1e3, I2t(i_eddy));
fprintf('without Lp           : peak %.2f kA, I2t %.1f MA^2s\n', max(i_noLp)/1e3, I2t(i_noLp));

% ---- 3. analytic e.m.f. model vs Fig. 6
S = dtt_plasma_scenario(par.plasma.div3, t);
fprintf('analytic e.m.f.      : peak %.0f V (ref %.0f), rms %.0f V, total flux %.1f Wb (ref %.1f)\n', ...
    min(S.e), min(e3), sqrt(mean((S.e - e3).^2)), trapz(t, S.e), trapz(t, e3));

% ---- plots
figure('Name','DTT DIV3 load model validation');
subplot(2,2,1); plot(t*1e3, e3/1e3, 'k', t*1e3, S.e/1e3, 'r--'); grid on
xlabel('t [ms]'); ylabel('e_{oc} [kV]'); legend('spec Fig. 6 DIV3','analytic model'); title('Open-circuit e.m.f.')
subplot(2,2,2); plot(t*1e3, C.i_ind/1e3, 'k', 'LineWidth', 1.5); hold on
plot(t*1e3, i_S2/1e3, t*1e3, i_cal/1e3, t*1e3, i_ke1/1e3); grid on
xlabel('t [ms]'); ylabel('i [kA]'); legend('spec Fig. 7','S2: 3.46 mH/24.9 m\Omega, k_e=1.84','calibrated 1.92 mH/13.1 m\Omega','3.46 mH/24.9 m\Omega, k_e=1','Location','south')
title('Ideal crowbar current')
subplot(2,2,3); plot(t*1e3, C.i_tot/1e3, 'k', 'LineWidth', 1.5); hold on
plot(t*1e3, (i_S2 + 5000)/1e3, t*1e3, dtt_sim_coil(t, e3, L_tot, par.div3.R0, [], [], par.enea.k_e, 5000)/1e3); grid on
xlabel('t [ms]'); ylabel('i [kA]'); legend('spec Fig. 7 total','S2 + 5 kA constant','S2 with i_0 = 5 kA','Location','south'); title('Total current')
subplot(2,2,4); plot(t*1e3, C.i_ind/1e3, 'k', 'LineWidth', 1.5); hold on
plot(t*1e3, i_S2/1e3, t*1e3, i_R/1e3, t*1e3, i_eddy/1e3, t*1e3, i_noLp/1e3); grid on
xlabel('t [ms]'); ylabel('i [kA]'); legend('spec Fig. 7','S2','+R_{cable}+R_p','+eddy loops','without L_p','Location','south'); title('Physical variants')
