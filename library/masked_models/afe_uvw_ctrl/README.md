# afe_uvw_ctrl — AFE control in the uvw frame as MATLAB Function blocks

Rev. 01, 2026-11-04: the section "Using the blocks in afe_uvw_three_phase" describes the model
`afe_rst_ctrl.slx` and the init section that builds `param.afe.uvw` (rev. 00 the same day: first version).

Five masked Simulink blocks, one MATLAB Function each, that replace the control subsystems of the
model `foundations_of_power_electronics/afe_uvw_three_phase` (`afe_uvw_ctrl.slx`, renamed
`afe_rst_ctrl.slx` once the blocks were in; pwr-control/modelization-and-control): the grid voltage and grid current sequence measurements, the
reactive current control, the fault ride-through of VDE-AR-N 4110 and the per-phase resonant current
control, plus a new passive islanding detector. The model needs almost 1000 non-virtual blocks for
these functions; here each block costs 2 (the atomic subsystem and the S-function of the MATLAB
Function). The code is plain MATLAB in `src/`, written to be read and changed: no C-Caller, no
selector between C and MATLAB versions, one parameter struct `p` for the five blocks.

| Block                           | Source                               | Replaces in the model                          | Non-virtual blocks |
|---------------------------------|--------------------------------------|------------------------------------------------|-------------------:|
| `grid_voltage_sequences`        | `src/grid_voltage_sequences.m`       | `grid_voltage_sequences`                       | 2 |
| `frt_vde4110`                   | `src/frt_vde4110.m`                  | `FRT-VDE4110`                                  | 2 |
| `grid_current_sequences_q_ctrl` | `src/grid_current_sequences_q_ctrl.m`| `grid_current_sequences_and_reactive_pwr_ctrl` | 2 |
| `current_ctrl_uvw`              | `src/current_ctrl_uvw.m`             | `current_ctrl`                                 | 2 |
| `islanding_detector`            | `src/islanding_detector.m`           | `islanding_mode_detector` (a stub in the model) | 2 |

## Files

```
afe_uvw_ctrl/
├── afe_uvw_ctrl.slx                 the library (R2026a format, loads in R2026b; Simulink re-saves it)
├── afe_uvw_ctrl_param_example.m     p = afe_uvw_ctrl_param_example(ts, f_nom): the numbers of the model
├── update_afe_uvw_ctrl.m            MATLAB: loads src/*.m into the blocks (and the test functions into the bench)
├── README.md                        this file (Help of the five masks)
├── src/                             the code of the blocks, one file per block
├── test/
│   ├── test_afe_uvw_ctrl.slx        test bench: the five blocks in the chain of the model, source and RL plant
│   ├── afe_uvw_ctrl_test_param.m    [p, tb] = ... : parameters and scenario of the bench
│   ├── afe_uvw_ctrl_test_source.m   MATLAB Function of the bench: grid voltage, PLL angle, references
│   ├── afe_uvw_ctrl_test_plant.m    MATLAB Function of the bench: three RL branches
│   ├── afe_uvw_ctrl_test_loop.m     the bench as a MATLAB loop of the same functions
│   ├── afe_uvw_ctrl_test_log_index.m columns of the 50-signal log
│   └── afe_uvw_ctrl_test_run.m      runs the model and the loop, 15 checks with PASS / FAIL, one figure
└── tools/
    ├── make_afe_uvw_ctrl.py         python3: writes the library and the bench without MATLAB, checks them
    └── check_afe_uvw_ctrl.py        python3 + GNU Octave: the new code against a twin of the model's diagrams
```

## The blocks and how they connect

The chain is the one of the model (`afe_abc_inv_psm_mod1/AFE_control/afe_control`, a triggered
subsystem that runs once per control period `ts`). All signals are per unit, angles in radians.

```
 PLL ─ theta, omega_pu ──────────────┬──────────────────┬──────────────────┬───────────────┐
                                     │                  │                  │               │
 ug_abc ─► grid_voltage_sequences ─ v_seq_avg ─► frt_vde4110 ─ i_grid_ref ─► grid_current_ │
                │                                   ▲  │  │               sequences_q_ctrl │
                └ ug_ab ──► islanding_detector      │  │  └ pwr_lim_enable ► DC-link ctrl    │
                               ▲                    │  │                         │           │
 i_react_pos/neg_ref ───────────┼────────────────────┘  └ frt_active            i_stack_ref  │
 enable, reset ─────────────────┘                                                 ▼           │
 ig_abc ─────────────────────────────────────────────────────────────────────► (q_ctrl)        │
 i_xi_ref (DC-link control) ─────────────────────────────────────────────► current_ctrl_uvw ◄─┘
 is_abc ───────────────────────────────────────────────────────────────────►      │
                                                                       u_abg ─► modulator
```

### grid_voltage_sequences

| Port | Direction | Size | Meaning |
|------|-----------|------|---------|
| `ug_abc`   | in  | 3×1 | grid phase voltages |
| `theta`    | in  | 1   | grid angle of the PLL |
| `omega_pu` | in  | 1   | grid pulsation of the PLL, pu of `p.omega_nom` |
| `v_seq_avg`| out | 4×1 | `[pos_xi; pos_eta; neg_xi; neg_eta]` averaged (zero before `p.vseq.t_enable`) |
| `v_seq`    | out | 4×1 | the same without averaging |
| `ug_ab`    | out | 2×1 | `[alpha; beta]`, Clarke 2/3 (amplitude invariant) |

Positive frame: `xi = alpha cos(theta) + beta sin(theta)`, `eta = -alpha sin(theta) + beta cos(theta)`;
negative frame: `xi = alpha cos(theta) - beta sin(theta)`, `eta = alpha sin(theta) + beta cos(theta)`.
Each component goes through a moving average whose window is `2*pi/(p.omega_nom*p.vseq.avg_order*w)`,
`w = |omega_pu|` limited to `[omega_pu_min, omega_pu_max]`: half a grid period with `avg_order = 2`, which
removes the 2ω ripple that the other sequence leaves in the frame. The window is a real number of
samples: the average takes the `floor(n)` newest samples plus the next older one with the fractional
weight, so that it follows the grid period without jumps (the model's `dmavg_flt`). During the fill-up
the mean of the stored samples is used.

### frt_vde4110

| Port | Direction | Size | Meaning |
|------|-----------|------|---------|
| `v_seq_avg`     | in  | 4×1 | output of `grid_voltage_sequences` |
| `i_react_ref`   | in  | 2×1 | `[pos; neg]` reactive grid current references in normal operation |
| `enable`        | in  | 1   | > 0.5: detector on (the model: a step at the settle time) |
| `reset`         | in  | 1   | > 0.5: leaves the state EXCEEDED (the model: 1 for the first 25 ms) |
| `i_grid_ref`    | out | 3×1 | `[pos_eta; neg_xi; neg_eta]` grid current references → `grid_current_sequences_q_ctrl` |
| `frt_active`    | out | 1   | 1 while the fault is detected |
| `pwr_lim_enable`| out | 1   | 1 when the active power must be limited (read by the DC-link controller) |
| `frt_log`       | out | 10×1| `[state (0 idle, 1 active, 2 exceeded); exceeded; red_dyn; v_pos_dot; v_neg_dot; v_prefault (4); |v_neg|]` |

**Detection.** Two double-integrator observers give the rates of the positive and negative xi
components (`x += ts*(v + kx*(u - x))`, `v += ts*kv*(u - x)`, held at zero before
`p.frt.t_obs_release`; the same algorithm as `linear_double_integrator_observer_ccaller` of the
library, gains from the poles `p.frt.obs_poles` as the `acker` call of `ctrl_afe_setup`). State machine:

- IDLE → ACTIVE when (`v_pos < v_pos_low` or `v_pos > v_pos_high` or `|v_neg| > v_neg_max`) and
  (`|v_pos_dot| > v_pos_dot_max` or `|v_neg_dot| > v_neg_dot_max`) and the detector has been idle for
  more than `t_rearm`;
- ACTIVE → IDLE when `v_pos` is back inside the band narrowed by `v_hyst`;
- ACTIVE → EXCEEDED after `t_hold_max` (fault too long); EXCEEDED → IDLE with `reset`.

In ACTIVE the power limitation flag is set when `v_pos < pwrlim_v_pos` or `|v_neg| > pwrlim_v_neg` and
released when `v_pos > pwrlim_v_pos + pwrlim_hyst` and `|v_neg| < pwrlim_v_neg_release`. The reduced
dynamic support flag (`red_dyn`) follows `reddyn_v_pos` / `reddyn_v_neg` when `p.frt.reddyn_enabled`
(the model keeps it off: its input is a constant 0).

**References.** The pre-fault voltages are moving averages of `v_seq_avg` over `t_avg_prefault`
(0.5 s), frozen while the fault is active and started at `t_avg_start` (after the start-up of the
sequence averages). With `dv = v_seq_avg - v_prefault`, during the fault

```
i_pos_eta = i_react_ref(1) + k_frt_ref*dv_pos_xi
i_neg_eta = i_react_ref(2) - k_frt_ref*dv_neg_xi
i_neg_xi  =                  k_frt_ref*dv_neg_eta
```

(the negative-sequence current is the negative-sequence voltage change turned by 90 degrees: reactive
current against the unbalance); outside the fault the first two are the inputs and the third is zero.
Each reference is limited to ±`lim_*` (`lim_*_red` with `red_dyn`) and low-pass filtered at
`f_lpf_ref` (`y = g0*u + (1 - g0)*y`, `g0 = 2*pi*f*ts`, the `u_161Hz_flt` blocks of the model).

### grid_current_sequences_q_ctrl

| Port | Direction | Size | Meaning |
|------|-----------|------|---------|
| `ig_abc`     | in  | 3×1 | grid phase currents |
| `theta`, `omega_pu` | in | 1 | as above |
| `i_grid_ref` | in  | 3×1 | `[pos_eta; neg_xi; neg_eta]` from `frt_vde4110` |
| `i_stack_ref`| out | 3×1 | `[pos_eta; neg_xi; neg_eta]` stack current references → `current_ctrl_uvw` |
| `i_seq_avg`  | out | 4×1 | `[pos_xi; pos_eta; neg_xi; neg_eta]` averaged grid current |
| `i_seq`      | out | 4×1 | the same without averaging |

Same transformation and moving average as the voltage block (`p.iseq.*`). Three PI controllers
(`kp + ki*ts/(z - 1)`, backward Euler, integrator clamped to the output limit as the Simulink PID
block does) on `e = p.iseq.err_sign*(i_grid_ref - i_seq_avg)`: `err_sign = -1` when the grid current
is measured towards the converter (the model: error = measured − reference), `+1` when it is measured
towards the grid. Limits `lim_pos_eta`, `lim_neg_xi`, `lim_neg_eta`; the model uses `ieta_pos_ref_lim`
for the negative xi too, the example keeps that (1.0).

### current_ctrl_uvw

| Port | Direction | Size | Meaning |
|------|-----------|------|---------|
| `i_xi_ref`   | in  | 1   | positive-sequence xi (active) stack current reference, from the DC-link control |
| `i_stack_ref`| in  | 3×1 | `[pos_eta; neg_xi; neg_eta]` from `grid_current_sequences_q_ctrl` |
| `is_abc`     | in  | 3×1 | stack (converter) phase currents |
| `theta`      | in  | 1   | grid angle of the PLL |
| `u_abg`      | out | 3×1 | `[u_alpha; u_beta; u_gamma]` voltage references for the modulator |
| `i_abc_ref`  | out | 3×1 | phase current references (log) |
| `is_xe`      | out | 2×1 | stack current in the positive frame `[xi; eta]` (log) |

1. References: the positive sequence `(xi, pos_eta)` turned by `+theta`, the negative one
   `(neg_xi, neg_eta)` by `-theta`, summed in alpha/beta and transformed to abc.
2. One resonant PI per phase on `e = i_ref - i_meas`:
   `d = kp*e + ki*s/(s^2 + 2*delta*w*s + w^2)*e`, `w = p.ictrl.omega_res`, `delta = p.ictrl.delta_res`
   (0.015 in the model; 0 is the ideal resonator). State space `x1' = x2`,
   `x2' = -w^2*x1 - 2*delta*w*x2 + ki*e`, output `x2`, forward Euler with `ts` (the model:
   `Aresd = I + A*ts`, `Bresd = B*ts`).
3. Vector limiter: the three outputs are divided by the length of the previous alpha/beta output,
   limited to `[mag_lim, mag_scale_max]` (the `antiwind_up` of the model: a soft scaling, not a hard
   limit), then abc → alpha/beta (the zero sequence of the three outputs is dropped). The model
   delivers alpha/beta through a Unit Delay: `p.ictrl.out_delay = 1` keeps that one-step delay,
   0 removes it.
4. Zero-sequence current: PI with clamped integrator on `iz_ref - mean(is_abc)`, limited to
   ±`u_z_lim`, gives `u_gamma`.

The grid voltage feed-forward is not part of the block (the model computes `v_grid_ff_abc` but only
displays it). With `delta = 0.015` the resonator gain at `w` is finite (`ki/(2*delta*w) = 3.7`): the
steady-state error of the inner loop is corrected by the outer loops (DC-link PI for xi,
`grid_current_sequences_q_ctrl` for eta and the negative sequence), as in the model.

### islanding_detector (new)

| Port | Direction | Size | Meaning |
|------|-----------|------|---------|
| `ug_ab`    | in  | 2×1 | `[alpha; beta]` from `grid_voltage_sequences` |
| `theta`, `omega_pu` | in | 1 | as above |
| `enable`   | in  | 1   | > 0.5: armed; 0 resets the latch and the timers |
| `island`   | out | 1   | 1 when islanding is detected (latched when `p.island.latch = 1`) |
| `crit`     | out | 1   | bit mask of the criteria that tripped: 1 U<, 2 U>, 4 f<, 8 f>, 16 ROCOF, 32 harmonics |
| `idet_log` | out | 8×1 | `[u1; u5; u7; harmonic ratio; f (pu); ROCOF (Hz/s); longest running criterion (s); time since detection (s)]` |

Passive detection: the block watches what the voltage at the point of connection does when the grid
is lost and the converter keeps feeding the local load. Six criteria, each with a threshold and an
on-delay (the condition must hold for the whole delay):

| # | Criterion | Condition | Default (VDE-AR-N 4105 / 4110 network protection) |
|---|-----------|-----------|----------------------------------------------------|
| 1 | under-voltage   | `u1 < u_min` for `t_trip_u_min`        | 0.8 pu, 2.7 s |
| 2 | over-voltage    | `u1 > u_max` for `t_trip_u_max`        | 1.15 pu, 0.1 s |
| 3 | under-frequency | `f < f_min` for `t_trip_f`             | 47.5 Hz, 0.1 s |
| 4 | over-frequency  | `f > f_max` for `t_trip_f`             | 51.5 Hz, 0.1 s |
| 5 | ROCOF           | `|df/dt| > rocof_max` for `t_trip_rocof` | 2.5 Hz/s, 0.1 s |
| 6 | harmonics       | `sqrt(u5^2 + u7^2)/u1 > h_max` for `t_trip_h` | 10 %, 0.1 s |

`u1`, `u5`, `u7` are the amplitudes of the positive-sequence fundamental, the negative-sequence 5th
and the positive-sequence 7th harmonic (the two an inverter with dead time or a non-linear load
produces most), measured as the model measures the 7th harmonic: alpha/beta turned with the matching
multiple of the PLL angle and averaged over one grid period. The frequency is the PLL pulsation
through a first-order low pass (`tau_f`); the ROCOF is the velocity state of a double-integrator
observer on it (`obs_poles`). The frequency and harmonic criteria are blocked while
`u1 < u_valid` (a PLL in a deep dip is not a frequency meter): a grid fault is the job of
`frt_vde4110`. The slow under-voltage stage (2.7 s) is what lets the converter ride through a fault
without an islanding trip; the harmonic threshold must stay above the background distortion of the
grid (EN 50160 allows 6 % 5th and 5 % 7th harmonic). Limit of any passive method: when the local load
takes exactly the active and reactive power of the converter, voltage and frequency do not move and
only the harmonics can tell (non-detection zone).

## Parameter struct p

One struct for the five blocks, `p = afe_uvw_ctrl_param_example(ts, f_nom)` (defaults 125 µs and
50 Hz: the control period of the model, 4 kHz PWM with double update). Copy the file next to your
model, change the numbers, keep the field names. The names in brackets are those of the model
(`ctrl_afe_setup`, `frt_settings`, `setup_global_filters`, `init_model.m`).

| Field | Default | Meaning |
|-------|---------|---------|
| `ts` | 125e-6 | control period [s], the integration step of every block |
| `omega_nom` | 2π·50 | nominal grid pulsation [rad/s], base of `omega_pu` |
| `vseq.avg_order`, `iseq.avg_order` | 2 | window = grid period / avg_order (`mavg_order`) |
| `vseq.omega_pu_min/max`, `iseq.*` | 0.1, 2 | limits of the pulsation used for the window |
| `vseq.t_enable`, `iseq.t_enable` | 0.025 | averages are zero before this time (`dmavg_filter_enable_time`) |
| `iseq.kp_pos`, `iseq.ki_pos` | 0.25, 35 | PI of the positive-sequence eta grid current (`kp_rc_pos_grid`, `ki_rc_pos_grid`) |
| `iseq.kp_neg`, `iseq.ki_neg` | 0.25, 35 | PI of the negative-sequence currents (`kp_rc_neg_grid`, `ki_rc_neg_grid`) |
| `iseq.lim_pos_eta`, `lim_neg_xi`, `lim_neg_eta` | 1, 1, 0.5 | limits of the stack current references (`ieta_pos_ref_lim`, `ieta_neg_ref_lim`) |
| `iseq.err_sign` | -1 | sign of the control error (see above) |
| `frt.obs_poles`, `obs_kx`, `obs_kv` | [-0.1 -0.4]·ω, gains | voltage-rate observers (`vr_obs`) |
| `frt.t_obs_release` | 0.025 | observers held at zero before this time (`time_release`) |
| `frt.v_pos_low`, `v_pos_high`, `v_hyst` | 0.85, 1.15, 0.1 | detection band and hysteresis (`LVRT_VPOS_TH_LOW/HIGH`, `LVRT_SEQ_DETECTION_HYST`) |
| `frt.v_neg_max` | 0.1 | negative sequence above this is a fault (`LVRT_VNEG_TH`) |
| `frt.v_pos_dot_max`, `v_neg_dot_max` | 2, 2 | the voltage must also change faster than this [pu/s] (`LVRT_V*_DOT_TH`) |
| `frt.t_rearm`, `t_hold_max` | 0.125, 7.625 | idle time before a new detection, longest fault [s] (1000 and 61000 samples) |
| `frt.pwrlim_v_pos`, `pwrlim_v_neg`, `pwrlim_hyst`, `pwrlim_v_neg_release` | 0.8, 0.1, 0.1, 0.7 | power limitation flag (`LVRT_VPOS/VNEG_PWRLIM_TH`; the model releases at `LVRT_VPOS_PWRLIM_TH - hyst`) |
| `frt.reddyn_enabled`, `reddyn_v_pos`, `reddyn_v_neg` | 0, 0.7, 0.2 | reduced dynamic support (`LVRT_V*_RED_DYN_TH`) |
| `frt.k_frt_ref` | 2 | reactive current per voltage change [pu/pu] (`frt_settings.k_frt_ref`) |
| `frt.t_avg_prefault`, `t_avg_start` | 0.5, 0.05 | pre-fault average window and start [s] (`avg_flt_500ms`) |
| `frt.lim_pos_eta`, `lim_neg_xi`, `lim_neg_eta`, `lim_*_red` | 1, 0.5, 0.5, 0.1 | limits of the references (`i_grid_*_lim`, `i_grid_*_red_lim`) |
| `frt.f_lpf_ref` | 161 | low pass of the references [Hz] (`g0_161Hz`) |
| `ictrl.kp`, `ictrl.ki` | 0.6, 35 | resonant PI (`res_pi.kp_rpi`, `ki_rpi`, the LVRT setting of `init_model.m`) |
| `ictrl.delta_res`, `omega_res` | 0.015, ω | damping and pulsation of the resonator |
| `ictrl.mag_lim`, `mag_scale_max` | 1, 10 | vector limiter |
| `ictrl.out_delay` | 1 | one-step output delay as the model (0: none) |
| `ictrl.kp_z`, `ki_z`, `u_z_lim`, `iz_ref` | 0.5, 18, 1, 0 | zero-sequence current PI (`kp_is_z`, `ki_is_z`) |
| `island.*` | see the table above | thresholds and delays; `h_avg_order` 1, `omega_pu_min/max` 0.5/1.5, `t_enable` 0.1 s, `tau_f` 0.02 s, `obs_poles` [-20 -80] rad/s, `u_valid` 0.5, `latch` 1 |

## Sample time and where to put the blocks

The blocks inherit their sample time and integrate with `p.ts`: they must run once per `p.ts`.
In the model this is the triggered subsystem `afe_control` (trigger from the PWM carrier, double
update). In a new model use the same kind of subsystem, or a fixed-step discrete model with step
`p.ts` (the test bench). Do not drop them into a continuous-time model as they are: an inherited
sample time would then be continuous and the discrete integrators wrong.

States live in `persistent` variables and start from zero at the start of the simulation (the moving
averages fill up from the first sample; `t_enable`, `t_obs_release` and `t_avg_start` count from
there).

## How the code was checked

**Against the model, without MATLAB** (`tools/check_afe_uvw_ctrl.py`): a Python twin of the block
diagrams of the model (`dmavgflt_process`, `LVRT_detector`, `linear_double_integrator_observer`,
`avg_flt`, `u_161Hz_flt`, the resonant PIs, `antiwind_up`, `zero_sequence_current_ctrl`, written block
by block from the `.slx` and the library sources) and the five functions (GNU Octave) run on the same
inputs for 1.2 s: 50.2 Hz grid with 2 % 7th and 1.5 % 5th harmonic, a dip to 0.55 pu with 0.25 pu
negative sequence at 0.75–0.90 s, grid current and reference steps. The comparison is done twice: in
the chain (each implementation on its own signals, as the model) and block by block (the twin reads
the signals of the new code at the block borders, so that each block sees the same inputs).

| Signal | Block by block, max difference (t > 0.05 s) | Note |
|--------|-------------------------------------------:|------|
| `ug_ab`, `v_seq`, `i_seq`, `is_xe` | 4e-16 | same transformations |
| `v_seq_avg`, `i_seq_avg` | 3e-3 at the dip edges, 2e-4 in steady state | different moving average (see below) |
| `v_pos_dot`, `v_neg_dot` (observers) | 7e-14 | |
| `frt_active`, `pwr_lim_enable` | same edges (0.75488 s and 0.90813 s) | |
| `i_grid_ref` | 5e-4 (pos_eta), 5e-8 (neg) | pre-fault average one sample apart |
| `i_stack_ref` (PIs) | 4e-14 | |
| `u_abg`, `i_abc_ref` (current control) | 4e-13 | |

In the chain the small differences of the averages propagate: 5e-3 on `i_grid_ref` at the dip edges,
and the PI integrators of the open-loop scenario keep a 9e-3 offset from the start-up until the first
saturation. Figure: `check_afe_uvw_ctrl.png` (project files of the thread).

**The test bench in a loop** (`test/afe_uvw_ctrl_test_loop.m`, run in GNU Octave 8.4): the 14
behaviour checks of `afe_uvw_ctrl_test_run.m` pass (fault detected 5 ms after the dip start and
released 8 ms after its end, power limitation set, FRT reference −0.80 pu reached within 3e-3, grid
eta current on its reference within 5e-5 before the dip and within 0.02 at the end of the dip, xi stack
current on −0.85 within 6e-3, zero-sequence current 7e-13, islanding detected 0.14 s after the start of
the 6 Hz/s frequency ramp by the ROCOF criterion and not by the dip). The Simulink run of the bench
and the check "blocks = functions" need MATLAB.

## Differences from the model

- **Moving average.** `dmavgflt_process` (the MATLAB port of the C `mavgflt`) averages the samples up
  to the previous one and starts from an implicit zero sample; the new `moving_average_frac` includes
  the present sample and is unbiased during the fill-up. Same steady-state value (within the 2ω
  residual, 2e-4), one sample of lead, no start-up transient.
- **Pre-fault averages of the FRT** start at `p.frt.t_avg_start` (0.05 s) instead of 0: the model's
  average takes the zeros and the start-up transient of the sequence averages into its 0.5 s window,
  which puts an offset of 1e-2 on the negative-sequence references of a fault in the first second.
- **`frt_state` in `frt_log`** is the state after the update of the step (the model reports the state
  of the previous step). `frt_active` and `pwr_lim_enable` have the same timing as the model.
- **Power-limitation release**: the model releases on `|v_neg| < LVRT_VPOS_PWRLIM_TH - hyst` = 0.7
  (its block diagram, probably a slip); kept as `p.frt.pwrlim_v_neg_release = 0.7`, a tighter release
  would be e.g. 0.05.
- **Reduced dynamic support** is a parameter (`p.frt.reddyn_enabled`, default 0) instead of the
  constant 0 of the model.
- **Islanding detector** is new: the model only measured the 7th harmonic and terminated it.
- The feed-forward of the grid voltage, the DC-link control, the PLL and the modulator are not part of
  these blocks (as they are not part of the replaced subsystems).

## Using the blocks in afe_uvw_three_phase

The model `afe_rst_ctrl.slx` of `foundations_of_power_electronics/afe_uvw_three_phase`
(pwr-control/modelization-and-control) uses the five blocks inside `afe_control`, all with the mask
parameter `param.afe.uvw`: `grid_voltage_sequences` takes `ugd_abc_pu`, `phase_grid_pll` and
`omega_grid_pll_pu` (absolute value limited to 0.1...2 pu); `frt_vde4110` takes its `v_seq_avg`,
`[i_react_pos_ref; i_react_neg_ref]`, the enable step at `param.frt.data.settle_time` and a reset
pulse at 25 ms, and gives `pwr_lim_enable` to the DC-link controller; `grid_current_sequences_q_ctrl`
takes `ig_abc_pu`, the same angle and pulsation and `i_grid_seq_ref`; `current_ctrl_uvw` takes the xi
reference of the DC-link controller, `i_stack_ref` = `[i_stack_pos_eta_ref; i_stack_neg_xi_ref;
i_stack_neg_eta_ref]`, `isd_abc_pu` and the angle, and its `u_abg` goes to the modulator. The section
"Control in uvw" of `init_model.m` builds `param.afe.uvw` field by field from the numbers of the model
(`param.afe.ctrl` from `ctrl_afe_setup`, `param.frt.data`, `param.ctrl`); they are the same numbers as
`afe_uvw_ctrl_param_example(param.glb_time.ts_afe, param.grid.fgrid)`, which can be used instead as a
start.

## Changing the code

Edit the file in `src/`, then either run `update_afe_uvw_ctrl` in MATLAB (loads the sources into the
blocks of the library and of the test bench and saves both) or run `python3 tools/make_afe_uvw_ctrl.py`
(rewrites both files from scratch and checks them: use it after a change of the ports or of the
masks). Keep the function signature as `function [outputs] = name(inputs, p)`: the port inputs first,
the mask parameter last, as Simulink requires for a parameter of a MATLAB Function block. Commit the
source together with the `.slx`.

## Test bench

`afe_uvw_ctrl_test_run` (folder with `src/` and `test/` on the path) runs `test/test_afe_uvw_ctrl.slx`
and the same functions in a MATLAB loop for 1.6 s and prints 15 checks: the model and the loop give the
same log (the blocks are the functions), the FRT detects the dip (0.75–0.90 s, 0.55 pu with 0.25 pu
negative sequence) and asks for the right reactive current, the Q loops follow the references in normal
operation and during the fault, the resonant control tracks the active current, the zero-sequence PI
cancels a 0.02 pu DC offset of the plant, and the islanding detector ignores the dip but trips on the
frequency ramp of 6 Hz/s that starts at 1.15 s (ROCOF criterion, then over-frequency). The plant is
three RL branches (`x_l` 0.1 pu, `r` 0.01 pu) and the converter voltage includes the measured grid
voltage (`tb.k_ff = 1`, the feed-forward a modulator adds; set it to 0 to see the inner loop alone, as
in the model). The grid current of the bench is minus the stack current (`p.iseq.err_sign = -1`).
