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
