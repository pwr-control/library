# Grid-forming and grid-following AFE blocks

*Grid-forming and grid-following AFE blocks: two-level bridge with LCL filter, description and
user guide* (technical note and user guide, Rev. 00, October 2026). The two single-block
converters of [`../../masked_models/grid_forming`](../../masked_models/grid_forming) and
[`../../masked_models/grid_following`](../../masked_models/grid_following) in simple English:
quick start (what you need, eight steps to a running model, checks before the first run, how to
read `m` and `ctrl_log`); the power stage `afe_ssc.afe_two_level_lcl` (two-level bridge, DC link,
LCL filter, switch model, measurement vector `M` and gate vector `G`, how the block is assembled);
the control parts common to both blocks (local clock, carrier and trigger, acquisitions, Clarke
and Park, first harmonic tracker and sequences, dq vector PI, SVPWM and dead time); the
grid-forming chain (phase generator, voltage and current loops, master/slave `sync` ports,
negative-sequence compensator, ports and the 43-entry control log); the grid-following chain
(PLL, DC-link loop, current and zero-sequence loops, ports and the 45-entry control log); the
parameter structure `p` (`p.hw`, `p.pwm`, `p.ctrl`) with the values of the example files
`grid_forming_param_example.m` and `grid_following_param_example.m`; what the blocks do not
model.

The same source is kept in `repos_doc/grid_forming_following_afe/` of
[repositories-documentation](https://github.com/pwr-control/repositories-documentation); this
copy exists so that the two block masks can open the PDF from their Help button (the Help
command looks for `grid_forming_following_afe.pdf` on the MATLAB path and falls back to the
GitHub copy).

| File | Content |
|---|---|
| `grid_forming_following_afe.tex`, `grid_forming_following_afe.pdf` | source and compiled note (all figures are TikZ, no data files) |

Build: `pdflatex grid_forming_following_afe.tex` three times from this folder (the template is
reached as `../../AAA_template_latex_settings/`).
