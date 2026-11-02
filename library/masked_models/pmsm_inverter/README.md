# `pmsm_inverter` — PMSM inverter in one block

Rev. 00, 2026-11-02.

The inverter of a permanent magnet synchronous machine (PMSM) as one masked block, like
`grid_forming_dqctrl` and `grid_following_dqctrl`: the power stage is a Simscape component, the whole
control with the PWM is one MATLAB Function, so one inverter is a handful of non-virtual blocks and runs
fast inside bigger systems.

- **The machine is not in the block.** Connect any machine model to `u`, `v`, `w` (for example the library
  block `permanent_magnet_synchronous_machine`, as in the test bench).
- **Hardware = the AFE hardware.** The power stage is the same Simscape component as the grid-forming block,
  `afe_ssc.afe_two_level_lcl` of [`../../foundation/pwr_electronics`](../../foundation/pwr_electronics):
  ideal two-level bridge, DC-link capacitor, LCL filter. Only the control is new.
- **L or LC output filter with the same block.** Normal case, L filter: `p.hw.Rcf` very high (1e5 Ω, the
  capacitor branch carries a few mA) and the second inductor reduced to a small leakage (`p.hw.L2p = 0`,
  `p.hw.L20 = 0`, `p.hw.Lls2 = 1 µH`; it must stay above zero). LC filter: `p.hw.Cf`, `p.hw.Rcf` with a real
  damping resistor.
- **Two sensorless observers and the encoder.** `p.ctrl.angle_src` = 0 encoder, 1 back-EMF observer
  (active flux), 2 extended Kalman filter (EKF). All three always run, so the log shows the three angles.

The control is the field-oriented control of the study model `inv_psm` of pwr-control/modelization-and-control
(`foundations_of_power_electronics/inv_psm`), written again as one function, with the corrections listed
below.

## Files

| File | Content |
|---|---|
| `pmsm_inverter_dqctrl.slx` | library, block `pmsm_inverter_dqctrl_mod1` |
| `private/pmsm_dq_ctrl_pwm.m` | source of the MATLAB Function (control, PWM, observers); the header documents the algorithm |
| `pmsm_inverter_param_example.m` | example parameter struct `p` (and machine data `mach`): one 267 kW system of the wind generator of `inv_psm` |
| `pmsm_inverter_log_index.m` | indices of the output `ctrl_log` (44×1) |
| `update_pmsm_inverter_dqctrl.m` | loads `private/pmsm_dq_ctrl_pwm.m` into the block (MATLAB) |
| `tools/make_pmsm_inverter_dqctrl.py` | makes the library without MATLAB from `../grid_forming/grid_forming_dqctrl.slx` (python3), with 40 structure checks |
| `tools/make_test_pmsm_inverter.py` | makes the test bench `test/test_pmsm_inverter.slx` (python3, uses `slxlib.py` of `../semiconductors_bridges/tools`) |
| `test/test_pmsm_inverter.slx` | test bench: DC source, inverter, library PMSM, shaft on a velocity source |
| `test/pmsm_inverter_test_param.m` | parameters of the test cases (`tb`, `p_inv`, `mach`) |
| `test/pmsm_inverter_test_run.m` | runs the cases, checks them (PASS/FAIL table) and plots them |

## Ports

| Port | Side | Content |
|---|---|---|
| `Udc(+)`, `Udc(-)` | left (physical) | DC link (the block has its own DC-link capacitor `p.hw.Cdc`) |
| `u`, `v`, `w` | right (physical) | to the machine (output of the filter) |
| `t_master` | input 1 | master time [s] (a Clock) |
| `ref` | input 2, 2×1 | `[enable; reference]`: `enable > 0.5` lets the bridge switch (after `p.ctrl.t_enable`); `reference` = torque [pu] (`mode` 0), speed [pu] (`mode` 1) or scale of the torque curve (`mode` 2, 1 = curve as given) |
| `enc` | input 3 | electrical rotor angle [rad] from an encoder: angle of the magnet flux (d axis) from the axis of phase u. Ground it when the machine has no encoder (then do not use `angle_src = 0` or `omega_th > 0`) |
| `m` | output 1, 17×1 | measurements of `afe_two_level_lcl` in pu, as in `grid_forming_dqctrl`: `m(1:3)` converter current, `m(4:6)` filter capacitor voltage, `m(7:9)` output current (towards the machine), `m(10:12)` terminal voltage without zero sequence, `m(13)` vdc/udc_nom, `m(14)` DC-link capacitor current, `m(15:17)` filter capacitor currents |
| `ctrl_log` | output 2, 44×1 | control signals, indices in `pmsm_inverter_log_index.m` (angles and speeds of the three observers, their angle errors against the encoder, currents and references, voltages, duties, …) |

`m`, `ref` and `enc` reach the control through Unit Delays of one step `p.pwm.tc` (`meas_delay`,
`ref_delay`, `enc_delay`): no algebraic loop, also when `ref` or `enc` come from the Simscape network (the
encoder angle of the machine, an outer controller on a measured quantity).

## Parameter `p`

One numeric struct with three fields, see `pmsm_inverter_param_example.m` (copy it next to your model,
change the numbers, keep the field names):

- `p.hw` — parameters of `afe_ssc.afe_two_level_lcl` (same names as in `grid_forming_param_example.m`).
  **`p.hw.ubez` and `p.hw.ibez` are the bases of the machine** (peak rated phase back-EMF `psi_m*omega_b`,
  peak rated current): the measurements `m` and the control work in these per unit.
- `p.pwm` — step `tc` (must equal the step of the Simscape local solver), carrier `fpwm`, `double_update`,
  `dead_time`, gate voltages, duty limits; as the grid-forming block.
- `p.ctrl` — control: base pulsation `omega_b` (electrical), machine model `rs`, `ld`, `lq`, `psi_m` in pu,
  `mode`, `angle_src`, `omega_th`, `t_enable`, `mtpa`, limits, gains of the current and speed loops, torque
  curve, observer settings. Every field is commented in the example file.

Per unit: currents of `p.hw.ibez`, voltages of `p.hw.ubez`, flux of `p.hw.ubez/p.ctrl.omega_b`, speed of
`p.ctrl.omega_b` (electrical; equal to mechanical in pu), torque of `3/2*pole_pairs*(p.hw.ubez/p.ctrl.omega_b)*p.hw.ibez`
(so that torque = psi·i in pu). With the bases of the machine `p.ctrl.psi_m = 1`.

## How to use it

1. Put `library/masked_models/pmsm_inverter` on the MATLAB path (`addpath(genpath(...))` of the library
   adds it) and build the Simscape library `afe_ssc_lib` once (`ssc_build afe_ssc` in
   `library/foundation/pwr_electronics`), as for the AFE blocks.
2. Make the struct: `[p_inv, mach] = pmsm_inverter_param_example(tc)` (L filter) or
   `pmsm_inverter_param_example(tc, 'LC')`, then change the numbers of your machine and inverter.
3. Drop `pmsm_inverter_dqctrl_mod1` into the model, set its mask parameter (default `param.inv_mod(1)`)
   to your struct, connect `Udc(+)/Udc(-)` to the DC link and `u/v/w` to the machine.
4. Clock to `t_master`, `[enable; reference]` to `ref`, the encoder angle to `enc` (or ground it).
5. Solver Configuration of the network: local solver (Backward Euler) with sample time `p.pwm.tc`.

The test bench `test/test_pmsm_inverter.slx` is a working example of all this.

## Control

Every step `tc` the function makes the local clock, the carrier and the TRGO flag (as `grid_forming_dqctrl`:
same clock alignment, carrier, triggers, gates). On each rising edge of TRGO (every 125 µs at 4 kHz with
double update) it runs the control period:

- **Timing.** The samples taken at a trigger are used at the next one (one period of computation); the
  voltage computed at trigger k is applied from t(k) to t(k+1). The observers predict from t(k-2) to t(k-1)
  with the voltage really applied there and correct with the sample of t(k-1); the inverse Park transform
  uses `theta + 1.5*omega*omega_b*ts` (`k_delay = 1.5`, middle of the next period).
- **Applied voltage.** From the duties actually applied, the measured vdc and the dead time
  (`-sign(i)*dead_time*fpwm*vdc`, sign of the reference current with a band `dt_band`). With the gates off,
  the measured terminal voltage.
- **Encoder.** Tracking loop (PLL, double integrator, poles `pll_poles`) on the encoder angle.
- **Back-EMF observer** [1, 2]. Active flux `psi_a = ∫(u - R·i) - L·i`, with the filter inductors split
  (`L1·i1 + (L2 + Lq)·i2`: exact also with an LC filter), slowly corrected towards the model flux
  `psi_m + (Ld - Lq)·i_d` along the angle of its own PLL (gain `bemf_fb`; this replaces a pure integrator and
  needs no leak, so no angle error in steady state); PLL on the angle of `psi_a`. With the gates off the
  terminal voltage is the back-EMF itself: the PLL tracks its angle - 90° (+90° backwards) and the flux is
  set along it, so the observer is locked when the bridge starts (flying start).
- **EKF** [3]. Five states `[i_alpha; i_beta; psi_a_alpha; psi_a_beta; omega]` in pu on the active-flux
  model with `L = Lq + L1 + L2`, prediction with the second-order Taylor series, Joseph form of the update
  (as `ekf_im_step` of the library). The filter capacitor current is neglected (exact with the L filter).
- **Angle source.** `angle_src` selects the angle and speed used by the control. With `omega_th > 0` the
  encoder is used below `omega_th` (hysteresis 20 %) and the sensorless observers are reset to the encoder
  state every period meanwhile, so they take over from the right angle (start from standstill).
- **Torque.** `mode` 0: torque reference; 1: speed PI (back-calculation anti-windup on the applied torque,
  filter of the reference `w_ref_fc` and of the speed `w_flt_fc`); 2: torque curve `curve_w/curve_T` of the
  filtered speed, braking (generator), scaled by the reference. Then limit `torque_lim` and slew rate
  `torque_slew`.
- **Currents.** MTPA [4] (`mtpa = 1`, `|i_d| ≤ id_max`) or `i_d = 0`; current vector limit `i_lim` with
  priority to `i_q`.
- **Current loop.** dq vector PI of the grid-forming block (limiter of radius `u_lim` = linear range of the
  modulator, leak of the integrators while clipped) on the output current `i2`, feed-forward of the
  back-EMF and of the cross-coupling (`ff = 1`), division by the measured vdc. Example: crossover 250 Hz,
  PI zero at 31 Hz, plant `L = Lq + L1 + L2`.
- **Modulator.** SVPWM (`sv_pwm_cm` of the grid-forming block) and dead-time compensation [5]
  (`dt_comp = 1`).
- **Gates off** (`ref(1) < 0.5` or `t_master < t_enable`): PIs and torque held at zero, the observers follow
  the turning machine on its terminal voltage; when the gates go on the control starts on the angle of the
  selected observer with the back-EMF feed-forward.

### Differences from `inv_psm`

The design check of `inv_psm` (November 2026, modelization-and-control PR #21) found these points; here
they are solved by construction:

1. MTPA: the `inv_psm` block used a wrong gain and the speed as input, `i_d` stuck at -0.35 pu (+6 %
   torque). Here the MTPA law of [4] is solved for the requested torque (4 fixed-point iterations).
2. Angle source switch: two inputs of `switch_enc2obs` were swapped (the "sensorless" case used the encoder
   speed). Here one parameter, `angle_src`, and the log shows all three observers.
3. EKF: the prediction lacked `omega_bez` on one path (speed estimate 1.6 % low, angle error about -3° at
   rated load). Here the EKF works on the active-flux model in pu with the voltage really applied and the
   total inductance `Lq + L1 + L2`.
4. Current loop: `kp 0.25 / ki 35` gave 13-14 Hz and 32-35° of phase margin. Here 250 Hz with about 65° of
   phase margin with the 1.5 periods of delay, plus delay compensation of the angle.
5. Back-EMF observer: the leak `emf_p = 0.08` of `inv_psm` gives about 4° of angle error; here the
   correction towards the model flux replaces the leak (`bemf_leak = 0`).
6. New: dead-time compensation, applied-voltage estimate from the duties and the measured vdc, flying start
   with the gates off, encoder hand-over at low speed.

## Checks done (without MATLAB)

- **Library file.** `tools/make_pmsm_inverter_dqctrl.py` copies `grid_forming_dqctrl.slx` part by part and
  runs 40 checks: package, ports and port counts, lines, unchanged power stage, the Stateflow id rules that
  made MATLAB R2026b crash in an earlier hand-made library (chart id, instance id = chart id + objects + 1,
  target id last, parameter after the port inputs, sorted S-Function parameters), script = source file.
- **Control code.** `private/pmsm_dq_ctrl_pwm.m` runs in GNU Octave in a twin of the plant written in Python
  (switched ideal bridge with dead time, L or LC filter, PMSM in dq with `Lmu`, speed source or inertia):
  gates and logs of the MATLAB code and of the Python port agree to 1e-14 (back-EMF, EKF, LC, speed cases).
- **Results of the twin** (example parameters, 1070 V):
  - rated point on the torque curve (×1.15 as `inv_psm`): angle error below 0.1° with all three sources,
    torque -1.005 pu as requested;
  - torque step: rise time 1.6 ms, 3 % overshoot; large steps are limited by the voltage;
  - speed control from standstill with encoder hand-over: largest angle error 0.65° (encoder), 1.7°
    (back-EMF), 4.2° (EKF) during the hand-over; the speed PI of `inv_psm` (kept as example) overshoots
    about 18 %;
  - flying start from 0.19 pu to 1 pu and backwards: back-EMF observer and EKF lock before the gates go on;
  - the three cases of the test bench (below): all checks pass, angle error in the last 0.1 s 0.27°
    (back-EMF) and 0.12° (EKF), torque = reference, torque reference = curve within 0.003 pu, largest current
    0.88 pu (generator) and 1.04 pu (torque steps).
- **Not done here:** compile and run in Simulink. Please run `test/pmsm_inverter_test_run.m`.

## Limits and advice

- **Machine model accuracy matters most for Lq**: +20 % error on `lq` gives about 10° of angle error at
  rated current (both observers; inherent to model-based observers). An error on `psi_m` shifts the
  back-EMF observer by 1-3.5° and the torque (open loop); the EKF is robust to it. `rs` ±50 %: negligible.
- **No field weakening.** The current loop needs `vdc/sqrt(3)` above about 472 V peak at the rated point of
  the example (vdc about 820 V or more); with less the voltage clips and the torque falls short.
- **LC filter needs damping.** With the example (75 µF, 1.2 kHz resonance with the 230 µH and the machine)
  `Rcf = 0.5 Ω` (ζ ≈ 0.15) works; 0.2 Ω is marginal with the EKF, 0.05 Ω does not work. The current loop
  runs on the machine current `i2`.
- **Sensorless at low speed.** Both observers need speed: start the bridge above about 0.1 pu, or use the
  encoder (`angle_src = 0`) or the hand-over (`omega_th > 0`) at standstill and low speed.
- **Speed loop** (`mode` 1): the gains of `inv_psm` (2.5 / 18) are kept in the example; they overshoot
  about 18 % with the example inertia. Tune them for your shaft.
- The test bench imposes the speed with a velocity source, so it does not test `mode` 1 (checked in the
  Python twin only).

## Test bench

`test/test_pmsm_inverter.slx`: DC source `tb.Vdc` with series `tb.Rdc` → inverter → library PMSM (one
system of WindGen, 104 poles), shaft on an ideal angular velocity source (speed profile, filtered 10 ms).
References from 1-D lookup tables of the time, encoder = `phase_elec` of the machine. Logged every 20 µs
(`ctrl_log`, `m_log`, `mach_log`). The machine model uses the custom Simscape unit `percent`:
`pmsm_inverter_test_param` registers it (`pm_addunit('percent', 0.01, '1')`, as the `init_model.m` of the
models of modelization-and-control).

```matlab
pmsm_inverter_test_run                                           % all cases, table and plots
[tb, p_inv, mach] = pmsm_inverter_test_param('generator_ekf');   % or one case by hand,
open_system('test_pmsm_inverter')                                % then press Run
```

| Case | Filter | Angle | Mode | Profile | Checks |
|---|---|---|---|---|---|
| `generator_bemf` | L | back-EMF | torque curve | 0.5 pu, bridge on at 50 ms (flying start), ramp to 1 pu 0.15-0.45 s, stop 0.7 s | last 0.1 s: angle error < 3°, torque = reference ± 0.03 pu, reference = curve ± 0.05 pu, vdc ± 5 % |
| `generator_ekf` | L | EKF | torque curve | same | same |
| `torque_steps_lc` | LC | encoder | torque | 0.8 pu, steps 0 → -0.5 → +0.5 → -1 pu every 0.1 s | torque = reference ± 0.03 pu at the end of each step |

All cases also check the current vector (below `i_lim + 0.1` after the start).

## Changing the block

- **Control code**: edit `private/pmsm_dq_ctrl_pwm.m`, run `update_pmsm_inverter_dqctrl` in MATLAB, commit
  the source and the `.slx`. Keep `ctrl_log` and `pmsm_inverter_log_index.m` in step.
- **Ports or power stage**: `python3 tools/make_pmsm_inverter_dqctrl.py` makes the library again from
  `grid_forming_dqctrl.slx` and the source file (it overwrites what was changed in MATLAB, e.g. the mask).
- **Test bench**: `python3 tools/make_test_pmsm_inverter.py`.

## References

1. I. Boldea, M. C. Paicu, G.-D. Andreescu, "Active flux concept for motion-sensorless unified AC drives,"
   IEEE Trans. Power Electron., vol. 23, no. 5, pp. 2612-2618, 2008.
2. J. Hu, B. Wu, "New integration algorithms for estimating motor flux over a wide speed range," IEEE Trans.
   Power Electron., vol. 13, no. 5, pp. 969-977, 1998.
3. S. Bolognani, R. Oboe, M. Zigliotto, "Sensorless full-digital PMSM drive with EKF estimation of speed and
   rotor position," IEEE Trans. Ind. Electron., vol. 46, no. 1, pp. 184-191, 1999.
4. S. Morimoto, Y. Takeda, T. Hirasa, K. Taniguchi, "Expansion of operating limits for permanent magnet
   motor by current vector control considering inverter capacity," IEEE Trans. Ind. Appl., vol. 26, no. 5,
   pp. 866-871, 1990.
5. T. Sukegawa, K. Kamiyama, K. Mizuno, T. Matsui, T. Okuyama, "Fully digital, vector-controlled PWM VSI-fed
   ac drives with an inverter dead-time compensation strategy," IEEE Trans. Ind. Appl., vol. 27, no. 3,
   pp. 552-559, 1991.
