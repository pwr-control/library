# ideal_bridges — functional two-level and three-level T-type bridges (Simscape language)

Package `+ideal_bridges`, folder `foundation/pwr_electronics`. Rev. 01, 2026-10-31.

Five behavioral Simscape components that model a complete converter as **one
Simulink block each**: switches, freewheeling diodes, optional DC-link
capacitor(s), optional AC series inductors and the basic measurements. Two
two-level bridges and three three-level T-type bridges. They are meant for
system-level simulations (control design, several converters in one model)
where the semiconductor detail is irrelevant and the block count matters
(MATLAB Home / Student: at most 1000 non-virtual blocks per model, referenced
models included).

| File                           | Block name (in `ideal_bridges_lib`)   | Levels | Switches | DC terminals | AC terminals | Gate vector |
|--------------------------------|----------------------------------------|--------|----------|--------------|--------------|-------------|
| `three_phase_bridge.ssc`       | Three-Phase Bridge (ideal)             | 2      | 6        | +, -         | a, b, c      | [6x1]       |
| `full_bridge.ssc`              | Full Bridge (ideal)                    | 2      | 4        | +, -         | a, b         | [4x1]       |
| `three_phase_bridge_ttype.ssc` | Three-Phase Bridge T-Type (ideal)      | 3      | 12       | +, np, -     | a, b, c      | [12x1]      |
| `full_bridge_ttype.ssc`        | Full Bridge T-Type (ideal)             | 3      | 8        | +, np, -     | a, b         | [8x1]       |
| `half_bridge_ttype.ssc`        | Half Bridge T-Type (ideal)             | 3      | 4        | +, np, -     | a            | [4x1]       |

`onoff.m` is the enumeration class (`ideal_bridges.onoff`, members `off`, `on`)
used by the on/off parameters; it must stay in the package folder.
`check_ideal_bridges_ttype.py` (python3 + numpy) checks the five `.ssc` files
without MATLAB, see [Checks](#checks); its output is in
`check_ideal_bridges_ttype_output.txt`.

All blocks are bidirectional: the same block works as inverter (DC -> AC) and
as active front end / rectifier (AC -> DC).

## Model

### Switch + antiparallel diode

Each switch + antiparallel diode pair is a piecewise-linear resistor with no
dynamics and no forward drop (`Vf = 0`). With `v` the collector-emitter
voltage and `i` the current in the same direction:

| Condition                     | Equation        | Meaning                        |
|-------------------------------|-----------------|--------------------------------|
| `G(k) > Vth`                  | `i = v/Ron`     | switch on (both directions)    |
| `G(k) <= Vth` and `v < 0`     | `i = v/Ron`     | antiparallel diode conducting  |
| `G(k) <= Vth` and `v >= 0`    | `i = v*Goff`    | blocking                       |

`Ron` and `Goff` are numerical values (defaults 1 mOhm and 1 uS); the model
has no conduction or switching losses to speak of. There is no dead time and
no interlock inside any block: dead time belongs to the modulator.

### Two-level legs

Upper switch between + and the leg midpoint, lower switch between the
midpoint and -. If both switches of a leg are on, the leg shorts the DC link
through `2*Ron`.

Implementation note: the leg midpoints are internal algebraic variables, not
nodes. The upper switch of leg a is declared as a branch `(+) -> a` and the
lower one as `a -> (-)`, so that the current leaving terminal a is
`i_a = i_ah - i_al` and the inductor equation is written between the midpoint
voltage `vm_a` and `a.v`.

### T-type legs

Each T-type leg has four switch + diode pairs, numbered as in the T-type
blocks of `masked_models/semiconductors_bridges` and in
`afe_ttype_ssc.afe_single_phase_ttype`:

| Switch | Position                                                    | Leg output when on |
|--------|-------------------------------------------------------------|--------------------|
| Q1     | between + and the midpoint m (collector on +)               | m = +              |
| Q4     | between m and - (collector on m)                            | m = -              |
| Q2, Q3 | anti-series, common emitter, between np and m (Q2 collector on np, Q3 collector on m) | m = np (both on) |

The three states of the modulation are `P = {Q1, Q2}`, `O = {Q2, Q3}` and
`N = {Q3, Q4}`; `Q1/Q3` and `Q2/Q4` are the complementary pairs. Because of
the antiparallel diodes, more patterns than Q1 + Q4 are destructive:

| Pattern (any other gate state) | Effect                                  | Path                 |
|--------------------------------|-----------------------------------------|----------------------|
| Q1 and Q4 on                   | whole DC link shorted through `2*Ron`   | Q1, Q4               |
| Q1 and Q3 on                   | upper bank shorted through `3*Ron`      | Q1, Q3, D2           |
| Q2 and Q4 on                   | lower bank shorted through `3*Ron`      | Q2, D3, Q4           |

With only one switch on (dead-time intervals of the modulation) the midpoint
is clamped by the diodes according to the current: with Q2 alone, a positive
current (out of the bridge) goes to np through Q2 + D3 and a negative one to
+ through D1; with Q3 alone, a negative current goes to np through Q3 + D2
and a positive one to - through D4. With all gates off the leg is a
three-level diode rectifier (D1, D4 and the anti-series pair, which blocks in
both directions).

Three-level carrier modulation of a leg with the reference `m` in [-1, 1]
and the carrier `c` in [0, 1] (the scheme of the library modulators
`single_phase_three_levels_PWM_modulator` / `three_phase_three_levels_PWM_modulator`
and of `afe_single_phase_ttype`):

| Reference | Always on | Switched                               | Off |
|-----------|-----------|----------------------------------------|-----|
| `m >= 0`  | Q2        | Q1 on while `c < m` (duty `m`), Q3 = not Q1 | Q4 |
| `m < 0`   | Q3        | Q4 on while `c < -m` (duty `-m`), Q2 = not Q4 | Q1 |

The midpoint then averages `m*Vdc/2` with respect to np (balanced banks).
Full bridge: leg a with `m`, leg b with `-m`, bridge voltage `m*Vdc` with
five levels. Three-phase: one reference per leg, five-level line voltages.
Neutral-point balancing (zero-sequence or redundant-state injection) is not
inside the block; the bank voltages are available on the output `V` for it.

Implementation note: as in the two-level blocks the midpoints and the
common-emitter nodes of the neutral pairs are internal variables. Q1 is
declared as a branch `(+) -> a`, Q4 as `a -> (-)` and the neutral pair as
`a -> np` carrying the current of Q3 (`= -i2` by the KCL of the common
emitter), so that the current leaving terminal a is `i_a = i1 - i4 - i3`.
The neutral point `np` is a node (port): the neutral branches of the legs and
the two capacitor banks meet there.

### Optional passives

Each with an on/off parameter; the related parameters are hidden when off.

- `cap_dc`, two-level blocks: DC-link capacitor `Cdc` between + and -,
  initial voltage `Vdc0`. Set it **off** when several bridges share one DC
  bus with a single external capacitor (two capacitors in parallel on the
  same nodes give dependent states) and when an ideal DC Voltage Source sits
  directly across + and - (same reason: the initial equation `vdc == Vdc0`
  would then conflict with the source).
- `cap_dc`, T-type blocks: split DC link, `Cdc1` + `Rdc1` from + to np and
  `Cdc2` + `Rdc2` from np to -, both at `Vdc0/2` at the start. The neutral
  point np is a port in any case:
  - `cap_dc = on`: the two banks define np; leave the port unconnected or use
    it to measure / to connect the neutral of a filter. The series
    resistances keep the two bank voltages independent states when an ideal
    DC Voltage Source sits across + and - (set `Vdc0` equal to its voltage
    to avoid the initial transient); with `Rdc1 = Rdc2 = 0` and a source
    across the link the two states would be dependent, as above.
  - `cap_dc = off`: connect np to the external split DC link, i.e. to
    `masked_models/dclinks/dclink_for_three_levels` or to another T-type
    block whose capacitors are on (back-to-back AFE + inverter on one split
    link: one block carries the capacitors, the other has `cap_dc = off`).
    With np left unconnected and `cap_dc = off` the neutral branch has no
    return path and the block degenerates to a two-level bridge.
- `ind_ac`: series inductor `L` with resistance `RL` on **each** AC terminal.
  Three-phase: `L` is the per-phase line inductance. Full bridge: the split is
  symmetric, so the total inductance in the a-load-b loop is `2*L` (enter half
  of the output inductor). Half bridge: `L` is the whole output inductor. The
  inductor currents are the states.

## Ports

| Port | Type                     | Side   | Blocks     | Description                                                      |
|------|--------------------------|--------|------------|------------------------------------------------------------------|
| +, - | electrical               | left   | all        | DC link                                                          |
| np   | electrical               | left   | T-type     | neutral point of the split DC link (between + and -)             |
| a b c / a b / a | electrical    | right  | all        | AC terminals (after the inductors)                               |
| G    | PS input, vector, V      | bottom | all        | gate commands, see the order below                               |
| I    | PS output, A             | top    | all        | terminal currents `[i_a; i_b; i_c]` / `[i_a; i_b]` / `i_a`, positive out of the bridge |
| V    | PS output, V             | top    | two-level  | DC-link voltage (+) - (-)                                         |
| V    | PS output, vector, V     | top    | T-type     | `[vdc; vdc1; vdc2]` = `[(+) - (-); (+) - np; np - (-)]`           |

Gate order:

| Block        | `G`                                                              | Same order as                                   |
|--------------|------------------------------------------------------------------|-------------------------------------------------|
| two-level    | `[a+; a-; b+; b-; c+; c-]` / `[a+; a-; b+; b-]`                  | Simscape Electrical *Converter (Three-Phase)*   |
| T-type       | `[Q1a; Q2a; Q3a; Q4a; Q1b; ...; Q4c]` / `[Q1a; ...; Q4b]` / `[Q1; Q2; Q3; Q4]` | `gate_cmds_phX.cmd_gate_Q1..Q4` of the library T-type blocks and three-level modulators, input `G` of `afe_single_phase_ttype` |

With +15 V / -10 V commands use `Vth = 2.5 V` (default); with 0/1 commands
use `Vth = 0.5 V`. Build the vector in Simulink (Mux or Vector Concatenate,
both virtual) and feed it to one *Simulink-PS Converter* with input unit `V`.
`I` and `V` can stay unconnected.

Current sign: positive out of the AC terminals (inverter convention). As AFE
the fundamental component of `I` is negative in phase with the grid voltage
when power flows into the DC link. The neutral-point current of the T-type
blocks (`i_np`, positive from the legs into np) and the switch voltages and
currents are logged variables (`ExternalAccess = observe`), not ports.

## Parameters

| Group         | Name     | Default          | Blocks     | Description                                   |
|---------------|----------|------------------|------------|-----------------------------------------------|
| Switches      | `Vth`    | 2.5 V            | all        | gate threshold                                |
|               | `Ron`    | 1 mOhm           | all        | on-state resistance of switch and diode       |
|               | `Goff`   | 1 uS             | all        | off-state conductance                         |
| DC link       | `cap_dc` | on               | two-level  | DC-link capacitor present                     |
|               | `Cdc`    | 2 mF             | two-level  | capacitance                                   |
|               | `Vdc0`   | 0 V              | all        | initial voltage (initial equation, cap on); T-type: `Vdc0/2` per bank |
| Split DC link | `cap_dc` | on               | T-type     | split DC-link capacitors present              |
|               | `Cdc1`, `Cdc2` | 4 mF, 4 mF | T-type     | upper (+ to np) and lower (np to -) bank      |
|               | `Rdc1`, `Rdc2` | 1 mOhm, 1 mOhm | T-type | series resistance of each bank               |
| AC inductors  | `ind_ac` | on               | all        | series inductors present                      |
|               | `L`      | 1 mH / 0.5 mH / 1 mH | all    | inductance per AC terminal (three-phase / full bridge / half bridge) |
|               | `RL`     | 10 / 5 / 10 mOhm | all        | series resistance per AC terminal             |

Initial inductor currents: Variables tab of the block dialog (`i_a`, `i_b`,
`i_c`), as usual in Simscape.

## Why one block per converter

The Home/Student licence counts **non-virtual** blocks (virtual ones such as
Mux, From/Goto, virtual subsystems, Inport/Outport do not count). Every
Simscape block is non-virtual, whatever it contains, and a component written
in the Simscape language is one block regardless of the number of equations
or member components. For one three-phase converter with measurements:

| Approach                                    | Non-virtual blocks |
|---------------------------------------------|--------------------|
| six ideal switches + Cdc + 3 L + 3 I sensors + 1 V sensor + 6 gate S-PS + 4 PS-S | ~24 |
| this block + 1 gate S-PS + 2 PS-S            | 4                  |
| T-type: twelve switches + 2 Cdc + 3 L + sensors + 12 gate S-PS + PS-S | ~40 |
| T-type block + 1 gate S-PS + 2 PS-S          | 4                  |

Two AFE + two full bridges: about 16 blocks instead of ~90, before the
sources, loads, references and Solver Configuration. The simulation cost is
unchanged (same equations, same states); only the block count drops.

## Build

From the folder that contains `+ideal_bridges` (i.e. `foundation/pwr_electronics`):

```matlab
ssc_build ideal_bridges     % -> ideal_bridges_lib.slx
```

Or `ssc_build('ideal_bridges')`. All five blocks appear in the generated
library. Rebuild after every edit of the `.ssc` files (`ssc_clean` if the old
library is locked).

## Checks

`check_ideal_bridges_ttype.py` (python3 + numpy, no Simscape; output in
`check_ideal_bridges_ttype_output.txt`, 189 checks):

```bash
python3 check_ideal_bridges_ttype.py                          # exit code 0 if all pass
python3 check_ideal_bridges_ttype.py --png waveforms.png      # with matplotlib: figure of part C
```

- **A. structure of the five `.ssc` files.** For each combination of
  `cap_dc` and `ind_ac` the number of equations is compared with the number
  of variables plus outputs, and the number of equations containing `der()`
  with the number of differentiated variables (the Simscape rule "total size
  of differential equations must match the total size of differential
  variables", which `ssc_build` does not check when the structure depends on
  a parameter `if`). Both branches of every dynamic `if` (gate / diode
  conditions, one per switch) must have the same number of equations; gate
  indices, branch variables, port sides and hidden parameters are checked too.
- **B. one T-type leg at an operating point.** The switch, common-emitter and
  midpoint equations of the `.ssc` are rebuilt and solved by enumerating the
  diode states for an imposed inductor current and DC potentials
  (Vdc = 800 V): states P, O, N for both current signs (`vm = (+) - Ron*i_a`,
  `vm = np - 2*Ron*i_a`, `vm = (-) - Ron*i_a`, the np current `-i_a` in O),
  freewheeling with all gates off (D4 / D1), the dead-time clampings with one
  switch on, the three shoot-through patterns (133 kA on a bank through
  `3*Ron`, 400 kA on the link through `2*Ron`) and the scan of the 16 gate
  patterns, which must short a bank exactly for `(Q1 & Q4) | (Q1 & Q3) |
  (Q2 & Q4)`.
- **C. `half_bridge_ttype` in the time domain.** The complete component
  (split DC link with ESR, leg, inductor) with an ideal 800 V source across
  + and -, a 4 Ohm load from a to np, three-level carrier PWM at 10 kHz with
  1 us dead time, `m = 0.8 sin(2*pi*50*t)`, backward Euler at 0.5 us. The
  midpoint is on one of the three levels at every instant; the fundamental of
  the midpoint voltage is `m*Vdc/2 - (4/pi)*dt*fpwm*Vdc/2` (315 V), the
  current `U1/|R + jwL|` (78 A) with the lag `atan(wL/R)`; the net
  neutral-point current is the load current times `|m|` (52 A at 50 Hz: in
  the O state the leg takes the load current back from np, in P and N it
  flows into the two banks in parallel) and the np voltage ripple is
  `I_np1/(w*(Cdc1 + Cdc2))` (21 V); power balance of the source against the
  load. The run starts at the periodic steady state of the neutral point,
  otherwise the np offset of a half bridge decays with
  `(Cdc1 + Cdc2)*(R + RL)/d^2 ~ 130 ms`.

## Suggested tests in Simulink

1. *Full bridge*: DC Voltage Source 400 V on + and -, `cap_dc = off`, series RL
   load between a and b (e.g. 10 Ohm), `L = 0.5 mH`. Gate: unipolar PWM from a
   sine reference at 50 Hz and a 10 kHz triangle, legs complementary,
   levels +15/-10 V through a Gain/Bias or a Switch block, then Mux -> Simulink-PS
   Converter -> G. Check `I(1)` (sinusoidal with ripple) and that
   `vm_a` (log) commutates between 0 and 400 V.
2. *Three-phase AFE*: three AC Voltage Sources 230 V rms, 50 Hz, star with
   Electrical Reference, on a b c; `cap_dc = on`, `Cdc = 2 mF`, `Vdc0 = 560 V`;
   resistive load 20 Ohm on + / -. All gates at -10 V: diode rectifier,
   `V` settles near 540 V. Then apply a PWM pattern from the dq current
   controller and verify `V` regulation.
3. *Half bridge T-type* (the case of part C of the check script): DC Voltage
   Source 800 V on + and -, `cap_dc = on` with the defaults and `Vdc0 = 800 V`,
   `L = 1 mH`, resistor 4 Ohm from a to np, Electrical Reference on -.
   Three-level PWM from `single_phase_three_levels_PWM_modulator` or from the
   table above (10 kHz, `m = 0.8 sin`), `G = [Q1; Q2; Q3; Q4]` through one
   Simulink-PS Converter. Expect `vm_a` (log) on 800 / np / 0 V, `I` 78 A
   peak, `V(2) - V(3)` a 50 Hz ripple of about 42 V peak-to-peak around zero,
   `i_np` (log) 52 A at 50 Hz.
4. *Three-phase T-type inverter on an external split link*: `cap_dc = off`,
   + np - on `dclink_for_three_levels` (or on a second T-type block with its
   capacitors on), three-phase RL load in star, `three_phase_three_levels_PWM_modulator`
   with the gate bus flattened to the 12-wide vector. Check the five-level
   line voltages and that `V(2)` and `V(3)` stay balanced (third-harmonic
   ripple of the neutral point with a balanced load).
5. Block count: `sldiagnostics('model_name', 'CountBlocks')` before and after
   replacing the discrete bridges.

The files were written without MATLAB at hand; `ssc_build ideal_bridges`
then compiled all five blocks (2026-10-31, `ideal_bridges_lib.slx` committed
next to the package). Constructs used and where they are documented:
vector physical-signal ports (`inputs G = {zeros(6,1), 'V'}`), parametric
`if` in equations, conditional sections for the initial equation and for
hiding parameters (`annotations [Cdc, Vdc0] : ExternalAccess = none`),
`ideal_bridges.onoff` parameters, `intermediates`. The T-type files use the
same constructs as `afe_ttype_ssc.afe_single_phase_ttype`, which compiles
(`afe_ttype_ssc_lib.slx`), plus the conditional sections of the two-level
files; their equation and `der()` counts are verified by the check script
for every on/off combination. If a conditional section is rejected by an
older release, delete the two `annotations` sections (the parameters stay
visible) and replace the `equations (Initial = true)` section by a
high-priority target on `vdc` (two-level) or on `vc1`, `vc2` (T-type) in
the Variables tab.

## Limitations

- No switching or conduction losses, no reverse recovery, no thermal ports.
  For losses use the `*_mos_simple_2th` / `*_igbt_simple_2th` bridges of
  `masked_models/semiconductors_bridges` instead.
- No dead time or shoot-through protection; no neutral-point balancing.
- Two-level and three-level T-type topologies only; the NPC (diode-clamped)
  bridges remain among the legacy models of
  `masked_models/semiconductors_bridges` (Simscape Electrical devices).

## Revision history

| Rev. | Date       | Notes                                                                 |
|------|------------|-----------------------------------------------------------------------|
| 00   | 2026-09-29 | First issue, two-level full bridge and three-phase bridge             |
| 01   | 2026-10-31 | Three-level T-type half bridge, full bridge and three-phase bridge; check script |
