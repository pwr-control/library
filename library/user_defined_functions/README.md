# User defined functions — C code for the C-Caller blocks

The control algorithms in C. The same source runs inside the Simulink models through C-Caller
blocks and on the target, so simulation and firmware share one implementation.

## Layout

```
user_defined_functions/
├── ccaller/
│   ├── all_ccallers.h      aggregator header (the 26 files wired into the C-Caller set)
│   ├── all_ccallers.c      list of the matching source file names — a manifest, not compilable C
│   ├── include/            48 headers
│   └── src/                47 sources
├── hex2bin/
└── maximum_bits/
```

## How a function is organised

Each algorithm comes as two pairs of files:

- **`<name>.h` / `<name>.c`** — the portable core. It owns a `<name>_t` state struct (aliased by
  an upper-case macro) and exposes `<name>_init()`, usually `<name>_ts()` to set the sampling
  time, `<name>_reset()`, sometimes `<name>_update()`, and `<name>_process()`, each taking
  `volatile <NAME> *` as first argument. All state is `float`, nothing is allocated dynamically.
- **`<name>_simulink.h` / `<name>_simulink.c`** — the C-Caller shim. A C-Caller block cannot
  return more than one value, so the shim declares a `<name>_output_t` struct and one flat entry
  point `<name>_process_simulink(...)` with scalar arguments, holding the core state in a
  file-scope instance that is initialized lazily on the first call or on `reset`.

`include/math_f.h` is the shared constants header (π, 2π/3, 1/√3, √3/2, pulse width, …), included
by every core. Quantities are per unit (`_pu`) and estimated values carry `_hat`. Every file
carries an SPDX MIT licence header.

To use the blocks, add `ccaller/include` to the model's custom-code include path and the sources
listed in `all_ccallers.c` to its source file list.

## Current and vector control

- `rpi.*` — resonant PI current controller: PI plus a two-state resonant block, anti-windup and a
  DC-link-referred output limit.
- `dqvector_pi.*` — d and q PI current controllers with common output clipping.

## Speed control of elastic drivetrains

Written for a two-mass drive (motor, load and the elasticity between them — the ropeway case).

- `advanced_speed_control.*` — three-state observer with integral state feedback; returns the
  torque reference and the estimated motor speed, load speed and shaft torque.
- `adv_speed_ctrl_pisf.*` — the same plant in PI + state feedback form with an explicit torque
  limit.
- `adv_speed_ctrl_pisfle.*` — PISF with load estimation: a four-state observer that also returns
  the estimated load torque.

## Observers

- `bemf_obsv.*` — back-EMF / rotor-flux observer in αβ giving speed and angle, with phase
  compensation and an output speed filter.
- `bemf_obsv_load_est.*` — the same extended with a Luenberger mechanical loop estimating the load
  torque.
- `first_harmonic_tracker.*` — second-order resonant observer locking onto the fundamental of a
  scalar signal; returns the estimate and its derivative.
- `harmonic_tracker.*` — the generalized version, tuned on an arbitrary harmonic.
- `linear_double_integrator_observer.*` — position and velocity observer on a double integrator.

## Grid synchronization

- `dqpll_grid.*` — three-phase dq PLL for grid connection: PI plus double integrator, a five-state
  lock machine (stop, fault, start, run, connecting) and lock-loss fault counters.
- `dqpll_thyr.*` — the same retuned for a thyristor rectifier front end (wider lock windows).
- `single_phase_pll.*` — single-phase PLL: orthogonal signal generation plus PI and double
  integrator, with an embedded first-order filter on the ξ/η components.

## Modulators

- `sv_pwm.*` — space-vector PWM: sector detection, dwell times, symmetric centring and
  overmodulation clamping, returning the three duty cycles.
- `sv_pwm_cm.*` — the same with an added zero-sequence input applied to the zero-vector split.

## Firing-pulse generators for line-commutated rectifiers

These declare their own `…ProcessSimulink` entry point instead of a separate `_simulink` pair.

- `six_pulse_rect.*` — six-pulse thyristor bridge: six ramps over the period, level detection at
  the firing angle and a pulse-width limiter.
- `twelve_pulse_rect.*` — twelve-pulse (delta and wye) version with separate pulse outputs.
  `src/twelve_pulse_rect_old.c` is the previous implementation, kept for reference.
- `dual_six_pulses_rect.h` — dual bridge (positive and negative group). Header only: the source is
  not in `src/`.

## Filters

- `mavgflt.*` — moving average over a variable period, interpolating between the sample counts
  bracketing it.
- `mavgflts.*` — simplified single-sum moving average.
- `dsmavgflt.*` — double/decimated-sum moving average.
- `phase_shift_flt.*` — all-pass giving 90° at the chosen frequency, with output scaling.
- `sogi_flt.*` — second-order generalized integrator producing the αβ quadrature pair.

## State machines

- `global_state_machine.*` — converter supervisory machine: global and inverter state, command and
  error words, PWM enable and start/stop edges; states stop, ready, connecting, run, disconnecting
  and error, with bit-mapped faults (DC-link overvoltage, per-phase overcurrent, driver, IGBT
  overtemperature).
- `fb_state_machine.*` — the same machine with feedback-based transition guards (DC-link voltage
  and duty thresholds). It reuses the same include guard and symbol names, so it is an alternative
  build of the same unit, not a second one to be compiled alongside.

## MATLAB helpers

- `hex2bin/hex2bin.m` — hexadecimal string to binary string, with an optional minimum bit count
  (third-party, its licence is in the folder).
- `maximum_bits/max_bits.m` — number of binary bits needed to represent a given number of decimal
  digits.
