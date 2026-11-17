# diode_rr_th — Lauritzen-Ma diode with Cauer thermal model

Same electrical model as [`diode_rr`](../+diode_rr/diode_rr.ssc) (charge-controlled diode:
reverse recovery, depletion capacitance, leakage), plus the junction temperature computed inside
the block by a Cauer ladder junction → case and a thermal port `H` for the outside world: a
thermal mass, a heat-sink network or an ideal temperature source. One block can stand for `ns`
identical devices in series.

Build with `ssc_build diode_rr_th` from `library/foundation/semiconductors`; the block is in
`diode_rr_th_lib.slx`.

## Interface

| Port | Type | Meaning |
|---|---|---|
| `p`, `n` | electrical | anode, cathode |
| `H` | thermal | case (heat-sink side) of the `ns` devices |
| `Tj` | physical signal out | junction temperature of each device, K |
| `P` | physical signal out | power dissipated by the `ns` devices, W |

Sign convention on `H`: `Q : H.Q -> *` with `Q == -qout`, so a positive dissipated power leaves
the block through `H` into the connected network.

## Thermal model

```
Tj o--+--[R1]--+--[R2]-- ... --+--[Rn + Rch]--o H
      |        |               |
     C1       C2              Cn
      |        |               |
     ===      ===             ===
```

- `Rth = [R1 ... Rn]`, `Cth = [C1 ... Cn]` (one device, `n >= 2`) are a **Cauer** ladder. A
  datasheet Foster network is converted with
  [`foster2cauer.m`](../../../setup_files/simulink_models_initialization/foster2cauer.m); the
  Foster coefficients are not a ladder and must not be entered directly. The equivalent ladder
  has the datasheet Zth with the case at constant temperature and, unlike the Foster network,
  gives the right heat flow into whatever is connected to `H`.
- `Rch` is the case → heat-sink contact resistance of one device (0 when the datasheet curve is
  already Zth(j-hs), or when the network connected to `H` has its own contact resistance).
- With `ns > 1` the `ns` ladders are identical and in parallel: the block uses `Rth/ns`,
  `Cth*ns`, `Rch/ns`. Connect to `H` the total external mass (`ns` times that of one device).
- `T0` is the initial temperature of the internal nodes; give the external network the same.
- Dissipated power: `P = Rs*i^2 + vj*(qE - qM)/TM + vj^2/Rr`, i.e. `v*i` minus the reactive power
  of the depletion charge.
- The electrical parameters do not depend on `Tj` (no electrothermal loop): enter them at Tj max.

## Parameters

Electrical parameters of one device, as for `diode_rr` (forward line at Tj max, one recovery
point Qrr, Irrm at a given di/dt; see the header of `diode_rr.ssc`). `ns` scales `N`, `Rs`, `Rr`,
`Vjp`, `dsm` by `ns` and `Cj0` by `1/ns`.

Defaults: Littelfuse (Westcode) W8245EC450, one device: forward tangent at 7.5 kA of
VT0 = 0.776 V, rT = 0.087 mΩ (160 °C); Qrr = 21.5 mC, Irrm = 350 A at 10 A/µs → τ = 78.9 µs,
TM = 99.1 µs; Zth(j-hs) double side, contact included, Foster
[1.8146 1.3878 1.3962 0.4167] K/kW, [0.8936 0.3521 0.0597 0.0188] s → Cauer
Rth = [1.6784 1.0831 1.8173 0.4364] K/kW, Cth = [19.42 46.00 178.76 1536.32] J/K, `Rch = 0`.

## Checks (R2026b, local backward Euler)

- Power step with `H` at constant temperature: Tj − T_H equals the datasheet Foster Zth(t)
  within 0.1 %, for `ns = 1` and `ns = 2`.
- Recovery at 10 A/µs from 2 kA: 335 A, 19.9 mC (datasheet 350 A typ, 21.5 mC max; the
  single-point Lauritzen-Ma fit is approximate when the ramp is only about 3 τ).
- Crowbar discharge 7.5 kA, τ = 2.96 s, two devices in series on 4 kJ/K: Tj max 73.3 °C at 0.69 s
  from 40 °C, same as an independent integration of the Cauer network.
