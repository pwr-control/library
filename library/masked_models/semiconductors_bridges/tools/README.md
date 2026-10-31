# tools — generator of the bridge libraries

Python 3 scripts (standard library only, no MATLAB) that write the 18 libraries and the test
model of `semiconductors_bridges` as `.slx` packages.

| Script                    | Role                                                                                                   |
|---------------------------|--------------------------------------------------------------------------------------------------------|
| `slxlib.py`               | minimal `.slx` writer: block diagram, systems, lines, masks, relationships, content types, metadata, the binary `mxarray` parts (byte copies of files saved by Simulink R2026a) |
| `sscblocks.py`            | Simscape blocks used by the bridges and the test (Foundation elements, sensors, thermal network, `igbt_simple_2th`, `mos_simple_2th`) with the parameter names, units and port ids written by Simulink |
| `generate_bridges.py`     | mask tables, cells (ideal / 2th), two-level and T-type topologies; writes the 18 libraries              |
| `generate_test_model.py`  | writes `../test/test_semiconductors_bridges.slx`                                                       |
| `check_slx.py`            | structural checks of the generated files (XML, SIDs, port ranges, one line per port, mxarray parts)    |

```bash
cd library/masked_models/semiconductors_bridges
python3 tools/generate_bridges.py            # -> half_bridge/, full_bridge/, three_phase_bridge/
python3 tools/generate_test_model.py         # -> test/test_semiconductors_bridges.slx
python3 tools/check_slx.py */*.slx test/*.slx
```

To change a mask default, a parameter name, the thermal network or the layout, edit the
generator and regenerate all files; Simulink rewrites a file in its own canonical form when it is
saved from the editor, which is fine, but hand edits are lost at the next regeneration.
