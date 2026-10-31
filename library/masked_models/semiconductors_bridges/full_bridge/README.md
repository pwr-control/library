# full_bridge — two legs, single-phase output

Six libraries, one masked block each (same name as the file). Interface and mask parameters are
described in the folder [README](../README.md); this page gives what is specific to the full
bridge.

| Library                           | Devices                                   | dc ports (left)            | ac ports (right)      |
|-----------------------------------|-------------------------------------------|----------------------------|-----------------------|
| `full_bridge_ideal_switch`        | 4 × Foundation switch + diode + snubber    | `udc(+)`, `udc(-)`         | `uac(+)`, `uac(-)`    |
| `full_bridge_mos_simple_2th`      | 4 × `mos_simple_2th` + thermal network     | `udc(+)`, `udc(-)`         | `uac(+)`, `uac(-)`    |
| `full_bridge_igbt_simple_2th`     | 4 × `igbt_simple_2th` + thermal network    | `udc(+)`, `udc(-)`         | `uac(+)`, `uac(-)`    |
| `full_bridge_ttype_ideal_switch`  | 8 × Foundation switch + diode + snubber    | `udc(+)`, `np`, `udc(-)`   | `uac(+)`, `uac(-)`    |
| `full_bridge_ttype_mos_simple_2th`| 8 × `mos_simple_2th` + thermal network     | `udc(+)`, `np`, `udc(-)`   | `uac(+)`, `uac(-)`    |
| `full_bridge_ttype_igbt_simple_2th`| 8 × `igbt_simple_2th` + thermal network   | `udc(+)`, `np`, `udc(-)`   | `uac(+)`, `uac(-)`    |

## Two-level

```
udc(+) ──┬──┤ Q1 ├──┬── uac(+)      ┌──┤ Q3 ├──┬── uac(-)
         │          │               │          │
udc(-) ──┴──┤ Q2 ├──┘               └──┤ Q4 ├──┘
```

Leg `uac(+)`: Q1 upper, Q2 lower; leg `uac(-)`: Q3 upper, Q4 lower. Gate bus `gate_cmd_Q1..Q4`
from `single_phase_pwm_modulator` (`m ∈ [−1, 1]`, leg 1 duty `(1 + m)/2`, leg 2 duty `(1 − m)/2`),
differential output fundamental `m·Vdc`.

## T-type

Two T-type legs (Q1..Q4 on `uac(+)`, Q5..Q8 on `uac(-)`), each wired as in
[`../half_bridge/README.md`](../half_bridge/README.md): Q1/Q5 from `udc(+)`, Q4/Q8 to `udc(-)`,
Q2/Q6 collector on `np` and Q3/Q7 collector on the leg output, common emitter. Gate bus from
`single_phase_three_levels_PWM_modulator`: `gate_cmds_ph1.cmd_gate_Q1..Q4` → Q1..Q4,
`gate_cmds_ph2.cmd_gate_Q1..Q4` → Q5..Q8 (`m12 ∈ [−1, 1]`, leg 2 receives `−m12`; differential
output fundamental `m·Vdc`).

## Measurement bus

`m` carries, per device k = 1..4 (two-level) or 1..8 (T-type), the elements listed in the folder
README.
