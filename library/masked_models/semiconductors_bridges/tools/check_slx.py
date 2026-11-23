#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
check_slx.py - structural checks of .slx files written by generate_bridges.py /
generate_test_model.py (no MATLAB needed):

  * every zip part is well-formed XML (or a known binary part);
  * [Content_Types].xml and the relationship files agree with the parts;
  * SIDs are unique, SIDHighWatermark is the maximum;
  * every line endpoint names an existing block and a port index within its PortCounts;
  * every Simscape block has its SimscapeInstrumentationVariables mxarray and relationship;
  * physical ports (PMIOPort) are numbered 1..n without gaps;
  * every Inport/Outport/BusCreator/BusSelector/Simscape port is connected exactly once
    (fan-out from one output is allowed), and every Simulink input is driven.

Usage: python3 check_slx.py file.slx [more.slx ...]
"""
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from collections import defaultdict


def P(el, name):
    for p in el.findall("P"):
        if p.get("Name") == name:
            return p.text
    return None


def check(path):
    errors = []
    z = zipfile.ZipFile(path)
    names = set(z.namelist())

    def err(msg):
        errors.append(msg)

    # content types vs parts
    ct = ET.fromstring(z.read("[Content_Types].xml"))
    ns = {"c": "http://schemas.openxmlformats.org/package/2006/content-types"}
    overrides = {o.get("PartName").lstrip("/") for o in ct.findall("c:Override", ns)}
    for o in overrides:
        if o not in names:
            err(f"content type override for missing part {o}")
    for n in names:
        if n.endswith(".xml") and not n.endswith(".rels") and n not in overrides \
                and n not in ("[Content_Types].xml", "simulink/configSetInfo.xml"):
            err(f"xml part without content type override: {n}")   # configSetInfo uses the Default

    # xml well-formedness
    for n in names:
        if n.endswith(".xml") or n.endswith(".rels"):
            try:
                ET.fromstring(z.read(n))
            except ET.ParseError as e:
                err(f"{n}: {e}")

    # systems
    systems = {}
    for n in names:
        m = re.match(r"simulink/systems/system_(\w+)\.xml$", n)
        if m:
            systems[m.group(1)] = ET.fromstring(z.read(n))
    if "root" not in systems:
        err("no system_root.xml")
        return errors

    blocks = {}      # sid -> (system key, element)
    ssc_sids = []
    pmio_by_sys = defaultdict(list)
    for key, root in systems.items():
        for b in root.findall("Block"):
            sid = b.get("SID")
            if sid in blocks:
                err(f"duplicate SID {sid}")
            blocks[sid] = (key, b)
            idata = b.find("InstanceData")
            if idata is not None:
                for p in idata.findall("P"):
                    if p.get("Name") == "SimscapeInstrumentationVariables":
                        ssc_sids.append(sid)
                        ref = p.get("Ref")
                        part = "simulink/bdmxdata/" + ref.split(":")[1] + ".mxarray"
                        if part not in names:
                            err(f"missing {part}")
            if b.get("BlockType") == "PMIOPort":
                pmio_by_sys[key].append(int(P(b, "Port") or 1))
            sysref = b.find("System")
            if sysref is not None:
                ref = sysref.get("Ref").replace("system_", "")
                if ref not in systems:
                    err(f"block {sid} refers to missing system {ref}")
                elif ref != sid:
                    err(f"block {sid} refers to system {ref} (expected same number)")
    high = int(P(systems["root"], "SIDHighWatermark") or 0)
    maxsid = max(int(s) for s in blocks)
    if high < maxsid:
        err(f"SIDHighWatermark {high} < max SID {maxsid}")
    for key, ports in pmio_by_sys.items():
        if sorted(ports) != list(range(1, len(ports) + 1)):
            err(f"system {key}: PMIO port numbers {sorted(ports)}")

    # relationships for mxarrays
    rels = ET.fromstring(z.read("simulink/_rels/blockdiagram.xml.rels"))
    rel_ids = {r.get("Id") for r in rels}
    for sid in ssc_sids:
        if f"SimscapeInstrumentationVariables_{sid}" not in rel_ids:
            err(f"no relationship for SimscapeInstrumentationVariables_{sid}")

    # port counts and line endpoints
    def port_counts(b):
        pc = b.find("PortCounts")
        c = {"in": 0, "out": 0, "lconn": 0, "rconn": 0}
        bt = b.get("BlockType")
        if pc is not None:
            for k, v in pc.attrib.items():
                c[k] = int(v)
        else:
            if bt in ("Inport", "Constant", "Clock", "Sin"):
                c["out"] = 1
            elif bt in ("Outport", "Terminator", "ToWorkspace"):
                c["in"] = 1
            elif bt == "Gain":
                c["in"] = 1; c["out"] = 1
            elif bt == "PMIOPort":
                c["rconn"] = 1
            elif bt in ("Scope",):
                c["in"] = int(P(b, "NumInputPorts") or 1)
        return c

    is_library = ET.fromstring(z.read("simulink/blockdiagram.xml")).find("Library") is not None
    for key, root in systems.items():
        if is_library and key == "root":
            continue              # the library block itself has no connections
        used = defaultdict(int)   # (sid, type, idx) -> count
        local = {b.get("SID"): b for b in root.findall("Block")}

        def endpoint(txt, where):
            m = re.match(r"(\d+)#(in|out|lconn|rconn):(\d+)$", txt or "")
            if not m:
                err(f"system {key}: bad endpoint {txt!r} ({where})")
                return
            sid, typ, idx = m.group(1), m.group(2), int(m.group(3))
            if sid not in local:
                err(f"system {key}: line endpoint {txt} refers to a block of another system")
                return
            if idx < 1 or idx > port_counts(local[sid])[typ]:
                err(f"system {key}: {txt} out of range for {local[sid].get('Name')!r} {port_counts(local[sid])}")
            used[(sid, typ, idx)] += 1

        def walk(el, signal):
            s = P(el, "Src"); d = P(el, "Dst")
            if s: endpoint(s, "Src")
            if d: endpoint(d, "Dst")
            for br in el.findall("Branch"):
                walk(br, signal)

        for ln in root.findall("Line"):
            walk(ln, ln.get("LineType") != "Connection")

        for sid, b in local.items():
            c = port_counts(b)
            bt = b.get("BlockType")
            for typ in ("in", "lconn", "rconn"):
                for i in range(1, c[typ] + 1):
                    n = used[(sid, typ, i)]
                    if n == 0:
                        err(f"system {key}: unconnected {typ}:{i} of {b.get('Name')!r} ({bt})")
                    elif n > 1:
                        err(f"system {key}: port {typ}:{i} of {b.get('Name')!r} appears in {n} lines")
            for i in range(1, c["out"] + 1):
                n = used[(sid, "out", i)]
                if n == 0:
                    err(f"system {key}: unused output out:{i} of {b.get('Name')!r} ({bt})")
                elif n > 1:
                    err(f"system {key}: output out:{i} of {b.get('Name')!r} appears in {n} lines (use one line with branches)")
    return errors


def main():
    bad = 0
    for path in sys.argv[1:]:
        errs = check(path)
        status = "OK " if not errs else "ERR"
        print(f"{status} {path}")
        for e in errs[:40]:
            print("     -", e)
        bad += bool(errs)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
