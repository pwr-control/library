# AFE blocks with LCL filter — `afe_ssc` and `afe_ttype_ssc` (Simscape language)

Packages `+afe_ssc` and `+afe_ttype_ssc`, folder `foundation/pwr_electronics`. Rev. 00, 2026-11-02.

Four Simscape components. Each one is the whole power stage of a three-phase active front end
(AFE) in **one block**: bridge, DC link and LCL filter, gate commands in as one physical-signal
vector, measurements out in pu as one vector. One converter then counts as one nonvirtual block
(MATLAB Home licence: at most 1000 nonvirtual blocks per model, referenced models and library
links included).

| File | Package | Block name in the library | Bridge | Filter capacitors | DC ports | `G` | `M` |
|------|---------|---------------------------|--------|-------------------|----------|-----|-----|
| `afe_two_level_lcl.ssc` | `afe_ssc` | AFE Two-Level Bridge with LCL Filter | two-level, 6 switches | star, floating star point | `+`, `-` | [6x1] | [17x1] |
| `afe_two_level_lcl_delta.ssc` | `afe_ssc` | AFE Two-Level Bridge with LCL Filter, Delta Capacitors | two-level, 6 switches | delta | `+`, `-` | [6x1] | [17x1] |
| `afe_three_level_ttype_lcl.ssc` | `afe_ttype_ssc` | AFE Three-Level T-Type Bridge with LCL Filter | three-level T-type, 12 switches | star, floating star point | `+`, `np`, `-` | [12x1] | [22x1] |
| `afe_three_level_ttype_lcl_delta.ssc` | `afe_ttype_ssc` | AFE Three-Level T-Type Bridge with LCL Filter, Delta Capacitors | three-level T-type, 12 switches | delta | `+`, `np`, `-` | [12x1] | [22x1] |

`afe_two_level_lcl` is the power stage of the masked blocks `grid_forming_dqctrl` and
`grid_following_dqctrl` (`masked_models/grid_forming`, `masked_models/grid_following`). The other
three were added in November 2026. `afe_ttype_ssc` also holds `afe_single_phase_ttype` (single-phase
T-type AFE with LC filter, see `foundation/README.md`). `onoff.m` in each package is the enumeration
of the `cap_dc` parameter (`afe_ssc.onoff`, `afe_ttype_ssc.onoff`, members `off` and `on`); it must
stay in the package folder.

The block name in the library is the first comment line after `component` in the `.ssc` file. The
masks link to the block `AFE Two-Level Bridge with LCL Filter` of `afe_ssc_lib`, so that line of
`afe_two_level_lcl.ssc` must not change.

## What changed in `afe_two_level_lcl` (November 2026)

Only the measurement vector: `M` is now [17x1] instead of [14x1]. `M(1:14)` are unchanged,
`M(15:17)` are the three filter capacitor currents. Effects:

- `grid_forming_dqctrl` and `grid_following_dqctrl`: no change needed. Their control (MATLAB
  Function) takes `M` with inherited size and reads it by index (`M(1:13)`), and the Unit Delay of
  the measurements has a scalar initial condition. Their output `m` is now [17x1].
- A model that splits `m` (or `M`) with a Demux of 14 outputs must be changed to 17 outputs, or use
  a Selector.
- `afe_ssc_lib.slx` must be rebuilt (see [Build](#build)).

## Ports and parameters

All four blocks: AC terminals `a`, `b`, `c` and gate input `G` on the left, DC terminals and
measurement output `M` on the right. The star and the delta block of each pair have the same ports,
the same parameter names and the same layout of `M`, so they can be swapped in a model (with the
capacitor values converted, see [Star and delta](#star-and-delta)).

| Group | Parameters | Notes |
|-------|------------|-------|
| Switches | `Vth`, `Ron`, `Goff` | gate threshold 2.5 V, 1 mOhm, 1 uS: ideal switches, no losses |
| DC link (two-level) | `cap_dc`, `Cdc`, `Rdc` | 7.2 mF, 2 mOhm; `cap_dc = off` removes the capacitor (external DC link or ideal source) |
| Split DC link (T-type) | `cap_dc`, `Cdc1`, `Rdc1`, `Cdc2`, `Rdc2`, `Vdc0` | 2 x 14.4 mF, 2 x 1 mOhm (the 7.2 mF / 2 mOhm of the two-level block split in two banks); `Vdc0/2` on each bank at the start |
| Converter-side inductor | `L1p`, `L10`, `R1`, `Lls1` | positive- and zero-sequence inductance, series resistance, leakage |
| Filter capacitors | `Cf`, `Rcf` | star: 360 uF, 50 mOhm per phase; delta: 120 uF, 150 mOhm per branch |
| Grid-side inductor | `L2p`, `L20`, `R2`, `Lls2` | as the converter side |
| Normalization | `ubez`, `ibez`, `udc_nom` | 326.6 V, 566.7 A (peak phase values), 660 V |

The inductors use the equations of `threephase_inductor.ssc` (`Lm = (Lp - L0)/3`,
`La = (L0 + Lp + Lm)/2`; positive sequence `Lp + Lls`, zero sequence `L0 + Lls`). With the defaults
`L1 = L1p + Lls1 = 336 uH`, `L2 = L2p + Lls2 = 85 uH` and 360 uF in star the filter resonates at
`f_res = 1/(2*pi)*sqrt((L1 + L2)/(L1*L2*Cf)) = 1.02 kHz`.

Switch + antiparallel diode pair (current `i`, voltage `v` from collector to emitter): gate on
(`G(k) > Vth`) `i = v/Ron`; gate off and `v < 0` `i = v/Ron` (diode); gate off and `v >= 0`
`i = v*Goff`. No dead time and no interlock inside the blocks: they belong to the modulator.
Drive the gates with +15 V / -10 V.

Initial conditions: the two-level blocks impose none (the inductor currents and the capacitor
voltages have priority none: set them in the Variables tab, or use "Start simulation from steady
state" of the Solver Configuration). The T-type blocks start with `Vdc0/2` on each bank when
`cap_dc = on`.

## Measurement vector `M` (pu)

Currents on `ibez`, AC voltages on `ubez`, DC voltages on `udc_nom`.

| Index | Star blocks | Delta blocks |
|-------|-------------|--------------|
| `M(1:3)` | converter-side inductor currents `i1_abc`, positive out of the bridge | same |
| `M(4:6)` | filter capacitor voltages, capacitor node to star point | capacitor node voltages without zero sequence, `uc_a = vk_a - (vk_a + vk_b + vk_c)/3`: the voltages of the equivalent star (the delta capacitor voltages are `uc_a - uc_b`, ...) |
| `M(7:9)` | grid-side inductor currents `i2_abc`, positive towards the grid | same |
| `M(10:12)` | grid terminal voltages without zero sequence, `ug_a = (2*va - vb - vc)/3` | same |
| `M(13)` | DC-link voltage `vdc = (+) - (-)` | same |
| `M(14)` | DC-link capacitor current, `(+)` to `(-)` (T-type: mean of the two banks, `(ic1 + ic2)/2`) | same |
| `M(15:17)` | **filter capacitor currents** `icf_a, icf_b, icf_c`, capacitor node to star point; `= i1 - i2` of the same phase, the three add up to zero | **delta capacitor currents** `icf_ab, icf_bc, icf_ca`; `icf_ab` flows from node a to node b through the capacitor between a and b. The current from line a into the capacitor bank is `icf_ab - icf_ca = i1_a - i2_a` |
| `M(18)` | T-type only: upper bank voltage `vdc1 = (+) - np` | same |
| `M(19)` | T-type only: lower bank voltage `vdc2 = np - (-)` (`M(18) - M(19)` is the neutral-point unbalance) | same |
| `M(20)` | T-type only: neutral-point current `i_np`, from the three legs into `np` | same |
| `M(21)` | T-type only: upper bank current `ic1`, `(+)` to `np` | same |
| `M(22)` | T-type only: lower bank current `ic2`, `np` to `(-)` | same |

With `cap_dc = off`, `M(14)`, `M(21)` and `M(22)` are zero.

## Star and delta

Seen from the capacitor nodes, a delta of `Cf` and `Rcf` per branch is exactly the same filter as a
star of `3*Cf` and `Rcf/3` per phase (at every frequency and in transients). The delta defaults
(120 uF, 150 mOhm) are the delta equivalent of the star defaults (360 uF, 50 mOhm): same resonance,
same currents and voltages at the terminals. To move a model from a star block to the delta block:
**divide `Cf` by 3 and multiply `Rcf` by 3**.

- Each delta capacitor sees the line-to-line voltage (`sqrt(3)` times the phase voltage) and carries
  `1/sqrt(3)` of the capacitive line current, leading it by 30 deg. Same reactive power with one
  third of the capacitance at `sqrt(3)` times the voltage.
- `Rcf` must be greater than zero in the delta blocks: the three capacitors form a loop and `Rcf`
  sets the current that circulates in it (zero in normal operation; a circulating current from
  initial voltages that do not add up to zero decays with `Rcf*Cf`).
- Neither the floating star nor the delta carries zero-sequence current from the lines.

## T-type blocks

Each leg has four switch + antiparallel diode pairs, numbered as in `ideal_bridges`,
`afe_single_phase_ttype` and the T-type blocks of `masked_models/semiconductors_bridges`:

| Switch | Position | Leg midpoint when on |
|--------|----------|----------------------|
| Q1 | between `+` and the midpoint m (collector on `+`) | `+` |
| Q4 | between m and `-` (collector on m) | `-` |
| Q2, Q3 | anti-series, common emitter, between `np` and m (Q2 collector on `np`, Q3 collector on m) | `np` (both on) |

Gate vector `G = [Q1a; Q2a; Q3a; Q4a; Q1b; ...; Q4c]` [12x1], the order of `gate_cmds_phu/phv/phw`
of the library modulator `three_phase_three_levels_PWM_modulator` (as
`ideal_bridges.three_phase_bridge_ttype`). States: `P = {Q1, Q2}`, `O = {Q2, Q3}`,
`N = {Q3, Q4}`; Q1/Q3 and Q2/Q4 are the complementary pairs. Destructive patterns (no interlock in
the block): Q1 + Q4 short the DC link through `2*Ron`, Q1 + Q3 short the upper bank and Q2 + Q4 the
lower bank through `3*Ron` (via the diodes of Q2 / Q3).

- **`np` is always a port.** With `cap_dc = on` leave it open (the two banks define it). With
  `cap_dc = off` connect `+`, `np` and `-` to an external split DC link (another T-type block with its
  capacitors on, or `dclink_for_three_levels`).
- With an ideal source across `+` and `-`, set `Vdc0` to its voltage; the series resistances keep
  the two bank voltages as separate states.
- `M(1:17)` mean the same as in the two-level blocks, so a control written for
  `afe_two_level_lcl` can read the T-type `M(1:13)` unchanged (the modulator is different).
- Driven with two-level patterns (P and N only), a T-type block gives the waveforms of the two-level
  block with the same filter (checked to 1e-6 pu).

## Build

The files were written without MATLAB. Build both packages from this folder and commit the two
libraries:

```matlab
cd library/foundation/pwr_electronics
ssc_build afe_ssc          % -> afe_ssc_lib.slx: afe_two_level_lcl, afe_two_level_lcl_delta
ssc_build afe_ttype_ssc    % -> afe_ttype_ssc_lib.slx: afe_single_phase_ttype + the two LCL T-type blocks
```

The blocks use the constructs of the existing `afe_two_level_lcl` and `ideal_bridges` T-type blocks
(vector physical-signal ports, parametric `if` on `cap_dc`, dynamic `if` for the switches,
`equations (Initial = true)` and hidden parameters inside `if cap_dc == ...on`, intermediates).

Simulation: the checks below use backward Euler at 0.625 us, the step of the models. If the local
solver stops at a switching instant of a T-type block (two diodes changing state in the same step),
raise the nonlinear iterations of the Solver Configuration (the T-type blocks of
`semiconductors_bridges` need 10 or more).

## Checks

`check_afe_lcl.py` (python3 + numpy, no Simscape; output in `check_afe_lcl_output.txt`, 272 checks,
about 40 s):

```bash
python3 check_afe_lcl.py                     # exit code 0 if all checks pass
python3 check_afe_lcl.py --png figure.png    # also a figure of the waveforms (needs matplotlib)
```

- **A. structure.** For `cap_dc = on` and `off`: number of equations = variables + outputs, number
  of equations with `der()` = differentiated variables (a rule `ssc_build` does not check when the
  structure depends on a parameter `if`), same number of equations in both branches of every switch
  `if`; gate indices, branches, port sides, dialog groups, hidden parameters, size of `M`; star and
  delta of each pair with the same ports, parameters and `M`; delta defaults equal to the star
  defaults converted; block name of `afe_two_level_lcl` unchanged.
- **B. the `.ssc` equations against an independent circuit simulation.** The same circuit (switches
  as `Ron`/`Goff` with the diode condition, coupled three-phase inductors, filter capacitors in star
  or delta, DC link, 400 V grid, 700 V DC source) solved by modified nodal analysis with backward
  Euler at 0.625 us, sine-triangle PWM at 4 kHz with 2 us dead time, `i2 = 0.5 pu`,
  `L0 = 0.5*Lp` so that the mutual terms of the inductors count. At every step all the equations
  of each `.ssc`, translated to numpy, are evaluated on the circuit solution: worst residual about
  1e-10 of the scale; port currents and every element of `M` (the new `M(15:17)` included) equal to
  the circuit quantities. Two cases per block: `cap_dc = on` with `np` open, and `cap_dc = off`
  with the DC link outside and a path to ground that drives zero-sequence current through the
  filter. Ten deliberate errors written into copies of the `.ssc` (two rows of `M` swapped, wrong
  sign of a mutual-inductance term or of a node equation, a branch reversed, two gate indices
  swapped, the neutral branch on the wrong node, ...) were all detected (done once while writing
  the script, not part of it).
- **C. physics.** Star and delta blocks with the converted capacitors give the same currents and
  voltages (difference about 1e-13 pu); fundamentals of `i1`, `i2`, capacitor voltages and currents
  within 0.1 % of the phasor model of the LCL filter; delta capacitor currents `1/sqrt(3)` of the
  star ones and 30 deg ahead; bridge voltage `m*vdc/2` minus the dead-time error
  (`(4/pi)*td*fpwm*vdc` two-level, half of it T-type); T-type: three levels, neutral-point current
  averaged over a carrier period equal to `sum(|m_x|*i1_x)`, the 150 Hz unbalance `vdc1 - vdc2`
  equal to `-i_np*(1/(j*3*w*Cdc1) + Rdc1)` (about 10 V peak at 0.5 pu with 2 x 14.4 mF), and the
  two-level waveforms with two-level patterns.

## Limitations

- Ideal switches: no switching or conduction losses, no reverse recovery, no thermal ports. For
  losses use the bridges of `masked_models/semiconductors_bridges`.
- No dead time, no interlock and no neutral-point balancing inside the blocks.
- Not yet compiled in MATLAB at the time of writing (first `ssc_build` by the maintainer).
