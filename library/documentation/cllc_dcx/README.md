# CLLC-DCX isolated DC/DC stage: 800 V / 800 V, 50 kW, 50 kHz

*CLLC-DCX isolated DC/DC stage: 800 V / 800 V, 50 kW, 50 kHz, sizing, simulation model and
library block* (technical design note, Rev. 00, October 2026). The isolated stage of the
solid-state transformer module as an open-loop DC transformer: first-harmonic gain, why the stage
is not regulated (tank reactance at the switching frequency, power against phase displacement),
resonant tank and magnetizing inductance for the ZVS of the driving bridge, transformer on stacked
UU93/152/30 ferrite sets, SiC modules and synchronous-rectifier drive, DC links and chokes, loss
budget; the 35 kHz variant 790 V → 700 V and where its numbers come from; the Simscape bench of
`pwr-control/solid-state-transformers` (power-flow modes, switch model, numerical damping of the
Backward Euler local solver against the step); the library block
[`cllc_dcx/cllc_dcx_mod1`](../../masked_models/cllc_dcx) (ports, measurement and gate vectors,
control chain, control log, parameter structure, build and use in the SST bench).

The same source is kept in `repos_doc/cllc_dcx/` of
[repositories-documentation](https://github.com/pwr-control/repositories-documentation); this
copy exists so that the Simulink models can link the PDF.

| File | Content |
|---|---|
| `cllc_dcx.tex`, `cllc_dcx.pdf` | source and compiled note |
| `figures/fha_gain_50kHz.dat`, `fha_gain_35kHz.dat` | FHA gain and input-impedance phase against the normalized frequency at 10 / 50 / 100 % load (pgfplots data) |
| `figures/tank_waveforms_50kHz.dat`, `tank_waveforms_35kHz.dat` | idealized tank waveforms at full load over two switching periods |
| `py/cllc_dcx_figures.py` | writes the four data files from the numbers of the two parameter sets and prints the derived quantities (resonance, tank, gain, tank reactance, numerical damping per unit of step) |

Build: `pdflatex cllc_dcx.tex` twice from this folder (the template is reached as
`../../AAA_template_latex_settings/`). Regenerate the data files with
`python3 py/cllc_dcx_figures.py` from this folder (standard library only).
