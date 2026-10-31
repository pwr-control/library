#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
generate_test_model.py - writes test/test_semiconductors_bridges.slx: the 18 bridges of
semiconductors_bridges, each in its own test cell with a dc supply, an R-L load, current and
voltage sensors and a local-solver Solver Configuration, driven by the five PWM modulators of
masked_models/modulators. The parameters come from the struct tb created by
test_semiconductors_bridges_param.m; test_semiconductors_bridges_run.m runs the model and
checks the results.

Usage:  python3 generate_test_model.py [output_dir]      (default: ../test)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slxlib import System, SidPool, write_slx, pos, solver_model, DATAIO_MODEL  # noqa: E402
import sscblocks as sb  # noqa: E402
from generate_bridges import FAMILIES, TOPOLOGIES, block_name  # noqa: E402

MODULATORS = {
    "hb": ("half_bridge_PWM_generator_with_TRGO/half-bridge-PWM-generator-with-TRGO", "0.98", "0.02"),
    "1ph": ("single_phase_pwm_modulator/Single phase two level PWM generator with global TRGO", "0.98", "0.02"),
    "3ph": ("three_phase_pwm_modulator/Three phase two level PWM generator with global TRGO", "0.98", "0.02"),
    "1ph3L": ("single_phase_three_levels_PWM_modulator/single_phase_three_levels_PWM_generator_with_global_TRGO", "1", "-1"),
    "3ph3L": ("three_phase_three_levels_PWM_modulator/three_phase_three_levels_PWM_generator_with_global_TRGO1", "1", "-1"),
}
TB_FAMILY = {"ideal_switch": "ideal", "igbt_simple_2th": "igbt", "mos_simple_2th": "mos"}


def mask_values(family):
    """(mask parameter, tb expression) for a bridge of the given family."""
    f = TB_FAMILY[family]
    out = []
    for name, _, _ in FAMILIES[family]["params"]:
        field = name[:-2] if name.endswith("_m") else name
        out.append((name, f"tb.{f}.{field}"))
    return out


def test_cell(sids, topology, ttype, family):
    """Bridge + supply + load + sensors + logging. Inport: gate_commands."""
    name = block_name(topology, ttype, family)
    legs = TOPOLOGIES[topology]["legs"]
    n_left = 3 if ttype else 2
    n_right = legs
    s = System(sids, location="[100, 100, 1300, 700]")
    gate = s.inport("gate_commands", 1, pos(40, 193, 30, 14))
    h = 40 + 36 * max(n_left + 1, n_right + 1)
    br = s.library_ref(name, f"{name}/{name}",
                       {"in": 1, "out": 1, "lconn": n_left, "rconn": n_right},
                       pos(360, 120, 230, h), mask_values(family))
    s.sig(f"{gate}#out:1", f"{br}#in:1")
    tw_m = s.to_workspace(f"{name}_m", f"{name}_m", pos(700, 110, 120, 30), sample_time="tb.ts_log")
    s.sig(f"{br}#out:1", f"{tw_m}#in:1")

    split = ttype or topology == "half_bridge"
    udcp, udcm = f"{br}#lconn:1", f"{br}#lconn:{n_left}"
    ref = sb.electrical_reference(s, "Electrical Reference", pos(150, 500, 30, 30))
    solver = s.solver_configuration("Solver Configuration", pos(40, 420, 50, 32))
    if split:
        v1 = sb.dc_voltage(s, "Vdc1", pos(170, 120, 30, 50), "tb.Vdc/2", rotation="90")
        v2 = sb.dc_voltage(s, "Vdc2", pos(170, 300, 30, 50), "tb.Vdc/2", rotation="90")
        mid0 = [f"{v1}#rconn:1", f"{v2}#lconn:1", f"{ref}#lconn:1", f"{solver}#rconn:1"]
        s.conn(f"{v1}#lconn:1", udcp)
        s.conn(f"{v2}#rconn:1", udcm)
        if ttype:
            mid0.append(f"{br}#lconn:2")
        ret_node = mid0            # return of the single-phase load / ground of the measurement
    else:
        v1 = sb.dc_voltage(s, "Vdc", pos(170, 200, 30, 50), "tb.Vdc", rotation="90")
        s.conn(f"{v1}#lconn:1", udcp)
        s.conn(f"{v1}#rconn:1", udcm, f"{ref}#lconn:1", f"{solver}#rconn:1")
        ret_node = None

    isen = sb.current_sensor(s, "i_load", pos(680, 200, 40, 40))
    vsen = sb.voltage_sensor(s, "u_load", pos(680, 320, 40, 40), rotation="270", mirror=True)
    ps_i = s.ps2sl("i_A", pos(760, 180, 15, 16), "A")
    ps_v = s.ps2sl("u_V", pos(760, 320, 15, 16), "V")
    tw_i = s.to_workspace(f"{name}_i", f"{name}_i", pos(840, 173, 120, 30), sample_time="tb.ts_log")
    tw_u = s.to_workspace(f"{name}_u", f"{name}_u", pos(840, 313, 120, 30), sample_time="tb.ts_log")
    s.conn(f"{isen}#rconn:1", f"{ps_i}#lconn:1")
    s.conn(f"{vsen}#rconn:1", f"{ps_v}#lconn:1")
    s.sig(f"{ps_i}#out:1", f"{tw_i}#in:1")
    s.sig(f"{ps_v}#out:1", f"{tw_u}#in:1")

    if topology == "three_phase_bridge":
        # star R-L load with floating star point; i_u and u_uv are logged
        star = []
        for k, ph in enumerate(("u", "v", "w")):
            r = sb.resistor(s, f"R{ph}", pos(900, 200 + 90 * k, 40, 20), "tb.load.R")
            l = sb.inductor(s, f"L{ph}", pos(980, 200 + 90 * k, 40, 20), "tb.load.L")
            if k == 0:
                s.conn(f"{isen}#rconn:2", f"{r}#lconn:1")
            elif k == 1:
                s.conn(f"{br}#rconn:2", f"{r}#lconn:1", f"{vsen}#rconn:2")
            else:
                s.conn(f"{br}#rconn:3", f"{r}#lconn:1")
            s.conn(f"{r}#rconn:1", f"{l}#lconn:1")
            star.append(f"{l}#rconn:1")
        s.conn(*star)
        s.conn(f"{br}#rconn:1", f"{isen}#lconn:1", f"{vsen}#lconn:1")
    else:
        r = sb.resistor(s, "R", pos(900, 230, 40, 20), "tb.load.R")
        l = sb.inductor(s, "L", pos(980, 230, 40, 20), "tb.load.L")
        s.conn(f"{br}#rconn:1", f"{isen}#lconn:1", f"{vsen}#lconn:1")
        s.conn(f"{isen}#rconn:2", f"{r}#lconn:1")
        s.conn(f"{r}#rconn:1", f"{l}#lconn:1")
        if topology == "full_bridge":
            s.conn(f"{l}#rconn:1", f"{br}#rconn:2", f"{vsen}#rconn:2")
        else:
            s.conn(f"{l}#rconn:1", f"{vsen}#rconn:2", *ret_node)
    if split and topology != "half_bridge":
        s.conn(*ret_node)
    return s


def build_model(out_dir):
    sids = SidPool()
    root = System(sids, location="[40, 40, 1800, 1000]", zoom="70")

    # --- common sources
    clk = root.clock("t", pos(60, 60, 30, 30))
    phase = root.constant("phase", "0", pos(60, 130, 30, 30))
    m_sin = root.sine("m_sin", "tb.m_amp", "2*pi*tb.f_out", "0", pos(60, 220, 30, 30))
    d_half = root.sine("d_half", "0.5*tb.m_amp", "2*pi*tb.f_out", "0", pos(60, 300, 30, 30), bias="0.5")
    d2 = [root.sine(f"d_{p}", "0.5*tb.m_amp", "2*pi*tb.f_out", ph, pos(60, 380 + 60 * k, 30, 30), bias="0.5")
          for k, (p, ph) in enumerate((("u", "0"), ("v", "-2*pi/3"), ("w", "2*pi/3")))]
    d3 = [root.sine(f"d_{p}_3L", "0.5*tb.m_amp", "2*pi*tb.f_out", ph, pos(60, 600 + 60 * k, 30, 30), bias="0.5")
          for k, (p, ph) in enumerate((("u", "0"), ("v", "-2*pi/3"), ("w", "2*pi/3")))]
    bc2 = root.bus_creator(3, pos(180, 380, 5, 130), name="m_uvw")
    bc3 = root.bus_creator(3, pos(180, 600, 5, 130), name="m_uvw_3L")
    for k, (p, b) in enumerate(zip(("u", "v", "w"), d2)):
        root.sig(f"{b}#out:1", f"{bc2}#in:{k + 1}", name=f"m{p}")
    for k, (p, b) in enumerate(zip(("u", "v", "w"), d3)):
        root.sig(f"{b}#out:1", f"{bc3}#in:{k + 1}", name=f"m{p}(k)")

    # --- modulators
    mods = {}
    m_in = {"hb": d_half, "1ph": m_sin, "3ph": bc2, "1ph3L": m_sin, "3ph3L": bc3}
    for k, (key, (src, m_up, m_low)) in enumerate(MODULATORS.items()):
        y = 60 + 150 * k
        mod = root.library_ref(f"modulator_{key}", src, {"in": 3, "out": 2}, pos(330, y, 200, 90),
                               [("f", "tb.fpwm"), ("m_up", m_up), ("m_low", m_low),
                                ("dead_time", "tb.dead_time"), ("pos_cmd_gate", "tb.gate_on"),
                                ("neg_cmd_gate", "tb.gate_off"), ("polarity", "1"),
                                ("tc", "tb.tc"), ("double_sampling", "1")])
        term = root.terminator(f"TRGO_{key}", pos(580, y + 10, 20, 20))
        root.sig(f"{mod}#out:1", f"{term}#in:1")
        mods[key] = mod
    # fan-outs: clock -> all time_source, phase -> all phase inputs
    root.sig(f"{clk}#out:1", [f"{m}#in:1" for m in mods.values()])
    root.sig(f"{phase}#out:1", [f"{m}#in:2" for m in mods.values()])
    root.sig(f"{d_half}#out:1", f"{mods['hb']}#in:3")
    root.sig(f"{m_sin}#out:1", [f"{mods['1ph']}#in:3", f"{mods['1ph3L']}#in:3"])
    root.sig(f"{bc2}#out:1", f"{mods['3ph']}#in:3")
    root.sig(f"{bc3}#out:1", f"{mods['3ph3L']}#in:3")
    # leg 1 of the single-phase three-level modulator drives the T-type half bridges
    sel_ph1 = root.bus_selector(["gate_cmds_ph1"], pos(640, 520, 5, 30))

    # --- test cells, one column per family
    gate_src = {}
    cells = []
    col = {"ideal_switch": 0, "igbt_simple_2th": 1, "mos_simple_2th": 2}
    row = 0
    for topology in TOPOLOGIES:
        for ttype in (False, True):
            for family in FAMILIES:
                name = block_name(topology, ttype, family)
                sid = sids()
                child = test_cell(sids, topology, ttype, family)
                x = 800 + 330 * col[family]
                y = 60 + 110 * row
                root.subsystem(f"test_{name}", pos(x, y, 260, 60), {"in": 1}, child, sid=sid)
                key = {("half_bridge", False): "hb", ("full_bridge", False): "1ph",
                       ("three_phase_bridge", False): "3ph", ("half_bridge", True): "sel_ph1",
                       ("full_bridge", True): "1ph3L", ("three_phase_bridge", True): "3ph3L"}[(topology, ttype)]
                gate_src.setdefault(key, []).append(f"{sid}#in:1")
                cells.append(name)
            row += 1
    gate_src["1ph3L"].append(f"{sel_ph1}#in:1")
    for key, dsts in gate_src.items():
        src = f"{sel_ph1}#out:1" if key == "sel_ph1" else f"{mods[key]}#out:2"
        root.sig(src, dsts)

    path = os.path.join(out_dir, "test_semiconductors_bridges.slx")
    write_slx(path, root, is_library=False, model_name="test_semiconductors_bridges",
              solver_xml=solver_model("tb.t_stop", "auto"), dataio_xml=DATAIO_MODEL,
              description=("Test bench of library/masked_models/semiconductors_bridges: the 18 "
                           "bridges with dc supply, R-L load and the five PWM modulators. Run "
                           "test_semiconductors_bridges_run.m (parameters in "
                           "test_semiconductors_bridges_param.m, struct tb). Generated by "
                           "tools/generate_test_model.py."))
    return path, cells


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "test")
    path, cells = build_model(out_dir)
    print(f"{os.path.getsize(path):>8d}  {path}")
    print(f"{len(cells)} test cells")


if __name__ == "__main__":
    main()
