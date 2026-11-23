# pelib.mos_simple_2th — simplified power MOSFET loss model

Simscape Language component for converter-level loss and junction temperature
estimation. Same modelling philosophy as `pelib.igbt_simple_2th`: the switching
transient is not resolved, the switching energies come from single datasheet
values scaled to the operating point, and the losses are split between two
thermal ports.

Build with `ssc_build pelib` from the folder containing `+pelib`.

## Interface

| Port | Type | Meaning |
|---|---|---|
| `p` | electrical | Drain |
| `n` | electrical | Source |
| `G` | physical signal in | Gate command, 0 or 1 |
| `Ht` | thermal | MOSFET die |
| `Hd` | thermal | Diode die |
| `Pt` | physical signal out | Transistor dissipated power, W |
| `Pd` | physical signal out | Diode dissipated power, W |

Sign convention on the thermal ports: `Q : H.Q -> *` with `Q == -P`, so a
positive dissipated power delivers heat from the component into the thermal
network.

## Conduction

Channel and diode are two parallel branches across the same terminal voltage
`v = v_p - v_n`:

```
i_ch = G_ch * v            G_ch = 1/Rds  (gate high)   1/Roff  (gate low)
i_d  = max(-v - Vf, 0)/Rd
i    = i_ch - i_d
```

The `max` is smoothed as `(x + sqrt(x^2 + eps^2))/2`.

Two consequences worth noting, both different from the IGBT model:

- The channel is bidirectional. During synchronous rectification the negative
  current returns through the channel with loss `v*i_ch = Rds*i^2`, charged to
  `Ht`. The diode is not switched off explicitly: since `Rds*|i|` is normally
  below `Vf`, the parallel formulation gives the diode a small residual share,
  which is the physical behaviour. If `Rds*|i| > Vf` the split moves to the
  diode automatically, as it does in reality.
- Conduction loss is `Rds*i^2`, so it is quadratic in current, not affine as
  with `Vce_sat + Ron*i`. Dimensioning at nominal current with `Rds_on` taken at
  the maximum junction temperature is the conservative choice.

`Rds_on` is given at `Tj_ref`. Setting `alpha_R` different from zero enables

```
Rds = Rds_on * (1 + alpha_R*(T_Ht - Tj_ref))
```

with a smooth floor at 0.2·Rds_on to keep the resistance positive if the thermal
network is initialised far from the operating point. This closes the
electrothermal loop through `Ht`. With `alpha_R = 0` (default) the loop is
absent and the model is a pure feed-forward loss calculator, like the IGBT one.
Typical values are 0.005…0.008 1/K for SiC and 0.008…0.012 1/K for Si
superjunction, both around 125 °C.

## Switching energies

```
E = E_ref * (I/Iref)^ki * (Vbl/Vref)^kv
```

`ki = kv = 1` reproduces the usual linear-linear scaling. `Vbl` is a held
estimate of the blocking voltage, obtained by tracking `v` with time constant
`tau_v` only while `v > Vth_off` (weighted by a `tanh` indicator to avoid an
extra zero crossing), so at the switching instant it holds the dc-link voltage
of the interval that just ended.

Event detection and attribution:

| Event | Trigger | Energy | Current used |
|---|---|---|---|
| Turn-on | `v` falls below `Vth_on` | `G * Eon` | terminal current at the event |
| Turn-off | `v` rises above `Vth_off` | `Eoff` | `ith` (held) |
| Recovery | `v` rises above `Vth_off` | `Err` | `idh` (held) |

The gate factor on `Eon` suppresses the voltage collapse caused by the diode
starting to conduct during the dead time. Turn-on into the third quadrant with
the diode already conducting produces no down-crossing at all, so a ZVS turn-on
correctly costs nothing.

Turn-off and recovery share one trigger, because the terminal voltage rises both
when this transistor turns off and when the complementary switch turns on and
reverse biases this diode. The two held states separate the cases:

- `ith` tracks the positive part of the channel current while the gate is high
  and holds while it is low. During synchronous rectification the channel
  current is negative, so `ith` decays to zero and `Eoff` vanishes, which is the
  correct behaviour for a soft turn-off into the body diode.
- `idh` tracks the diode current. While the channel shunts the diode it is
  nearly zero; during the dead time it recovers the load current. Hence one
  `Err` event per switching period, in the half period where the diode conducts.

`tau_s` must be well below the dead time, otherwise `idh` does not reach the
load current before the recovery event and `Err` is underestimated. Default
100 ns against a dead time of 1…2 µs.

## From energy to power

Two event variables accumulate the energies; two states follow them through a
first-order lag:

```
tau_p * dEo/dt = Eq - Eo        P_sw = (Eq - Eo)/tau_p
```

The integral of `P_sw` equals the accumulated energy exactly, with a bounded
residual `Eq - Eo`. Choose `tau_p` of the order of a few switching periods:
large enough to smooth the pulse train, small compared with the fastest Foster
time constant of the thermal network.

## Thermal ports and the body diode

`two_die = 1` routes diode conduction and recovery to `Hd`. This is the case of
a module with a separate antiparallel die, e.g. a SiC MOSFET with SiC Schottky
diode, where the two junctions have distinct `Rth(j-c)` and deserve separate
temperatures.

`two_die = 0` adds those losses to `Ht` instead. Use this whenever the diode is
the intrinsic body diode: it is the same silicon or SiC as the channel, and two
independent junctions would be a modelling error rather than a refinement. `Hd`
then carries zero heat but must still be connected — a Thermal Reference, or the
same node as `Ht`, both work.

## Parameter extraction from the datasheet

- `Rds_on` at the temperature you intend to dimension at, at the actual `Vgs`.
  Datasheets usually give it at 25 °C and at 150 °C; interpolate.
- `Vf`, `Rd` from the third-quadrant characteristic with `Vgs` at the negative
  off-state value, not from the synchronous-conduction curve.
- `Eon`, `Eoff` from the energy vs. current curves, read at the operating `Vgs`,
  `Rg` and dc voltage of your design. Set `Iref` near the current you actually
  operate at, since the linear scaling concentrates its error away from the
  reference point.
- `Err` from the recovery curve, or from `Err ≈ Vdc*Qrr` when only `Qrr` is
  given. For a Schottky diode the residual is capacitive charge only, so a small
  non-zero value is appropriate rather than exactly zero.

Two remarks specific to MOSFETs:

- Datasheet `Eon` is measured hard-switched and already includes both the
  recovery of the complementary diode and the discharge of `Coss`. Do not add
  them separately.
- Under ZVS operation the datasheet `Eon` is meaningless. If you use the model
  for a resonant or phase-shifted converter, set `Eon_ref` to the `Coss`
  hysteresis energy of the device, which is one to two orders of magnitude
  smaller, and check that the model is not detecting spurious turn-on events by
  monitoring `Pt`.

## Limits

- No transient waveforms: no `di/dt`, no overshoot, no gate resistance
  dependence. For those use `mos_dyn`.
- Energies are scaled from a single reference point, so the error grows away
  from `Iref` and `Vref`.
- No temperature dependence of `Eon`, `Eoff`, `Err`, `Vf`. For SiC this is a
  minor omission, since the switching energies are almost temperature
  independent; for Si it is not, and the parameters should be taken at the
  maximum expected junction temperature.
- Gate signal must be a clean 0/1 physical signal, with dead time. The channel
  conductance switches discontinuously, which is what keeps the crossover
  energy out of the conduction term, but it also means the model relies on the
  external dead time to avoid shoot-through.

## Suggested checks

1. Steady-state run at constant duty and constant load current: compare
   `mean(Pt) + mean(Pd)` against a hand calculation
   `Rds*Irms^2 + (Eon + Eoff)*fsw*(I/Iref)*(Vdc/Vref)`.
2. Sweep the load current sign and verify that `Pd` collapses in the half period
   where the channel conducts synchronously.
3. Set `two_die = 0` and verify that `Pt` picks up exactly what `Pd` loses.
4. If the solver complains about scaling with very small energies, add explicit
   `nominal` values to `Eqt`, `Eqd`, `Eot`, `Eod`.
