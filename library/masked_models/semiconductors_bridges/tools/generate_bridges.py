#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
generate_bridges.py - writes the 18 semiconductor bridge libraries of
library/masked_models/semiconductors_bridges:

    {half_bridge | full_bridge | three_phase_bridge}_{two_level | three_level_ttype}_{ideal_switch | mos_simple_2th | igbt_simple_2th}.slx

Each library holds one masked subsystem with the same name as the file. The switching cells
are full copies (no links inside the library), so a bridge is self-contained apart from the
Simscape Foundation library and, for the 2th versions, igbt_simple_2th_lib / mos_simple_2th_lib
(library/foundation/semiconductors).

Usage:  python3 generate_bridges.py [output_dir]
The files are written in <output_dir>/{half_bridge,full_bridge,three_phase_bridge}/, by default
the folder that contains tools/ (the legacy models of that folder are not touched). Simulink then opens them directly; "save" from Simulink
rewrites them in its own canonical form (the content is the same).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slxlib import System, SidPool, mask_xml, write_slx, pos  # noqa: E402
import sscblocks as sb  # noqa: E402

GITHUB = "https://github.com/pwr-control/library/blob/dev/library/masked_models/semiconductors_bridges"

# ----------------------------------------------------------------------------- mask tables
THERMAL_PARAMS = lambda jh_t, jh_d, cj: [  # noqa: E731
    ("rth_switch_JH_m", "Thermal resistance junction-heatsink, transistor die [K/W]", jh_t),
    ("rth_switch_HA_m", "Thermal resistance heatsink-ambient, transistor die [K/W]", "0.05"),
    ("rth_diode_JH_m", "Thermal resistance junction-heatsink, diode die [K/W]", jh_d),
    ("rth_diode_HA_m", "Thermal resistance heatsink-ambient, diode die [K/W]", "0.05"),
    ("JunctionTermalMass_m", "Junction thermal mass of each die [J/K]", cj),
    ("Tambient_m", "Ambient temperature [degC]", "40"),
    ("mass_heatsink_m", "Heatsink mass seen by each die [kg]", "1"),
    ("specific_heat_m", "Specific heat of the heatsink [J/(K kg)]", "900"),
]
THERMAL_NAMES = [p[0] for p in THERMAL_PARAMS("0", "0", "0")]

FAMILIES = {
    "ideal_switch": dict(
        short="ideal switch", prefix="switch", lib_suffix="ideal_switch",
        description=(
            "Ideal switch cells: Simscape Foundation controlled switch (closed when the gate "
            "command is above Vth) with antiparallel piecewise-linear diode and RC snubber. "
            "No losses are computed; the cell measures the device current (positive from "
            "collector/drain to emitter/source, diode current negative) and the device voltage. "
            "Bus m: switch_current_Qk, switch_voltage_Qk."),
        params=[
            ("Rds_on", "On-state resistance of the switch [Ohm]", "1.85e-3"),
            ("Vdon_diode", "Diode forward voltage [V]", "0.35"),
            ("Rdon_diode", "Diode on-state resistance [Ohm]", "1.85e-3"),
            ("Csnubber", "RC snubber capacitance [F]", "6e-9"),
            ("Rsnubber", "RC snubber resistance [Ohm]", "3e3"),
            ("Vth", "Gate threshold: the switch is closed when the gate command is above Vth", "7.5"),
        ],
        groups=[("Switch and diode", ["Rds_on", "Vdon_diode", "Rdon_diode", "Vth"]),
                ("RC snubber", ["Csnubber", "Rsnubber"])],
        sigs=["current", "voltage"],
    ),
    "igbt_simple_2th": dict(
        short="igbt_simple_2th", prefix="igbt", lib_suffix="igbt_simple_2th",
        description=(
            "IGBT cells built on igbt_simple_2th (library/foundation/semiconductors): knee + "
            "slope conduction, switching energies scaled from one datasheet point, separate "
            "thermal ports for the IGBT and the free-wheeling diode. Each die drives its own "
            "junction thermal mass -> Rth JH -> heatsink mass -> Rth HA -> ambient temperature "
            "source. Gate command in volts (modulators: +15/-10 V). Bus m per device k: "
            "igbt_current, igbt_voltage, igbt_ploss, igbt_JH_temp, igbt_HA_temp, diode_current, "
            "diode_ploss, diode_JH_temp, diode_HA_temp (temperatures are differences in K). "
            "Default data: Infineon FF450R17ME4 at 125 degC."),
        params=[
            ("vce_sat_m", "Collector-emitter on-state voltage (knee) [V]", "0.96"),
            ("rce_on_m", "IGBT on-state series resistance (slope) [mOhm]", "3.05"),
            ("v_gamma_m", "Diode forward voltage (knee) [V]", "0.90"),
            ("rd_on_m", "Diode series resistance (slope) [mOhm]", "2.15"),
            ("Gce_off_m", "Off-state conductance [1/Ohm]", "1e-6"),
            ("Vth_gate_m", "Gate-emitter threshold voltage [V]", "5.8"),
            ("Vth_gate_hyst_m", "Half hysteresis band for the switching events [V]", "0.85"),
            ("Eon_m", "Turn-on energy at Ic_ref, Vdc_ref [mJ]", "135"),
            ("Eoff_m", "Turn-off energy at Ic_ref, Vdc_ref [mJ]", "155"),
            ("Err_m", "Reverse recovery energy at Ic_ref, Vdc_ref [mJ]", "110"),
            ("Ic_ref_m", "Reference current of the energies [A]", "450"),
            ("Vdc_ref_m", "Reference voltage of the energies [V]", "900"),
            ("Vblock_Errf_m", "Blocking detection level for the Err event [V]", "50"),
            ("time_constant_edge_m", "Sample&hold time constant (<< on-time) [us]", "1"),
            ("time_constant_ploss_m", "Loss averaging time constant (2-5 x Tsw) [us]", "200"),
            ("Csnubber_m", "RC snubber capacitance [F]", "12e-12"),
            ("Rsnubber_m", "RC snubber resistance [Ohm]", "2200"),
        ] + THERMAL_PARAMS("0.093", "0.152", "0.81"),
        groups=[("Conduction", ["vce_sat_m", "rce_on_m", "v_gamma_m", "rd_on_m", "Gce_off_m"]),
                ("Gate", ["Vth_gate_m", "Vth_gate_hyst_m"]),
                ("Switching energies", ["Eon_m", "Eoff_m", "Err_m", "Ic_ref_m", "Vdc_ref_m",
                                        "Vblock_Errf_m"]),
                ("Numerics and snubber", ["time_constant_edge_m", "time_constant_ploss_m",
                                          "Csnubber_m", "Rsnubber_m"]),
                ("Thermal network", THERMAL_NAMES)],
        sigs=["current", "voltage", "ploss", "JH_temp", "HA_temp"],
    ),
    "mos_simple_2th": dict(
        short="mos_simple_2th", prefix="mosfet", lib_suffix="mos_simple_2th",
        description=(
            "MOSFET cells built on mos_simple_2th (library/foundation/semiconductors): resistive "
            "bidirectional channel (synchronous rectification), piecewise-linear diode, switching "
            "energies scaled from one datasheet point, optional Rds_on temperature coefficient, "
            "separate thermal ports for the channel and the diode die (two_die = 0 charges the "
            "body diode losses to the transistor die). Each die drives its own junction thermal "
            "mass -> Rth JH -> heatsink mass -> Rth HA -> ambient temperature source. The gate "
            "command is compared with G_th (works with 0/1 logic and with +15/-10 V). Bus m per "
            "device k: mosfet_current, mosfet_voltage, mosfet_ploss, mosfet_JH_temp, "
            "mosfet_HA_temp, diode_current, diode_ploss, diode_JH_temp, diode_HA_temp "
            "(temperatures are differences in K). Default data: Wolfspeed CAB450M12XM3."),
        params=[
            ("rds_on_m", "On-state resistance at Tj_ref [mOhm]", "2.6"),
            ("alpha_R_m", "Rds_on temperature coefficient, 0 disables it [1/K]", "0"),
            ("Tj_ref_m", "Reference junction temperature of Rds_on [degC]", "125"),
            ("Roff_m", "Off-state resistance [Ohm]", "1e7"),
            ("v_gamma_m", "Diode knee voltage [V]", "4.5"),
            ("rd_on_m", "Diode differential resistance [mOhm]", "0.185"),
            ("two_die_m", "Diode die: 1 = separate die (losses to Hd), 0 = body diode (losses to Ht)", "0"),
            ("G_th_m", "Gate threshold: on when the gate command is above G_th", "0.5"),
            ("Eon_m", "Turn-on energy at Ic_ref, Vdc_ref [mJ]", "24"),
            ("Eoff_m", "Turn-off energy at Ic_ref, Vdc_ref [mJ]", "8"),
            ("Err_m", "Diode recovery energy at Ic_ref, Vdc_ref [mJ]", "1.1"),
            ("Ic_ref_m", "Reference current of the energies [A]", "450"),
            ("Vdc_ref_m", "Reference voltage of the energies [V]", "600"),
            ("ki_m", "Current exponent of the energy scaling", "1"),
            ("kv_m", "Voltage exponent of the energy scaling", "1"),
            ("Vth_off_m", "Turn-off / recovery detection threshold [V]", "50"),
            ("Vth_on_m", "Turn-on detection threshold (< Vth_off) [V]", "25"),
            ("V_sm_m", "Smoothing width of the blocking detector [V]", "10"),
            ("time_constant_edge_m", "Sample-and-hold time constant (<< dead time) [us]", "0.1"),
            ("tau_v_m", "Blocking voltage estimator time constant [us]", "10"),
            ("time_constant_ploss_m", "Energy-to-power lag time constant (2-5 x Tsw) [us]", "200"),
            ("i_eps_m", "Current smoothing [A]", "1e-3"),
            ("Csnubber_m", "RC snubber capacitance [F]", "12e-12"),
            ("Rsnubber_m", "RC snubber resistance [Ohm]", "2200"),
        ] + THERMAL_PARAMS("0.116", "0.116", "0.2"),
        groups=[("Conduction", ["rds_on_m", "alpha_R_m", "Tj_ref_m", "Roff_m", "v_gamma_m",
                                "rd_on_m", "two_die_m"]),
                ("Gate", ["G_th_m"]),
                ("Switching energies", ["Eon_m", "Eoff_m", "Err_m", "Ic_ref_m", "Vdc_ref_m",
                                        "ki_m", "kv_m", "Vth_off_m", "Vth_on_m", "V_sm_m"]),
                ("Numerics and snubber", ["time_constant_edge_m", "tau_v_m",
                                          "time_constant_ploss_m", "i_eps_m", "Csnubber_m",
                                          "Rsnubber_m"]),
                ("Thermal network", THERMAL_NAMES)],
        sigs=["current", "voltage", "ploss", "JH_temp", "HA_temp"],
    ),
}

TOPOLOGIES = {
    "half_bridge": dict(legs=1, ac=["u"], title="half bridge"),
    "full_bridge": dict(legs=2, ac=["uac(+)", "uac(-)"], title="full bridge"),
    "three_phase_bridge": dict(legs=3, ac=["u", "v", "w"], title="three-phase bridge"),
}


def bus_signal_names(family, k):
    """Names of the m-bus elements produced by device k (order = cell outport order)."""
    f = FAMILIES[family]
    if family == "ideal_switch":
        return [f"switch_current_Q{k}", f"switch_voltage_Q{k}"]
    p = f["prefix"]
    return [f"{p}_current_Q{k}", f"{p}_voltage_Q{k}", f"{p}_ploss_Q{k}", f"{p}_JH_temp_Q{k}",
            f"{p}_HA_temp_Q{k}", f"diode_current_Q{k}", f"diode_ploss_Q{k}",
            f"diode_JH_temp_Q{k}", f"diode_HA_temp_Q{k}"]


def gate_signals(topology, ttype):
    """Bus Selector OutputSignals of the gate_commands bus, in device order Q1..Qn."""
    legs = TOPOLOGIES[topology]["legs"]
    if not ttype:
        return [f"gate_cmd_Q{k}" for k in range(1, 2 * legs + 1)]
    if topology == "half_bridge":
        return [f"cmd_gate_Q{k}" for k in range(1, 5)]
    if topology == "full_bridge":
        return [f"gate_cmds_ph{l}.cmd_gate_Q{k}" for l in (1, 2) for k in range(1, 5)]
    return [f"gate_cmds_ph{p}.cmd_gate_Q{k}" for p in ("u", "v", "w") for k in range(1, 5)]


# ----------------------------------------------------------------------------- cells
def cell_ideal(sids):
    """Ideal switch cell: in g | lconn C | rconn E | out i, v."""
    s = System(sids, location="[200, 150, 1000, 560]")
    g = s.inport("g", 1, pos(40, 213, 30, 14))
    conv = s.sl2ps("gate", pos(110, 212, 15, 16), unit="1")
    C = s.pmio("C", 1, "Left", pos(340, 20, 30, 14))
    isen = sb.current_sensor(s, "i_sensor", pos(335, 60, 40, 40), rotation="90")
    sw = sb.switch(s, "switch", pos(200, 180, 40, 40), "Rds_on", "Vth", rotation="90",
                   mirror=True, name_location="left")
    dio = sb.diode(s, "diode", pos(290, 180, 28, 40), "Vdon_diode", "Rdon_diode",
                   rotation="270", name_location="right")
    csn = sb.capacitor(s, "RC snubber", pos(390, 180, 40, 40), "Csnubber", "Rsnubber",
                       rotation="90", name_location="left")
    vsen = sb.voltage_sensor(s, "v_sensor", pos(480, 180, 40, 40), rotation="270", mirror=True,
                             name_location="right")
    E = s.pmio("E", 2, "Right", pos(340, 300, 30, 14), mirror=True)
    ps_i = s.ps2sl("i_A", pos(440, 72, 15, 16), "A")
    ps_v = s.ps2sl("v_V", pos(560, 192, 15, 16), "V")
    o_i = s.outport("i", 1, pos(620, 73, 30, 14))
    o_v = s.outport("v", 2, pos(620, 193, 30, 14))
    s.sig(f"{g}#out:1", f"{conv}#in:1")
    s.conn(f"{conv}#rconn:1", f"{sw}#rconn:1")
    s.conn(f"{C}#rconn:1", f"{isen}#lconn:1")
    s.conn(f"{isen}#rconn:2", f"{sw}#rconn:2", f"{dio}#rconn:1", f"{csn}#lconn:1", f"{vsen}#lconn:1")
    s.conn(f"{sw}#lconn:1", f"{dio}#lconn:1", f"{csn}#rconn:1", f"{vsen}#rconn:2", f"{E}#rconn:1")
    s.conn(f"{isen}#rconn:1", f"{ps_i}#lconn:1")
    s.conn(f"{vsen}#rconn:1", f"{ps_v}#lconn:1")
    s.sig(f"{ps_i}#out:1", f"{o_i}#in:1")
    s.sig(f"{ps_v}#out:1", f"{o_v}#in:1")
    return s, 2


def cell_2th(sids, family):
    """igbt_simple_2th / mos_simple_2th cell with two thermal networks.
    in g | lconn C | rconn E | out i_t, v, p_t, dT_JH_t, dT_HA_t, i_d, p_d, dT_JH_d, dT_HA_d."""
    s = System(sids, location="[100, 80, 1500, 740]")
    is_igbt = family == "igbt_simple_2th"
    g = s.inport("g", 1, pos(440, 267, 30, 14))
    conv = s.sl2ps("gate", pos(520, 266, 15, 16), unit="V" if is_igbt else "1")
    if is_igbt:
        dev = sb.igbt_simple_2th(s, "igbt_simple_2th", pos(600, 100, 170, 232))
    else:
        dev = sb.mos_simple_2th(s, "mos_simple_2th", pos(600, 100, 170, 232))
    C = s.pmio("C" if is_igbt else "D", 1, "Left", pos(520, 151, 30, 14))
    E = s.pmio("E" if is_igbt else "S", 2, "Right", pos(860, 50, 30, 14), mirror=True)
    csn = sb.capacitor(s, "RC snubber", pos(640, 20, 40, 20), "Csnubber_m", "Rsnubber_m")
    vsen = sb.voltage_sensor(s, "v_sensor", pos(700, 20, 40, 20))
    ps_v = s.ps2sl("v_V", pos(790, 25, 15, 16), "V")
    t_Pt = s.ps2sl("p_t_W", pos(800, 192, 15, 16), "W")
    t_Pd = s.ps2sl("p_d_W", pos(800, 225, 15, 16), "W")
    ps_it = s.ps2sl("i_t_A", pos(800, 258, 15, 16), "A")
    ps_id = s.ps2sl("i_d_A", pos(800, 291, 15, 16), "A")

    def thermal_branch(tag, x0, flip):
        """Junction node -> Rth JH -> heatsink node -> Rth HA -> ambient; two difference sensors.
        Returns (junction node port list, ps_jh, ps_ha)."""
        d = -1 if flip else 1
        rth_jh = "rth_switch_JH_m" if tag == "t" else "rth_diode_JH_m"
        rth_ha = "rth_switch_HA_m" if tag == "t" else "rth_diode_HA_m"
        die = "transistor" if tag == "t" else "diode"
        cj = sb.thermal_mass(s, f"Cj {die}", pos(x0 + d * 60 - 14, 250, 28, 40),
                             "JunctionTermalMass_m/specific_heat_m", "specific_heat_m", "Tambient_m",
                             rotation="90", mirror=True, name_location="left")
        rjh = sb.thermal_resistance(s, f"Rth JH {die}", pos(x0 + d * 160 - 27, 203, 55, 28), rth_jh,
                                    rotation="180" if flip else None)
        ch = sb.thermal_mass(s, f"C heatsink {die}", pos(x0 + d * 240 - 14, 250, 28, 40),
                             "mass_heatsink_m", "specific_heat_m", "Tambient_m",
                             rotation="90", mirror=True, name_location="left")
        rha = sb.thermal_resistance(s, f"Rth HA {die}", pos(x0 + d * 330 - 27, 203, 55, 28), rth_ha,
                                    rotation="180" if flip else None)
        tamb = sb.temperature_source(s, f"Tambient {die}", pos(x0 + d * 420 - 20, 203, 40, 28),
                                     "Tambient_m", mirror=flip)
        ts_jh = sb.temperature_sensor_diff(s, f"dT JH {die}", pos(x0 + d * 160 - 15, 300, 30, 33),
                                           rotation="180" if flip else None)
        ts_ha = sb.temperature_sensor_diff(s, f"dT HA {die}", pos(x0 + d * 330 - 15, 300, 30, 33),
                                           rotation="180" if flip else None)
        ps_jh = s.ps2sl(f"dT_JH_{tag}_K", pos(x0 + d * 160 - 7, 360, 15, 16), "K")
        ps_ha = s.ps2sl(f"dT_HA_{tag}_K", pos(x0 + d * 330 - 7, 360, 15, 16), "K")
        # junction node: device port, Cj, Rth JH A, sensor JH A  (device port added by caller)
        junction = [f"{cj}#lconn:1", f"{rjh}#lconn:1", f"{ts_jh}#lconn:1"]
        s.conn(f"{rjh}#rconn:1", f"{ch}#lconn:1", f"{rha}#lconn:1", f"{ts_jh}#rconn:1",
               f"{ts_ha}#lconn:1")
        s.conn(f"{rha}#rconn:1", f"{tamb}#lconn:1", f"{ts_ha}#rconn:1")
        s.conn(f"{ts_jh}#rconn:2", f"{ps_jh}#lconn:1")
        s.conn(f"{ts_ha}#rconn:2", f"{ps_ha}#lconn:1")
        return junction, ps_jh, ps_ha

    jt, ps_jh_t, ps_ha_t = thermal_branch("t", 560, flip=True)   # transistor die, left of the device
    jd, ps_jh_d, ps_ha_d = thermal_branch("d", 820, flip=False)  # diode die, right of the device

    outs = []
    names = ["i_t", "v", "p_t", "dT_JH_t", "dT_HA_t", "i_d", "p_d", "dT_JH_d", "dT_HA_d"]
    for k, n in enumerate(names):
        outs.append(s.outport(n, k + 1, pos(1380, 26 + 40 * k, 30, 14)))
    srcs = [ps_it, ps_v, t_Pt, ps_jh_t, ps_ha_t, ps_id, t_Pd, ps_jh_d, ps_ha_d]
    for src, o in zip(srcs, outs):
        s.sig(f"{src}#out:1", f"{o}#in:1")

    s.sig(f"{g}#out:1", f"{conv}#in:1")
    s.conn(f"{conv}#rconn:1", f"{dev}#lconn:3")
    s.conn(f"{C}#rconn:1", f"{dev}#lconn:1", f"{csn}#lconn:1", f"{vsen}#lconn:1")
    s.conn(f"{dev}#rconn:1", f"{E}#rconn:1", f"{csn}#rconn:1", f"{vsen}#rconn:2")
    s.conn(f"{vsen}#rconn:1", f"{ps_v}#lconn:1")
    s.conn(f"{dev}#rconn:3", f"{t_Pt}#lconn:1")
    s.conn(f"{dev}#rconn:4", f"{t_Pd}#lconn:1")
    s.conn(f"{dev}#rconn:5", f"{ps_it}#lconn:1")
    s.conn(f"{dev}#rconn:6", f"{ps_id}#lconn:1")
    s.conn(f"{dev}#lconn:2", *jt)
    s.conn(f"{dev}#rconn:2", *jd)
    return s, 9


def make_cell(sids, family):
    if family == "ideal_switch":
        return cell_ideal(sids)
    return cell_2th(sids, family)


# ----------------------------------------------------------------------------- bridge body
def build_body(sids, topology, ttype, family):
    """The content of the masked subsystem. Returns (System, n_left_ports, n_right_ports)."""
    topo = TOPOLOGIES[topology]
    legs = topo["legs"]
    n_dev = 4 * legs if ttype else 2 * legs
    n_out = 2 if family == "ideal_switch" else 9
    cw, ch = 130, 24 + 22 * max(n_out, 2)
    x0, y0 = 420, 120
    dx = 480 if ttype else 300
    dy = ch + 90
    rows = 3 if ttype else 2
    height = y0 + rows * dy
    s = System(sids, location=f"[60, 60, {min(1800, x0 + legs * dx + 700)}, {min(1000, height + 200)}]",
               zoom="60" if n_out > 2 else "100")

    gate = s.inport("gate_commands", 1, pos(40, y0 + 40, 30, 14))
    sel = s.bus_selector(gate_signals(topology, ttype), pos(170, y0, 5, 22 * n_dev + 10))
    s.sig(f"{gate}#out:1", f"{sel}#in:1")

    # PMIO ports: left = dc, right = ac; numbers are global over all physical ports
    port = 1
    udcp = s.pmio("udc(+)", port, "Left", pos(40, y0 - 60, 30, 14)); port += 1
    np_port = None
    if ttype:
        np_port = s.pmio("np", port, "Left", pos(40, y0 + dy + ch // 2, 30, 14)); port += 1
    udcm = s.pmio("udc(-)", port, "Left", pos(40, height + 10, 30, 14)); port += 1
    n_left = port - 1
    xr = x0 + (legs - 1) * dx + cw + 160
    ac_ports = []
    for i, name in enumerate(topo["ac"]):
        yac = y0 + dy + (ch // 2 if ttype else -40) + i * 30
        ac_ports.append(s.pmio(name, port, "Right", pos(xr, yac, 30, 14), mirror=True)); port += 1
    n_right = len(ac_ports)

    # bus creator and outport m
    xbc = xr + 160
    bc = s.bus_creator(n_dev * n_out, pos(xbc, y0, 5, 20 * n_dev * n_out + 10), out_name="m")
    out_m = s.outport("m", 1, pos(xbc + 120, y0 + 10 * n_dev * n_out, 30, 14))
    s.sig(f"{bc}#out:1", f"{out_m}#in:1")

    # cells
    nodes_p, nodes_m, nodes_np = [f"{udcp}#rconn:1"], [f"{udcm}#rconn:1"], []
    if ttype:
        nodes_np.append(f"{np_port}#rconn:1")
    counts = {"in": 1, "out": n_out, "lconn": 1, "rconn": 1}

    def add_cell(k, x, y):
        sid = sids()
        child, _ = make_cell(sids, family)
        s.subsystem(f"Q{k}", pos(x, y, cw, ch), counts, child, sid=sid)
        s.sig(f"{sel}#out:{k}", f"{sid}#in:1")
        for j, name in enumerate(bus_signal_names(family, k)):
            s.sig(f"{sid}#out:{j + 1}", f"{bc}#in:{(k - 1) * n_out + j + 1}", name=name)
        return sid

    for l in range(legs):
        x = x0 + l * dx
        mid = [f"{ac_ports[l]}#rconn:1"]
        if not ttype:
            top = add_cell(2 * l + 1, x, y0)
            bot = add_cell(2 * l + 2, x, y0 + dy)
            nodes_p.append(f"{top}#lconn:1")
            mid += [f"{top}#rconn:1", f"{bot}#lconn:1"]
            nodes_m.append(f"{bot}#rconn:1")
        else:
            q1 = add_cell(4 * l + 1, x, y0)
            q2 = add_cell(4 * l + 2, x - 200, y0 + dy)
            q3 = add_cell(4 * l + 3, x, y0 + dy)
            q4 = add_cell(4 * l + 4, x, y0 + 2 * dy)
            nodes_p.append(f"{q1}#lconn:1")
            mid += [f"{q1}#rconn:1", f"{q4}#lconn:1", f"{q3}#lconn:1"]
            nodes_m.append(f"{q4}#rconn:1")
            nodes_np.append(f"{q2}#lconn:1")
            s.conn(f"{q2}#rconn:1", f"{q3}#rconn:1")          # common emitter of the neutral pair
        s.conn(*mid)
    s.conn(*nodes_p)
    s.conn(*nodes_m)
    if ttype:
        s.conn(*nodes_np)
    return s, n_left, n_right


def icon_commands(topology, ttype, family, n_left, n_right):
    topo = TOPOLOGIES[topology]
    lines = [topo["title"], "T-type 3 levels" if ttype else "2 levels", FAMILIES[family]["short"]]
    cmd = "disp(sprintf('" + "\\n".join(lines) + "'))\n"
    cmd += "port_label('input', 1, 'gate_commands')\nport_label('output', 1, 'm')\n"
    left = ["udc(+)", "np", "udc(-)"] if ttype else ["udc(+)", "udc(-)"]
    for i, n in enumerate(left):
        cmd += f"port_label('LConn', {i + 1}, '{n}')\n"
    for i, n in enumerate(topo["ac"]):
        cmd += f"port_label('RConn', {i + 1}, '{n}')\n"
    return cmd


def block_name(topology, ttype, family):
    return f"{topology}_{'three_level_ttype' if ttype else 'two_level'}_{FAMILIES[family]['lib_suffix']}"


def build_library(topology, ttype, family, out_dir):
    name = block_name(topology, ttype, family)
    sids = SidPool()
    root = System(sids, location="[100, 100, 900, 600]")
    root_sid = sids()
    body, n_left, n_right = build_body(sids, topology, ttype, family)
    topo = TOPOLOGIES[topology]
    fam = FAMILIES[family]
    desc = (f"{topo['title'].capitalize()}, {'three-level T-type' if ttype else 'two-level'}, "
            f"{fam['short']} devices. {fam['description']} Ports: gate_commands (bus from the "
            f"{'three-level' if ttype else 'two-level'} PWM modulators of masked_models/modulators), "
            f"m (measurement bus), left dc terminals {' / '.join(['udc(+)', 'np', 'udc(-)'] if ttype else ['udc(+)', 'udc(-)'])}, "
            f"right ac terminals {' / '.join(topo['ac'])}. Device numbering: see {topology}/README.md.")
    mask = mask_xml(name, desc, fam["params"], fam["groups"],
                    icon=icon_commands(topology, ttype, family, n_left, n_right),
                    help_cmd=f"web('{GITHUB}/{topology}/README.md', '-browser')")
    h = 40 + 36 * max(n_left + 1, n_right + 1)
    root.subsystem(name, pos(300, 120, 230, h),
                   {"in": 1, "out": 1, "lconn": n_left, "rconn": n_right}, body, mask_xml=mask,
                   sid=root_sid)
    path = os.path.join(out_dir, topology, name + ".slx")
    write_slx(path, root, is_library=True, model_name=name)
    return path


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(
        os.path.dirname(os.path.abspath(__file__)))
    paths = []
    for topology in TOPOLOGIES:
        for ttype in (False, True):
            for family in FAMILIES:
                paths.append(build_library(topology, ttype, family, out_dir))
    for p in paths:
        print(f"{os.path.getsize(p):>8d}  {os.path.relpath(p, out_dir)}")
    print(f"{len(paths)} libraries written")


if __name__ == "__main__":
    main()
