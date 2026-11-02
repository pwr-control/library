# afe_ttype_ssc — T-type AFE power stages in one Simscape block

Package `+afe_ttype_ssc`, folder `foundation/pwr_electronics`. Build with `ssc_build afe_ttype_ssc`
from that folder (`afe_ttype_ssc_lib.slx`, committed next to the package).

| File | Block name in the library | Content | `G` | `M` |
|------|---------------------------|---------|-----|-----|
| `afe_single_phase_ttype.ssc` | AFE Single-Phase Three-Level T-Type Bridge with LC Filter | single-phase T-type full bridge, split DC link (`np` internal), LC filter; power stage of the masked block `afe_single_phase_ttype` | [8x1] | [13x1] |
| `afe_three_level_ttype_lcl.ssc` | AFE Three-Level T-Type Bridge with LCL Filter | three-phase T-type bridge, split DC link (optional, `np` port), LCL filter with star capacitors | [12x1] | [22x1] |
| `afe_three_level_ttype_lcl_delta.ssc` | AFE Three-Level T-Type Bridge with LCL Filter, Delta Capacitors | the same with the filter capacitors in delta | [12x1] | [22x1] |

`onoff.m` is the enumeration of the `cap_dc` parameter of the two LCL blocks
(`afe_ttype_ssc.onoff`, members `off` and `on`); it must stay in this folder.

The two LCL blocks are the T-type versions of `afe_ssc.afe_two_level_lcl` and
`afe_ssc.afe_two_level_lcl_delta`: same filter, same parameter names, same `M(1:17)`, plus the
split DC link in `M(18:22)`. Description, measurement vector, star/delta conversion and checks:
[`../+afe_ssc/README.md`](../+afe_ssc/README.md) (check script `../+afe_ssc/check_afe_lcl.py`).
