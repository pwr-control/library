# Solid State Transformers: architecture, modelization and control

*Solid State Transformers: architecture, modelization and control* (technical research report,
Rev. 01, October 2026). Sections 2 to 6 are the comparative study of 2025: candidate
architectures, control principles, simulation of each combination of isolated DC/DC stage (three
phase DAB, single phase DAB, single phase CLLC) and inverter (NPC, T-type) at about 250 kW per
phase, HF transformer designs, comparison of the losses. Section 7, added in Rev. 01, documents
the two-module bench that `pwr-control/solid-state-transformers` keeps today: CLLC-DCX
800 V / 800 V, 50 kW, 50 kHz and three-level T-type single-phase inverter per module, the
inverters in series on the line, module B slave of module A; the two models (compact library
blocks [`cllc_dcx`](../../masked_models/cllc_dcx) and
[`afe_single_phase_ttype`](../../masked_models/afe_single_phase_ttype), or discrete blocks with
switch losses and thermal model), the `param` structure, timing and Backward Euler settings.

The same source is kept in `repos_doc/solid_state_transformers/` of
[repositories-documentation](https://github.com/pwr-control/repositories-documentation); this
copy exists so that the Simulink models can link the PDF. The source references its figures
without extension: in repositories-documentation they are the original EPS files (121 MB,
converted by `epstopdf` at build time), here the same figures as PDF (`figures/`, 2.8 MB), so the
document compiles unchanged in both places.

| File | Content |
|---|---|
| `solid_state_transformers.tex`, `solid_state_transformers.pdf` | source and compiled report |
| `figures/arch/`, `figures/control/`, `figures/sim_results/`, `figures/magnetics/` | the 56 figures of the report, PDF versions of the EPS originals |

Build: `pdflatex solid_state_transformers.tex` twice from this folder (the template is reached
as `../../AAA_template_latex_settings/`).
