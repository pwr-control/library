# Library

Open collection of simulation components shared by the other repositories of this project
(**modelization and control**, **solid state transformers**). Everything is developed in a mixed
way — Simscape language, C code, MATLAB code and Simulink — and every component is saved as a
Simulink **library** block, masked, so that it can be dropped into a model like a built-in block.

The same C code that runs inside the models through C-Caller blocks is the code that runs on the
target, so control algorithms are simulated and deployed from a single source.

## Prerequisites

MATLAB with Simulink, Simscape and Simscape Electrical.

## Installation

1. Clone the repository.
2. In MATLAB, add the repository to the path **with subfolders**.
3. The Simscape components are already compiled: each `+package` folder in `library/foundation`
   has its built `<package>_lib.slx` next to it. After editing a `.ssc` file, rebuild it from the
   folder that contains the `+package` directory:

   ```matlab
   cd library/foundation/<domain>
   ssc_build <package>          % e.g. ssc_build dtt
   ```

4. The C-Caller blocks need the C sources. In the model configuration
   (*Simulation Target → Custom Code*) add:
   - include directory `library/user_defined_functions/ccaller/include`
   - the source files listed in `library/user_defined_functions/ccaller/all_ccallers.c`
     (that file is a plain list of file names, not compilable C).

## Repository layout

| Folder | Content |
|---|---|
| [`library/foundation`](library/foundation) | Physical models written in Simscape language (`.ssc`), grouped by domain: semiconductors, power electronics passives, electrical machines and transformers, batteries, electrochemical, electronics, hydraulics, internal combustion engines, mechanics, control-system examples, varistors, non-linear loads |
| [`library/masked_models`](library/masked_models) | Masked Simulink library blocks: converter bridges, modulators, controllers, filters, observers, PLLs, DC links, metering, loads, grid emulators |
| [`library/user_defined_functions`](library/user_defined_functions) | The C code called from the models through C-Caller blocks (controllers, observers, PLLs, modulators, filters, state machines), plus two small MATLAB helpers |
| [`library/setup_files`](library/setup_files) | The parameter layer: classes and factory functions that build the hardware, machine, device, timing and controller objects used by the model initialization scripts; device datasets and datasheets |
| [`library/documentation`](library/documentation) | Technical notes (LaTeX + PDF) documenting the components: device models, active clamping, crowbars, snubbers, saturable reactors, thermal analyses |
| [`library/icons`](library/icons) | Block icons used by the masks |

Each folder has its own README with a component-by-component description.

## Conventions

- Quantities are normalized: `*_bez` is the peak-per-phase base, `*_nom` the rated value
  (line-to-line RMS for voltages, phase RMS for currents), `*_norm` and `*_pu` the per-unit value.
- `xi` / `eta` are the stationary-frame components used by the sequence controllers.
- Simscape packages are named `+<component>` and built into `<component>_lib.slx`.
- C functions come in pairs: a portable core (`<name>.c/.h`, target-ready) and a C-Caller shim
  (`<name>_simulink.c/.h`) that returns a `<name>_output_t` struct, because a Simulink C-Caller
  block cannot return more than one value.
- Sources carry an SPDX MIT licence header.
