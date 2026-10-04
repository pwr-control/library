# dtt.crowbar — functional Simscape model of the solution-B crowbar

Sub-package of `+dtt` (put this `+crowbar` folder inside `ssc/+dtt`, then `ssc_build dtt` from the
`ssc` folder: the blocks appear in `dtt_lib` under the sublibrary "crowbar"). No parasitic elements:
piecewise-linear diodes and thyristor, ideal clamp instead of the hysteretic regulator.

| Block (file) | Ports | Purpose |
|---|---|---|
| Diode (functional) `diode_fn` | A, K | placeholder for `diode_rr` |
| Diode Bridge (functional) `diode_bridge` | a, b (AC) ; +, - (DC) | 4 x diode_fn, D1 a->+, D2 b->+, D3 -->a, D4 -->b |
| Thyristor (functional) `thyristor_fn` | A, K ; G (PS in, 0/1) | latching, holding current I_H, gate turn-on above V_on, break-over V_BO (BOD); with G held at 1 it re-fires as soon as forward voltage reappears (maintained gate) |
| RLC Branch `rlc_branch` | +, - ; vC (PS out) | series L-R-C, L = 0 allowed: snubber (0, R2, C2) and peak-holding branch (L2, Rch, Ch) |
| Shunt Regulator (functional) `shunt_regulator` | +, - ; P (PS out) | ideal clamp: conducts through R_reg above V_reg |
| Firing Unit `firing_unit` | i, v, ext (PS in) ; trip, G, stop (PS out) | latched trip on abs(i) > I_th, v > V_th or ext > 0.5; G delayed by t_fire, stop by t_stop (both > 0) |
| Crowbar B (functional) `crowbar_b` | a, b ; i, ext (PS in) ; G, stop, v_x, P_reg (PS out) | the whole DC side assembled: bridge, T, snubber, Ch branch, bleeder Rb, regulator, firing unit, voltage sensor |

## Wiring in the converter model

```
PWM node A  --[L_a 20 uH, yours]--  a |Crowbar B|          i   <-- Current Sensor on the coil (PS)
PWM node B  ------------------------ b |         |          ext <-- Simulink-PS Converter (Step / Constant 0)
                                       |         | G     --> PS-Simulink Converter -> scope (gate state)
                                       |         | stop  --> PS-Simulink Converter -> trig of gate_block (PWM stop)
                                       |         | v_x   --> PS-Simulink Converter -> scope (thyristor voltage)
                                       |         | P_reg --> PS-Simulink Converter -> scope (regulator loss)
```
* `i` = coil (or converter output) current, used for the overcurrent trigger; `ext` = external firing command.
* `stop` goes to the `trig` input of `gate_block` (the MATLAB Function of the PWM); `t_stop` is the
  control latency, `t_fire` the gate-unit delay.
* Set `v0` = DC-link voltage (e.g. 700 V) to start with the peak-holding capacitor already charged and
  skip the energisation transient; `v0` = 0 shows it (bridge current, no overshoot with Rch = 2 ohm).
* The thyristor current and the mode of T and of the firing unit are loggable (ExternalAccess = observe).
* Solver: ode23t/ode23tb, max step 1e-6 s around the firing if the 20 us delays must be resolved.

## Replacing the functional devices by diode_rr / thyristor_rr

Edit the `components` section: in `diode_bridge.ssc` replace `dtt.crowbar.diode_fn(...)` by the class
of `diode_rr` with its parameter names; in `crowbar_b.ssc` replace `dtt.crowbar.thyristor_fn(...)` by
`thyristor_rr`. Port names must stay A, K (and G for the thyristor, a physical-signal gate command);
if `thyristor_rr` takes a gate current in A instead of a 0/1 command, insert a gain in the `G` path
(e.g. a PS Gain block in Simulink, or multiply in the firing unit: `G == I_G*delay(...)`).

## Defaults (crowbar_b)

Vf_d 1.2 V, Ron_d 0.2 mOhm, Goff_d 1e-6 S | Vf_t 1.5 V, Ron_t 0.15 mOhm, I_H 0.5 A, V_on 5 V, V_BO 1100 V |
R2 3 ohm, C2 1 uF | L2 5 uH, Rch 2 ohm, Ch 20 uF, v0 0 | Rb 100 kohm | V_reg 920 V, R_reg 300 ohm |
I_th 7 kA, V_th 1000 V, en_I 1, en_V 1, t_fire 20 us, t_stop 10 us.

## Crowbar C (gate-fired, thyristor_rr) — added 2026-09-23

Bidirectional crowbar of solution C (pre-filter L_Fc / C_Fc1-R_Fc1 / C_Fc2-R_Fc2 in front of it):
two antiparallel `thyristor_rr` (ABB 5STP 50Q1800) fired by the **same** gate command, held for
`t_gate` after the trip. It replaces the two `thyristor_selftrig` blocks with the M->G cross-coupling,
whose passive gate disappears when the partner's current crosses zero (sim_results_7/8: 124 us gap,
re-firing of T2 about 60 us after turn-off, far below t_q = 500 us).

| Block (file) | Ports | Purpose |
|---|---|---|
| Firing Unit (bidirectional) `firing_unit_bidir` | i, v, ext (PS in) ; trip, G [V], stop (PS out) | latched trip on abs(i) > I_th, abs(v) > V_th, abs(v) > V_BO (backup, always on) or ext > 0.5; G = V_G in the window [t_trip + t_fire, t_trip + t_fire + t_gate); stop after t_stop. Event variables + time comparisons, no `delay()` |
| Crowbar C (gate-fired) `crowbar_c` | p, n ; i, ext (PS in) ; trip, stop, G [V], iT1, iT2 (PS out) | T1 p->n, T2 n->p (thyristor_rr), current sensors on each device, voltage sensor p-n, firing_unit_bidir driving both gates |

Paths: `foundation/semiconductors` (package `+thyristor_rr`) and `foundation/nonlinear_loads`
(package `+dtt`) must both be on the MATLAB path; then `ssc_build dtt` from `foundation/nonlinear_loads`.
Note: `thyristor_rr` ports are `a`, `k` (lowercase) and its gate `G` is a physical signal in **volts**
(compared with `Vgt`), which is why the firing unit outputs `G` in V (`V_G` = 10 V).

### Wiring in ps_full_bridge

```
filtered node (+) ---- p |Crowbar C|  i    <-- coil current (PS), or PS Constant 0 with en_I = 0
filtered node (-) ---- n |         |  ext  <-- PS Constant 0 (or a Simulink step for forced firing)
                         |         |  stop --> PS-Simulink -> trig of gate_block (PWM stop), if wanted
                         |         |  iT1, iT2 --> PS-Simulink -> To Workspace (crwbr_1/2 currents)
                         |         |  trip, G --> PS-Simulink -> scopes
```
* `iT1` is positive p->n through T1, `iT2` positive n->p through T2; the crowbar current p->n is
  `iT1 - iT2`. The device states are loggable (ExternalAccess = observe: `T1.on`, `T2.on`, `T1.qM` ...).
* Solver: ode23t / ode23tb, max step about 1e-6 s around the firing; `thyristor_rr` is sensitive to
  large `tau` (a 26N6500 set with tau = 300 us did not run, 50-100 us did); the 50Q1800 set uses 65 us.
* `t_gate` = 10 s keeps both gates on for the whole run (as a pulse train in hardware). Setting
  `t_gate` to a few hundred microseconds reproduces the gap seen with the passive network.
* No RC snubber inside the block: add one across p-n if wanted (its discharge adds to the turn-on di/dt).

### Defaults (crowbar_c)

Thyristors (5STP 50Q1800, Tvj = 125 degC): Vf 0.90 V, Ron 0.050 mOhm, Goff 1.67e-4 S
(I_DRM 300 mA / V_DRM 1800 V), Vgt 2.6 V, Vth 50 V, Il 0.35 A, Ih 0.075 A, tau 65 us, Tm 108 us
(fit: Qrr 2450 uAs, IRM 59 A at IT 2000 A, -1.5 A/us, VR 200 V; tau_rr = 41 us), Qth 1 uC, tq 500 us.
Firing unit: I_th 7 kA, V_th 750 V, V_BO 1100 V, en_I 0, en_V 1, t_fire 5 us, t_gate 10 s,
t_stop 10 us, V_G 10 V.
