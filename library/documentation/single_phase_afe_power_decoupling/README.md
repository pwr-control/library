# Active power decoupling of a single-phase AFE

*Active power decoupling of a single-phase AFE: the ripple port and its control in the model
`single_phase_afe`* (technical note, Rev. 00, October 2026). The method implemented in the model
`foundations_of_power_electronics/single_phase_afe` of
[modelization-and-control](https://github.com/pwr-control/modelization-and-control), in simple
English: why the power of a single-phase converter pulsates at twice the grid frequency and the
energy that moves (P/ω); the ripple port of the model (a second full bridge, two inductors and a
buffer capacitor at 2000 V, boost type seen from the DC link) and the sizing of its parts; the
control step by step: the double-integrator observer that isolates the 100 Hz ripple of the DC-link
voltage (C source `linear_double_integrator_observer.c` of this library), the phase-shift filter that
builds its quadrature (`phase_shift_flt.c`), the rotation at 2θ, the vector PI, and why the output is
applied through the β axis (it compensates the 90° of the DC-link capacitor); the buffer voltage and
current loops; an averaged simulation with the discrete loops of the model (DC-link ripple 16 % →
0.8 %, third harmonic of the grid current 13 % → 0.5 %); a check of the numbers and margins of the
model; the open points found during the check.

The same source is kept in `repos_doc/single_phase_afe_power_decoupling/` of
[repositories-documentation](https://github.com/pwr-control/repositories-documentation) (master
copy); this copy sits next to the C sources it describes.

| File | Content |
|---|---|
| `single_phase_afe_power_decoupling.tex`, `single_phase_afe_power_decoupling.pdf` | source and compiled note |
| `single_phase_afe_design_check.py` | the Python script (numpy, scipy, matplotlib) that prints the numbers and produces the figures |
| `figures/*.pdf` | the figures of the note produced by the script |

Build: `pdflatex single_phase_afe_power_decoupling.tex` three times from this folder (the template is
reached as `../../AAA_template_latex_settings/`).
