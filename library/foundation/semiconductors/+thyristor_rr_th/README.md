# thyristor_rr_th — thyristor with reverse recovery and Cauer thermal model

Same electrical model as [`thyristor_rr`](../+thyristor_rr/thyristor_rr.ssc) (piecewise-linear
static characteristic, Lauritzen-Ma charge dynamics, latching, holding, spontaneous re-fire and
tq logic), plus the junction temperature computed inside the block by a Cauer ladder junction →
case and a thermal port `H` for the outside world.

Build with `ssc_build thyristor_rr_th` from `library/foundation/semiconductors`; the block is in
`thyristor_rr_th_lib.slx`.

## Interface

| Port | Type | Meaning |
|---|---|---|
| `a`, `k` | electrical | anode, cathode |
| `G` | physical signal in | gate command, V (fires above `Vgt` with forward voltage) |
| `H` | thermal | case (heat-sink side) |
| `Tj` | physical signal out | junction temperature, K |
| `P` | physical signal out | dissipated power `v*i`, W |

## Thermal model

Same ladder as [`diode_rr_th`](../+diode_rr_th/README.md): `Rth`, `Cth` a Cauer ladder junction →
case from [`foster2cauer.m`](../../../setup_files/simulink_models_initialization/foster2cauer.m),
`Rch` the case → heat-sink resistance (both sides for a double-side cooled press-pack), `T0` the
initial temperature. No electrothermal loop: enter the electrical parameters at Tvj max.

## Recovery parameters

The model turns off abruptly when `i < Ih`; the stored charge at the current zero,
`qM0 = a*tau^2` (ramp ≫ τ), then drives the reverse current `i = -qM/Tm`. From one datasheet
point (IRM, Qrr at |di/dt| = a) — not the `diode_rr` formulas:

```
IRM = a*tau^2/Tm,   Qrr = a*tau^3/(tau + Tm)
c = IRM/a, q = Qrr/a:   tau = (q/c + sqrt((q/c)^2 + 4*q))/2,   Tm = tau^2/c
```

## Defaults

Hitachi Energy (ABB) 5STP 42U6500 (5SYA1043-08), Tvj = 125 °C: VT0 = 1.17 V, rT = 0.181 mΩ;
Goff = 1e-5 S; VGT = 2.6 V, IL = 0.7 A, IH = 0.1 A; Qrr = 6860 µAs, IRM = 91 A at −1.5 A/µs →
τ = 115.1 µs, Tm = 218.4 µs; tq = 970 µs; Rth(j-c) Foster [2.736 0.813 0.338 0.113] K/kW,
[0.9484 0.1155 0.0131 0.0036] s → Cauer Rth = [0.4189 0.4102 1.2590 1.9118] K/kW,
Cth = [14.90 30.19 80.83 343.43] J/K; Rth(c-h) = 0.8 K/kW.

## Checks (R2026b, local backward Euler)

- Power step with `H` at constant temperature: Tj − T_H equals the datasheet Foster Zth(t) plus
  `Rch` within 0.1 %.
- Recovery at −1.5 A/µs from 2 kA: IRM 91.5 A, Qrr 6.89 mC (datasheet 91 A, 6.86 mC).
- Crowbar discharge 7.5 kA, τ = 2.96 s, on 2 kJ/K: Tj max 82.9 °C at 1.23 s from 40 °C, same as an
  independent integration of the Cauer network.
