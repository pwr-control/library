#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
check_emulators_mfcn.py - checks of the MATLAB Function copies of the two grid emulators,
without MATLAB.

Structure (always):
  * every zip part is well-formed XML (or a known binary part), content types and
    relationship files agree with the parts;
  * SIDs are unique, every line joins existing blocks within their port counts, every
    input port is driven exactly once;
  * MATLAB Function block: chart name = Stateflow instance name = block path,
    chartFileNumber = S-function Tag, chart inputs/outputs = Inports/Outports of the block,
    chart parameters = mask parameters, script = tools/mfcn_src/<function>.m;
  * mask = mask of the original block (parameter names, prompts, default values, dialog
    order), output bus = bus of the original (element names and order);
  * non-virtual blocks of the original and of the copy, counted as
    find_system(lib, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Virtual', 'off').

Equivalence (--sim; needs GNU Octave, numpy and scipy):
  the original block is simulated from its .slx with slxsim.py (Python, classic RK4 with
  fixed step h), the code of the copy, read from the new .slx, runs in Octave with the same
  RK4 and step (octave_mfcn.py); the outputs are compared on several scenarios. The FRT
  copy writes the ramps of the rate limiters exactly, the Rate Limiter blocks of the
  original (continuous mode) run one step ahead on a ramp: the difference is bounded by
  slew*h (h = step size, MaxStep in Simulink), so the tolerance of those cases is 3*slew*h.

Usage:
  python3 check_emulators_mfcn.py                    # structure only
  python3 check_emulators_mfcn.py --sim [--h 1e-5] [--t-end 0.2] [--plot out_dir]
"""
import argparse
import collections
import html
import os
import posixpath
import re
import sys
import time
import zipfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
LIBDIR = os.path.dirname(HERE)
sys.path.insert(0, HERE)

PAIRS = [  # (original library, copy, MATLAB Function source)
    ("three_phase_voltage_emulator", "three_phase_voltage_emulator_mfcn", "grid_emulator.m"),
    ("three_phase_voltage_with_frt_emulator", "three_phase_voltage_with_frt_emulator_mfcn",
     "grid_emulator_frt.m"),
]

VIRTUAL = {"Inport", "Outport", "BusCreator", "BusSelector", "Mux", "Demux", "From", "Goto",
           "GotoTagVisibility", "Terminator", "Ground", "SignalSpecification", "PMIOPort",
           "ConnectionLabel", "VariantSource", "VariantSink", "Trigger", "EnablePort"}
DEFAULT_PORTS = {"Inport": (0, 1), "Outport": (1, 0), "Clock": (0, 1), "Terminator": (1, 0),
                 "Constant": (0, 1), "Ground": (0, 1), "Step": (0, 1), "From": (0, 1),
                 "Goto": (1, 0)}


# ----------------------------------------------------------------------------- reading
def P(el, name):
    p = el.find(f"P[@Name='{name}']")
    return None if p is None else (p.text or "")


class Slx:
    def __init__(self, path):
        self.path = path
        self.zip = zipfile.ZipFile(path)
        self.names = set(self.zip.namelist())
        self.systems = {}
        for n in self.names:
            m = re.match(r"simulink/systems/(system_[^/]+)\.xml$", n)
            if m:
                self.systems[m.group(1)] = ET.fromstring(self.zip.read(n))

    def read(self, name):
        return self.zip.read(name)

    def blocks(self, sysname):
        return self.systems[sysname].findall("Block")

    def root_block(self):
        bl = self.blocks("system_root")
        assert len(bl) == 1, "one block expected at the root of the library"
        return bl[0]

    @staticmethod
    def child_system(block):
        ref = block.find("System")
        return None if ref is None else ref.get("Ref")


def lines_of(sys_el):
    """[(src_sid, src_port, dst_sid, dst_port, name)] including branches."""
    out = []

    def walk(el, src, name):
        s = P(el, "Src")
        if s is not None:
            sid, port = s.rsplit("#", 1)
            src = (sid, int(port.split(":")[1]))
        n = P(el, "Name")
        if n is not None:
            name = n
        d = P(el, "Dst")
        if d is not None:
            sid, port = d.rsplit("#", 1)
            out.append((src[0], src[1], sid, int(port.split(":")[1]), name))
        for br in el.findall("Branch"):
            walk(br, src, name)

    for ln in sys_el.findall("Line"):
        walk(ln, None, None)
    return out


def mask_of(block):
    m = block.find("Mask")
    params = [(p.get("Name"), p.findtext("Prompt"), p.findtext("Value"))
              for p in m.findall("MaskParameter")]
    dialog = [d.get("Name") for d in m.iter("DialogControl") if d.get("Type") == "Edit"]
    return params, dialog


def bus_of(slx):
    """Element names of the bus at the Outport of the masked block, in order."""
    root = slx.root_block()
    sysname = slx.child_system(root)
    s = slx.systems[sysname]
    bc = [b for b in s.findall("Block") if b.get("BlockType") == "BusCreator"]
    assert len(bc) == 1
    bc = bc[0]
    names = {}
    for src_sid, src_port, dst_sid, dst_port, name in lines_of(s):
        if dst_sid == bc.get("SID"):
            names[dst_port] = name
    outport = [b.get("Name") for b in s.findall("Block") if b.get("BlockType") == "Outport"]
    return [names[k] for k in sorted(names)], outport


def count_non_virtual(slx):
    """find_system(lib, 'LookUnderMasks','all', 'FollowLinks','on', 'Virtual','off'),
    following the $bdroot library links inside the same file."""
    paths = {}

    def index(sysname, prefix):
        for b in slx.blocks(sysname):
            path = (prefix + "/" if prefix else "") + b.get("Name")
            paths[path] = b
            child = slx.child_system(b)
            if b.get("BlockType") == "SubSystem" and child:
                index(child, path)

    index("system_root", "")
    counts = collections.Counter()

    def walk(sysname):
        for b in slx.blocks(sysname):
            typ = b.get("BlockType")
            if typ == "Reference":
                src = P(b, "SourceBlock")
                assert src.startswith("$bdroot/"), src
                b = paths[src[len("$bdroot/"):].replace("\\n", "\n")]
                typ = b.get("BlockType")
            if typ == "SubSystem":
                if P(b, "TreatAsAtomicUnit") == "on":
                    counts["SubSystem (atomic)"] += 1
                child = slx.child_system(b)
                if child:
                    walk(child)
            elif typ not in VIRTUAL:
                counts[typ] += 1

    walk("system_root")
    return sum(counts.values()), counts


# ----------------------------------------------------------------------------- structure
def check_structure(slx, original, src_file):
    errors = []
    err = errors.append
    names = slx.names

    # content types
    ct = ET.fromstring(slx.read("[Content_Types].xml"))
    ns = {"c": "http://schemas.openxmlformats.org/package/2006/content-types"}
    overrides = {o.get("PartName").lstrip("/") for o in ct.findall("c:Override", ns)}
    defaults = {d.get("Extension") for d in ct.findall("c:Default", ns)}
    for o in overrides:
        if o not in names:
            err(f"content type override for a missing part: {o}")
    for n in names:
        ext = n.rsplit(".", 1)[-1]
        if n != "[Content_Types].xml" and n not in overrides and ext not in defaults:
            err(f"part without content type: {n}")
        if n.startswith(("simulink/systems/system_", "simulink/stateflow/chart_")) \
                and n.endswith(".xml") and n not in overrides:
            err(f"system/chart part without its override: {n}")

    # well-formed XML and relationship targets
    for n in names:
        if n.endswith((".xml", ".rels")):
            try:
                el = ET.fromstring(slx.read(n))
            except ET.ParseError as e:
                err(f"{n}: {e}")
                continue
            if n.endswith(".rels"):
                folder = posixpath.dirname(posixpath.dirname(n))
                for r in el:
                    target = posixpath.normpath(posixpath.join(folder, r.get("Target")))
                    if target not in names:
                        err(f"{n}: relationship to a missing part {target}")

    # SIDs, ports, lines
    sid_seen = {}
    for sysname, s in slx.systems.items():
        ports = {}
        for b in s.findall("Block"):
            sid = b.get("SID")
            if sid in sid_seen:
                err(f"duplicate SID {sid} in {sysname} and {sid_seen[sid]}")
            sid_seen[sid] = sysname
            pc = b.find("PortCounts")
            if pc is not None:
                ports[sid] = (int(pc.get("in", 0)), int(pc.get("out", 0)))
            else:
                ports[sid] = DEFAULT_PORTS.get(b.get("BlockType"), (0, 0))
            child = slx.child_system(b)
            if child and child not in slx.systems:
                err(f"{sysname}: block {b.get('Name')} refers to missing {child}")
        driven = collections.Counter()
        used = set()
        for src_sid, src_port, dst_sid, dst_port, _ in lines_of(s):
            for sid, port, kind in ((src_sid, src_port, 1), (dst_sid, dst_port, 0)):
                if sid not in ports:
                    err(f"{sysname}: line to a missing block {sid}")
                elif not 1 <= port <= ports[sid][kind]:
                    err(f"{sysname}: port {port} out of range on block {sid}")
            driven[(dst_sid, dst_port)] += 1
            used.add((src_sid, src_port))
        for sid, (nin, nout) in ports.items():
            for k in range(1, nin + 1):
                if driven[(sid, k)] != 1:
                    err(f"{sysname}: input {k} of block {sid} driven {driven[(sid, k)]} times")
            for k in range(1, nout + 1):
                if (sid, k) not in used and sysname != "system_root":   # library root: free
                    err(f"{sysname}: output {k} of block {sid} not connected")
        high = P(s, "SIDHighWatermark")
        if high is not None:
            local = [int(x.rsplit(":", 1)[-1]) for x in ports]
            if int(high) < max(local):
                err(f"{sysname}: SIDHighWatermark {high} < {max(local)}")

    # MATLAB Function block <-> Stateflow chart <-> source file
    root = slx.root_block()
    inner = slx.child_system(root)
    machine = ET.fromstring(slx.read("simulink/stateflow/machine.xml"))
    instances = {P(i, "name"): P(i, "chart") for i in machine.findall("instance")}
    charts = {}
    for n in names:
        if re.match(r"simulink/stateflow/chart_\d+\.xml$", n):
            c = ET.fromstring(slx.read(n))
            charts[P(c, "chartFileNumber")] = c
    mfcns = [b for b in slx.blocks(inner) if P(b, "SFBlockType") == "MATLAB Function"]
    if len(mfcns) != 1:
        err(f"one MATLAB Function block expected, found {len(mfcns)}")
    for b in mfcns:
        path = f"{root.get('Name')}/{b.get('Name')}"
        msys = slx.child_system(b)
        sfun = [x for x in slx.blocks(msys) if x.get("BlockType") == "S-Function"][0]
        num = P(sfun, "Tag").split()[-1]
        chart = charts.get(num)
        if chart is None:
            err(f"no chart with chartFileNumber {num}")
            continue
        if P(chart, "name") != path:
            err(f"chart name {P(chart, 'name')} != block path {path}")
        if instances.get(path) != chart.get("id"):
            err(f"Stateflow instance of {path} does not point to chart {chart.get('id')}")
        data = collections.defaultdict(list)
        for d in chart.find("Children").findall("data"):
            data[P(d, "scope")].append(d.get("name"))
        ins = sorted(((int(P(x, "Port") or 1), x.get("Name")) for x in slx.blocks(msys)
                      if x.get("BlockType") == "Inport"))
        outs = sorted(((int(P(x, "Port") or 1), x.get("Name")) for x in slx.blocks(msys)
                       if x.get("BlockType") == "Outport"))
        if [n for _, n in ins] != data["INPUT_DATA"]:
            err(f"chart inputs {data['INPUT_DATA']} != Inports {ins}")
        if [n for _, n in outs] != data["OUTPUT_DATA"]:
            err(f"chart outputs {data['OUTPUT_DATA']} != Outports {outs}")
        if P(sfun, "PortCounts") != f"[{len(ins)} {len(outs) + 1}]":
            err(f"S-function PortCounts {P(sfun, 'PortCounts')}")
        pc = b.find("PortCounts")
        if (int(pc.get("in", 0)), int(pc.get("out", 0))) != (len(ins), len(outs)):
            err("PortCounts of the MATLAB Function block do not match its ports")
        mask_names = [p[0] for p in mask_of(root)[0]]
        if data["PARAMETER_DATA"] != mask_names:
            err(f"chart parameters {data['PARAMETER_DATA']} != mask parameters {mask_names}")
        script = chart.find(".//eml/P[@Name='script']").text
        with open(os.path.join(HERE, "mfcn_src", src_file), encoding="utf-8") as fh:
            if fh.read().replace("\r\n", "\n") != script:
                err(f"the script in the .slx differs from tools/mfcn_src/{src_file}")

    # same mask, same bus as the original
    o_root = original.root_block()
    if o_root.get("Name") != root.get("Name"):
        err(f"block name {root.get('Name')} != original {o_root.get('Name')}")
    if mask_of(o_root) != mask_of(root):
        err("mask parameters or dialog differ from the original")
    if bus_of(original) != bus_of(slx):
        err(f"output bus {bus_of(slx)} != original {bus_of(original)}")
    return errors


# ----------------------------------------------------------------------------- equivalence
def scenarios():
    import numpy as np
    from scipy import signal

    def sof(f0, zeta=1.0):
        w = 2 * np.pi * f0
        return (np.array([[-2 * zeta * w, -w * w], [1.0, 0.0]]), np.array([[1.0], [0.0]]),
                np.array([[0.0, w * w]]))

    def fof(fc):
        w = 2 * np.pi * fc
        return np.array([[-w]]), np.array([[1.0]]), np.array([[w]])

    # a non-companion realization of a second-order filter (similarity transform)
    A2, B2, C2 = sof(80.0, 0.7)
    T = np.array([[1.0, 0.3], [-0.2, 0.8]]) * np.array([[1.0], [1.0 / (2 * np.pi * 80.0)]])
    Ti = np.linalg.inv(T)
    A3, B3, C3 = Ti @ A2 @ T, Ti @ B2, C2 @ T
    assert np.allclose(signal.ss2tf(A3, B3, C3, np.zeros((1, 1)))[0],
                       signal.ss2tf(A2, B2, C2, np.zeros((1, 1)))[0])

    base = [
        ("default mask values", dict(freq=50, ugrid_nom=690, vp_xi_pu=1, vp_eta_pu=0,
                                     vn_xi_pu=0, vn_eta_pu=0, fcut_lvrt=50)),
        ("60 Hz, unbalanced, 20 Hz LVRT filter",
         dict(freq=60, ugrid_nom=400, vp_xi_pu=0.9, vp_eta_pu=0.1, vn_xi_pu=0.05,
              vn_eta_pu=-0.04, fcut_lvrt=20)),
    ]
    A, B, C = sof(50.0)
    frt0 = dict(nominal_frequency_m=50, nominal_voltage_m=690, Vemu_ref_norm_m=1.0,
                vp_xi_pu_m=1, vp_eta_pu_m=0.05, vn_xi_pu_m=0.04, vn_eta_pu_m=-0.03,
                Am=A, Bm=B, Cm=C, enable_frt_1_m=0, enable_frt_2_m=0,
                start_time_LVRT_m=0.05, end_time_LVRT_m=0.12, deepPOSxi_m=0.6,
                deepPOSeta_m=-0.4, deepNEGxi_m=0.4, deepNEGeta_m=0.4, Amplitude_U_m=0.25,
                Amplitude_V_m=0.6, Amplitude_W_m=0.6, t_ramp_m=0.02, Phase_shift_m=-0.3)
    Af, Bf, Cf = fof(100.0)
    frt = [
        ("no FRT (enable_frt_1 = enable_frt_2 = 0)", frt0),
        ("FRT 2: dips on the sequence references", dict(frt0, enable_frt_2_m=1)),
        ("FRT 1: dips on the phase amplitudes + phase shift", dict(frt0, enable_frt_1_m=1)),
        ("FRT 1, t_ramp = 0, first-order filter",
         dict(frt0, enable_frt_1_m=1, t_ramp_m=0, Am=Af, Bm=Bf, Cm=Cf)),
        ("FRT 2, non-companion second-order filter, 60 Hz",
         dict(frt0, enable_frt_2_m=1, nominal_frequency_m=60, Am=A3, Bm=B3, Cm=C3,
              t_ramp_m=0.01, start_time_LVRT_m=0.04)),
    ]
    return base, frt


def original_workspace(orig, prm):
    """Mask workspace of the original block: the base emulator adds the variables of its
    mask callback init_grid_emulator.m (Control System Toolbox tf2ss of the LVRT filter)."""
    import numpy as np
    from scipy import signal
    import warnings
    ws = dict(prm)
    if orig == "three_phase_voltage_emulator":
        wc = 2 * np.pi * prm["fcut_lvrt"]
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", signal.BadCoefficients)   # leading zero of num
            A, B, C, _ = signal.tf2ss([0.0, 1.0], [1.0 / wc, 1.0])
        ws.update(ugrid_phase=prm["ugrid_nom"] / np.sqrt(3 / 2),
                  omega_grid_emulator_nom=prm["freq"] * 2 * np.pi, A=A, B=B, C=C)
    return ws


def tolerance(prm, h):
    """Bound of the difference copy - original of the FRT emulator with a fixed step h [pu].

    - Ramps: the Rate Limiter blocks of the original (continuous mode) run one step ahead,
      the copy writes the exact ramp: |difference| <= slew*h on every reference; a phase
      voltage combines up to four references with weights <= 1 (factor 3 used).
    - Steps on the grid: the Step blocks of the original switch at the major step, the copy
      at t >= t_step, i.e. already in the last Runge-Kutta stage (weight 1/6) of the step
      that ends on t_step: the filter state differs by h/6*Bm*jump, the output by at most
      h/6*g_max*jump (g_max = peak of the impulse response Cm*expm(Am*t)*Bm), then decays.
    """
    import numpy as np
    from scipy.linalg import expm
    A = np.atleast_2d(prm["Am"])
    B = np.atleast_2d(prm["Bm"]).reshape(-1, 1)
    C = np.atleast_2d(prm["Cm"]).reshape(1, -1)
    lam = np.max(np.abs(np.linalg.eigvals(A)))
    g_max = max(abs((C @ expm(A * t) @ B).item()) for t in np.linspace(0, 20 / lam, 2001))
    e1, e2 = prm["enable_frt_1_m"] == 1, prm["enable_frt_2_m"] == 1
    vref = prm["Vemu_ref_norm_m"]
    seq = [prm["vp_xi_pu_m"] * prm["deepPOSxi_m"], prm["deepPOSeta_m"], prm["deepNEGxi_m"],
           prm["deepNEGeta_m"]]
    amp = [vref * (1 - prm[k]) for k in ("Amplitude_U_m", "Amplitude_V_m", "Amplitude_W_m")]
    ramps = prm["t_ramp_m"] > 0 and (e1 or e2)
    jump = 0.0
    if e1:
        jump += abs(prm["Phase_shift_m"])                   # never rate limited
    if not ramps:
        jump += (sum(map(abs, seq)) if (e1 or e2) else 0) + (sum(map(abs, amp)) if e1 else 0)
    tol = 2 * h / 6 * g_max * jump + 1e-6
    if ramps:
        tol += 3 * vref / prm["t_ramp_m"] * h
    return tol, ramps


def compare(pair, cases, h, t_end, plot_dir=None):
    import numpy as np
    import octave_mfcn
    from slxsim import Library, Simulator

    orig, copy, _ = pair
    original = Library(os.path.join(LIBDIR, orig + ".slx"))
    new = Slx(os.path.join(LIBDIR, copy + ".slx"))
    chart = [ET.fromstring(new.read(n)) for n in new.names
             if re.match(r"simulink/stateflow/chart_\d+\.xml$", n)][0]
    script = chart.find(".//eml/P[@Name='script']").text
    data = collections.defaultdict(list)
    for d in chart.find("Children").findall("data"):
        data[P(d, "scope")].append(d.get("name"))
    outputs = [o for o in data["OUTPUT_DATA"] if o != "dx"]
    stateful = "x" in data["INPUT_DATA"]
    ok = True
    rows = []
    for title, prm in cases:
        vnom = prm.get("ugrid_nom", prm.get("nominal_voltage_m"))
        kv = vnom / np.sqrt(1.5)                      # phase peak voltage [V] = 1 pu
        nx = 8 * np.atleast_2d(prm["Am"]).shape[0] if stateful else 0
        t0 = time.time()
        to, yo = Simulator(original, original_workspace(orig, prm)).run(t_end, h)
        t1 = time.time()
        tn, yn = octave_mfcn.run(script, prm, outputs, t_end, h, nx=nx)
        t2 = time.time()
        tol, ramps = tolerance(prm, h) if stateful else (1e-6, False)
        worst = 0.0
        detail = []
        for name in outputs:
            d = yn[name] - yo[name]
            if name.startswith("gamma"):
                d = np.mod(d + np.pi, 2 * np.pi) - np.pi
                e, unit = np.max(np.abs(d)), "rad"
            elif name.startswith("omega"):
                e, unit = np.max(np.abs(d)) / (2 * np.pi * 50), "pu of 2*pi*50 rad/s"
            else:
                e, unit = np.max(np.abs(d)) / kv, "pu of Vnom*sqrt(2/3)"
            worst = max(worst, e)
            detail.append((name, e, unit))
        passed = worst <= tol
        ok &= passed
        rows.append((title, worst, tol, passed))
        print(f"  {'PASS' if passed else 'FAIL'}  {title}: max difference {worst:.2e} "
              f"(tolerance {tol:.1e}; original {t1 - t0:.0f} s in Python, copy {t2 - t1:.0f} s "
              "in Octave)")
        for name, e, unit in detail:
            print(f"          {name:20s} {e:.2e} {unit}")
        if plot_dir and ramps and prm["enable_frt_1_m"] == 1:
            plot_case(plot_dir, copy, title, to, yo, yn, kv)
    return ok, rows


def plot_case(plot_dir, copy, title, t, yo, yn, kv):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
    os.makedirs(plot_dir, exist_ok=True)
    fig, ax = plt.subplots(3, 1, figsize=(10, 9), sharex=True)
    colors = {"ua_grid_emu": "#1f77b4", "ub_grid_emu": "#d62728", "uc_grid_emu": "#2ca02c"}
    for name, c in colors.items():
        ax[0].plot(t, yo[name] / kv, color=c, lw=2.5, alpha=0.35, label=f"{name} original")
        ax[0].plot(t, yn[name] / kv, color=c, lw=0.9, ls="--", label=f"{name} copy")
    ax[0].set_ylabel("phase voltage [pu]")
    ax[0].legend(ncol=3, fontsize=8, loc="lower left")
    for name in ("vp_xi", "vp_eta", "vn_xi", "vn_eta"):
        ax[1].plot(t, yo[name] / kv, lw=2.5, alpha=0.35)
        ax[1].plot(t, yn[name] / kv, lw=0.9, ls="--", label=name)
    ax[1].set_ylabel("sequence voltages [pu]")
    ax[1].legend(ncol=4, fontsize=8)
    for name, c in colors.items():
        ax[2].plot(t, (yn[name] - yo[name]) / kv, color=c, lw=0.9, label=name)
    ax[2].set_ylabel("copy - original [pu]")
    ax[2].set_xlabel("t [s]")
    ax[2].legend(ncol=3, fontsize=8)
    ax[0].set_title(f"{copy}: {title}")
    for a in ax:
        a.grid(alpha=0.3)
    fig.tight_layout()
    out = os.path.join(plot_dir, f"{copy}_frt1.png")
    fig.savefig(out, dpi=120)
    print(f"          figure {out}")


# ----------------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--sim", action="store_true", help="also compare the outputs (Octave)")
    ap.add_argument("--h", type=float, default=1e-5, help="fixed step of the comparison [s]")
    ap.add_argument("--t-end", type=float, default=0.2, help="simulated time [s]")
    ap.add_argument("--plot", default=None, help="folder for a figure of the FRT 1 case")
    args = ap.parse_args()

    ok = True
    for orig, copy, src in PAIRS:
        o = Slx(os.path.join(LIBDIR, orig + ".slx"))
        c = Slx(os.path.join(LIBDIR, copy + ".slx"))
        errors = check_structure(c, o, src)
        n_o, _ = count_non_virtual(o)
        n_c, cnt = count_non_virtual(c)
        print(f"{copy}.slx: {'OK' if not errors else 'ERRORS'}; non-virtual blocks "
              f"{n_o} (original) -> {n_c} ({', '.join(f'{k} {v}' for k, v in sorted(cnt.items()))})")
        print(f"  mask parameters: {len(mask_of(c.root_block())[0])}, same as the original; "
              f"bus: {', '.join(bus_of(c)[0])}")
        for e in errors:
            print("  ERROR", e)
        ok &= not errors

    if args.sim:
        base, frt = scenarios()
        for pair, cases in zip(PAIRS, (base, frt)):
            print(f"{pair[1]}: equivalence, h = {args.h:g} s, t_end = {args.t_end:g} s")
            res, _ = compare(pair, cases, args.h, args.t_end, args.plot)
            ok &= res
    print("ALL CHECKS PASSED" if ok else "SOME CHECKS FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
