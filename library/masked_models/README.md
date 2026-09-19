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
