#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
sscblocks - the Simscape blocks used by the semiconductor bridges and by their test model,
as thin wrappers around slxlib.System.ssc(). The parameter names, units and port ids are the
ones Simulink R2026a writes for the same library blocks.
"""
from slxlib import FL_VERSION, SSC_LIB_VERSION

IV = [("i", "off", "None", "0", "A"), ("v", "off", "None", "0", "V")]

IGBT_SRC = ("igbt_simple_2th_lib/IGBT_SIMPLE_2TH\nSimplified IGBT +\nantiparallel FWD,"
            "\nseparate thermal\nports")
MOS_SRC = ("mos_simple_2th_lib/MOS_SIMPLE_2TH\nSimplified power\nMOSFET +\nantiparallel diode,"
           "\ntwo thermal ports")


# --------------------------------------------------------------------------- electrical
def switch(s, name, pos, r_closed, threshold, **kw):
    """Foundation controlled switch: p (lconn1) ... n (rconn2), control vT (rconn1)."""
    return s.ssc(name, "fl_lib/Electrical/Electrical Elements/Switch",
                 "foundation.electrical.elements.controlled_switch", "controlled_switch",
                 [("R_closed", r_closed, "Ohm"), ("G_open", "1e-8", "1/Ohm"),
                  ("Threshold", threshold, "1")],
                 [("lconn", 1, "p"), ("rconn", 1, "vT"), ("rconn", 2, "n")], pos,
                 variables=IV, **kw)


def diode(s, name, pos, vf, ron, **kw):
    """Piecewise linear diode: anode p (lconn1), cathode n (rconn1)."""
    return s.ssc(name, "fl_lib/Electrical/Electrical Elements/Diode",
                 "foundation.electrical.elements.pwl_diode", "pwl_diode",
                 [("Vf", vf, "V"), ("Ron", ron, "Ohm"), ("Goff", "1e-8", "1/Ohm")],
                 [("lconn", 1, "p"), ("rconn", 1, "n")], pos, variables=IV, **kw)


def capacitor(s, name, pos, c, r, **kw):
    """Capacitor with series resistance (RC snubber): p (lconn1), n (rconn1)."""
    return s.ssc(name, "fl_lib/Electrical/Electrical Elements/Capacitor",
                 "foundation.electrical.elements.capacitor", "capacitor",
                 [("c", c, "F"), ("r", r, "Ohm"), ("g", "0", "1/Ohm")],
                 [("lconn", 1, "p"), ("rconn", 1, "n")], pos,
                 variables=IV + [("vc", "off", "High", "0", "V")], **kw)


def resistor(s, name, pos, r, **kw):
    return s.ssc(name, "fl_lib/Electrical/Electrical Elements/Resistor",
                 "foundation.electrical.elements.resistor", "resistor",
                 [("R", r, "Ohm")], [("lconn", 1, "p"), ("rconn", 1, "n")], pos,
                 variables=IV, **kw)


def inductor(s, name, pos, l, r="0", **kw):
    return s.ssc(name, "fl_lib/Electrical/Electrical Elements/Inductor",
                 "foundation.electrical.elements.inductor", "inductor",
                 [("l", l, "H"), ("r", r, "Ohm"), ("g", "0", "1/Ohm")],
                 [("lconn", 1, "p"), ("rconn", 1, "n")], pos,
                 variables=IV + [("i_L", "off", "High", "0", "A")], **kw)


def dc_voltage(s, name, pos, v0, **kw):
    """DC voltage source: + p (lconn1), - n (rconn1)."""
    return s.ssc(name, "fl_lib/Electrical/Electrical Sources/DC Voltage Source",
                 "foundation.electrical.sources.dc_voltage", "dc_voltage",
                 [("v0", v0, "V")], [("lconn", 1, "p"), ("rconn", 1, "n")], pos,
                 variables=IV, **kw)


def electrical_reference(s, name, pos, **kw):
    return s.ssc(name, "fl_lib/Electrical/Electrical Elements/Electrical Reference",
                 "foundation.electrical.elements.reference", "reference", [],
                 [("lconn", 1, "V")], pos, **kw)


def current_sensor(s, name, pos, **kw):
    """p (lconn1) -> n (rconn2), measurement I (rconn1) positive from p to n."""
    return s.ssc(name, "fl_lib/Electrical/Electrical Sensors/Current Sensor",
                 "foundation.electrical.sensors.current", "current", [],
                 [("lconn", 1, "p"), ("rconn", 1, "I"), ("rconn", 2, "n")], pos, **kw)


def voltage_sensor(s, name, pos, **kw):
    """V (rconn1) = v(p) - v(n), p = lconn1, n = rconn2."""
    return s.ssc(name, "fl_lib/Electrical/Electrical Sensors/Voltage Sensor",
                 "foundation.electrical.sensors.voltage", "voltage", [],
                 [("lconn", 1, "p"), ("rconn", 1, "V"), ("rconn", 2, "n")], pos, **kw)


# --------------------------------------------------------------------------- thermal
def thermal_mass(s, name, pos, mass, sp_heat, t_init, **kw):
    """Thermal mass with one port M (lconn1); T initialised at t_init [degC]."""
    return s.ssc(name, "fl_lib/Thermal/Thermal Elements/Thermal Mass",
                 "foundation.thermal.elements.mass", "mass",
                 [("mass_type", "foundation.enum.constant_variable.constant", "1"),
                  ("mass", mass, "kg"), ("sp_heat", sp_heat, "J/(K*kg)"),
                  ("mass_min", "1e-6", "kg"), ("num_ports", "foundation.enum.numPorts2.one", "1")],
                 [("lconn", 1, "M")], pos,
                 variables=[("m", "off", "High", "1", "kg"), ("T", "on", "High", t_init, "degC"),
                            ("Q", "off", "High", "0", "W")], **kw)


def thermal_resistance(s, name, pos, rth, **kw):
    """A (lconn1) - B (rconn1)."""
    return s.ssc(name, "fl_lib/Thermal/Thermal Elements/Thermal Resistance",
                 "foundation.thermal.elements.resistance", "resistance",
                 [("resistance", rth, "K/W")], [("lconn", 1, "A"), ("rconn", 1, "B")], pos,
                 variables=[("T", "off", "High", "0", "deltadegC"), ("Q", "off", "None", "0", "W")],
                 **kw)


def temperature_source(s, name, pos, temperature, **kw):
    return s.ssc(name, "fl_lib/Thermal/Thermal Sources/Temperature Source",
                 "foundation.thermal.sources.temperature", "temperature",
                 [("temperature", temperature, "degC")], [("lconn", 1, "A")], pos, **kw)


def temperature_sensor_diff(s, name, pos, **kw):
    """T (rconn2) = T(A) - T(B), A = lconn1, B = rconn1 (difference mode)."""
    return s.ssc(name, "fl_lib/Thermal/Thermal Sensors/Temperature Sensor",
                 "foundation.thermal.sensors.temperature", "temperature",
                 [("temperature_measure", "foundation.enum.MeasurementReference.difference", "1")],
                 [("lconn", 1, "A"), ("rconn", 1, "B"), ("rconn", 2, "T")], pos, **kw)


def ps_terminator(s, name, pos, **kw):
    return s.ssc(name, "fl_lib/Physical Signals/Sinks/PS Terminator",
                 "foundation.signal.sinks.terminator", "terminator", [], [("lconn", 1, "I")],
                 pos, **kw)


# --------------------------------------------------------------------------- 2th devices
IGBT_PORTS = [("lconn", 1, "p"), ("lconn", 2, "Ht"), ("lconn", 3, "g"), ("rconn", 1, "n"),
              ("rconn", 2, "Hd"), ("rconn", 3, "Pt"), ("rconn", 4, "Pd"), ("rconn", 5, "it"),
              ("rconn", 6, "id")]
MOS_PORTS = [("lconn", 1, "p"), ("lconn", 2, "Ht"), ("lconn", 3, "G"), ("rconn", 1, "n"),
             ("rconn", 2, "Hd"), ("rconn", 3, "Pt"), ("rconn", 4, "Pd"), ("rconn", 5, "it"),
             ("rconn", 6, "id")]

IGBT_VARS = [("i", "off", "None", "0", "A"), ("v", "off", "None", "0", "V"),
             ("i_t", "off", "None", "0", "A"), ("i_d", "off", "None", "0", "A"),
             ("i_h", "off", "None", "0", "A"), ("i_dh", "off", "None", "0", "A"),
             ("v_h", "off", "None", "0", "V"), ("E_lpt", "off", "None", "0", "J"),
             ("E_lpd", "off", "None", "0", "J"), ("Qt", "off", "None", "0", "W"),
             ("Qd", "off", "None", "0", "W")]
IGBT_EVENT_VARS = [("E_t", "J"), ("E_d", "J")]

MOS_VARS = [("v", "off", "None", "0", "V"), ("i", "off", "None", "0", "A"),
            ("ich", "off", "None", "0", "A"), ("ichp", "off", "None", "0", "A"),
            ("idio", "off", "None", "0", "A"), ("vfd", "off", "None", "0", "V"),
            ("ith", "off", "None", "0", "A"), ("idh", "off", "None", "0", "A"),
            ("vbl", "off", "None", "600", "V"), ("hb", "off", "None", "0", "1"),
            ("Gch", "off", "None", "0", "S"), ("gl", "off", "None", "0", "1"),
            ("Rds", "off", "None", "1e-3", "Ohm"), ("xr", "off", "None", "1", "1"),
            ("Eot", "off", "None", "0", "J"), ("Eod", "off", "None", "0", "J"),
            ("Pswt", "off", "None", "0", "W"), ("Pswd", "off", "None", "0", "W"),
            ("Pct", "off", "None", "0", "W"), ("Pcd", "off", "None", "0", "W"),
            ("Qt", "off", "None", "0", "W"), ("Qd", "off", "None", "0", "W")]
MOS_EVENT_VARS = [("Eqt", "J"), ("Eqd", "J")]


def _event_vars(evs):
    out = ""
    for v, unit in evs:
        out += (f'      <P Name="{v}_specify">off</P>\n      <P Name="{v}_priority">None</P>\n'
                f'      <P Name="{v}">0</P>\n      <P Name="{v}_unit">{unit}</P>\n')
    return out


def igbt_simple_2th(s, name, pos, **kw):
    """igbt_simple_2th with the mask variables of the bridge (Davide's naming)."""
    params = [("Vce_sat", "vce_sat_m", "V"), ("Vf", "v_gamma_m", "V"), ("Vth", "Vth_gate_m", "V"),
              ("Vhyst", "Vth_gate_hyst_m", "V"), ("Eon_ref", "Eon_m", "mJ"),
              ("Eoff_ref", "Eoff_m", "mJ"), ("Err_ref", "Err_m", "mJ"), ("Ic_ref", "Ic_ref_m", "A"),
              ("Vdc_ref", "Vdc_ref_m", "V"), ("V_rr_th", "Vblock_Errf_m", "V"),
              ("Ron", "rce_on_m", "mOhm"), ("Rd", "rd_on_m", "mOhm"), ("Goff", "Gce_off_m", "1/Ohm"),
              ("tau_s", "time_constant_edge_m", "us"), ("tau_p", "time_constant_ploss_m", "us")]
    return s.ssc(name, IGBT_SRC, "igbt_simple_2th.igbt_simple_2th", "igbt_simple_2th", params,
                 IGBT_PORTS, pos, lib_version=SSC_LIB_VERSION, variables=IGBT_VARS,
                 extra_idata=_event_vars(IGBT_EVENT_VARS), **kw)


def mos_simple_2th(s, name, pos, **kw):
    """mos_simple_2th with the mask variables of the bridge."""
    params = [("Rds_on", "rds_on_m", "mOhm"), ("alpha_R", "alpha_R_m", "1/K"),
              ("Tj_ref", "Tj_ref_m", "degC"), ("Roff", "Roff_m", "Ohm"), ("Vf", "v_gamma_m", "V"),
              ("Rd", "rd_on_m", "mOhm"), ("two_die", "two_die_m", "1"), ("G_th", "G_th_m", "1"),
              ("Eon_ref", "Eon_m", "mJ"), ("Eoff_ref", "Eoff_m", "mJ"), ("Err_ref", "Err_m", "mJ"),
              ("Iref", "Ic_ref_m", "A"), ("Vref", "Vdc_ref_m", "V"), ("ki", "ki_m", "1"),
              ("kv", "kv_m", "1"), ("Vth_off", "Vth_off_m", "V"), ("Vth_on", "Vth_on_m", "V"),
              ("V_sm", "V_sm_m", "V"), ("tau_s", "time_constant_edge_m", "us"),
              ("tau_v", "tau_v_m", "us"), ("tau_p", "time_constant_ploss_m", "us"),
              ("i_eps", "i_eps_m", "A"), ("v_eps", "1e-3", "V")]
    return s.ssc(name, MOS_SRC, "mos_simple_2th.mos_simple_2th", "mos_simple_2th", params,
                 MOS_PORTS, pos, lib_version=SSC_LIB_VERSION, variables=MOS_VARS,
                 extra_idata=_event_vars(MOS_EVENT_VARS), **kw)
