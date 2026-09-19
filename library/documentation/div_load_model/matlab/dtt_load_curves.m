function C = dtt_load_curves(csvfile)
%DTT_LOAD_CURVES  Load the digitised spec PSS-SPT-59401 Fig. 6 / Fig. 7 curves.
%   C = dtt_load_curves()          reads dtt_fig6_fig7_digitised.csv next to this file
%   C = dtt_load_curves(csvfile)   reads the given file
%   Fields (SI units, 0.05 ms step, 0..300 ms):
%     C.t          time [s]
%     C.e_div12    open-circuit e.m.f. DIV1/DIV2 [V]   (Fig. 6, ENEA sign convention)
%     C.e_div3     open-circuit e.m.f. DIV3 [V]        (Fig. 6)
%     C.i_ind      induced crowbar current DIV3 [A]     (Fig. 7, ideal crowbar)
%     C.i_tot      induced + 5 kA pre-disruption [A]   (Fig. 7)
%     C.ts_e_div3, C.ts_e_div12  timeseries objects for "From Workspace" blocks
%   Usage with the Simscape blocks:
%     set_param(blk,'t_tab','C.t','e_tab','C.e_div3')      (dtt.emf_table)
%   The curves were digitised from the spec PDF (about 1 % of full scale accuracy).
if nargin < 1 || isempty(csvfile)
    csvfile = fullfile(fileparts(mfilename('fullpath')),'..','data','dtt_fig6_fig7_digitised.csv');
end
T = readtable(csvfile);
C.t       = T.t_s(:);
C.e_div12 = T.e_div12_V(:);
C.e_div3  = T.e_div3_V(:);
C.i_ind   = T.i_ind_fig7_A(:);
C.i_tot   = T.i_tot_fig7_A(:);
C.ts_e_div3  = timeseries(C.e_div3, C.t, 'Name','e_oc DIV3 [V]');
C.ts_e_div12 = timeseries(C.e_div12, C.t, 'Name','e_oc DIV1/2 [V]');
C.dt = C.t(2) - C.t(1);
[emin, ke] = min(C.e_div3); [imax, ki] = max(C.i_ind);
C.info = sprintf(['DIV3: peak e = %.0f V @ %.1f ms, flux 0-80 ms %.1f Wb, quench+tail %.1f Wb; ' ...
                  'Fig.7 peak %.2f kA @ %.0f ms, i(300 ms) %.2f kA, I2t(0-300 ms) %.1f MA^2 s'], ...
    emin, 1e3*C.t(ke), trapz(C.t(C.t<=0.08),C.e_div3(C.t<=0.08)), ...
    trapz(C.t(C.t>=0.08),C.e_div3(C.t>=0.08)), imax/1e3, 1e3*C.t(ki), ...
    C.i_ind(end)/1e3, trapz(C.t, C.i_ind.^2)/1e6);
end
