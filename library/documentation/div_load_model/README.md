# DTT DIV in-vessel coil load model for disruption studies (Simscape)

Companion package of the note `div_plasma_load_model.tex` (Rev. 00, 2026-09-18).

```
ssc/+dtt/div_coil.ssc        one coil: R0, L0, two eddy-current loops, e.m.f. input e, gain k_e   -> "DIV Coil"
ssc/+dtt/div_coils3.ssc      the three coils with mutual inductance matrix (M to be given by ENEA)  -> "DIV Coils 3"
ssc/+dtt/emf_table.ssc       e.m.f. source from a time table (digitised spec Fig. 6)               -> "EMF Table"
ssc/+dtt/emf_analytic.ssc    parametrised plasma-flux e.m.f. (VDE growth + linear quench + delay) -> "EMF Analytic"
ssc/+dtt/plasma_emf.ssc      e.m.f. from Ip(t) and Mcp(t) physical-signal inputs                  -> "Plasma EMF"
data/dtt_fig6_fig7_digitised.csv   t, e_div12, e_div3 (spec Fig. 6), i_ind, i_tot (spec Fig. 7), 0.05 ms step
data/*.json                  identification results (Fig. 3 eddy-loop fits, analytic fit, validation numbers)
matlab/dtt_div_params.m      parameter sets (physical, ENEA-equivalent, calibrated, analytic plasma)
matlab/dtt_load_curves.m     CSV loader (timeseries for From Workspace / table parameters)
matlab/dtt_plasma_scenario.m Ip(t), Mcp(t) trajectories for the Plasma EMF block
matlab/dtt_sim_coil.m        MATLAB replica of the div_coil equations (no Simulink needed)
matlab/dtt_validate_ode.m    reproduces spec Fig. 7 from Fig. 6 and compares the parameter sets
matlab/dtt_build_validation_model.m  builds/runs the Simscape validation circuit (ssc_build dtt first)
py/                          Python scripts used for digitising, identification and the figures of the note
```

## Quick start (MATLAB)

```matlab
cd ssc; ssc_build dtt; cd ..            % creates dtt_lib.slx (library "dtt_lib")
addpath matlab ssc
par = dtt_div_params();                 % parameter sets
C   = dtt_load_curves();                % digitised curves (C.t, C.e_div3, ...)
dtt_validate_ode                        % pure-MATLAB check: Fig. 7 reproduced (peak 11.0 kA, 4.3 kA @ 300 ms)
dtt_build_validation_model              % Simscape circuit, compares with Fig. 7
```

Block ports of `DIV Coil`: left = `e` (physical signal), `p`; right = `i` (physical signal), `n`.

In your converter model: drop `dtt_lib/DIV Coil` in place of the coil, put the cable (L, R) and the
protection reactor L_p in series, feed the `e` input from `EMF Table` (t_tab = C.t, e_tab = C.e_div3).
* Fig. 6 (open-circuit voltage worst case): k = 1.
* Fig. 7 (crowbar current worst case): k = 1.84 with L0 = 1.7 mH, R0 = 24.9 mOhm, Lm1 = Lm2 = 0,
  cable R = 0, R_p = 0 (spec Sec. 8.2 circuit). The physical additions (R_cable, R_p, eddy loops)
  lower the current, as stated in spec Sec. 8.4.
* Pre-disruption current: set i0 = +5000 A (worst case: same direction as the induced current) and the
  same initial current on the external series inductors (cable, L_p).

The models were written against the Simscape language specification but could not be compiled here
(no MATLAB in the authoring environment): expect at most cosmetic syntax fixes at `ssc_build`.
