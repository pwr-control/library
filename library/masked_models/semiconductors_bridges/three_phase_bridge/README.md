# three_phase_bridge — three legs

Six libraries, one masked block each (same name as the file). Interface and mask parameters are
described in the folder [README](../README.md); this page gives what is specific to the
three-phase bridge.

| Library                                  | Devices                                   | dc ports (left)            | ac ports (right) |
|------------------------------------------|-------------------------------------------|----------------------------|------------------|
| `three_phase_bridge_ideal_switch`        | 6 × Foundation switch + diode + snubber    | `udc(+)`, `udc(-)`         | `u`, `v`, `w`    |
| `three_phase_bridge_mos_simple_2th`      | 6 × `mos_simple_2th` + thermal network     | `udc(+)`, `udc(-)`         | `u`, `v`, `w`    |
| `three_phase_bridge_igbt_simple_2th`     | 6 × `igbt_simple_2th` + thermal network    | `udc(+)`, `udc(-)`         | `u`, `v`, `w`    |
| `three_phase_bridge_ttype_ideal_switch`  | 12 × Foundation switch + diode + snubber   | `udc(+)`, `np`, `udc(-)`   | `u`, `v`, `w`    |
| `three_phase_bridge_ttype_mos_simple_2th`| 12 × `mos_simple_2th` + thermal network    | `udc(+)`, `np`, `udc(-)`   | `u`, `v`, `w`    |
| `three_phase_bridge_ttype_igbt_simple_2th`| 12 × `igbt_simple_2th` + thermal network  | `udc(+)`, `np`, `udc(-)`   | `u`, `v`, `w`    |

## Two-level

Legs u (Q1 upper, Q2 lower), v (Q3, Q4), w (Q5, Q6). Gate bus `gate_cmd_Q1..Q6` from
`three_phase_pwm_modulator`, whose input bus `m_uvw` has the duty cycles `mu`, `mv`, `mw`
(0..1) of the upper devices. Phase-to-midpoint fundamental `(2·d − 1)·Vdc/2`.

## T-type

Legs u (Q1..Q4), v (Q5..Q8), w (Q9..Q12), each wired as in
[`../half_bridge/README.md`](../half_bridge/README.md) (Q1 from `udc(+)`, Q4 to `udc(-)`, Q2
collector on `np`, Q3 collector on the leg output, common emitter). Gate bus from
`three_phase_three_levels_PWM_modulator`: `gate_cmds_phu.cmd_gate_Q1..Q4` → Q1..Q4,
`gate_cmds_phv.*` → Q5..Q8, `gate_cmds_phw.*` → Q9..Q12. Its input bus has the duty cycles
`mu(k)`, `mv(k)`, `mw(k)` (0..1), converted internally to `2·d − 1 ∈ [−1, 1]`; phase-to-`np`
fundamental `m·Vdc/2`.

## Measurement bus

`m` carries, per device k = 1..6 (two-level) or 1..12 (T-type), the elements listed in the folder
README.
