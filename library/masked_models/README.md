# Masked models — Simulink library blocks

Masked Simulink blocks, one per `.slx` file, ready to be dropped into a model. Three kinds of
implementation appear, and the description of each block says which one it is:

- **Simscape** — the block wraps Simscape Electrical elements or a custom component from
  [`../foundation`](../foundation);
- **Simulink** — plain blocks and MATLAB Function blocks;
- **C-Caller** — the block calls the C code in
  [`../user_defined_functions`](../user_defined_functions), so the simulated algorithm is the one
  that runs on the target.

Where an algorithm exists in both forms (filters, observers, PLLs), the two files sit side by side
and the `_cc` / `_ccaller` suffix marks the C version.

---

## `semiconductors_bridges`

Converter power stages. Each has a `gate_commands` inport (except the passive rectifiers),
physical DC and AC terminals and a measurement bus `m`. Switches are either ideal
(controlled switch + PWL diode) or thermal IGBT / MOSFET devices with a junction-heatsink-ambient
network, so the same topology can be run fast or with losses. All Simscape.

- Two-level, ideal switch: `full_bridge_ideal_switch.slx`,
  `three_phase_inverter_ideal_switch_based_model.slx`.
- Two-level with thermal model: `full_bridge_igbt_based_with_thermal_model.slx`,
  `full_bridge_mosfet_based_with_thermal_model.slx`,
  `full_bridge_mosfet_based_with_thermal_model_zvs.slx`,
  `three_phase_inverter_igbt_based_with_thermal_model.slx`,
  `three_phase_inverter_mosfet_based_with_thermal_model.slx`,
  `three_phase_inverter_mosfet_based_with_thermal_model_zvs.slx` — the `_zvs` variants carry a
  snubber sized for soft switching.
- Two-level, advanced thermal model (separate free-wheeling diodes, per-device thermal paths,
  reverse-recovery current and module stray inductance):
  `full_bridge_igbt_based_with_advanced_thermal_model.slx`,
  `three_phase_inverter_igbt_advanced_thermal_model.slx`.
- `three_phase_inverter_with_igbt_simple.slx` — six `igbt_simple` devices with averaged switching
  loss estimation and three module thermal blocks.
- Three-level NPC single-phase: `full_bridge_three_level_npc_ideal_switch_based_model.slx`,
  `full_bridge_three_level_npc_igbt_based_model.slx`,
  `full_bridge_three_level_npc_mosfet_based_model.slx`.
- Three-level T-type single-phase: `full_bridge_three_level_ttype_ideal_switch_based_model.slx`,
  `full_bridge_three_level_ttype_igbt_based_model.slx`,
  `full_bridge_three_level_ttype_mosfet_based_model.slx` — the IGBT version has separate parameter
  sets for the neutral branch and the outer switches.
- Three-level T-type three-phase: `three_phase_three_level_ttype_inverter_ideal_switch_based_model.slx`,
  `three_phase_inverter_three_level_ttype_igbt_based_model.slx`.
- `vienna_rectifier_ideal_switch_based_model.slx` — three-level Vienna rectifier, twelve switches.
- Passive rectifiers: `full_bridge_diode_rectifier.slx`, `three_phase_diode_rectifier.slx`,
  `three_phase_diode_rectifier_with_thermal_model.slx`.

## `modulators`

PWM and gate-pattern generators, all plain Simulink with MATLAB Function blocks. Each provides a
global `TRGO` trigger output that synchronizes control sampling with the carrier; the mask exposes
the PWM frequency, the modulation clamp, the dead time, the gate levels, the solver step and the
double-update flag.

- Carrier-based two-level: `three_phase_pwm_modulator.slx`, `single_phase_pwm_modulator.slx`,
  `half_bridge_PWM_generator_with_TRGO.slx`.
- Carrier-based three-level: `three_phase_three_levels_PWM_modulator.slx`,
  `single_phase_three_levels_PWM_modulator.slx`.
- Space vector: `SV_pattern_generator_with_global_TRGO.slx`.
- DAB phase shift: `dab_single_phase_pwm_modulator.slx`,
  `dab_single_phase_pwm_modulator_with_corrections.slx` (two extra correction inputs),
  `three_phase_dab_modulator.slx` (built from two space-vector generators).
- Resonant and soft switching: `full_bridge_zvs_pwm_modulator.slx` (plus a
  `.slx.r2025b` copy of the same model saved for MATLAB R2025b),
  `half_bridge_LLC_modulator.slx` (frequency control only),
  `resonant_llc_modulator.slx` (variable frequency and phase displacement).

## `controllers`

Discrete PI regulators for the converter loops, plain Simulink.

- `pi_ctrl.slx` — PI with feed-forward input and output clamping.
- `dq_vector_pi.slx` — two PI channels with a vector-length limiter on the output and anti-windup
  clip-release logic.

## `filters`

Signal conditioning for the control loops.

- `discrete_time_low_pass_filter.slx` — first-order discrete low pass (Simulink).
- `phase_shift_filter.slx` / `phase_shift_filter_ccaller.slx` — all-pass giving 90° at a chosen
  frequency, used to build the virtual dq frame in single phase.
- `moving_average_filter.slx` / `_cc` and `simple_moving_average_filter.slx` / `_cc` — moving
  average over a period derived from the measured pulsation (the non-simple one interpolates
  between the two sample counts bracketing the period).
- `sogi_quadrature_generator.slx` / `_ccaller.slx` — second-order generalized integrator producing
  the αβ quadrature pair.

## `observers`

- `first_harmonic_tracker.slx` / `_ccaller.slx` — resonant observer locking onto the fundamental
  of a scalar signal, used to clean the grid voltage.
- `linear_double_integrator_observer_ccaller.slx` — position/velocity observer on a double
  integrator (C-Caller).

## `phase_lock_loops`

- `single_phase_pll_park.slx` — single-phase PLL built on the phase-shift filter and a double
  integrator observer (Simulink).
- `single_phase_pll_sogi.slx` — the same with SOGI as orthogonal-signal generator.
- `three_phase_dqpll_ccaller.slx` — three-phase dq PLL in C, returning the estimated pulsation and
  phase, the ξ/η grid voltages and the PLL lock state.

## `transformations`

Reference-frame rotations as MATLAB Function blocks: `alpha_beta_to_dq.slx`,
`dq_to_alpha_beta.slx`.

## `dclinks`

DC-link capacitor banks in Simscape, with a pre-charge ramp (variable resistor) and a voltage
measurement subsystem publishing the bus `m`.

- `dclink_for_two_levels.slx` — single capacitor.
- `dclink_with_center_tap.slx` — two capacitors with a mid-point.
- `dclink_for_three_levels.slx` — split DC link with neutral-point terminals, per-half sensing and
  initial conditions.

## `electrical_machines`

Machines and transformers wrapping the custom Simscape components of
[`../foundation/electrical_machines`](../foundation/electrical_machines), with a measurement bus
output.

- `induction_machine.slx` — wraps `im_uvw_2`.
- `permanent_magnet_synchronous_machine.slx` — wraps `pmsm_uvw_with_harmonics`, with the 5th/7th
  harmonic content, initial fluxes, speed, phase and position-sensor error in the mask.
- `single_phase_transformer.slx`, `saturable_single_phase_transformer.slx` (explicit saturation
  model), `three_windings_transformer.slx`.

## `electronic_components`

Gate-driver logic and operational amplifiers, each available as a transistor-level Simscape
circuit and as an equivalent Simulink model.

- `dead_time_generator_cmos_circuit.slx` — dead-time generator built from discrete CMOS gates with
  RC networks (Simscape).
- `dead_time_generator_cmos_simulink.slx` — same function with MATLAB Function blocks.
- `deadtime_with_minimum_pulse_generator.slx` — three variants of a dead-time plus
  minimum-pulse-rejection generator: CMOS circuit, state machine, and state machine with an extra
  time constant.
- `opamp.slx` — five transistor-level operational amplifier cores (BJT and MOS, with and without
  bias current, with output clamp).

## `semiconductor_devices`

Standalone MOSFET models with gate, drain and source terminals and a measurement bus.

- `simple_mosfet.slx` — conduction and body diode.
- `adv_mosfet.slx` — adds the capacitance set, switching energies, gate resistances and drain and
  source stray inductances.

## `metering`

- `threephase_voltage_current_measure.slx`, `dual_threephase_voltage_current_measure.slx` —
  pass-through voltage and current sensing for one or two three-phase sets.
- `power_meter_iec.slx` — positive- and negative-sequence voltages, currents and P/Q according to
  IEC, computed with six moving-average filters over a half grid period.

## `loads`

Passive three-phase loads in Simscape: `three_phase_rl_load.slx`, `three_phase_rlc_load.slx`,
`dual_RL_load.slx` (two independent sets, for open-winding machines).

## `power_supply_emulators`

Programmable three-phase sources with positive- and negative-sequence references in ξ/η
coordinates (Simulink).

- `three_phase_voltage_emulator.slx` — sequence references and nominal values.
- `three_phase_voltage_with_frt_emulator.slx` — adds scripted fault-ride-through events (dip
  depths per sequence, start and end times, ramp, phase shift), driven by the FRT settings from
  [`../setup_files`](../setup_files).

## `lithium_ion_batteries`

- `lithium_ion_battery.slx` — pack built on the `lithium_ion_cell` Simscape component with the
  analytical OCV curve and a Kalman SOC estimator; the mask exposes the OCV coefficients, the RC
  branch, the hysteresis, the initial SOC and the Kalman covariances.

## `mechanical_components`

- `simple_flexible_shaft.slx` — two-inertia torsional shaft wrapping the `flexshaft` component.

## `main_blocks`

- `afe_inverter_ctrl.slx` — the complete grid-side control application assembled from the blocks
  above: PLLs, sequence extraction, current control, instantaneous power, islanding detection,
  FRT according to VDE 4110, phase acquisition and compensation, quantization and logging. Mixed
  MATLAB Function and C-Caller implementation.

## `grid_following`, `grid_forming`

Single-block AFEs: the two-level bridge with DC-link capacitor and LCL filter is the Simscape
component `afe_ssc.afe_two_level_lcl` of [`../foundation/pwr_electronics`](../foundation/pwr_electronics),
the whole control with the PWM is one MATLAB Function, so that one converter counts as a handful
of nonvirtual blocks. Mask parameter `p`, one numeric struct (`p.hw`, `p.pwm`, `p.ctrl`); physical
ports `ug_a/b/c` (AC, left) and `Udc(+)/Udc(-)` (DC, right), input `t_master`, outputs `m` (14×1
measurements in pu) and `ctrl_log`.

- `grid_following_dqctrl.slx` — grid follower: FHT-PLL, DC-link voltage loop, dq current loop.
- `grid_forming_dqctrl.slx` — grid former: free-running phase generator, voltage loop on the FHT
  positive sequence of the terminal voltage, dq current loop. Master/slave for converters sharing one
  load: input `sync` and output `sync_out`, both `[theta; i_xi_ref; i_eta_ref; i_xi_n_ref; i_eta_n_ref]`;
  with `p.ctrl.slave = 1` the block runs only its current loop, with the angle and the current
  references of the master (`sync_out` of the master to `sync` of the slave). Optional
  negative-sequence compensator for unbalanced loads (e.g. a single-phase load on a transformer),
  `p.ctrl.nsc_enable = 1`, off when absent or 0: PI on the negative sequence of the terminal voltage
  (FHT, negative frame) giving negative-sequence current references, tracked by a resonant term at
  `2*fgrid` in the current loop; master and slaves need the same value. The control code is
  `grid_forming/private/afe_dq_ctrl_pwm.m`; `grid_forming/update_grid_forming_dqctrl.m` loads it
  into the block and adds the two ports. References for the compensator (full citations in the header
  of `afe_dq_ctrl_pwm.m`):
  1. Fortescue, symmetrical components, Trans. AIEE 37, 1918.
  2. Rodríguez et al., positive/negative-sequence calculation from quadrature signals (DSOGI), IEEE PESC
     2006, doi:10.1109/PESC.2006.1712059.
  3. Song, Nam, dual current control in positive and negative synchronous frames, IEEE Trans. Ind.
     Electron. 46(5), 1999, doi:10.1109/41.793344.
  4. Rodríguez et al., decoupled double synchronous reference frame, IEEE Trans. Power Electron. 22(2),
     2007.
  5. Liserre, Teodorescu, Blaabjerg, PI plus resonant current controller in a rotating frame, IEEE Trans.
     Power Electron. 21(3), 2006, doi:10.1109/TPEL.2006.875566.
  6. Teodorescu et al., proportional-resonant controllers and filters, IEE Proc. Electr. Power Appl.
     153(5), 2006, doi:10.1049/ip-epa:20060008.
  7. Yepes et al., discretization of resonant controllers, IEEE Trans. Power Electron. 25(7), 2010.
  8. Savaghebi et al., voltage unbalance compensation with voltage-source inverters, IEEE Trans. Smart
     Grid 3(2), 2012, doi:10.1109/TSG.2011.2181432.
  9. Teodorescu, Liserre, Rodríguez, *Grid Converters for Photovoltaic and Wind Power Systems*,
     Wiley-IEEE Press, 2011.

## `cllc_dcx`

Single-block CLLC-DCX (isolated resonant DC/DC stage, DC transformer), the DC/DC counterpart of the
AFE blocks above and the compact version of `sst_cllc_dcx.slx` of `pwr-control/solid-state-transformers`
(`theory_analysis_solid_state_transformer/sst_cllc_dcx_800V_800V_50kW`): the power stage (DC chokes,
DC-link capacitors, two full bridges with optional `Coss`, symmetrical resonant tank, transformer with
magnetizing inductance and core-loss resistance) is the Simscape component
`cllc_ssc.cllc_dcx_single_phase` of [`../foundation/pwr_electronics`](../foundation/pwr_electronics), the
modulator, the two synchronous rectifiers and the control are one MATLAB Function. Mask parameter `p`,
one numeric struct (`p.hw` = parameters of the ssc block with the options as 0/1, `p.pwm`, `p.ctrl`;
`cllc_dcx/cllc_dcx_param_example.m` builds the one of the 800 V → 800 V, 50 kW stage of the SST);
physical ports `dc1+`/`dc1-` (left, side 1) and `dc2+`/`dc2-` (right, side 2, galvanically separate: one
Electrical Reference per side), input `t_master`, outputs `m` (15×1 measurements in pu) and `ctrl_log`
(24×1, indices in `cllc_dcx/cllc_dcx_log_index.m`).

- `cllc_dcx.slx` — block `cllc_dcx_mod1`. Both bridges at 50 % duty, bridge 2 shifted by the angle
  `phi`; each bridge in PWM, as synchronous rectifier on the sign of the current entering its own
  midpoint (hysteresis `sr_i_off`..`sr_i_on`, body diodes in between) or off (diode rectifier):
  `p.ctrl.sr_mode_1/2`. `p.ctrl.mode` 0 = open-loop DCX at fixed ratio (`phi0`; the design use: bridge 1
  in PWM, bridge 2 synchronous rectifier, swap the two modes for power from side 2 to side 1), 1 =
  current loop (PI on the current rectified into the DC link of the regulated side `p.ctrl.side` →
  `phi`), 2 = voltage loop → current loop (cascade); the sign of `phi` follows the sign of the tank
  reactance at the switching frequency (inductive above resonance, capacitive below), computed from
  `p.hw` or given as `p.ctrl.phi_sign`. Optional frequency soft start (`p.pwm.f_start`, `p.pwm.t_soft`)
  and enable time (`p.pwm.t_enable`). The control reads period averages of the DC quantities, quantized
  with `adc_q`, through a Unit Delay of one `p.pwm.tc`. The control code is
  `cllc_dcx/private/cllc_dcx_ctrl_pwm.m`; `cllc_dcx/update_cllc_dcx.m` builds the library from scratch,
  or loads the source into the existing block, once `cllc_ssc_lib.slx` has been built:

  ```matlab
  cd library/foundation/pwr_electronics
  ssc_build cllc_ssc
  cd ../../masked_models/cllc_dcx
  update_cllc_dcx
  ```
