# single_phase_grid_tied_inverter_analysis

*Single-Phase Grid-Tied T-Type Inverter: model, control design and discrete implementation*
(Rev. 01, October 2026). Technical note on the controller of the library block
`afe_single_phase_ttype` (`masked_models/afe_single_phase_ttype`, MATLAB Function
`afe_sp_ttype_ctrl_pwm`, Simscape power stage `afe_ttype_ssc.afe_single_phase_ttype`): plant of
the SST module, first harmonic tracker and vector PI on the fundamental of the single-phase
current with its exact stationary-frame equivalent, single-phase PLL, DC-link voltage loop,
three-level modulator and the discrete implementation operation by operation.

Master copy: `repos_doc/single_phase_grid_tied_inverter_analysis/` of
[repositories-documentation](https://github.com/pwr-control/repositories-documentation); this
folder holds the same source and PDF so that the Simulink block can link the document.

## Files

- `single_phase_grid_tied_inverter_analysis.pdf` — the note.
- `single_phase_grid_tied_inverter_analysis.tex` — LaTeX source; compile with
  `pdflatex single_phase_grid_tied_inverter_analysis.tex` (twice), it reads the shared template
  `../../AAA_template_latex_settings/`.
- `single_phase_grid_tied_inverter_analysis.py` — companion script (python3, numpy, scipy,
  matplotlib): linear model of the module, margins, stability map, PLL and DC-link loop,
  sampled-data simulation of the controller as coded; prints every number of the note and writes
  the figures (`python3 single_phase_grid_tied_inverter_analysis.py [figures_dir]`).
- `figures/` — figures of the note (PDF), produced by the script.
