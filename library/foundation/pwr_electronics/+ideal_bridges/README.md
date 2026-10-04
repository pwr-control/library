# ideal_bridges — functional two-level bridges (Simscape language)

Package `+ideal_bridges`, folder `foundation/pwr_electronics`. Rev. 00, 2026-09-29.

Two behavioral Simscape components that model a complete two-level converter
as **one Simulink block each**: switches, freewheeling diodes, optional DC-link
capacitor, optional AC series inductors and the basic measurements. They are
meant for system-level simulations (control design, several converters in one
model) where the semiconductor detail is irrelevant and the block count matters
(MATLAB Home / Student: at most 1000 non-virtual blocks per model, referenced
models included).

| File                     | Block name (in `ideal_bridges_lib`) | Switches | AC terminals | Gate vector |
|--------------------------|--------------------------------------|----------|--------------|-------------|
| `three_phase_bridge.ssc` | Three-Phase Bridge (ideal)           | 6        | a, b, c      | [6x1]       |
| `full_bridge.ssc`        | Full Bridge (ideal)                  | 4        | a, b         | [4x1]       |

`onoff.m` is the enumeration class (`ideal_bridges.onoff`, members `off`, `on`)
used by the on/off parameters; it must stay in the package folder.

Both are bidirectional: the same block works as inverter (DC -> AC) and as
active front end / rectifier (AC -> DC).

## Model

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
no interlock inside: if both switches of a leg are on, the leg shorts the DC
link through `2*Ron`. Dead time belongs to the modulator.

Optional passives (each with an on/off parameter, the related parameters are
hidden when off):

- `cap_dc`: DC-link capacitor `Cdc` between + and -, initial voltage `Vdc0`.
  Set it **off** when several bridges share one DC bus with a single external
  capacitor (two capacitors in parallel on the same nodes give dependent
  states) and when an ideal DC Voltage Source sits directly across + and -
  (same reason: the initial equation `vdc == Vdc0` would then conflict with
  the source).
- `ind_ac`: series inductor `L` with resistance `RL` on **each** AC terminal.
  Three-phase: `L` is the per-phase line inductance. Full bridge: the split is
  symmetric, so the total inductance in the a-load-b loop is `2*L` (enter half
  of the output inductor). The inductor currents are the states.

Implementation note: the leg midpoints are internal algebraic variables, not
nodes. The upper switch of leg a is declared as a branch `(+) -> a` and the
lower one as `a -> (-)`, so that the current leaving terminal a is
`i_a = i_ah - i_al` and the inductor equation is written between the midpoint
voltage `vm_a` and `a.v`.

## Ports

| Port | Type                     | Side   | Description                                                      |
|------|--------------------------|--------|------------------------------------------------------------------|
| +, - | electrical               | left   | DC link                                                          |
| a b c / a b | electrical        | right  | AC terminals (after the inductors)                               |
| G    | PS input, vector, V      | bottom | gate commands, order per leg `[a+; a-; b+; b-; c+; c-]` / `[a+; a-; b+; b-]` |
| I    | PS output, vector, A     | top    | terminal currents `[i_a; i_b; i_c]` / `[i_a; i_b]`, positive out of the bridge |
| V    | PS output, V             | top    | DC-link voltage (+) - (-)                                         |

The gate order is the one of the Simscape Electrical *Converter (Three-Phase)*
block. With +15 V / -10 V commands use `Vth = 2.5 V` (default); with 0/1
commands use `Vth = 0.5 V`. Build the vector in Simulink (Mux or Vector
Concatenate, both virtual) and feed it to one *Simulink-PS Converter* with
input unit `V`. `I` and `V` can stay unconnected.

Current sign: positive out of the AC terminals (inverter convention). As AFE
the fundamental component of `I` is negative in phase with the grid voltage
when power flows into the DC link.

## Parameters

| Group        | Name     | Default | Description                                   |
|--------------|----------|---------|-----------------------------------------------|
| Switches     | `Vth`    | 2.5 V   | gate threshold                                |
|              | `Ron`    | 1 mOhm  | on-state resistance of switch and diode       |
|              | `Goff`   | 1 uS    | off-state conductance                         |
| DC link      | `cap_dc` | on      | DC-link capacitor present                     |
|              | `Cdc`    | 2 mF    | capacitance                                   |
|              | `Vdc0`   | 0 V     | initial voltage (initial equation, cap on)    |
| AC inductors | `ind_ac` | on      | series inductors present                      |
|              | `L`      | 1 mH / 0.5 mH | inductance per AC terminal              |
|              | `RL`     | 10 / 5 mOhm | series resistance per AC terminal         |

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

Two AFE + two full bridges: about 16 blocks instead of ~90, before the
sources, loads, references and Solver Configuration. The simulation cost is
unchanged (same equations, same states); only the block count drops.

## Build

From the folder that contains `+ideal_bridges` (i.e. `foundation/pwr_electronics`):

```matlab
ssc_build ideal_bridges     % -> ideal_bridges_lib.slx
```

Or `ssc_build('ideal_bridges')`. Both blocks appear in the generated library.
Rebuild after every edit of the `.ssc` files (`ssc_clean` if the old library is
locked).

## Suggested test

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
3. Block count: `sldiagnostics('model_name', 'CountBlocks')` before and after
   replacing the discrete bridges.

The files were written without compiling them in MATLAB; the first
`ssc_build` will tell. Constructs used and where they are documented:
vector physical-signal ports (`inputs G = {zeros(6,1), 'V'}`), parametric
`if` in equations, conditional sections for the initial equation and for
hiding parameters (`annotations [Cdc, Vdc0] : ExternalAccess = none`),
`ideal_bridges.onoff` parameters, `intermediates`. If a conditional section
is rejected by an older release, delete the two `annotations` sections (the
parameters stay visible) and replace the `equations (Initial = true)` section
by a high-priority target on `vdc` in the Variables tab.

## Limitations

- No switching or conduction losses, no reverse recovery, no thermal ports.
  For losses use `igbt_simple` / `igbt_loss` bridges instead.
- No dead time or shoot-through protection.
- Only the two-level topology; the T-type / NPC bridges remain in
  `masked_models/semiconductors_bridges`.

## Revision history

| Rev. | Date       | Notes          |
|------|------------|----------------|
| 00   | 2026-09-29 | First issue    |
