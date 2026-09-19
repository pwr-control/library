# Setup files — parameters, hardware data and controller objects

The parameter layer of the library. A model does not hold its numbers: its initialization script
calls the functions here, which build objects carrying the ratings, the derived and normalized
values, the discretized state-space matrices and the controller gains.

## Calling order

The chain has three levels, and the order matters because each stage consumes the normalization
factors produced by the previous one:

```matlab
[out, options] = init_environment('my_model');        % environment, custom Simscape units
glb_time       = timing_setup(...);                   % PWM frequencies, sample times, dead times

hwdata.afe     = three_phase_afe_hwdata(application_voltage, pwr_nom, glb_time.fPWM_AFE);
hwdata.inv     = three_phase_inverter_hwdata(application_voltage, pwr_nom, glb_time.fPWM_INV);
psm            = psm_calculus();                      % machine objects
im             = im_calculus();

igbt.inv       = device_igbt_setup('infineon_FF1200R17IP5', glb_time.fPWM_INV, hwdata.inv.udc_nom);
mosfet.dab     = device_mosfet_setup('danfoss_SKM1700MB20R4S2I4', glb_time.fPWM_DAB, hwdata.dab.udc1_nom);

afe_ctrl       = ctrl_afe_setup(glb_time.ts_inv, grid.omega_nom);
psm_ctrl       = ctrl_pmsm_setup(glb_time.ts_inv, psm.omega_bez, u_psm_scale, psm.Jm_norm);
psm_ctrl.ekf   = ekf_pmsm_setup(psm.Rs_norm, psm.Ls_norm, psm.Jm_norm, glb_time.ts_inv);
```

**timing → machine and grid objects → hardware objects → device objects → controllers and
observers.** Most classes expose `displayInfo(obj)`, which the factory functions call to echo the
configuration to the console.

Two naming conventions coexist: `*_setup.m` under `objs/` are **classes**; `*_setup.m` and
`*_hwdata.m` under `simulink_models_initialization/` are **functions that build those classes**.
The pairs `device_igbt_setup` / `device_igbt_setting` and `device_mosfet_setup` /
`device_mosfet_setting` follow the same split.

Suffixes: `*_bez` is the peak-per-phase base, `*_nom` the rated value, `*_norm` / `*_pu` per unit,
`xi` / `eta` the stationary-frame components.

Several files are scripts, not functions, and read variables the caller must have defined
(`number_of_modules`, `n_sys`, `rpm_base`, `tau_bez`, `hwdata`, `frt_data`, `glb_time`,
`options`): they cannot be run standalone.

---

## `objs`

The class library. Every file is a `classdef` whose constructor takes plain numbers.

**Timing**

- `timing_setup` — the object referenced everywhere as `glb_time`: per converter the PWM
  frequency and period, the double-update flag and the resulting sample time, plus the logging
  time base with its decimation, the sample counts, the PWM delay and all dead times.

**Machines, grid and transformers**

- `pmsm_setup` — multi-three-phase PMSM: per-system inductances and resistance, rated torque and
  voltage, normalization factors and the per-unit set, with optional 5th/7th flux harmonics.
- `im_setup` — induction machine built from nameplate plus no-load and rotor-locked tests, with
  `im_parameter_calculation`, `optimizeRotorResistor` (iterates Rr until the computed torque
  matches the rated one) and `im_normalization`.
- `grid_three_phase_emulator` — grid plus coupling transformer (Dyn or Yyn) with equivalent grid
  impedance and the positive/negative sequence ξ/η voltage references used for fault injection.
- `single_phase_transformer_setup`, `three_phase_transformer_setup` — winding resistances and
  leakage from the short-circuit voltage, magnetizing branch from the no-load current and iron
  losses, core flux from the geometry.

**Power stages** — each stores rated power, voltages and currents, PWM frequency, filter and
DC-link components and the normalization bases:

- `hw_afe_three_phase_setup` — three-phase active front end with split DC link, LCL filter
  (differential and common mode) and brake resistor.
- `hw_inverter_three_phase_setup`, `hw_inverter_full_bridge_setup`,
  `hw_single_phase_inverter_setup`.
- `hw_dab_single_phase_setup`, `hw_dab_three_phase_setup`, `hw_cllc_single_phase_setup` — isolated
  DC/DC stages with a resonant frequency, transformer data and both DC-link sides.
- `hw_psfbc_single_phase_setup`, `hw_isop_rail_setup` — the same without the resonant frequency
  (phase-shift full bridge; the ISOP rail is that topology used as an auxiliary rail).
- `hw_ps_full_bridge_setup` — lighter record with filter and normalization values only.

**Devices and cooling**

- `device_igbt_setting` — conduction, switching energies, thermal network, gate and parasitic
  data; computes the ZVS snubber from the recovery current and the module stray inductance, and
  carries a fitted parameter set for the detailed gate-charge and tail-current models.
- `device_mosfet_setting` — the MOSFET/SiC counterpart (single-die thermal path, drain and source
  stray inductances, full capacitance set).
- `liquid_cooled_plate_2kw_setup` — water-cooled aluminium plate sized for a PrimePACK2 at about
  2 kW of losses; here "ambient" is the water. A reduced mass is available to drop the thermal
  inertia in fast steady-state runs.

**Controllers, filters and observers**

- `ctrl_afe_setup` — grid-side control: DC-link PI, converter and grid current PIs in ξ/η,
  resonant gains, and the sub-objects built by its own methods (double integrator observer,
  voltage rate observer, first harmonic tracker, resonant PI, RMS).
- `ctrl_pmsm_setup` — speed PI, d/q current PIs and limits, field-weakening PI, back-EMF observer
  gains, encoder threshold, plus a slot for the EKF.
- `ctrl_im_setup` — the same structure for the induction machine.
- `ctrl_single_phase_inverter_setup` — same observer, tracker, resonant-PI and RMS set for a
  single-phase inverter.
- `ctrl_dab_setup`, `ctrl_cllc_setup`, `ctrl_isop_rail_setup` — voltage and current PI gains of
  the isolated DC/DC stages.
- `ekf_pmsm_setup`, `ekf_im_setup` — extended Kalman filters: linearization blocks, covariances
  and gain, built from the per-unit machine parameters and the sample time.
- `fof_setup`, `sof_setup` — first- and second-order filters, continuous and ZOH-discretized.
- `harmonic_observer` — resonant two-state observer with gains placed by `acker` in the continuous
  and discrete domain.

## `simulink_models_initialization`

The model-facing layer: the functions a model's init script actually calls.

**Entry point and timing**

- `init_environment(model_name)` — clears the session, registers the custom `percent` Simscape
  unit and returns the Bode plot options.
- `setup_global_filters(ts_afe, ts_inv, ts_dab, tc)` — the filter bank used by the control
  chains (first- and second-order filters at 10 and 50 Hz, one-pole low passes from 0.2 Hz to
  161 Hz, speed-observer filter), computed for each sample time.
- `rms_filter_setup(obj)` — moving-average window lengths for 1-, 2- and 10-period RMS.
- `sogi_filter(omega, delta, kepsilon, ts)` — continuous and discrete SOGI transfer functions,
  with their Bode plot.

**Hardware factories** — each holds the project's numbers and returns the object matching the
application voltage: `three_phase_afe_hwdata`, `three_phase_inverter_hwdata`,
`single_phase_inverter_hwdata`, `single_phase_dab_hwdata`, `three_phase_dab_hwdata`,
`single_phase_cllc_hwdata`, `single_phase_psfbc_hwdata`, `isop_rail_aux_application`,
`ps_full_bridge_hwdata`. `parasitic_dclink_data.m` is a script that adds the DC-link stray
inductance with its HF damping branch and plots the resulting impedance.

**Machine factories** — `psm_calculus` (the 6-system, 1.6 MW, 17.8 rpm, 104-pole wind generator),
`psm_calculus_with_variants` (that one at 690 V, otherwise a 4-system 1 MW motor drive) and
`im_calculus` (ABB M3BP 355MLB 6, 261 kW).

**Device wrappers** — `device_igbt_setup`, `device_mosfet_setup` run the chosen dataset and pack
the resulting variables into the corresponding class; `device_ideal_switch_setting` returns the
plain ideal-switch struct.

**Grid, faults and FRT**

- `grid_emulator(...)` — grid-emulator test bench: application voltage and frequency, output
  transformer sized from the no-load current and short-circuit voltage, voltage-loop gains and
  measurement normalization.
- `frt_settings(...)` — builds the FRT configuration struct: test case, which scheme is enabled,
  sequence dip depths, event times and the grid-support settings. Asymmetric type 0 is VDE/FGW
  variant C (two-phase), 1 is variant D (single-phase).
- `grid_fault_generator.m` — script consuming that struct: a switch over the standard test
  catalogue (no FRT, 75 % / 50 % / 25 % / 20 % / 12 % dips, 10 % and 15 % swells, full and
  partial load) setting per-phase amplitudes, phase shift, event length, load levels and ramp.
- `asymmetric_error(voltage_dip, error_type)` — residual magnitude and phase shift of the affected
  phasor for variants C and D.

## `semiconductor_devices_data`

The device library for loss and thermal modelling, in three layers:

- `devices_source_dataname/` — the data itself: one script per device assigning the loose
  variables transcribed from the datasheet at 125 °C (100 °C for SiC) — thresholds, conduction
  parameters, switching energies at their reference point, thermal chain, stray inductance,
  capacitances, gate resistance, switching times, snubber.
- top-level `.m` files — one-line aliases giving each device a manufacturer-and-technology name
  that an init script can pass as a string to `device_igbt_setup`.
- `heatsinks/` — `heatsink_air_64W.m` (air-cooled aluminium) and `heatsink_liquid_2kW.m` (water
  plate) defining the cooler attached to the device thermal network.
- `device_datasheets/` — the manufacturer PDFs.

Devices covered: Infineon FF450R12KT4, FF650R17IE4, FF650R17IE4D_B2, FF900R12IE4, FF1200R17IP5,
FF1200XTR17T2P5, FF1800R12IE5, FF1800R23IE7, FF2400RB12IP7, FF1000UXTR23T2M1 and
FF2600UXTR33T2M1; Danfoss/Semikron SEMiX604GB17E4s, SKM1000GB17E4, SKM1400MLI12BM7,
DP650B1700T104001 and SKM1700MB20R4S2I4; Mitsubishi CM1200DW-24T and CM1200DW-34T;
ABB 5SNA1000G650300; Wolfspeed CAB006M12GM3, CAB450M12XM3, CAB760M12HM3 and CLB800M12HM3P; plus a
generic high-power ideal switch. Three datasheets have no MATLAB dataset yet (ABB 5SDF0131Z0401
diode, ABB 5STP26N6500 thyristor, Semikron SKM1200GB17E4S2I4).

## `generic_psm`, `motors`, `wind_generators`

Machine datasets as base-workspace scripts, in SI and per unit.

- `generic_psm/` — a virtual 250 kW, 18 rpm, 120-pole PMSM in a 400 V and a 690 V version, with
  the matching constant-torque curves.
- `motors/` — two direct-drive PMSMs, 138 kNm at 18 rpm and 88 kNm at 27 rpm.
- `wind_generators/pmsm_generators/` — the 1.5 MW, 104-pole, 17.8 rpm generator split over
  `number_of_modules` or over `n_sys` systems, its quarter-scale bench version, and the
  back-to-back `loopback_250kW` machine.
- `wind_generators/torque_curves/` — the matching turbine torque curves. Each must be run after
  its generator script, and `loopback_torque_curve` overwrites `rpm_base` in place, so it must run
  exactly once.

## `im_motors`

Offline derivation of the induction-machine equivalent circuit, from which the values hard-coded
in `im_calculus` come: `im_param_calc.mlx` (nameplate plus no-load and rotor-locked tests,
iterating Rr until the rated torque is matched), `normalization.mlx` (per-unit set and the
observer constants used by the EKF), the resulting `im_data_motor.txt` and the manufacturer curve
sheet and test report.

## `batteries_initialization`

- `lithium_ion_battery_setup(nominal_voltage, nominal_power, soc_init, ts)` — cell count, OCV
  coefficients, R0/R1/C1, hysteresis and the Kalman covariances for the SOC estimator, plus a
  tabulated OCV curve.

## `engines/liebherr_engines`

Datasheet torque and consumption points of two Liebherr diesel engines (D934 and D9512), spline
fitted into the 2-D and 3-D maps consumed by the generic engine components of
[`../foundation/ice`](../foundation/ice).

## `graphics`

Post-processing scripts to be run after a simulation (they read the variables the models leave in
the workspace): `plot_sim.m` (three-phase voltages over a fixed window), `plot_spectrum.m` (FFT of
the grid voltage over ten periods), `video_plot_sim.m` (animated voltages, currents and sequence
powers).

## `transformations`

- `abc2alphabeta(a, b, c)` — amplitude-invariant Clarke transform. The inverse is not in this
  folder.

## `user_defined_simscape_units`

- `user_defined_simscape_units.defineUnits()` — registers the custom `percent` Simscape unit. The
  same call is duplicated inline in `init_environment`.
