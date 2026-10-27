# Foundation — Simscape language components

Physical models written in Simscape language (`.ssc`), grouped by domain. Each component lives in
its own `+package` folder and is compiled into the `<package>_lib.slx` file next to it, which is
the Simulink library holding the block.

Rebuild a component after editing it:

```matlab
cd library/foundation/<domain>
ssc_build <package>
```

Several components are documented in detail in [`../documentation`](../documentation).

---

## `semiconductors`

Device models at two levels: **switching dynamics** (waveform shape, no losses) and **simplified
with thermal ports** (losses and temperatures, no transient).

- **`igbt_dyn`** — Behavioural IGBT for turn-on/turn-off transients: square-law channel with smooth
  saturation, constant Cge, charge-based nonlinear Miller and output capacitances, internal gate
  resistance, charge-based tail current. No losses; the antiparallel diode is separate, pair it
  with `diode_rr`.
- **`mos_dyn`** — Power MOSFET (Si or SiC) switching transients: symmetric channel conducting in
  both quadrants, nonlinear Cgd with oxide clamp, nonlinear Cds, intrinsic body diode with
  Lauritzen-Ma charge dynamics, gate/drain/source parasitics including common-source inductance
  feedback, optional avalanche clamp. No losses, no thermal port.
- **`diode_rr`** — Charge-controlled diode (Lauritzen-Ma): Irr, trr and recovery softness emerge
  from the circuit di/dt instead of being imposed. Includes SPICE depletion capacitance and a
  reverse leakage resistance for static voltage sharing in series stacks.
- **`igbt_simple`** — IGBT with antiparallel diode as two conduction branches (Vce_sat, Vf, Ron,
  Rd). Conduction only, no switching energies, no thermal ports.
- **`igbt_simple_2th`** — Same conduction model with single-point switching energies
  (Eon, Eoff, Err at a reference current and voltage, scaled linearly) dissipated on two thermal
  ports, `Ht` for the IGBT chip and `Hd` for the free-wheeling diode. Sample-and-hold states
  recover the commutated current and blocking voltage; Err is attributed locally by detecting the
  recovery event. Defaults: Mitsubishi CM1200DW-34T.
- **`mos_simple_2th`** — MOSFET counterpart: resistive channel with optional temperature
  coefficient (closing the electrothermal loop), third-quadrant conduction falling out of the
  parallel channel/diode branches, `two_die` selecting whether diode losses go to `Hd` or `Ht`.
  The package carries its own README with the interface and sign conventions.
- **`thyristor_rr`** — Thyristor with piecewise-linear static characteristic plus Lauritzen-Ma
  charge dynamics: latching and holding logic, spontaneous re-fire on residual excess charge, and
  a tq constraint. Defaults: ABB 5STP 26N6500.
- **`thyristor_selftrig`** — Thyristor with the explicit passive anode-to-gate self-trigger network
  (coupling capacitor, reset resistor, static break-over path). The `M` output reports which
  mechanism fired the device. No reverse recovery — use `thyristor_rr` for that.
- **`crowbar_bidir`** — Bidirectional self-triggered crowbar: two antiparallel thyristors, each
  with its own floating trigger network, for bypassing a low-impedance element that may open.
  Reports the firing mode and polarity, the I²t and the dissipated energy.
- **`tvs_clamp`** — Bidirectional TVS stack (N series × M parallel) for IGBT active clamping:
  symmetric avalanche with an algebraic smooth knee, dynamic resistance, leakage and junction
  capacitance. Device temperature is a parameter, no self-heating. Defaults: 1.5KE440CA.

## `pwr_electronics`

Reactors with a shared saturation model: a normalized table of differential inductance dψ/di
against the current normalized to the peak base current √2·`i_base`. Set `i_base = inf` to work
with a linear inductor.

- **`singlephase_inductor_with_saturation`** — Series reactor with saturable main inductance,
  non-saturable leakage and winding resistance; outputs the flux linkage.
- **`twolimb_inductor_with_saturation`** — Single-phase reactor with one winding on each limb, i.e.
  half the inductance and half the resistance in each conductor of a two-wire line (split DC-link
  reactors, rectifier output reactors in both poles). Differential-mode current magnetizes the
  core, common-mode current sees only the leakage.
- **`threephase_inductor`** — Linear three-phase reactor with mutual coupling, parameterized by
  positive- and zero-sequence inductance and resistance plus leakage.
- **`threephase_inductor_with_saturation`** — Same topology with per-phase saturation scaling the
  self and mutual inductances independently.

Single-block power stages of the compact converter blocks of [`../masked_models`](../masked_models)
(one converter = one nonvirtual block of power stage, MATLAB Home licence):

- **`afe_ssc`** — `afe_two_level_lcl`: two-level bridge with DC-link capacitor and LCL filter, the power
  stage of `grid_following_dqctrl` and `grid_forming_dqctrl`. Gate commands in as a physical-signal
  vector, measurements out in pu.
- **`afe_ttype_ssc`** — `afe_single_phase_ttype`: single-phase three-level T-type full bridge, the power
  stage of `afe_single_phase_ttype`: split DC link (two capacitor banks in series with their ESR, the
  neutral point internal, `Vdc0/2` on each bank at the start), two T-type legs of four switch +
  antiparallel-diode pairs (outer switches between the DC rails and the midpoint, anti-series pair to
  the neutral point), one inductor per line and the filter capacitor across the terminals. Gates `G`
  [8×1] in, measurements `M` [13×1] in pu out (currents on `ibez`, AC voltages on `ubez`, DC voltages
  on `udc_nom`). Same circuit as `single_phase_inverter_modA` of `sst_cllc_ttype_inv.slx` of
  `pwr-control/solid-state-transformers` without the device and thermal model. Build with
  `ssc_build afe_ttype_ssc` from this folder (`afe_ttype_ssc_lib.slx`, committed next to the package
  once built).
- **`cllc_ssc`** — `cllc_dcx_single_phase`: CLLC resonant DC/DC stage (DC transformer, DCX), the power
  stage of `cllc_dcx`: DC choke and DC-link capacitor on each side, two full bridges of switch +
  antiparallel-diode pairs with optional output capacitance `Coss` (ZVS transitions driven by the tank
  current), symmetrical resonant tank `Lr1`/`Cr1` – `Lr2`/`Cr2`, transformer with magnetizing
  inductance and core-loss resistance (reluctance model, turns `n1:n2`). Gates `G` [8×1] in,
  measurements `M` [15×1] in pu out; the options (`coss_on`, DC-link capacitors, chokes) are
  `cllc_ssc.onoff` enumerations. Same circuit as `sst_cllc_dcx.slx` of
  `pwr-control/solid-state-transformers`. Build with `ssc_build cllc_ssc` from this folder
  (`cllc_ssc_lib.slx`, committed next to the package once built). Documented in
  [`../documentation/cllc_dcx`](../documentation/cllc_dcx) (`cllc_dcx.pdf`, Section 5).
- **`buck_ssc`** — `interleaved_buck_3legs`: three-leg interleaved buck converter, the power stage of
  `interleaved_buck_3legs`: DC-link capacitor with its ESR (`Vdc0` at the start), three buck legs of two
  switch + antiparallel-diode pairs (upper switch between dc+ and the leg output, lower switch between the
  leg output and dc-), one inductor per leg (`L`, `RL` with the per-leg factors `kL`, `kRL` for mismatched
  legs), common output capacitor with its ESR; `out-` is the negative rail `dc-`. Gates `G` [6×1] in
  (upper and lower switch of legs 1, 2, 3), measurements `M` [10×1] in pu out (currents on `ibez`, the
  output voltage on `ubez`, the DC-link voltage on `udc_nom`). Same circuit as `interleaved_buck.slx` of
  `pwr-control/modelization-and-control` without the device and thermal model. Build with
  `ssc_build buck_ssc` from this folder (`buck_ssc_lib.slx`, committed next to the package once built).
- **`boost_ssc`** — `interleaved_boost_3legs`: three-leg interleaved boost converter, the power stage of
  `interleaved_boost_3legs`: the hardware of `buck_ssc.interleaved_buck_3legs` with the power flow
  reversed. Input capacitor with its ESR across the low-voltage terminals (`Vin0` at the start), three
  legs of two switch + antiparallel-diode pairs (upper switch between dc+ and the leg midpoint, the
  synchronous rectifier; lower switch between the midpoint and dc-, the boost switch), one inductor per
  leg from `in+` to the midpoint (`L`, `RL` with the per-leg factors `kL`, `kRL`), DC-link capacitor
  with its ESR (`Vdc0` at the start, = `Vin0` for a link precharged through the upper diodes); `in-` is
  the negative rail `dc-`. Gates `G` [6×1] in (upper and lower switch of legs 1, 2, 3, the order of the
  buck block), measurements `M` [10×1] in pu out (currents on `ibez`, positive from the battery into
  the legs; the input voltage on `uin_nom`, the DC-link voltage on `udc_nom`). Same circuit as
  `interleaved_boost.slx` of `pwr-control/modelization-and-control` without the device and thermal
  model. Build with `ssc_build boost_ssc` from this folder (`boost_ssc_lib.slx`, committed next to the
  package once built).

## `electrical_machines`

- **`im`** — Induction machine in stationary αβ coordinates, current/rotor-flux state form.
- **`im_uvw`** — Induction machine in full three-phase representation with a wide output set
  (phase and dq currents, stator and rotor flux linkages, torque, electrical speed and position).
- **`im_uvw_2`** — `im_uvw` extended with slip-frame quantities, αβ fluxes and an internal PLL
  giving stator pulsation, stator phase and slip phase.
- **`pmsm_alphabeta`** — PMSM in stationary αβ coordinates with saliency and rotating magnet flux
  states.
- **`pmsm_dq2`** — PMSM in rotor dq coordinates driven by `ud`/`uq` physical signals (no electrical
  nodes), salient-pole torque, peak-value convention.
- **`pmsm_uvw`** — PMSM in three-phase representation with position-dependent self and mutual
  inductances and explicit motional terms; linear, quadratic friction and inertia on the shaft.
- **`pmsm_spatial_harmonics_uvw`**, **`pmsm_uvw_with_harmonics`**,
  **`pmsm_uvw_with_harmonics_2`**, **`pmsm_uvw_with_harmonics_3`** — the same machine with spatial
  harmonics in the magnet flux: 5th and 7th, 5th and 7th with αβ outputs and a position-sensor
  `angle_error`, 5th and 11th, and 3rd/5th/7th/11th respectively.
- **`pmsm_dq_controller`** — Per-unit field-oriented controller for the PMSM models: speed and
  current PIs, MTPA reference for salient machines, cross-coupling and back-EMF feedforward,
  anti-windup on the torque limit and a field-weakening PI on the voltage magnitude.
- **`single_phase_transformer`**, **`single_phase_trafo`** — Linear single-phase transformers,
  reluctance-based; the second computes the reluctance from the core geometry.
- **`saturable_single_phase_transformer`** — Reluctance-based transformer with core-loss resistance
  and flux-density output. Note: the magnetic characteristic in the equations is linear; the
  geometry parameters only serve to report `Bc`.
- **`saturable_single_phase_transformer_2`** — Switchable nonlinear magnetization: `en_sat` selects
  between the linear law and an arctangent characteristic that smoothly limits the flux. No
  hysteresis.
- **`three_windings_transformer`** — Three windings on a common core, single flux, linear magnetics.
- **`scott_t`** — Scott-T transformer converting three-phase to a balanced two-phase system
  (main plus teaser at √3/2 turns), parameterized in per unit on the rated power and voltages.
  Secondaries are galvanically separate. Linear magnetizing branch, no saturation or hysteresis.
- **`tri_monophase_transformer`** — Three-phase to single-phase transformer: two star-connected
  primaries wound on the same three-limb core (Yy0, neutrals exposed) and one single-phase
  secondary made of limb coils in series, whose turns distribution on the limbs is a parameter
  (`[1 -1 0]` line-to-line type, `[1 -1/2 -1/2]` T type, `[1 0 0]` single limb, which needs the
  neutral). Positive- and zero-sequence magnetizing inductances, per-limb core-loss resistance,
  parameters in per unit on the single-phase rating; linear magnetics, no saturation. The limb
  flux linkages are outputs. `test_tri_monophase_transformer.m` is a pure-MATLAB steady-state
  check (no-load ratio, load, short circuit, parallel primaries, secondary distributions). The
  block library `tri_monophase_transformer_lib.slx` is not in the repository yet: build it with
  `ssc_build tri_monophase_transformer` from `electrical_machines`. Documented in
  `research/electrical_machines/transformers/tri_monophase_transformer` of
  [repositories-documentation](https://github.com/pwr-control/repositories-documentation).
- **`three_phase_transformer`** — Package with three two-winding three-phase transformers written
  from scratch in Simscape language on a common three-limb core model, one component per connection:
  **`transformer_Dd`** (Dd0/Dd6), **`transformer_Yyn`** (Yyn0/Yyn6, both neutrals N and n exposed)
  and **`transformer_Dyn`** (Dyn11 default, Dyn1/5/7 by `clock_number`, secondary neutral n exposed).
  Each component writes the coil equations explicitly: terminal voltage = R and leakage drop plus
  dψ/dt of the limb, secondary emf `s·n21·dψ/dt` with the limb and the sense of each secondary coil
  fixed by the vector group (this is where the 30° of the Dyn comes from), mmf balance per limb with
  the core-loss current, and the magnetizing matrix `ψ = Lm·im − Lc·Σim`, `Lc = (Lm − Lm0)/3`, i.e.
  `lm` for the positive/negative sequence and `lm0` for the zero sequence (a fraction of a pu for a
  three-limb core, `lm0 = lm` for a bank of single-phase units). Per-unit parameters on `Sr`, `V1`,
  `V2`: the base of a delta coil is `3·V²/Sr`, so the same pu numbers give the same line-side
  behaviour for every connection; `l1 + l2 = ucc/100`, `r1 + r2` = copper losses/Sr, `lm` = rated
  over magnetizing current, `rfe = Sr`/iron losses. Flux linkages of the primary coils are outputs.
  Linear magnetics, no saturation. `check_three_phase_transformer.py` (python3 + numpy, output in
  `check_three_phase_transformer_output.txt`) rebuilds the same equations in the phasor domain and
  checks, against closed-form expectations, the ratio and phase shift of every clock number, the
  no-load and short-circuit quantities, the regulation and the power balance at rated load, the
  neutral shift of the Yyn with a single-phase load (17 % of the phase voltage at 1 pu with
  `lm0 = 0.5` and N floating, 99 % for a bank with `lm0 = lm`, 1.6 % with N grounded), the absence
  of neutral shift and the circulating delta current of the Dyn, and the 2/3–1/3 coil split of a
  line-to-line load on the Dd. `test_three_phase_transformer.m` is the MATLAB port of the same
  check (not run yet). Each component defines the limb voltage `um_k = dψ_k/dt` once and uses it
  algebraically in the coil and mmf equations: Simscape counts every equation that contains `der()`
  as a differential equation and requires as many of them as differentiated variables (9 per
  component), otherwise the model fails to compile with "Total size of differential equations does
  not match the total size of differential variables". The block library
  `three_phase_transformer_lib.slx` is built with `ssc_build three_phase_transformer` from
  `electrical_machines`: rebuild it after every change to the `.ssc` files.

## `batteries`

- **`lithium_ion_cell`** — Equivalent-circuit cell/module with analytical OCV (exponential +
  polynomial + log form), coulomb counting with clamped SOC, one RC overpotential branch and a
  current-driven hysteresis state. No thermal model, no ageing.

## `electrochemical`

- **`pemfc_stack`** — PEM fuel-cell stack: anode and cathode gas dynamics, Nernst voltage, ohmic
  drop and an RC activation/concentration branch. Isothermal, no membrane hydration model.

## `electronics`

- **`opamp_cfa`** — Behavioural macromodel of a wideband, high-output-current current-feedback
  operational amplifier (defaults for the LT1210): input buffer with offset and bias currents and
  a soft common-mode clamp, transimpedance stage with a slew-rate limit, parasitic output pole,
  output buffer with supply-referred clipping and current limit, and supply pins carrying the
  quiescent plus load current so the power balance is consistent.

## `varistors`

- **`varistor_mov`** — Metal-oxide varistor for surge and clamping studies: series inductance and
  bulk resistance feeding a power-law nonlinear resistor with leakage and capacitance. The
  exponent is derived from two datasheet points, so the part is entered as varistor voltage and
  clamping point. Absorbed energy is integrated and optionally checked against the single-pulse
  rating. Defaults: EPCOS SIOV-B80K680. `test_varistor_mov.m` is a pure-MATLAB sanity check.

## `nonlinear_loads`

- **`+dtt`** — Load models for the DTT tokamak divertor in-vessel coils during a plasma
  disruption, all built into a single `dtt_lib.slx`:
  - `div_coil` — one coil as a Thevenin equivalent (R0, L0, two eddy-current loops) driven by the
    plasma-induced e.m.f.;
  - `div_coils3` — the three coils with their mutual inductance matrix;
  - `emf_table` — e.m.f. from a digitized time table;
  - `emf_analytic` — parametrized plasma-flux e.m.f. (flat top, VDE growth, current quench) with
    the passive-structure delay;
  - `plasma_emf` — e.m.f. computed from plasma current and mutual inductance signals.
  - Cable and protection reactor are not included and must be added in series.
  - Documented in [`../documentation/div_load_model`](../documentation/div_load_model).

## `mechanics`

- **`flexshaft`**, **`flexshaft_2masses`** — Two-inertia torsionally flexible shaft (the second
  exposes the torsion torque and the two speeds as outputs).
- **`flexshaft_3masses`** — Three inertias and two elastic spans.
- **`gear`** — Elastic gear pair: the mesh torque is a state driven by the speed mismatch and
  reflected through the ratio. No backlash, no meshing efficiency.
- **`gear2`** — Same with the damping coefficients as physical-signal inputs, so friction can be
  scheduled from outside.
- **`differential_gear`** — Three-shaft differential with an elastic mesh, inertia and viscous
  friction on all three shafts.

## `hydro`

Hydrostatic drivetrain components. Pumps and motors share the same structure: rotor inertia,
viscous friction, turbulent leakage orifice and chamber compressibility.

- Pumps: **`fixed_displacement_pump`**, **`variable_displacement_pump`** (displacement from a
  signal input), **`variable_displacement_pump_2`** (bulk modulus as a parameter),
  **`pressure_controlled_pump`** (with a PI pressure regulator, displacement limits and an internal
  relief valve).
- Motors: **`fixed_displacement_motor`**, **`variable_displacement_motor`**,
  **`variable_displacement_motor_2`** (opposite sign convention on Δp and explicit bulk modulus),
  **`variable_displacement_motor_withTh`** (thermal nodes declared, equations not implemented).
- Valves: **`hydraulic_orifice`** (fixed turbulent orifice), **`check_valve`** (second-order poppet
  with end stops), **`relief_valve`** (linear opening ramp over the regulation range),
  **`shuttle_valve`** and **`inverse_shuttle_valve`** (higher / lower pressure connected to the
  common port), **`fourway_threeland_valve`** (critical centre),
  **`fourway_fourland_valve`** (four metering edges with explicit underlap).
- Actuators: **`bichamber_piston`** and its **`_for_pump`** / **`_for_valve`** variants
  (double-acting cylinder with stroke-dependent chamber volumes; the two variants add end stops).
- Valve + actuator assemblies: **`fourway_fourland_valve_bichamber_piston`**,
  **`hydrostatic_fourway_valve_bichamber_piston`**,
  **`hydrostatic_threeway_valve_bichamber_piston`** (differential piston with the supply acting
  permanently on the rod-side annulus).
- **`linear_swashplate_ctrl`** — Signal-level state-feedback controller for the swashplate
  displacement.
- Note: `variable_displacement_pump_withTh` contains the plain pump source, and
  `pressure_controlled_pump` and `linear_swashplate_ctrl` have no built `_lib.slx`.

## `ice`

- **`engine`**, **`engine_1`**, **`engine_2`** — Diesel engines with hard-coded torque, friction
  and consumption maps: `engine` reports specific consumption in s/J, `engine_1` in g/(kW·h) with
  integrated fuel mass, `engine_2` uses a speed/power consumption map and reports fuel volume.
  All model the throttle as a second-order lag with crankshaft inertia and speed-dependent
  friction.
- **`engine_3`**, **`ice`**, **`ice_torque_consumption`** — Generic engines with the maps exposed
  as parameters instead of hard-coded, so a dataset from
  [`../setup_files/engines`](../setup_files/engines) can be plugged in.
- **`engine_speed_ctrl`**, **`engine_speed_ctrl_ii`**, **`engine_speed_ctrl_kinputs`** — PID speed
  controllers producing throttle, with integral anti-windup and output saturation; the last takes
  the proportional and integral gains as inputs so they can be scheduled at runtime.

## `control_systems`

Benchmark plants and small building blocks used for control design examples.

- **`pendulum_on_a_cart`** — Full nonlinear cart-pendulum dynamics with cart and pivot damping.
- **`segway`** — Two-body inverted-pendulum vehicle with the coupled inertia matrix inverted
  symbolically.
- **`simple_magnetic_bearing`** — One-axis active magnetic bearing with two opposing electromagnets:
  position-dependent inductance, motional EMF, nonlinear attraction force and a runaway limiter.
- **`pm_linear_actuator`** — Voice-coil linear actuator for a spool valve: coil R-L dynamics, back
  EMF, viscous damping and hard travel limits.
- **`lotka_volterra`** — Predator-prey pair with the four coefficients as runtime signals.
- **`pi`** — Generic PI controller with anti-windup and output limits.
- **`vco`** — Voltage-controlled oscillator with electrical input and output ports.
- **`gyro_electrical`** — Ideal lossless electrical gyrator/transformer two-port.
