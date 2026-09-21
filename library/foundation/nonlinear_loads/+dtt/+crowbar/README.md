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
