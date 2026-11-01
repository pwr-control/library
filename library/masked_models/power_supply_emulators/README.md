# power_supply_emulators — three-phase grid emulators

Two programmable three-phase voltage sources with positive- and negative-sequence references
in ξ/η coordinates. Each one exists in two versions that sit side by side: the original
Simulink diagram and a copy written as MATLAB code (suffix `_mfcn`), with the same block name,
the same mask and the same output bus, so either can be used in a model.

| Library                                          | Block inside                                   | Implementation                          | Non-virtual blocks |
|--------------------------------------------------|------------------------------------------------|-----------------------------------------|-------------------:|
| `three_phase_voltage_emulator.slx`               | `three_phase_voltage_source_emulator`          | Simulink diagram (original)             | 44                 |
| `three_phase_voltage_emulator_mfcn.slx`          | `three_phase_voltage_source_emulator`          | Clock + one MATLAB Function             | 3                  |
| `three_phase_voltage_with_frt_emulator.slx`      | `three_phase_voltage_source_with_frt_emulator` | Simulink diagram (original)             | 123                |
| `three_phase_voltage_with_frt_emulator_mfcn.slx` | `three_phase_voltage_source_with_frt_emulator` | Clock + one MATLAB Function + Integrator | 4                  |

Non-virtual blocks are counted as `non_virtual_blocks_counting.m` of `modelization-and-control`
does, `find_system(lib, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Virtual', 'off')`, with
all variant choices of the FRT original. The `_mfcn` copies are meant for licenses that cap the
number of non-virtual blocks of a model; they also need no Control System Toolbox (the mask
callback of the original base emulator calls `tf` and `tf2ss`).

```
power_supply_emulators/
├── three_phase_voltage_emulator.slx                 original
├── three_phase_voltage_emulator_mfcn.slx            MATLAB Function copy
├── three_phase_voltage_with_frt_emulator.slx        original
├── three_phase_voltage_with_frt_emulator_mfcn.slx   MATLAB Function copy
├── test/test_power_supply_emulators_mfcn.m          MATLAB test: original vs copy
└── tools/
    ├── mfcn_src/grid_emulator.m                     code of the base copy
    ├── mfcn_src/grid_emulator_frt.m                 code of the FRT copy
    ├── generate_emulators_mfcn.py                   writes the two _mfcn.slx (no MATLAB needed)
    ├── check_emulators_mfcn.py                      structure + equivalence checks (Python, Octave)
    ├── slxsim.py, octave_mfcn.py                    helpers of the checks
    └── swap_grid_emulators_mfcn.m                   replaces the blocks in a model (both ways)
```

## Output bus `grid_emulator_outputs`

Same element names, same order in the original and in the copy.

| Element                                       | Unit  | Base | FRT |
|-----------------------------------------------|-------|:----:|:---:|
| `ua_grid_emu`, `ub_grid_emu`, `uc_grid_emu`   | V     | ✓    | ✓   |
| `gamma_grid_emulator` (wrapped to [−π, π))    | rad   | ✓    | ✓   |
| `omega_grid_emulator`                         | rad/s | ✓    | ✓   |
| `vp_xi`, `vp_eta`, `vn_xi`, `vn_eta` (filtered sequence voltages) | V | | ✓ |

1 pu of the voltages is the peak phase voltage `Vnom*sqrt(2/3)` (563.4 V at 690 V).

## Mask parameters

`three_phase_voltage_source_emulator` (defaults are numbers):

| Parameter                                  | Prompt                 | Meaning                                                           |
|--------------------------------------------|------------------------|-------------------------------------------------------------------|
| `freq`                                     | Nominal Frequency [Hz] | grid frequency                                                    |
| `ugrid_nom`                                | Nominal Voltage [V]    | rms line-to-line voltage                                          |
| `vp_xi_pu`, `vp_eta_pu`, `vn_xi_pu`, `vn_eta_pu` | `..._pu [pu]`    | positive / negative sequence references                           |
| `fcut_lvrt`                                | LVRT_flt_ss [Hz]       | cut-off of the first-order filter on the references (soft start)  |

`three_phase_voltage_source_with_frt_emulator` (defaults point to `grid_emu.*`, `frt_data.*`
and `filters.afe.SOF_50Hz.ss_c.*` of the model workspace):

| Parameter                                  | Meaning                                                                                       |
|--------------------------------------------|-----------------------------------------------------------------------------------------------|
| `nominal_frequency_m`, `nominal_voltage_m` | grid frequency [Hz], rms line-to-line voltage [V]                                             |
| `Vemu_ref_norm_m`                          | amplitude of the phase references of FRT 1 [pu]; slew rate of all ramps = `Vemu_ref_norm/t_ramp` |
| `vp_xi_pu_m` … `vn_eta_pu_m`               | sequence references [pu]                                                                      |
| `Am`, `Bm`, `Cm`                           | single-input single-output LVRT filter (n×n, n×1, 1×n, no D term) applied to every reference  |
| `enable_frt_1_m`                           | 1: dips on the phase amplitudes and phase shift of V and W (the sequence outputs follow the dips of FRT 2) |
| `enable_frt_2_m`                           | 1: dips on the sequence references                                                            |
| `start_time_LVRT_m`, `end_time_LVRT_m`     | start and end of the dip [s]                                                                  |
| `deepPOSxi_m`                              | dip of `vp_xi`, relative: `vp_xi*(1 - deepPOSxi)` during the dip                              |
| `deepPOSeta_m`, `deepNEGxi_m`, `deepNEGeta_m` | dips of `vp_eta`, `vn_xi`, `vn_eta`, absolute [pu]: `v - deep` during the dip              |
| `Amplitude_U_m`, `Amplitude_V_m`, `Amplitude_W_m` | residual amplitude of each phase during the dip, as a fraction of `Vemu_ref_norm`      |
| `t_ramp_m`                                 | time of a full-scale ramp [s] (0: steps)                                                      |
| `Phase_shift_m`                            | phase shift during the dip [rad]: V lags by `Phase_shift`, W leads by `Phase_shift`           |

`enable_frt_1` and `enable_frt_2` cannot be both 1: the original then has two active variant
choices, the copy stops with an error from its mask initialization.

## How the copies work

In both copies the mask parameters reach the MATLAB Function block as arguments of the
function with scope Parameter (no ports), after the port inputs, with the same names as in
the mask.

**Base copy** (`tools/mfcn_src/grid_emulator.m`, one port input: the time `t` from a Clock).
The original integrates five states: the grid angle and four first-order LVRT filters fed by
constants. Both have a closed-form solution, so the copy has no states:

- `gamma = mod(omega*t + pi, 2*pi) - pi`, `omega = 2*pi*freq` (Constant → Integrator → bounder);
- each sequence voltage `(1 - exp(-2*pi*fcut_lvrt*t))*v_pu*ugrid_nom*sqrt(2/3)` (constant
  reference through `1/(s/(2*pi*fcut_lvrt) + 1)` from zero);
- ξη → αβ (positive sequence rotated by +γ, negative by −γ) → abc, as the MATLAB Function
  blocks of the original.

**FRT copy** (`tools/mfcn_src/grid_emulator_frt.m`, port inputs `t` and `x`, outputs the bus
elements and `dx`). The Step, Rate Limiter, Sum, Constant and Variant Source blocks of the
original are written as functions of `t` (a step followed by a rate limiter is a clamped ramp
of slope `Vemu_ref_norm/t_ramp`). The eight LVRT filters of the original (four on the sequence
references, three on the phase amplitudes, one on the phase shift) keep their continuous
states: `dx = Am*x + Bm*u`, `y = Cm*x` for each filter, the `8*size(Am,1)` states sit in the
Integrator next to the function (`dx` → Integrator → `x`, initial condition zero).

Differences from the originals, all within the solver step size:

- the copies read the simulation time: **the simulation must start at t = 0** (the states of the
  originals start from zero at the start time);
- Rate Limiter blocks in continuous mode start a ramp one solver step early (at the step time
  their output is already `slew*dt`), the copy writes the exact ramp: during a ramp each filtered
  reference differs by up to `slew*MaxStep`, a phase voltage, which adds up to four references,
  by up to about `3*slew*MaxStep` (5e-5 and 1.5e-4 pu with `t_ramp` = 20 ms and MaxStep = 1 µs);
- the Step blocks of the original have zero-crossing detection, the MATLAB Function has none:
  with a variable-step solver the step-size control resolves the event time instead. The only
  discontinuous inputs (phase-shift step, `t_ramp` = 0) reach the outputs through the LVRT
  filters, so the outputs stay continuous.

## Verification

`tools/check_emulators_mfcn.py` (no MATLAB): structure of the two `.slx` (parts, relationships,
SIDs, lines, MATLAB Function ↔ chart ↔ `mfcn_src` code), mask and output bus identical to the
originals, non-virtual block counts; with `--sim` it simulates each original diagram read from
its `.slx` (`slxsim.py`, classic RK4) and runs the code of the copy read from the new `.slx` in
GNU Octave with the same RK4 and step (`octave_mfcn.py`). Results with h = 10 µs over 0.2 s
(differences in pu of the peak phase voltage, angle in rad):

| Scenario | Max difference | Tolerance |
|----------|---------------:|----------:|
| Base, default mask values (50 Hz, 690 V, 50 Hz filter) | 2.3e-11 | 1e-6 |
| Base, 60 Hz, unbalanced references, 20 Hz filter | 1.3e-11 | 1e-6 |
| FRT, no dip (`enable_frt_1` = `enable_frt_2` = 0) | 2.3e-11 | 1e-6 |
| FRT 2, dips on the sequence references, `t_ramp` = 20 ms | 9.1e-4 | 1.5e-3 |
| FRT 1, dips on the phase amplitudes + phase shift, `t_ramp` = 20 ms | 4.5e-4 | 1.6e-3 |
| FRT 1, `t_ramp` = 0 (steps), first-order filter at 100 Hz | 7.9e-4 | 7.6e-3 |
| FRT 2, 60 Hz, second-order filter (80 Hz, ζ 0.7) not in companion form, `t_ramp` = 10 ms | 2.1e-3 | 3.0e-3 |

The FRT differences appear only during the ramps and right after the steps of the dips, and
shrink with the step size: the Rate Limiter blocks run one step ahead (see above); with
`t_ramp` = 0 the Step blocks of the original switch at the step that lands on the event time,
while the copy, which reads `t` in every Runge-Kutta stage, already sees the new reference in
the last stage of the step before (`h/6*jump` on the filter input), then the filter smooths it.

In MATLAB, `test/test_power_supply_emulators_mfcn.m` puts the original and the copy in one
temporary model for each scenario (same numeric mask values, same solver steps), compares
the two buses element by element and prints the non-virtual block counts:

```matlab
results = test_power_supply_emulators_mfcn;                    % ode45, MaxStep 1e-5
results = test_power_supply_emulators_mfcn('MaxStep', 1e-6, 'Plot', true);
```

Results in MATLAB R2026b (ode45, MaxStep 1e-5 s, RelTol 1e-6, 0.2 s, 2026-11-01), all passed:

| Scenario | Max difference | Tolerance |
|----------|---------------:|----------:|
| Base, default mask values | 1.6e-11 (`ua_grid_emu`) | 1e-4 |
| Base, 60 Hz, unbalanced, 20 Hz LVRT filter | 3.6e-11 (`gamma_grid_emulator`) | 1e-4 |
| FRT, no dip (`enable_frt_1` = `enable_frt_2` = 0) | 1.6e-11 (`ua_grid_emu`) | 1e-4 |
| FRT 2, dips on the sequence references | 4.5e-4 (`ua_grid_emu`) | 1.5e-3 |
| FRT 1, dips on the phase amplitudes + phase shift | 2.2e-4 (`vp_xi`) | 1.5e-3 |
| FRT 1, `t_ramp` = 0, first-order filter | 6.7e-5 (`ua_grid_emu`) | 1e-4 |
| FRT 2, non-companion second-order filter, 60 Hz | 1.1e-3 (`ua_grid_emu`) | 3e-3 |

Non-virtual blocks printed by the test: 44 and 3 (base), 123 and 4 (FRT).

## Using the copies in a model

Drag the block from the `_mfcn` library, or replace the existing links keeping names,
connections and mask values:

```matlab
swap_grid_emulators_mfcn('afe_inv_psm')              % originals -> _mfcn copies (model left unsaved)
swap_grid_emulators_mfcn('afe_inv_psm', 'original')  % back to the originals
```

## Regenerating the copies

```
python3 tools/generate_emulators_mfcn.py     # writes the two _mfcn.slx from tools/mfcn_src/*.m
python3 tools/check_emulators_mfcn.py --sim  # needs numpy, scipy and GNU Octave (octave-cli)
```

The generator writes the R2026a XML format of the originals; Simulink converts the files to
its own format the first time they are saved. Once a copy has been edited and saved in
Simulink, the `.slx` is the reference: copy the function code back to `tools/mfcn_src/` before
running the generator again.

The Stateflow part of a MATLAB Function block follows rules that the Simulink loader takes for
granted (a file that breaks the first one makes MATLAB R2026b stop on the assertion
`fParserOldIds.find(std::make_pair(fCurrentChart, id)) == fParserOldIds.end()` in
`loadhierarchy.cpp` while loading the library). They hold for every MATLAB Function block of
the `.slx` files of `library` and `modelization-and-control` (1838 blocks), and
`check_emulators_mfcn.py` checks them on the two copies:

- the loader numbers the objects of a chart (state, transition, junction, data) with the ids
  that follow the chart id: the Stateflow instance id is chart id + number of objects + 1, the
  target id comes after it;
- the parameters (scope Parameter) are arguments of the function, after the port inputs;
- the S-function inside the block lists them in its `Parameters` field, names joined by commas
  and sorted by character code (`Am,Amplitude_U_m,...,vp_xi_pu_m`).

Rev. 01, 2026-11-01: Stateflow ids, parameters in the signature and in the S-function (the
rev. 00 libraries crashed MATLAB on loading).
