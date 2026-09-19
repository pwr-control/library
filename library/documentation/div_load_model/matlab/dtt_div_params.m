function par = dtt_div_params()
%DTT_DIV_PARAMS  Parameter sets of the DTT DIV in-vessel coil load model.
%   par = dtt_div_params() returns a structure with:
%     par.div1, par.div2, par.div3 : coil parameters (spec PSS-SPT-59401 rev. 1.0,
%         Table 2 stand-alone values and the two-loop eddy-current fit of Fig. 3)
%     par.cable  : worst-case connection (Table 2: 160 uH, 5 mOhm)
%     par.enea   : "ENEA-equivalent" settings that reproduce the spec Fig. 7 crowbar
%                  current (Sec. 8.2 circuit: coil + cable + Lp inductances, coil
%                  resistance only, e.m.f. = 1.84 x Fig. 6 DIV3)
%     par.calib  : black-box single R-L equivalent (coil + cable + Lp lumped)
%     par.plasma : analytic plasma-flux e.m.f. parameters (fit of Fig. 6)
%   See note "DTT DIV in-vessel coil load model for disruption studies", Rev. 00.

% ---- coils: stand-alone R, L (Table 2), protection reactor Lp (Table 2),
%      eddy loops fitted on Fig. 3 (Lm = M^2/Lv, tau = Lv/Rv), Fig. 3 DC value L_dc (includes Lp)
par.div1 = struct('name','DIV1','R0',10.6e-3,'L0',0.5e-3,'Lp',1.5e-3,'L_dc_fig3',1.92e-3, ...
                  'Lm',[0.161e-3 0.034e-3],'tau',[9.8e-3 86.9e-3]);
par.div2 = struct('name','DIV2','R0',18.7e-3,'L0',1.2e-3,'Lp',0.6e-3,'L_dc_fig3',1.68e-3, ...
                  'Lm',[0.466e-3 0.069e-3],'tau',[11.3e-3 140.9e-3]);
par.div3 = struct('name','DIV3','R0',24.9e-3,'L0',1.7e-3,'Lp',1.6e-3,'L_dc_fig3',3.12e-3, ...
                  'Lm',[0.593e-3 0.152e-3],'tau',[11.8e-3 102.3e-3]);
% alternative L0 consistent with the Fig. 3 DC value: L_dc_fig3 - Lp
for c = {'div1','div2','div3'}
    par.(c{1}).L0_fig3 = par.(c{1}).L_dc_fig3 - par.(c{1}).Lp;
end

% ---- connections (Table 2 worst case, cables)
par.cable = struct('L',160e-6,'R',5e-3);
% protection reactor resistance: "as small as possible" (spec 8.3); placeholder
par.Rp_placeholder = 1.0e-3;

% ---- ENEA-equivalent (reproduces Fig. 7 within 0.24 kA rms): Sec. 8.2 circuit
%      L = Lcoil + Lcable + Lp = 3.46 mH, R = Rcoil = 24.9 mOhm, no eddy loops, k_e = 1.84
par.enea = struct('L_total',par.div3.L0 + par.cable.L + par.div3.Lp,'R_total',par.div3.R0, ...
                  'k_e',1.84,'Lm',[0 0],'tau',[1 1],'i_pre',5000, ...
                  'note','Fig. 7 peak 10.9 kA @ 140 ms, i(300 ms) 4.8 kA; total = induced + 5 kA constant');

% ---- calibrated black-box R-L (whole circuit lumped, k_e = 1)
par.calib = struct('L_total',1.919e-3,'R_total',13.14e-3,'k_e',1.0);

% ---- analytic plasma-flux model (fit of Fig. 6; e.m.f. sign as in the spec)
par.plasma.div3  = struct('Psi_a',30.60,'dPsi_v',11.93,'g',31.8,'tq',81.1e-3,'tcq',3.19e-3, ...
                          'tau_v',25.8e-3,'gam',0.92,'Ip0',5.5e6);
par.plasma.div12 = struct('Psi_a',62.88,'dPsi_v',24.72,'g',1.3,'tq',81.6e-3,'tcq',2.70e-3, ...
                          'tau_v',37.6e-3,'gam',0.91,'Ip0',5.5e6);
end
