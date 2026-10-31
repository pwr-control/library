# semiconductors_bridges — switching cells and bridges

Masked Simulink/Simscape blocks of the converter power stages, one block per `.slx` file. The
folder holds exactly one family of bridges, built by the same generator with one interface:

|                        | half bridge                                   | full bridge                                   | three-phase bridge                                          |
|------------------------|-----------------------------------------------|-----------------------------------------------|-------------------------------------------------------------|
| two-level, ideal switch | `half_bridge/half_bridge_two_level_ideal_switch`        | `full_bridge/full_bridge_two_level_ideal_switch`        | `three_phase_bridge/three_phase_bridge_two_level_ideal_switch`        |
| two-level, MOSFET       | `half_bridge/half_bridge_two_level_mos_simple_2th`      | `full_bridge/full_bridge_two_level_mos_simple_2th`      | `three_phase_bridge/three_phase_bridge_two_level_mos_simple_2th`      |
| two-level, IGBT         | `half_bridge/half_bridge_two_level_igbt_simple_2th`     | `full_bridge/full_bridge_two_level_igbt_simple_2th`     | `three_phase_bridge/three_phase_bridge_two_level_igbt_simple_2th`     |
| T-type, ideal switch    | `half_bridge/half_bridge_three_level_ttype_ideal_switch`  | `full_bridge/full_bridge_three_level_ttype_ideal_switch`  | `three_phase_bridge/three_phase_bridge_three_level_ttype_ideal_switch`  |
| T-type, MOSFET          | `half_bridge/half_bridge_three_level_ttype_mos_simple_2th`| `full_bridge/full_bridge_three_level_ttype_mos_simple_2th`| `three_phase_bridge/three_phase_bridge_three_level_ttype_mos_simple_2th`|
| T-type, IGBT            | `half_bridge/half_bridge_three_level_ttype_igbt_simple_2th`| `full_bridge/full_bridge_three_level_ttype_igbt_simple_2th`| `three_phase_bridge/three_phase_bridge_three_level_ttype_igbt_simple_2th`|

The block inside each library has the same name as the file. Three device families:

- **ideal switch** — Simscape Foundation *Switch* (controlled switch) with an antiparallel
  piecewise-linear *Diode* and an RC snubber. Fast, no losses; it measures current and voltage of
  every device.
- **mos_simple_2th** — the loss-oriented MOSFET component
  [`foundation/semiconductors/+mos_simple_2th`](../../foundation/semiconductors/+mos_simple_2th)
  (resistive bidirectional channel, PWL diode, switching energies scaled from one datasheet
  point, two thermal ports), one junction-heatsink-ambient thermal network per die.
- **igbt_simple_2th** — the IGBT component
  [`foundation/semiconductors/+igbt_simple_2th`](../../foundation/semiconductors/+igbt_simple_2th)
  (knee + slope conduction, Eon/Eoff/Err scaled from one datasheet point, two thermal ports),
  same thermal network.

The 2th bridges need the compiled libraries `igbt_simple_2th_lib.slx` / `mos_simple_2th_lib.slx`
of `foundation/semiconductors` on the MATLAB path. The 18 bridges use nothing from MathWorks beyond
Simscape Foundation. The 23 legacy models in the folder root (Simscape Electrical devices, see
[below](#legacy-models-in-the-folder-root)) are kept for now because the models of
`modelization-and-control` still link them; the new names carry `two_level` /
`three_level_ttype` so that none of them collides with a legacy file.

Folder layout:

```
semiconductors_bridges/
├── half_bridge/          6 libraries + README (device numbering, ports)
├── full_bridge/          6 libraries + README
├── three_phase_bridge/   6 libraries + README
├── test/                 test_semiconductors_bridges.slx + param/run scripts + README
├── tools/                Python generator of the 18 libraries and of the test model
└── *.slx                 23 legacy models (unchanged, to be removed once modelization-and-control
                          has been moved to the new bridges)
```

## Common interface

### Ports

| Port            | Kind                 | Side  | Notes                                                                 |
|-----------------|----------------------|-------|-----------------------------------------------------------------------|
| `gate_commands` | Simulink bus in      | left  | from the PWM modulators of [`../modulators`](../modulators), see below |
| `m`             | Simulink bus out     | right | measurements, flat bus, element names below                           |
| `udc(+)`        | electrical           | left  | LConn1                                                                 |
| `np`            | electrical           | left  | LConn2, T-type only: dc-link midpoint (neutral point)                 |
| `udc(-)`        | electrical           | left  | LConn2 (two-level) or LConn3 (T-type)                                 |
| `u` / `uac(+)`, `uac(-)` / `u`, `v`, `w` | electrical | right | ac terminals: RConn1.. (half / full / three-phase)        |

No dc-link capacitor is included: connect the dc terminals to a source or to the dc link
blocks of [`../dclinks`](../dclinks) (`dclink_for_two_levels`, `dclink_for_three_levels`, whose
midpoint goes to `np`).

### Device numbering and gate commands

Two-level legs: the upper device (collector/drain on `udc(+)`) has the odd number, the lower
one the even number. T-type legs have four devices numbered Q1..Q4, Q5..Q8, Q9..Q12 in leg order:

| T-type device | Position                                          | Leg state when on       |
|---------------|---------------------------------------------------|-------------------------|
| Q1            | `udc(+)` → midpoint (collector on `udc(+)`)       | P (with Q2)             |
| Q2            | `np` → common emitter (collector on `np`)         | O (with Q3)             |
| Q3            | midpoint → common emitter (collector on midpoint) | O (with Q2)             |
| Q4            | midpoint → `udc(-)` (collector on midpoint)       | N (with Q3)             |

Q2 and Q3 are in anti-series with common emitter (source); Q2 is on the `np` side. The same
convention is used by `foundation/pwr_electronics/+ideal_bridges`, by the three-level modulators
(Q1/Q3 and Q2/Q4 complementary) and by `afe_single_phase_ttype`.

| Bridge                        | Modulator (`../modulators`)                              | Bus elements read from `gate_commands`                                        |
|-------------------------------|----------------------------------------------------------|-------------------------------------------------------------------------------|
| `half_bridge_*`               | `half_bridge_PWM_generator_with_TRGO`                    | `gate_cmd_Q1`, `gate_cmd_Q2`                                                  |
| `full_bridge_*`               | `single_phase_pwm_modulator`                             | `gate_cmd_Q1..Q4` (Q1/Q2 leg `uac(+)`, Q3/Q4 leg `uac(-)`)                    |
| `three_phase_bridge_*`        | `three_phase_pwm_modulator`                              | `gate_cmd_Q1..Q6` (Q1/Q2 u, Q3/Q4 v, Q5/Q6 w)                                 |
| `half_bridge_ttype_*`         | `single_phase_three_levels_PWM_modulator`, sub-bus `gate_cmds_ph1` | `cmd_gate_Q1..Q4`                                                   |
| `full_bridge_ttype_*`         | `single_phase_three_levels_PWM_modulator`                | `gate_cmds_ph1.cmd_gate_Q1..Q4` → Q1..Q4, `gate_cmds_ph2.cmd_gate_Q1..Q4` → Q5..Q8 |
| `three_phase_bridge_ttype_*`  | `three_phase_three_levels_PWM_modulator`                 | `gate_cmds_phu/phv/phw.cmd_gate_Q1..Q4` → Q1..Q4 / Q5..Q8 / Q9..Q12            |

The gate commands are the voltages produced by the modulators (`pos_cmd_gate` / `neg_cmd_gate`,
typically +15 / −10 V). The ideal switch closes when the command is above `Vth`, the MOSFET when
it is above `G_th` (default 0.5, so 0/1 logic works as well), the IGBT reads the command in volts
against `Vth_gate_m` with the hysteresis `Vth_gate_hyst_m`.

### Measurement bus `m`

Flat bus, one group of elements per device k:

| Family            | Elements per device k                                                                                                              |
|-------------------|------------------------------------------------------------------------------------------------------------------------------------|
| ideal switch      | `switch_current_Qk` [A], `switch_voltage_Qk` [V]                                                                                   |
| igbt_simple_2th   | `igbt_current_Qk` [A], `igbt_voltage_Qk` [V], `igbt_ploss_Qk` [W], `igbt_JH_temp_Qk` [K], `igbt_HA_temp_Qk` [K], `diode_current_Qk` [A], `diode_ploss_Qk` [W], `diode_JH_temp_Qk` [K], `diode_HA_temp_Qk` [K] |
| mos_simple_2th    | as above with `mosfet_` instead of `igbt_`                                                                                         |

Conventions: the ideal switch current is the terminal current from collector to emitter
(negative when the diode conducts); for the 2th devices `*_current` is the transistor current
and `diode_current` the diode current, both positive when conducting; `*_voltage` is the
collector-emitter (drain-source) voltage; `*_ploss` is the dissipated power of the die (output
`Pt` / `Pd` of the component, already averaged by `time_constant_ploss_m`); `*_JH_temp` is the
junction-to-heatsink temperature difference and `*_HA_temp` the heatsink-to-ambient one, both in
kelvin (add them to `Tambient_m` for the junction temperature).

### Inside a cell

Every device is a subsystem `Qk` (full copy, no links inside the library) with the Simulink
gate input, the two electrical terminals and the measurement outputs:

- **ideal switch**: `Switch` (R_closed = `Rds_on`, threshold `Vth`), antiparallel `Diode`
  (`Vdon_diode`, `Rdon_diode`, Goff = 1e-8 S), `Capacitor` with series resistance as RC snubber
  (`Csnubber`, `Rsnubber`), current sensor on the collector, voltage sensor across the device.
- **2th devices**: the component, the RC snubber and the voltage sensor across the terminals;
  each thermal port (`Ht` transistor die, `Hd` diode die) drives

  ```
  H ──┬── Cj = JunctionTermalMass_m ──┐
      └── Rth_JH ──┬── C_hs = mass_heatsink_m·specific_heat_m
                   └── Rth_HA ── Tambient_m
  ```

  with two Temperature Sensors in difference mode (`*_JH_temp`, `*_HA_temp`). Each die has its
  own heatsink mass and `Rth_HA`: for N dies on one heatsink of mass M and resistance R_HA use
  `mass_heatsink_m = M/N` and `rth_*_HA_m = N·R_HA`. The mass parameters are per die, the
  junction mass is given in J/K (`JunctionTermalMass_m`) and converted internally.

### Solver settings

As in the models of `modelization-and-control`: a *Solver Configuration* per network with *Use
local solver* on, Backward Euler, sample time equal to the modulator `tc` (1 µs for 10 kHz PWM),
fixed-cost iterations on; global solver ode23tb.

**Nonlinear iterations.** 3–5 are enough for the two-level bridges, where one diode turns on per
commutation. In a T-type leg a commutation flips two diodes within one step: for a positive output
current at the P→O transition the third-quadrant diode D3 (through Q2) and the outer diode D4 both
see a hugely negative voltage in the first evaluation and turn on, then D4 turns off again; the
same happens with D1 and D2 for a negative current at O→N. The if/else branches of the devices are
re-evaluated inside the fixed-cost nonlinear iterations, so with 5 iterations the step is accepted
with inconsistent modes and kA of spurious current flow through a diode for one step. The
ideal-switch and IGBT cells do not stop on it (the IGBT events use absolute values), but the step
is wrong for every family; `mos_simple_2th` turns the negative held diode current into a negative
recovery energy and the junction temperature of the die falls below 0 K ("Temperature must be
greater than absolute zero" from the junction *Thermal Mass*, about 1 ms into the simulation).
**Use 20 nonlinear iterations for the T-type bridges** (verified with the test bench on
2026-10-31: 10, 20 and 50 pass, 5 fails; 20 keeps a margin for the steps in which two legs
commutate together) or switch fixed-cost off. The *Mode iterations* setting (default 2) did not
need to change.

## Mask parameters

### Ideal switch bridges

| Parameter    | Meaning                                                  | Unit | Default |
|--------------|----------------------------------------------------------|------|---------|
| `Rds_on`     | on-state resistance of the switch                         | Ohm  | 1.85e-3 |
| `Vdon_diode` | diode forward voltage                                     | V    | 0.35    |
| `Rdon_diode` | diode on-state resistance                                 | Ohm  | 1.85e-3 |
| `Csnubber`   | RC snubber capacitance                                    | F    | 6e-9    |
| `Rsnubber`   | RC snubber resistance                                     | Ohm  | 3e3     |
| `Vth`        | gate threshold (switch closed when the command is above it) | –  | 7.5     |

### igbt_simple_2th bridges (defaults: Infineon FF450R17ME4 at 125 °C)

| Parameter               | Component parameter | Meaning                                              | Unit  | Default |
|-------------------------|---------------------|------------------------------------------------------|-------|---------|
| `vce_sat_m`             | `Vce_sat`           | collector-emitter on-state voltage (knee)            | V     | 0.96    |
| `rce_on_m`              | `Ron`               | on-state series resistance (slope)                   | mOhm  | 3.05    |
| `v_gamma_m`             | `Vf`                | diode forward voltage (knee)                         | V     | 0.90    |
| `rd_on_m`               | `Rd`                | diode series resistance (slope)                      | mOhm  | 2.15    |
| `Gce_off_m`             | `Goff`              | off-state conductance                                | 1/Ohm | 1e-6    |
| `Vth_gate_m`            | `Vth`               | gate-emitter threshold voltage                       | V     | 5.8     |
| `Vth_gate_hyst_m`       | `Vhyst`             | half hysteresis band of the switching events         | V     | 0.85    |
| `Eon_m`, `Eoff_m`, `Err_m` | `Eon_ref`, `Eoff_ref`, `Err_ref` | switching energies at `Ic_ref_m`, `Vdc_ref_m` | mJ | 135, 155, 110 |
| `Ic_ref_m`, `Vdc_ref_m` | `Ic_ref`, `Vdc_ref` | reference current and voltage of the energies        | A, V  | 450, 900 |
| `Vblock_Errf_m`         | `V_rr_th`           | blocking detection level for the Err event           | V     | 50      |
| `time_constant_edge_m`  | `tau_s`             | sample & hold time constant (≪ on-time)              | us    | 1       |
| `time_constant_ploss_m` | `tau_p`             | loss averaging time constant (2–5 × Tsw)             | us    | 200     |
| `Csnubber_m`, `Rsnubber_m` | –                | RC snubber across each device (numerical)            | F, Ohm | 12e-12, 2200 |
| `rth_switch_JH_m`, `rth_switch_HA_m` | –      | thermal resistances of the IGBT die                  | K/W   | 0.093, 0.05 |
| `rth_diode_JH_m`, `rth_diode_HA_m` | –        | thermal resistances of the diode die                 | K/W   | 0.152, 0.05 |
| `JunctionTermalMass_m`  | –                   | junction thermal mass of each die                    | J/K   | 0.81    |
| `Tambient_m`            | –                   | ambient temperature (also initial temperature)       | degC  | 40      |
| `mass_heatsink_m`, `specific_heat_m` | –      | heatsink mass per die and specific heat              | kg, J/(K kg) | 1, 900 |

The parameter names are those of the IGBT cells already used in the `modelization-and-control`
models (`afe_inv_psm_param`), so the existing `param.*.igbt` structs map one to one.

### mos_simple_2th bridges (defaults: Wolfspeed CAB450M12XM3)

| Parameter               | Component parameter | Meaning                                                      | Unit  | Default |
|-------------------------|---------------------|--------------------------------------------------------------|-------|---------|
| `rds_on_m`              | `Rds_on`            | on-state resistance at `Tj_ref_m`                            | mOhm  | 2.6     |
| `alpha_R_m`             | `alpha_R`           | Rds_on temperature coefficient (0 = no electrothermal loop)  | 1/K   | 0       |
| `Tj_ref_m`              | `Tj_ref`            | reference junction temperature of Rds_on                     | degC  | 125     |
| `Roff_m`                | `Roff`              | off-state resistance                                         | Ohm   | 1e7     |
| `v_gamma_m`, `rd_on_m`  | `Vf`, `Rd`          | diode knee voltage and differential resistance               | V, mOhm | 4.5, 0.185 |
| `two_die_m`             | `two_die`           | 1 = separate diode die (losses to Hd), 0 = body diode (to Ht) | –    | 0       |
| `G_th_m`                | `G_th`              | gate threshold                                               | –     | 0.5     |
| `Eon_m`, `Eoff_m`, `Err_m` | `Eon_ref`, `Eoff_ref`, `Err_ref` | switching energies at `Ic_ref_m`, `Vdc_ref_m`     | mJ    | 24, 8, 1.1 |
| `Ic_ref_m`, `Vdc_ref_m` | `Iref`, `Vref`      | reference current and voltage of the energies                | A, V  | 450, 600 |
| `ki_m`, `kv_m`          | `ki`, `kv`          | current and voltage exponents of the energy scaling          | –     | 1, 1    |
| `Vth_off_m`, `Vth_on_m` | `Vth_off`, `Vth_on` | turn-off/recovery and turn-on detection thresholds           | V     | 50, 25  |
| `V_sm_m`                | `V_sm`              | smoothing width of the blocking detector                     | V     | 10      |
| `time_constant_edge_m`  | `tau_s`             | sample-and-hold time constant (≪ dead time)                  | us    | 0.1     |
| `tau_v_m`               | `tau_v`             | blocking voltage estimator time constant                     | us    | 10      |
| `time_constant_ploss_m` | `tau_p`             | energy-to-power lag (2–5 × Tsw)                              | us    | 200     |
| `i_eps_m`               | `i_eps`             | current smoothing                                            | A     | 1e-3    |
| `Csnubber_m`, `Rsnubber_m` and the eight thermal parameters | – | as for the IGBT bridges (`rth_*_JH_m` 0.116 K/W, `JunctionTermalMass_m` 0.2 J/K) | | |

With `two_die_m = 0` the diode outputs of `m` stay at zero and the diode thermal parameters are
unused (the port `Hd` is still connected, as the component requires).

## Test bench

[`test/test_semiconductors_bridges.slx`](test) instantiates the 18 bridges, each with its dc
supply, R-L load, sensors and local solver, in five groups, one per modulator (`modulator_hb`,
`modulator_1ph`, `modulator_3ph`, `modulator_1ph3L`, `modulator_3ph3L`); a group holds the
modulation sources, the modulator and the test cells it drives, so a whole group can be commented
out to shorten a run. `test_semiconductors_bridges_run.m` simulates it and checks the fundamental
of the load current and voltage of every bridge against the modulation, plus losses and
temperature rises of the 2th bridges. See [`test/README.md`](test/README.md).

## Regeneration

The libraries and the test model are written by the Python scripts in [`tools/`](tools)
(`python3 tools/generate_bridges.py`, `python3 tools/generate_test_model.py`,
`python3 tools/check_slx.py <files>`), without MATLAB: `slxlib.py` writes the `.slx` package
(block diagram XML, systems, relationships, the binary parts copied byte by byte from files saved
by Simulink R2026a), `sscblocks.py` holds the Simscape block definitions. Simulink opens the
generated files directly; saving from Simulink rewrites them in its canonical form. Edit the
generator and regenerate rather than editing 18 files by hand.

## Legacy models in the folder root

Before October 2026 the folder held 23 models that mixed four device technologies (Foundation
ideal switch, Simscape Electrical IGBT/MOSFET/Diode with thermal ports, `igbt_simple`) and five
topologies. They are **kept unchanged in the folder root** because about 20 models of
`modelization-and-control` link them (table in the next section); they will be removed once
those models have been moved to the new bridges. Do not use them for new work. Correspondence:

| Legacy file                                                         | Devices                                                                | New bridge                                                      |
|---------------------------------------------------------------------|------------------------------------------------------------------------|-----------------------------------------------------------------|
| `full_bridge_ideal_switch.slx`                                      | Foundation switch + diode + snubber                                    | `full_bridge/full_bridge_two_level_ideal_switch`                |
| `three_phase_inverter_ideal_switch_based_model.slx`                 | Foundation switch + diode + snubber                                    | `three_phase_bridge/three_phase_bridge_two_level_ideal_switch`  |
| `full_bridge_three_level_ttype_ideal_switch_based_model.slx`        | Foundation switch + diode (dc ports on the right)                      | `full_bridge/full_bridge_three_level_ttype_ideal_switch`        |
| `three_phase_three_level_ttype_inverter_ideal_switch_based_model.slx` | Foundation switch + diode (dc ports on the right)                    | `three_phase_bridge/three_phase_bridge_three_level_ttype_ideal_switch` |
| `full_bridge_igbt_based_with_thermal_model.slx`                     | Simscape Electrical `IGBT (Ideal, Switching)`                          | `full_bridge/full_bridge_two_level_igbt_simple_2th`             |
| `full_bridge_igbt_based_with_advanced_thermal_model.slx`            | Simscape Electrical IGBT + Diode with reverse recovery                 | `full_bridge/full_bridge_two_level_igbt_simple_2th`             |
| `full_bridge_mosfet_based_with_thermal_model.slx`, `_zvs`           | Simscape Electrical `MOSFET (Ideal, Switching)`                        | `full_bridge/full_bridge_two_level_mos_simple_2th`              |
| `three_phase_inverter_igbt_based_with_thermal_model.slx`            | Simscape Electrical IGBT                                               | `three_phase_bridge/three_phase_bridge_two_level_igbt_simple_2th` |
| `three_phase_inverter_igbt_advanced_thermal_model.slx`              | Simscape Electrical IGBT + Diode                                       | `three_phase_bridge/three_phase_bridge_two_level_igbt_simple_2th` |
| `three_phase_inverter_mosfet_based_with_thermal_model.slx`, `_zvs`  | Simscape Electrical MOSFET                                             | `three_phase_bridge/three_phase_bridge_two_level_mos_simple_2th` |
| `three_phase_inverter_with_igbt_simple.slx`                         | `igbt_simple` (single thermal port)                                    | `three_phase_bridge/three_phase_bridge_two_level_igbt_simple_2th` |
| `full_bridge_three_level_ttype_igbt_based_model.slx`                | Simscape Electrical IGBT                                               | `full_bridge/full_bridge_three_level_ttype_igbt_simple_2th`     |
| `full_bridge_three_level_ttype_mosfet_based_model.slx`              | Simscape Electrical MOSFET                                             | `full_bridge/full_bridge_three_level_ttype_mos_simple_2th`      |
| `three_phase_inverter_three_level_ttype_igbt_based_model.slx`       | Simscape Electrical IGBT + Diode                                       | `three_phase_bridge/three_phase_bridge_three_level_ttype_igbt_simple_2th` |
| `full_bridge_three_level_npc_{ideal_switch,igbt,mosfet}_based_model.slx` | NPC topology, outside the matrix (not linked by any model)        | none                                                            |
| `vienna_rectifier_ideal_switch_based_model.slx`                     | Vienna rectifier, outside the matrix                                   | none                                                            |
| `full_bridge_diode_rectifier.slx`, `three_phase_diode_rectifier.slx`, `three_phase_diode_rectifier_with_thermal_model.slx` | passive rectifiers, outside the matrix | none (gate a bridge off, or the diodes of `foundation/semiconductors`) |

New with the matrix: the six half bridges, the T-type MOSFET three-phase bridge and all the
`*_2th` versions.

### Moving the models of `modelization-and-control`

Nothing breaks now: the legacy libraries are still on the path. The models that link them, from
a scan of the repository on 2026-10-31, are:

| Legacy library                                               | Linking models                                                                                                                                                                                                                 |
|--------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `full_bridge_ideal_switch`                                   | battery_single_phase_inverter/ps_full_bridge, dcdc_zvs_full_bridge, ps_25V_12kA_r, ps_isop_rail, ps_isop_rail_bid, single_phase_inverter (+ `_param`), single_phase_dab, single_phase_cllc (+ `_param`)                       |
| `three_phase_inverter_ideal_switch_based_model`              | afe_inv_loopback, afe_inv_psm (+ `_param`), afe_inv_psm_n, afe_inv_psm (for_home), inv_im (+ `_param`), inv_psm, afe_inv_psm_with_hf_models, mpc_psm, ps_25V_12kA_r, three_phase_dab, grid_afe_n                              |
| `three_phase_inverter_igbt_advanced_thermal_model`, `three_phase_inverter_mosfet_based_with_thermal_model`, `three_phase_inverter_igbt_based_with_thermal_model` | the same afe_inv_psm / inv_im / inv_psm / mpc_psm / ps_25V_12kA_r / three_phase_dab / grid_afe_n family (thermal variants)                           |
| `full_bridge_mosfet_based_with_thermal_model` (+ `_zvs`), `full_bridge_igbt_based_with_thermal_model`, `full_bridge_igbt_based_with_advanced_thermal_model` | dcdc_zvs_full_bridge, ps_25V_12kA_r, single_phase_inverter (+ `_param`), single_phase_dab, single_phase_cllc (+ `_param`)                   |
| `full_bridge_three_level_ttype_{ideal_switch,mosfet}_based_model` | single_phase_afe_ttype, single_phase_ttype_inverter (+ `_param`)                                                                                                                                                          |
| `three_phase_three_level_ttype_inverter_ideal_switch_based_model`, `three_phase_inverter_three_level_ttype_igbt_based_model` | afe_dq_ttype, afe_inv_ttype_psm, mpc_ttype_psm                                                                                                                 |
| `full_bridge_diode_rectifier`, `three_phase_diode_rectifier` (+ `_with_thermal_model`) | dcdc_zvs_full_bridge, ps_isop_rail, ps_isop_rail_bid, single_phase_inverter (+ `_param`), single_phase_ttype_inverter (+ `_param`)                                               |
| `vienna_rectifier_ideal_switch_based_model`                  | vienna_rectifier                                                                                                                                                                                                               |

What changes when a model is moved to the new bridges: the library and block names (table
above); for the T-type bridges the dc ports
are now on the left (`udc(+)`, `np`, `udc(-)`) and the ac ports on the right; the `m` bus
element names (`switch_*` instead of `ideal_switch_*`, flat `igbt_*_Qk` / `mosfet_*_Qk` /
`diode_*_Qk` instead of `module_k.*`); the thermal mask parameters follow the `igbt_simple_2th`
cell set (`vce_sat_m`, `Eon_m` in mJ, ...) instead of the Simscape Electrical set (`Vce_sat_m`,
`Eon_m` in J, `Irr_m`, `Lstray_module_m`, `Cies_m`, `tc_m`, `DThs_init_m`). Models that only
need an ideal bridge can alternatively use the single-component bridges of
`foundation/pwr_electronics/+ideal_bridges`.

## Revision history

| Rev. | Date       | Notes                                                                                   |
|------|------------|-----------------------------------------------------------------------------------------|
| 01   | 2026-10-31 | 18 generated libraries in three subfolders, test bench, this README                      |
| 02   | 2026-10-31 | Names `*_two_level_*` / `*_three_level_ttype_*`; the 23 legacy models stay in the folder root; test grouped per modulator; T-type cells with 20 nonlinear iterations (`tb.nonlin_iter_ttype`), solver notes |
