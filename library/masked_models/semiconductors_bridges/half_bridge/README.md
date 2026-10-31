# half_bridge — one leg, two-level and T-type

Six libraries, one masked block each (same name as the file). Interface and mask parameters are
described in the folder [README](../README.md); this page gives what is specific to the half
bridge.

| Library                           | Devices                                   | dc ports (left)            | ac port (right) |
|-----------------------------------|-------------------------------------------|----------------------------|-----------------|
| `half_bridge_ideal_switch`        | 2 × Foundation switch + diode + snubber    | `udc(+)`, `udc(-)`         | `u`             |
| `half_bridge_mos_simple_2th`      | 2 × `mos_simple_2th` + thermal network     | `udc(+)`, `udc(-)`         | `u`             |
| `half_bridge_igbt_simple_2th`     | 2 × `igbt_simple_2th` + thermal network    | `udc(+)`, `udc(-)`         | `u`             |
| `half_bridge_ttype_ideal_switch`  | 4 × Foundation switch + diode + snubber    | `udc(+)`, `np`, `udc(-)`   | `u`             |
| `half_bridge_ttype_mos_simple_2th`| 4 × `mos_simple_2th` + thermal network     | `udc(+)`, `np`, `udc(-)`   | `u`             |
| `half_bridge_ttype_igbt_simple_2th`| 4 × `igbt_simple_2th` + thermal network   | `udc(+)`, `np`, `udc(-)`   | `u`             |

## Two-level leg

```
udc(+) ──┤ Q1 ├──┬── u
                 │
udc(-) ──┤ Q2 ├──┘        Q1 collector on udc(+), Q2 collector on u
```

Gate bus: `gate_cmd_Q1`, `gate_cmd_Q2` — the output of `half_bridge_PWM_generator_with_TRGO`
(`../modulators`), whose input `m` is the duty cycle of Q1 (0..1). Output voltage referred to the
dc midpoint: fundamental `(2·d − 1)·Vdc/2`.

## T-type leg

```
udc(+) ──┤ Q1 ├──────┬── u
                     │
np ──┤ Q2 ├──┤ Q3 ├──┤        Q2 collector on np, Q3 collector on u, emitters in common
                     │
udc(-) ──┤ Q4 ├──────┘        Q4 collector on u
```

States: P = Q1 + Q2, O = Q2 + Q3, N = Q3 + Q4. Gate bus: `cmd_gate_Q1..Q4`, i.e. the sub-bus
`gate_cmds_ph1` of `single_phase_three_levels_PWM_modulator` (select it with a Bus Selector, as
done in the test bench); `m12 ∈ [−1, 1]`, output fundamental `m·Vdc/2` referred to `np`.

## Measurement bus

`m` carries, per device k = 1..2 (two-level) or 1..4 (T-type), the elements listed in the folder
README (`switch_current_Qk`, `switch_voltage_Qk` for the ideal switch; `igbt_*_Qk` /
`mosfet_*_Qk` and `diode_*_Qk` for the 2th devices).
