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
(`theory_analysis_solid_state_transformer/sst_cllc_dcx_800V_800V_50kW`, 35 kHz variant in
`sst_cllc_dcx_790V_700V_50kW`): the power stage (DC chokes,
DC-link capacitors, two full bridges with optional `Coss`, symmetrical resonant tank, transformer with
magnetizing inductance and core-loss resistance) is the Simscape component
`cllc_ssc.cllc_dcx_single_phase` of [`../foundation/pwr_electronics`](../foundation/pwr_electronics), the
modulator, the two synchronous rectifiers and the control are one MATLAB Function. Mask parameter `p`,
one numeric struct (`p.hw` = parameters of the ssc block with the options as 0/1, `p.pwm`, `p.ctrl`;
`cllc_dcx/cllc_dcx_param_example.m` builds the one of the 800 V / 800 V, 50 kW, 50 kHz stage of the SST,
`cllc_dcx_param_example_35kHz.m` the one of the 790 V → 700 V, 35 kHz variant);
physical ports `dc1+`/`dc1-` (left, side 1) and `dc2+`/`dc2-` (right, side 2, galvanically separate: one
Electrical Reference per side), input `t_master`, outputs `m` (15×1 measurements in pu) and `ctrl_log`
(24×1, indices in `cllc_dcx/cllc_dcx_log_index.m`). Documented, with the sizing of the stage and the
bench of `solid-state-transformers`, in [`../documentation/cllc_dcx`](../documentation/cllc_dcx)
(`cllc_dcx.pdf`).

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

## `afe_single_phase_ttype`

Single-block single-phase three-level T-type AFE, the single-phase counterpart of the AFE blocks
above and the compact version of `single_phase_inverter_modA/B` of `sst_cllc_ttype_inv.slx` of
`pwr-control/solid-state-transformers` (`theory_analysis_solid_state_transformer/sst_based_on_full_bridge_ttype_inverter/sst_single_phase_cllc_single_phase_ttype_inv`):
the power stage (split DC link with its neutral point, two T-type legs of four switch +
antiparallel-diode pairs, LC output filter) is the Simscape component
`afe_ttype_ssc.afe_single_phase_ttype` of [`../foundation/pwr_electronics`](../foundation/pwr_electronics),
the acquisitions, the single-phase PLL, the current loop, the optional DC-link voltage loop and the
three-level PWM are one MATLAB Function. Mask parameter `p`, one numeric struct (`p.hw` = parameters
of the ssc block, `p.pwm`, `p.ctrl`; `afe_single_phase_ttype/afe_single_phase_ttype_param_example.m`
builds the one of the 50 kW, 800 V, 4 kHz module of the SST bench); physical ports `a`/`b` (left, AC
terminals after the filter) and `dc+`/`dc-` (right, DC link), inputs `t_master` and `sync`, outputs
`m` (13×1 measurements in pu), `ctrl_log` (32×1, indices in
`afe_single_phase_ttype/afe_single_phase_ttype_log_index.m`) and `sync_out`.

- `afe_single_phase_ttype.slx` — block `afe_single_phase_ttype_mod1`. Control at 2 `fpwm` (double
  update) on the rising edge of the TRGO of the local carrier: Park PLL on the terminal voltage with
  the virtual quadrature component (low-passed ξ/η rotated back) and a double integrator observer
  giving the angle of the control; first harmonic tracker on the current (fundamental and quadrature,
  then dq); dq vector PI with clip flag and integrator release, outputs divided by the acquired DC-link
  voltage (feed-forward) before the vector-length limiter; `m` = α component of (m_d, m_q); leg u
  modulated with `m`, leg v with `-m`, each leg as `single_phase_three_levels_PWM_modulator` (neutral
  switch on, outer switch at the duty, dead time around both edges). `p.ctrl.mode` 0 = current
  references (`i_ref` from `t_ref` with the slew `i_ref_slew`, `iq_ref`; positive d current = power from
  the DC link to the AC side), 1 = DC-link voltage loop (PI with filtered reference and measurement →
  d current reference). `p.ctrl.slave = 1`: the block applies m_d, m_q of the master wired to `sync`
  with its own PLL angle (`sync_out` = `[theta_hat; m_d; m_q]`), the scheme of the two modules in
  series of the bench. Optional enable time (`p.pwm.t_enable`, PI pre-loaded with the terminal voltage
  at the enable instant) and Gaussian noise on the current sample (`p.ctrl.i_noise_std`). The control
  reads the measurements quantized with `adc_q` through a Unit Delay of one `p.pwm.tc`. The control
  code is `afe_single_phase_ttype/private/afe_sp_ttype_ctrl_pwm.m`;
  `afe_single_phase_ttype/update_afe_single_phase_ttype.m` builds the library from scratch, or loads
  the source into the existing block, once `afe_ttype_ssc_lib.slx` has been built:

  ```matlab
  cd library/foundation/pwr_electronics
  ssc_build afe_ttype_ssc
  cd ../../masked_models/afe_single_phase_ttype
  update_afe_single_phase_ttype
  ```

## `interleaved_buck_3legs`

Single-block three-leg interleaved buck converter, the non-isolated DC/DC counterpart of the blocks above
and the compact version of `interleaved_buck.slx` of `pwr-control/modelization-and-control`
(`foundations_of_power_electronics/interleaved_buck_converter`): the power stage (DC-link capacitor, three
buck legs of two switch + antiparallel-diode pairs with one inductor each, common output capacitor) is the
Simscape component `buck_ssc.interleaved_buck_3legs` of [`../foundation/pwr_electronics`](../foundation/pwr_electronics),
the acquisitions, the output voltage loop, the three per-leg current loops and the interleaved PWM are one
MATLAB Function. Mask parameter `p`, one numeric struct (`p.hw` = parameters of the ssc block, `p.pwm`,
`p.ctrl`; `interleaved_buck_3legs/interleaved_buck_3legs_param_example.m` builds the one of the 750 V → 400 V,
250 kW, 4 kHz converter of the model, whose `init_model.m` produces the same struct as `param.buck`);
physical ports `dc+`/`dc-` (left, DC input) and `out+`/`out-` (right, output; `out-` is the negative rail),
input `t_master`, outputs `m` (10×1 measurements in pu) and `ctrl_log` (30×1, indices in
`interleaved_buck_3legs/interleaved_buck_3legs_log_index.m`).

- `interleaved_buck_3legs.slx` — block `interleaved_buck_3legs_mod1`. Three triangle carriers shifted by
  2π/3 (the output sees 3 `fpwm`), control at the extremes of carrier 1 (double update, 2 `fpwm`), the
  current of each leg sampled at the extremes of its own carrier (average value of the leg current, no
  ripple on the sample) and the duties of legs 2 and 3 loaded at their own extremes (shadow registers), so
  that the three loops see the same plant with one extra control step on legs 2 and 3. Cascade: PI on the
  output voltage (reference ramped with `u_ref_slew`, output the total current reference limited at
  `i_lim`) → one PI per leg on the leg current with the reference `i_ref/3` (inherent current sharing; the
  per-leg factors `kL`, `kRL` of the power stage give mismatched legs) → duty of the leg in
  [`m_low`, `m_up`], upper switch on around the carrier bottom, lower switch complementary with the dead
  time. `p.ctrl.mode` 0 = output voltage loop, 1 = total current reference (`i_ref` from `t_ref` with the
  slew `i_ref_slew`). Optional enable time (`p.pwm.t_enable`). The control reads the measurements quantized
  with `adc_q` through a Unit Delay of one `p.pwm.tc`. The control code is
  `interleaved_buck_3legs/private/interleaved_buck_3legs_ctrl_pwm.m`;
  `interleaved_buck_3legs/update_interleaved_buck_3legs.m` builds the library from scratch, or loads the
  source into the existing block, once `buck_ssc_lib.slx` has been built:

  ```matlab
  cd library/foundation/pwr_electronics
  ssc_build buck_ssc
  cd ../../masked_models/interleaved_buck_3legs
  update_interleaved_buck_3legs
  ```

## `interleaved_boost_3legs`

Single-block three-leg interleaved boost converter, the boost version of `interleaved_buck_3legs` (same
hardware, power flow reversed: battery on the inductor side, load on the DC link) and the compact
version of `interleaved_boost.slx` of `pwr-control/modelization-and-control`
(`foundations_of_power_electronics/interleaved_boost_converter`): the power stage (input capacitor
across the battery, three boost legs of two switch + antiparallel-diode pairs with one inductor each
from the input to the leg midpoint, DC-link capacitor) is the Simscape component
`boost_ssc.interleaved_boost_3legs` of [`../foundation/pwr_electronics`](../foundation/pwr_electronics),
the acquisitions, the DC-link voltage loop, the three per-leg current loops and the interleaved PWM are
one MATLAB Function. Mask parameter `p`, one numeric struct (`p.hw` = parameters of the ssc block,
`p.pwm`, `p.ctrl`; `interleaved_boost_3legs/interleaved_boost_3legs_param_example.m` builds the one of
the 200 V → 660 V, 750 A, 150 kW, 3 kHz converter of the model, whose `init_model.m` produces the same
struct as `param.boost`); physical ports `in+`/`in-` (left, battery) and `dc+`/`dc-` (right, DC link;
`in-` is the negative rail), input `t_master`, outputs `m` (10×1 measurements in pu: leg currents, their
sum, input current, `u_in`, `udc`, DC-side current, capacitor currents) and `ctrl_log` (30×1, indices in
`interleaved_boost_3legs/interleaved_boost_3legs_log_index.m`).

- `interleaved_boost_3legs.slx` — block `interleaved_boost_3legs_mod1`. Same carriers, sampling and
  shadow registers as the buck block (three triangle carriers shifted by 2π/3, control at the extremes
  of carrier 1 with double update, each leg current sampled at the extremes of its own carrier, duties
  of legs 2 and 3 loaded at their own extremes). Cascade: PI on the DC-link voltage (reference
  `udc_ref` ramped with `u_ref_slew` from `udc_ref_init`, the precharged link at the battery voltage;
  output the total input current reference limited at `i_lim`, negative = buck direction) → one PI per
  leg on the leg current with the reference `i_ref/3` → duty `d` of the lower (boost) switch in
  [`m_low`, `m_up`]; the modulator of the buck block gets `m = 1 - d` (lower switch on around the
  carrier top, upper switch complementary with the dead time: the leg current is at its average at
  both carrier extremes). The plant of the current loops is the same integrator `udc/L` as the buck
  (same gains, 225 Hz); the voltage loop crosses at 40 Hz, a quarter of the right-half-plane zero of
  the boost at nominal load (157 Hz). `p.ctrl.mode` 0 = DC-link voltage loop, 1 = total input current
  reference (`i_ref` from `t_ref` with the slew `i_ref_slew`). Optional enable time (`p.pwm.t_enable`).
  The control reads the measurements quantized with `adc_q` through a Unit Delay of one `p.pwm.tc`.
  The control code is `interleaved_boost_3legs/private/interleaved_boost_3legs_ctrl_pwm.m`;
  `interleaved_boost_3legs/update_interleaved_boost_3legs.m` builds the library from scratch, or loads
  the source into the existing block, once `boost_ssc_lib.slx` has been built:

  ```matlab
  cd library/foundation/pwr_electronics
  ssc_build boost_ssc
  cd ../../masked_models/interleaved_boost_3legs
  update_interleaved_boost_3legs
  ```
