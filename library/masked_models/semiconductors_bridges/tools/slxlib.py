#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
slxlib - minimal writer of Simulink .slx files (libraries and models) without MATLAB.

The .slx container is a zip of XML parts. This module builds the parts that Simulink
needs to load a block diagram: blockdiagram.xml, one systems/system_<sid>.xml per
(sub)system, the relationship files, the content types, the metadata and the small
binary mxarray parts that every Simscape block refers to.

Only the block types used by the semiconductor bridge library and by its test model are
provided. The XML fragments of the Simscape blocks are copies of what Simulink R2026a
writes for the same blocks, with the parameter values replaced.
"""
import io
import base64
import os
import struct
import uuid
import zlib
import zipfile
import datetime
from xml.sax.saxutils import escape

RELEASE = "R2026a"
RELEASE_VERSION = "26.1.0.3346908"
FL_VERSION = "26001000.2"      # LibraryVersion written for fl_lib blocks
NESL_VERSION = "11.0"          # LibraryVersion written for nesl_utility blocks
SSC_LIB_VERSION = "26001000.1" # LibraryVersion written for ssc_build libraries


# ----------------------------------------------------------------------------- helpers
def esc(text):
    """Escape text content (newlines are kept, as Simulink does)."""
    return escape(str(text), {'"': "&quot;", "'": "&apos;"})


def esc_attr(text):
    """Escape an attribute value (newlines become &#xA;)."""
    return escape(str(text), {'"': "&quot;", "'": "&apos;", "\n": "&#xA;"})


def P(name, value):
    return f'    <P Name="{name}">{esc(value)}</P>\n'


def P_indent(name, value, indent):
    return f'{indent}<P Name="{name}">{esc(value)}</P>\n'


def pos(x, y, w, h):
    return f"[{x}, {y}, {x + w}, {y + h}]"


def new_uuid():
    return str(uuid.uuid4())


class SidPool:
    def __init__(self, start=1):
        self.next = start

    def __call__(self):
        s = self.next
        self.next += 1
        return s

    @property
    def high(self):
        return self.next - 1


# ----------------------------------------------------------------------------- systems
class System:
    """One Simulink system: a list of block XML fragments and line XML fragments."""

    def __init__(self, sid_pool, location="[100, 100, 1500, 900]", zoom="100"):
        self.sids = sid_pool
        self.blocks = []        # (sid, xml)
        self.lines = []         # xml
        self.children = {}      # sid -> System (subsystems defined in this system)
        self.ssc_sids = []      # SIDs of Simscape blocks (need an mxarray part)
        self.location = location
        self.zoom = zoom
        self.zorder = 1

    def z(self):
        self.zorder += 1
        return self.zorder

    def add(self, xml, sid, simscape=False):
        self.blocks.append((sid, xml))
        if simscape:
            self.ssc_sids.append(sid)
        return sid

    # --- generic Simulink blocks ------------------------------------------------
    def inport(self, name, port, position):
        sid = self.sids()
        xml = (f'  <Block BlockType="Inport" Name="{esc_attr(name)}" SID="{sid}">\n'
               + P("Position", position) + P("ZOrder", self.z())
               + (P("Port", port) if port != 1 else "")
               + '  </Block>\n')
        return self.add(xml, sid)

    def outport(self, name, port, position):
        sid = self.sids()
        xml = (f'  <Block BlockType="Outport" Name="{esc_attr(name)}" SID="{sid}">\n'
               + P("Position", position) + P("ZOrder", self.z())
               + (P("Port", port) if port != 1 else "")
               + '  </Block>\n')
        return self.add(xml, sid)

    def pmio(self, name, port, side, position, mirror=False):
        """Physical connection port of a subsystem. side = 'Left' | 'Right'.
        Port numbers are global over all PMIO ports of the subsystem."""
        sid = self.sids()
        xml = (f'  <Block BlockType="PMIOPort" Name="{esc_attr(name)}" SID="{sid}">\n'
               + P("Position", position) + P("ZOrder", self.z())
               + (P("BlockMirror", "on") if mirror else "")
               + (P("Port", port) if port != 1 else "")
               + P("Side", side)
               + '  </Block>\n')
        return self.add(xml, sid)

    def bus_selector(self, signals, position):
        sid = self.sids()
        ports = "".join(
            f'      <Port Type="out" Index="{i + 1}">\n        <P Name="Name">&lt;{esc(s.split(".")[-1])}&gt;</P>\n      </Port>\n'
            for i, s in enumerate(signals))
        xml = (f'  <Block BlockType="BusSelector" Name="Bus&#xA;Selector" SID="{sid}">\n'
               f'    <PortCounts in="1" out="{len(signals)}"/>\n'
               + P("Position", position) + P("ZOrder", self.z())
               + P("OutputSignals", ",".join(signals))
               + '    <PortProperties>\n' + ports + '    </PortProperties>\n'
               + '  </Block>\n')
        return self.add(xml, sid)

    def bus_creator(self, n, position, name="Bus\nCreator", out_name=None):
        sid = self.sids()
        pp = ""
        if out_name:
            pp = ('    <PortProperties>\n      <Port Type="out" Index="1">\n'
                  f'        <P Name="Name">{esc(out_name)}</P>\n      </Port>\n    </PortProperties>\n')
        xml = (f'  <Block BlockType="BusCreator" Name="{esc_attr(name)}" SID="{sid}">\n'
               f'    <PortCounts in="{n}" out="1"/>\n'
               + P("Position", position) + P("ZOrder", self.z())
               + P("Inputs", n) + P("DisplayOption", "bar") + P("InheritFromInputs", "on")
               + pp + '  </Block>\n')
        return self.add(xml, sid)

    def mux(self, n, position, name="Mux"):
        sid = self.sids()
        xml = (f'  <Block BlockType="Mux" Name="{esc_attr(name)}" SID="{sid}">\n'
               f'    <PortCounts in="{n}" out="1"/>\n'
               + P("Position", position) + P("ZOrder", self.z())
               + P("Inputs", n) + P("DisplayOption", "bar") + '  </Block>\n')
        return self.add(xml, sid)

    def constant(self, name, value, position):
        sid = self.sids()
        xml = (f'  <Block BlockType="Constant" Name="{esc_attr(name)}" SID="{sid}">\n'
               + P("Position", position) + P("ZOrder", self.z()) + P("Value", value)
               + '  </Block>\n')
        return self.add(xml, sid)

    def gain(self, name, value, position):
        sid = self.sids()
        xml = (f'  <Block BlockType="Gain" Name="{esc_attr(name)}" SID="{sid}">\n'
               + P("Position", position) + P("ZOrder", self.z()) + P("Gain", value)
               + '  </Block>\n')
        return self.add(xml, sid)

    def sum(self, name, inputs, position):
        sid = self.sids()
        n = sum(1 for c in inputs if c in "+-")
        xml = (f'  <Block BlockType="Sum" Name="{esc_attr(name)}" SID="{sid}">\n'
               f'    <PortCounts in="{n}" out="1"/>\n'
               + P("Position", position) + P("ZOrder", self.z())
               + P("IconShape", "rectangular") + P("Inputs", inputs)
               + '  </Block>\n')
        return self.add(xml, sid)

    def clock(self, name, position):
        sid = self.sids()
        xml = (f'  <Block BlockType="Clock" Name="{esc_attr(name)}" SID="{sid}">\n'
               + P("Position", position) + P("ZOrder", self.z()) + '  </Block>\n')
        return self.add(xml, sid)

    def sine(self, name, amplitude, frequency, phase, position, bias="0"):
        sid = self.sids()
        xml = (f'  <Block BlockType="Sin" Name="{esc_attr(name)}" SID="{sid}">\n'
               '    <PortCounts out="1"/>\n'
               + P("Position", position) + P("ZOrder", self.z())
               + P("Amplitude", amplitude) + (P("Bias", bias) if str(bias) != "0" else "")
               + P("Frequency", frequency) + P("Phase", phase)
               + P("SampleTime", "0") + '  </Block>\n')
        return self.add(xml, sid)

    def terminator(self, name, position):
        sid = self.sids()
        xml = (f'  <Block BlockType="Terminator" Name="{esc_attr(name)}" SID="{sid}">\n'
               + P("Position", position) + P("ZOrder", self.z()) + '  </Block>\n')
        return self.add(xml, sid)

    def to_workspace(self, name, varname, position, sample_time="-1"):
        sid = self.sids()
        xml = (f'  <Block BlockType="ToWorkspace" Name="{esc_attr(name)}" SID="{sid}">\n'
               '    <PortCounts in="1"/>\n'
               + P("Position", position) + P("ZOrder", self.z())
               + P("VariableName", varname) + P("MaxDataPoints", "inf")
               + P("SampleTime", sample_time) + P("SaveFormat", "Timeseries")
               + '  </Block>\n')
        return self.add(xml, sid)

    def scope(self, name, n_in, position):
        sid = self.sids()
        xml = (f'  <Block BlockType="Scope" Name="{esc_attr(name)}" SID="{sid}">\n'
               f'    <PortCounts in="{n_in}"/>\n'
               + P("Position", position) + P("ZOrder", self.z())
               + P("NumInputPorts", n_in) + P("Floating", "off")
               + '  </Block>\n')
        return self.add(xml, sid)

    def subsystem(self, name, position, counts, child, mask_xml="", portschema=None,
                  extra="", sid=None):
        """A plain subsystem. counts = dict(in=, out=, lconn=, rconn=); child = System.
        sid may be reserved beforehand with sid_pool() so that the subsystem block gets a
        lower SID than its content."""
        if sid is None:
            sid = self.sids()
        pc = " ".join(f'{k}="{v}"' for k, v in counts.items() if v)
        xml = (f'  <Block BlockType="SubSystem" Name="{esc_attr(name)}" SID="{sid}">\n'
               f'    <PortCounts {pc}/>\n'
               + P("Position", position) + P("ZOrder", self.z())
               + extra
               + P("ContentPreviewEnabled", "on")
               + (P("PortSchema", portschema) if portschema else "")
               + mask_xml
               + f'    <System Ref="system_{sid}"/>\n'
               + '  </Block>\n')
        self.children[sid] = child
        return self.add(xml, sid)

    def library_ref(self, name, source_block, counts, position, params, lib_version="1.0"):
        """Instance of a masked block of one of our own libraries. params = [(name, value)]."""
        sid = self.sids()
        pc = " ".join(f'{k}="{v}"' for k, v in counts.items() if v)
        idata = P_indent("ContentPreviewEnabled", "on", "      ")
        for k, v in params:
            idata += P_indent(k, v, "      ")
        xml = (f'  <Block BlockType="Reference" Name="{esc_attr(name)}" SID="{sid}">\n'
               f'    <PortCounts {pc}/>\n'
               + P("Position", position) + P("ZOrder", self.z())
               + P("LibraryVersion", lib_version)
               + P("SourceBlock", source_block)
               + '    <P Name="SourceType"/>\n'
               + '    <InstanceData>\n' + idata + '    </InstanceData>\n'
               + '  </Block>\n')
        return self.add(xml, sid)

    # --- Simscape utility blocks ---------------------------------------------------
    def sl2ps(self, name, position, unit="1"):
        """Simulink-PS Converter: in1 -> rconn1."""
        sid = self.sids()
        xml = (f'  <Block BlockType="Reference" Name="{esc_attr(name)}" SID="{sid}">\n'
               '    <PortCounts in="1" rconn="1"/>\n'
               + P("Position", position) + P("ZOrder", self.z())
               + P("BackgroundColor", "automatic") + P("LibraryVersion", NESL_VERSION)
               + P("SourceBlock", "nesl_utility/Simulink-PS\nConverter")
               + P("SourceType", "Simulink-PS\nConverter")
               + '    <InstanceData>\n'
               + P_indent("ContentPreviewEnabled", "on", "      ")
               + P_indent("PhysicalDomain", "network_engine_domain", "      ")
               + P_indent("SubClassName", "ps_input", "      ")
               + P_indent("LeftPortType", "input", "      ")
               + P_indent("RightPortType", "output", "      ")
               + P_indent("PseudoPeriodic", "off", "      ")
               + P_indent("Frequencies", "[]", "      ")
               + P_indent("NoiseDistribution", "none", "      ")
               + P_indent("NoiseParameters", "[]", "      ")
               + P_indent("Unit", unit, "      ")
               + P_indent("AffineConversion", "off", "      ")
               + P_indent("FilteringAndDerivatives", "provide", "      ")
               + P_indent("SimscapeFilterOrder", "1", "      ")
               + P_indent("InputFilterTimeConstant", "0.001", "      ")
               + P_indent("UdotUserProvided", "0", "      ")
               + '    </InstanceData>\n  </Block>\n')
        return self.add(xml, sid)

    def ps2sl(self, name, position, unit, signal_name=None):
        """PS-Simulink Converter: lconn1 -> out1."""
        sid = self.sids()
        pp = ""
        if signal_name:
            pp = ('    <PortProperties>\n      <Port Type="out" Index="1">\n'
                  f'        <P Name="Name">{esc(signal_name)}</P>\n      </Port>\n    </PortProperties>\n')
        xml = (f'  <Block BlockType="Reference" Name="{esc_attr(name)}" SID="{sid}">\n'
               '    <PortCounts out="1" lconn="1"/>\n'
               + P("Position", position) + P("ZOrder", self.z())
               + P("BackgroundColor", "automatic") + P("LibraryVersion", NESL_VERSION)
               + P("SourceBlock", "nesl_utility/PS-Simulink\nConverter")
               + P("SourceType", "PS-Simulink\nConverter")
               + '    <InstanceData>\n'
               + P_indent("ContentPreviewEnabled", "on", "      ")
               + P_indent("PhysicalDomain", "network_engine_domain", "      ")
               + P_indent("SubClassName", "ps_output", "      ")
               + P_indent("LeftPortType", "input", "      ")
               + P_indent("RightPortType", "output", "      ")
               + P_indent("PseudoPeriodic", "off", "      ")
               + P_indent("Frequencies", "[]", "      ")
               + P_indent("VectorFormat", "1-D array", "      ")
               + P_indent("Unit", unit, "      ")
               + P_indent("AffineConversion", "off", "      ")
               + '    </InstanceData>\n' + pp + '  </Block>\n')
        return self.add(xml, sid)

    def solver_configuration(self, name, position, local_solver=True, sample_time="tb.tc",
                             nonlin_iter="tb.nonlin_iter", mode_iter="2"):
        sid = self.sids()
        idata = [("ContentPreviewEnabled", "on"), ("PhysicalDomain", "network_engine_domain"),
                 ("SubClassName", "solver"), ("LeftPortType", "input"), ("RightPortType", "generic"),
                 ("Tones", "[]"), ("Harmonics", "[]"), ("SimulateNoise", "off"), ("Profile", "off"),
                 ("UseLocalSampling", "off"), ("EnableSwitchedLinearOptims", "on"),
                 ("FrequencyDomain", "off"), ("UseCCode", "off"), ("RelTol", "0.001"),
                 ("AbsTol", "0.001"), ("MinStep", "1e-09"), ("ToWorkspace", "off"),
                 ("RevertToSquareIcSolve", "off"), ("NumHomotopyIterations", "100"),
                 ("PhasorMode", "off"), ("PhasorModeNumHarmonics", "1"),
                 ("ConsistencySolver", "NEWTON_FTOL"), ("CanonicalOrdering", "UNORDERED"),
                 ("OptimizeIntermediates", "UNOPTIMIZED"),
                 ("IndexReductionMethod", "DerivativeReplacement"), ("DoDC", "off"),
                 ("ResidualTolerance", "1e-4"), ("ConsistencyTolSource", "GLOBAL"),
                 ("ConsistencyAbsTol", "0.001"), ("ConsistencyRelTol", "0.001"),
                 ("ConsistencyTolFactor", "0.001"),
                 ("UseLocalSolver", "on" if local_solver else "off"),
                 ("LocalSolverChoice", "NE_BACKWARD_EULER_ADVANCER"),
                 ("ResolveIndetEquations", "on"), ("FunctionEvalNumThread", "1"),
                 ("LocalSolverSampleTime", sample_time), ("DoFixedCost", "on"),
                 ("MaxNonlinIter", nonlin_iter), ("MaxModeIter", mode_iter), ("ComputeImpulses", "off"),
                 ("ImpulseIterations", "2"), ("LinearAlgebra", "auto"),
                 ("LinearAlgebraNumThread", "0"), ("EquationFormulation", "NE_TIME_EF"),
                 ("DelaysMemoryBudget", "1024"), ("AutomaticFiltering", "on"),
                 ("FilteringTimeConstant", "0.001"), ("PartitionStorageMethod", "AS_NEEDED"),
                 ("PartitionMemoryBudget", "1024"), ("PartitionMethod", "ROBUST"),
                 ("MultibodyUseLocalSolver", "off")]
        xml = (f'  <Block BlockType="Reference" Name="{esc_attr(name)}" SID="{sid}">\n'
               '    <PortCounts rconn="1"/>\n'
               + P("Position", position) + P("ZOrder", self.z())
               + P("LibraryVersion", NESL_VERSION)
               + P("SourceBlock", "nesl_utility/Solver\nConfiguration")
               + P("SourceType", "Solver\nConfiguration")
               + '    <InstanceData>\n'
               + "".join(P_indent(k, v, "      ") for k, v in idata)
               + '    </InstanceData>\n  </Block>\n')
        return self.add(xml, sid)

    # --- Simscape foundation / custom components -----------------------------------
    def ssc(self, name, source_block, component_path, class_name, params, ports, position,
            lib_version=FL_VERSION, rotation=None, mirror=False, name_location=None,
            variables=(), extra_idata=""):
        """A Simscape block from a library.
        params = [(pname, value, unit)] ; variables = [(vname, specify, priority, value, unit)]
        ports = [(type 'lconn'|'rconn', index, PortId)]"""
        sid = self.sids()
        source_type = source_block.split("/")[-1]
        idata = (P_indent("LogSimulationData", "off", "      ")
                 + P_indent("SimscapeInstrumentationLogging", "off", "      ")
                 + f'      <P Name="SimscapeInstrumentationVariables" Ref="bdmxdata:SimscapeInstrumentationVariables_{sid}"/>\n'
                 + P_indent("SourceFile", component_path, "      ")
                 + P_indent("SscBlockScalableBuild", "off", "      ")
                 + P_indent("ComponentPath", component_path, "      ")
                 + P_indent("ComponentVariants", f'["{component_path}"]', "      ")
                 + P_indent("ComponentVariantNames", f'["{class_name}"]', "      ")
                 + P_indent("ClassName", class_name, "      ")
                 + P_indent("SchemaVersion", "1", "      "))
        for pname, value, unit in params:
            idata += P_indent(pname, value, "      ")
            idata += P_indent(pname + "_unit", unit, "      ")
            idata += P_indent(pname + "_conf", "compiletime", "      ")
        for vname, specify, priority, value, unit in variables:
            nominal_unit = {"degC": "K", "deltadegC": "K"}.get(unit, unit)
            idata += P_indent(vname + "_specify", specify, "      ")
            idata += P_indent(vname + "_priority", priority, "      ")
            idata += P_indent(vname, value, "      ")
            idata += P_indent(vname + "_unit", unit, "      ")
            idata += P_indent(vname + "_nominal_specify", "off", "      ")
            idata += P_indent(vname + "_nominal_value", "1", "      ")
            idata += P_indent(vname + "_nominal_unit", nominal_unit, "      ")
        idata += extra_idata
        pp = "".join(
            f'      <Port Type="{t}" Index="{i}">\n        <P Name="PortId">{esc(pid)}</P>\n      </Port>\n'
            for t, i, pid in ports)
        nl = sum(1 for t, _, _ in ports if t == "lconn")
        nr = sum(1 for t, _, _ in ports if t == "rconn")
        pc = (f'lconn="{nl}"' if nl else "") + (" " if nl and nr else "") + (f'rconn="{nr}"' if nr else "")
        xml = (f'  <Block BlockType="Reference" Name="{esc_attr(name)}" SID="{sid}">\n'
               f'    <PortCounts {pc}/>\n'
               + P("Position", position) + P("ZOrder", self.z())
               + (P("BlockRotation", rotation) if rotation else "")
               + (P("BlockMirror", "on") if mirror else "")
               + (P("NameLocation", name_location) if name_location else "")
               + P("LibraryVersion", lib_version)
               + P("SourceBlock", source_block) + P("SourceType", source_type)
               + '    <InstanceData>\n' + idata + '    </InstanceData>\n'
               + ('    <PortProperties>\n' + pp + '    </PortProperties>\n' if pp else "")
               + '  </Block>\n')
        return self.add(xml, sid, simscape=True)

    # --- lines ---------------------------------------------------------------------
    def sig(self, src, dst, name=None, points=None, log=False):
        """Signal line src 'SID#out:1' -> dst 'SID#in:1' (dst may be a list for fan-out)."""
        xml = "  <Line>\n"
        if name:
            xml += P("Name", name) + P("Labels", "[0, 0]")
        xml += P("ZOrder", self.z())
        if log:
            xml += P("DataLogging", "on")
        xml += P("Src", src)
        if points:
            xml += P("Points", points)
        if isinstance(dst, (list, tuple)):
            for d in dst:
                xml += f'    <Branch>\n      <P Name="ZOrder">{self.z()}</P>\n      <P Name="Dst">{d}</P>\n    </Branch>\n'
        else:
            xml += P("Dst", dst)
        xml += "  </Line>\n"
        self.lines.append(xml)

    def conn(self, *ports, points=None):
        """Physical connection between two or more ports ('SID#lconn:1' / 'SID#rconn:2')."""
        ports = list(ports)
        xml = '  <Line LineType="Connection">\n' + P("ZOrder", self.z()) + P("Src", ports[0])
        if points:
            xml += P("Points", points)
        if len(ports) == 2:
            xml += P("Dst", ports[1])
        else:
            for p in ports[1:]:
                xml += (f'    <Branch ConnectType="DEST_DEST">\n      <P Name="ZOrder">{self.z()}</P>\n'
                        f'      <P Name="Src">{p}</P>\n    </Branch>\n')
        xml += "  </Line>\n"
        self.lines.append(xml)

    # --- serialisation --------------------------------------------------------------
    def xml(self, root=False, sid_high=None):
        out = '<?xml version="1.0" encoding="utf-8"?>\n<System>\n'
        out += P("Location", self.location)
        if root:
            out += P("ReportName", "simulink-default.rpt")
            out += P("SIDHighWatermark", sid_high)
        else:
            out += P("Open", "off")
        out += P("ZoomFactor", self.zoom)
        for _, b in self.blocks:
            out += b
        for l in self.lines:
            out += l
        out += "</System>\n"
        return out

    def all_systems(self):
        """Yield (sid or 'root', System) for this system and all descendants."""
        for sid, child in self.children.items():
            yield sid, child
            yield from child.all_systems()

    def all_ssc_sids(self):
        sids = list(self.ssc_sids)
        for _, child in self.children.items():
            sids += child.all_ssc_sids()
        return sids


# ----------------------------------------------------------------------------- mask
def mask_xml(mask_type, description, params, groups, icon=None, help_cmd=None):
    """params = [(name, prompt, default)] ; groups = [(group_prompt, [param names])]."""
    x = "    <Mask>\n"
    x += f'      <Display RunInitForIconRedraw="off">{esc(icon) if icon else ""}</Display>\n' if icon else '      <Display RunInitForIconRedraw="off"/>\n'
    x += f"      <Type>{esc(mask_type)}</Type>\n"
    x += f"      <Description>{esc(description)}</Description>\n"
    if help_cmd:
        x += f"      <Help>{esc(help_cmd)}</Help>\n"
    for name, prompt, default in params:
        x += (f'      <MaskParameter Name="{esc_attr(name)}" Type="edit" ShowTooltip="off">\n'
              f'        <Prompt>{esc(prompt)}</Prompt>\n'
              f'        <Value>{esc(default)}</Value>\n'
              f'      </MaskParameter>\n')
    x += ('      <DialogControl Type="Group" Name="DescGroupVar">\n'
          '        <Prompt>%&lt;MaskType&gt;</Prompt>\n'
          '        <DialogControl Type="Text" Name="DescTextVar">\n'
          '          <Prompt>%&lt;MaskDescription&gt;</Prompt>\n'
          '        </DialogControl>\n'
          '      </DialogControl>\n')
    prompts = {n: p for n, p, _ in params}
    for gi, (gprompt, names) in enumerate(groups):
        x += (f'      <DialogControl Type="Group" Name="ParameterGroupVar{gi if gi else ""}">\n'
              f'        <Prompt>{esc(gprompt)}</Prompt>\n')
        for n in names:
            x += (f'        <DialogControl Type="Edit" Name="{esc_attr(n)}">\n'
                  f'          <Prompt>{esc(prompts[n])}</Prompt>\n'
                  f'          <ControlOptions PromptLocation="left"/>\n'
                  f'        </DialogControl>\n')
        x += '      </DialogControl>\n'
    x += "    </Mask>\n"
    return x


# ----------------------------------------------------------------------------- binary parts
def _mx_header():
    return b"\x00\x01IM\x00\x00\x00\x00"


def instrumentation_variables_mxarray():
    """The empty simscape.instrumentation.VariableTable that Simulink stores for every
    Simscape block (byte copy of what R2026a writes, 1352 bytes)."""
    data = base64.b64decode(
        "AAFJTQAAAAAOAAAAoAAAAAYAAAAIAAAAEQAAAAAAAAABAAAAAAAAAAEABABNQ09TAQAAACYAAABz"
        "aW1zY2FwZS5pbnN0cnVtZW50YXRpb24uVmFyaWFibGVUYWJsZQAADgAAAEgAAAAGAAAACAAAAA0A"
        "AAAAAAAABQAAAAgAAAAGAAAAAQAAAAEAAAAAAAAABgAAABgAAAAAAADdAgAAAAEAAAABAAAAAQAA"
        "AAEAAAAOAAAAkAQAAAYAAAAIAAAACQAAAAAAAAAFAAAACAAAAAEAAABgBAAAAQAAAAAAAAACAAAA"
        "YAQAAAABSU0AAAAADgAAAMADAAAGAAAACAAAAAIAAAAAAAAABQAAAAgAAAABAAAAAQAAAAEAAAAA"
        "AAAABQAEAAUAAAABAAAABQAAAE1DT1MAAAAADgAAAHgDAAAGAAAACAAAABEAAAAAAAAAAQAAAAAA"
        "AAABAAQATUNPUwEAAAANAAAARmlsZVdyYXBwZXJfXwAAAA4AAAA4AwAABgAAAAgAAAABAAAAAAAA"
        "AAUAAAAIAAAABgAAAAEAAAABAAAAAAAAAA4AAAAQAQAABgAAAAgAAAAJAAAAAAAAAAUAAAAIAAAA"
        "4AAAAAEAAAABAAAAAAAAAAIAAADgAAAABAAAAAMAAABYAAAAeAAAAJAAAADAAAAAyAAAAMgAAADI"
        "AAAA0AAAAGFueQBWYXJpYWJsZVRhYmxlAHNpbXNjYXBlLmluc3RydW1lbnRhdGlvbgAAAAAAAAAA"
        "AAAAAAAAAAAAAAAAAAADAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAQAAAAEAAAAAAAAAAAAA"
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        "AAAAAAEAAADYAAAAAAAAAAAAAAAOAAAAAAAAAA4AAABIAAAABgAAAAgAAAAEAAAAAAAAAAUAAAAI"
        "AAAAAQAAABgAAAABAAAAAAAAABAAAAAYAAAAeyJ0YWJsZSI6W10sInZlciI6IjEuMCJ9DgAAAKgA"
        "AAAGAAAACAAAAAEAAAAAAAAABQAAAAgAAAACAAAAAQAAAAEAAAAAAAAADgAAADgAAAAGAAAACAAA"
        "AAIAAAAAAAAABQAAAAgAAAABAAAAAAAAAAEAAAAAAAAABQAEAAEAAAABAAAAAAAAAA4AAAA4AAAA"
        "BgAAAAgAAAACAAAAAAAAAAUAAAAIAAAAAQAAAAAAAAABAAAAAAAAAAUABAABAAAAAQAAAAAAAAAO"
        "AAAAOAAAAAYAAAAIAAAADAAAAAAAAAAFAAAACAAAAAIAAAABAAAAAQAAAAAAAAAFAAAACAAAAAAA"
        "AAAAAAAADgAAAKgAAAAGAAAACAAAAAEAAAAAAAAABQAAAAgAAAACAAAAAQAAAAEAAAAAAAAADgAA"
        "ADgAAAAGAAAACAAAAAIAAAAAAAAABQAAAAgAAAABAAAAAAAAAAEAAAAAAAAABQAEAAEAAAABAAAA"
        "AAAAAA4AAAA4AAAABgAAAAgAAAACAAAAAAAAAAUAAAAIAAAAAQAAAAAAAAABAAAAAAAAAAUABAAB"
        "AAAAAQAAAAAAAAAOAAAAiAAAAAYAAAAIAAAACQAAAAAAAAAFAAAACAAAAAEAAABYAAAAAQAAAAAA"
        "AAACAAAAWAAAAAABSU0AAAAADgAAAEgAAAAGAAAACAAAAAIAAAAAAAAABQAAAAgAAAABAAAAAQAA"
        "AAEAAAAAAAAABQAEAAUAAAABAAAABQAAAE1DT1MAAAAADgAAAAAAAAA="
    )
    assert len(data) == 1352
    return data


def library_base_mxarray(value="17F0F7"):
    """LibraryBase_bd: a 6-character MATLAB char array (value written by R2026a)."""
    v = value.encode()
    body = (struct.pack("<II", 6, 8) + struct.pack("<II", 4, 0)          # class: char (mxCHAR_CLASS=4)
            + struct.pack("<II", 5, 8) + struct.pack("<II", 1, len(v))   # dims 1 x n
            + struct.pack("<II", 1, 0)                                  # name: empty
            + struct.pack("<II", 16, len(v)) + v + b"\x00" * ((8 - len(v) % 8) % 8))
    return _mx_header() + struct.pack("<II", 14, len(body)) + body


def tiny_png():
    """A valid 1x1 transparent PNG (thumbnail placeholder)."""
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    raw = zlib.compress(b"\x00\x00\x00\x00\x00")
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", raw) + chunk(b"IEND", b""))


# ----------------------------------------------------------------------------- packaging
CONFIGSET_LIBRARY = """<?xml version="1.0" encoding="utf-8"?>
<ConfigSet>
  <Object ObjectID="1" ClassName="Simulink.ConfigSet">
    <P Name="ExtraOptions" Class="char"/>
    <P Name="Name" Class="char">Configuration</P>
    <P Name="CurrentDlgPage" Class="char">Solver</P>
    <P Name="ConfigPrmDlgPosition" Class="double">[0.0, 0.0, 0.0, 0.0]</P>
    <P Name="Version" Class="char">26.0.0</P>
    <Array PropName="Components" Type="Simulink.ConfigComponent" Dimension="9*1">
      <Object ObjectID="2" ClassName="Simulink.SolverCC">
{SOLVER}        <P Name="Version" Class="char">26.0.0</P>
      </Object>
      <Object ObjectID="3" ClassName="Simulink.DataIOCC">
{DATAIO}        <P Name="Version" Class="char">26.0.0</P>
      </Object>
      <Object ObjectID="4" ClassName="Simulink.OptimizationCC">
        <P Name="Version" Class="char">26.0.0</P>
      </Object>
      <Object ObjectID="5" ClassName="Simulink.DebuggingCC">
        <P Name="Version" Class="char">26.0.0</P>
      </Object>
      <Object ObjectID="6" ClassName="Simulink.HardwareCC">
        <P Name="Version" Class="char">26.0.0</P>
      </Object>
      <Object ObjectID="7" ClassName="Simulink.ModelReferenceCC">
        <P Name="UpdateModelReferenceTargets" Class="char">IfOutOfDateOrStructuralChange</P>
        <P Name="Version" Class="char">26.0.0</P>
      </Object>
      <Object ObjectID="8" ClassName="Simulink.SFSimCC">
        <P Name="CustomCodeFunctionArrayLayout" Class="double">[]</P>
        <P Name="Version" Class="char">26.0.0</P>
      </Object>
      <Object ObjectID="9" ClassName="Simulink.RTWCC">
        <P Name="SystemTargetFile" Class="char">grt.tlc</P>
        <P Name="HardwareBoard" Class="char">None</P>
        <P Name="Toolchain" Class="char">Automatically locate an installed toolchain</P>
        <P Name="BuildConfiguration" Class="char">Faster Builds</P>
        <P Name="Description" Class="char">Generic Real-Time Target</P>
        <P Name="Version" Class="char">26.0.0</P>
        <Array PropName="Components" Type="Simulink.ConfigComponent" Dimension="2*1">
          <Object ObjectID="10" ClassName="Simulink.CodeAppCC">
            <P Name="Version" Class="char">26.0.0</P>
          </Object>
          <Object ObjectID="11" ClassName="Simulink.GRTTargetCC">
            <P Name="Version" Class="char">26.0.0</P>
          </Object>
        </Array>
      </Object>
      <Object ObjectID="12" ClassName="SlCovCC.ConfigComp">
        <P Name="CovEnable" Class="char">off</P>
        <P Name="Version" Class="char">26.0.0</P>
      </Object>
    </Array>
  </Object>
</ConfigSet>
"""

SOLVER_LIBRARY = """        <P Name="SolverName" Class="char">VariableStepAuto</P>
        <P Name="ODENIntegrationMethod" Class="char">ode3</P>
"""


def solver_model(stop_time, max_step, rel_tol="1e-3"):
    return (f'        <P Name="StartTime" Class="char">0.0</P>\n'
            f'        <P Name="StopTime" Class="char">{esc(stop_time)}</P>\n'
            f'        <P Name="MaxStep" Class="char">{esc(max_step)}</P>\n'
            f'        <P Name="RelTol" Class="char">{esc(rel_tol)}</P>\n'
            f'        <P Name="SolverType" Class="char">Variable-step</P>\n'
            f'        <P Name="SolverName" Class="char">ode23tb</P>\n'
            f'        <P Name="ZeroCrossControl" Class="char">EnableAll</P>\n'
            f'        <P Name="ZeroCrossAlgorithm" Class="char">Adaptive</P>\n'
            f'        <P Name="AlgebraicLoopSolver" Class="char">TrustRegion</P>\n')


DATAIO_MODEL = """        <P Name="SaveTime" Class="char">on</P>
        <P Name="TimeSaveName" Class="char">tout</P>
        <P Name="SaveOutput" Class="char">off</P>
        <P Name="SaveFormat" Class="char">Dataset</P>
        <P Name="SignalLogging" Class="char">on</P>
        <P Name="SignalLoggingName" Class="char">logsout</P>
        <P Name="ReturnWorkspaceOutputs" Class="char">on</P>
        <P Name="ReturnWorkspaceOutputsName" Class="char">out</P>
        <P Name="LimitDataPoints" Class="char">off</P>
"""

BDDEFAULTS = """<?xml version="1.0" encoding="utf-8"?>
<BlockDiagramDefaults>
  <AnnotationDefaults>
    <P Name="HorizontalAlignment">center</P>
    <P Name="VerticalAlignment">middle</P>
  </AnnotationDefaults>
  <MaskDefaults SelfModifiable="off">
    <Display IconFrame="on" IconOpaque="opaque" RunInitForIconRedraw="analyze" IconRotate="none" PortRotate="default" IconUnits="autoscale"/>
    <MaskParameter Evaluate="on" Tunable="on" NeverSave="off" Internal="off" ReadOnly="off" Enabled="on" Visible="on" ToolTip="on"/>
    <DialogControl>
      <ControlOptions Visible="on" Enabled="on" Row="new" HorizontalStretch="on" PromptLocation="top" Orientation="horizontal" Scale="linear" TextType="Plain Text" Expand="off" ShowFilter="on" ShowParameterName="on" WordWrap="on" AlignPrompts="off"/>
    </DialogControl>
  </MaskDefaults>
</BlockDiagramDefaults>
"""


def _windows_info(location="[100.0, 100.0, 1400.0, 800.0]"):
    return (f'<?xml version="1.0" encoding="utf-8"?>\n<WindowsInfo>\n'
            f'  <Object PropName="BdWindowsInfo" ObjectID="1" ClassName="Simulink.BDWindowsInfo">\n'
            f'    <Object PropName="WindowsInfo" ObjectID="2" ClassName="Simulink.WindowInfo">\n'
            f'      <P Name="IsActive" Class="logical">1</P>\n'
            f'      <P Name="Location" Class="double">{location}</P>\n'
            f'      <Array PropName="EditorsInfo" Type="Simulink.EditorInfo" Dimension="1*1">\n'
            f'        <Object ObjectID="3">\n'
            f'          <P Name="IsActive" Class="logical">1</P>\n'
            f'          <P Name="IsTabbed" Class="logical">1</P>\n'
            f'          <P Name="ViewObjType" Class="char">SimulinkTopLevel</P>\n'
            f'          <P Name="LoadSaveID" Class="char">0</P>\n'
            f'          <P Name="Extents" Class="double">[1300.0, 700.0]</P>\n'
            f'          <P Name="ZoomFactor" Class="double">1.0</P>\n'
            f'          <P Name="Offset" Class="double">[0.0, 0.0]</P>\n'
            f'          <P Name="SceneRectInView" Class="double">[0.0, 0.0, 1300.0, 700.0]</P>\n'
            f'        </Object>\n'
            f'      </Array>\n'
            f'      <P Name="WindowUuid" Class="char">{new_uuid()}</P>\n'
            f'    </Object>\n'
            f'    <P Name="BDUuid" Class="char">{new_uuid()}</P>\n'
            f'  </Object>\n</WindowsInfo>\n')


def write_slx(path, root_system, is_library, model_name, creator="pwr-control",
              solver_xml=None, dataio_xml="", description=None):
    """Assemble and write the .slx file."""
    sids = root_system.sids
    systems = {"root": root_system.xml(root=True, sid_high=sids.high)}
    for sid, sysobj in root_system.all_systems():
        systems[str(sid)] = sysobj.xml()
    ssc_sids = root_system.all_ssc_sids()
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    # --- blockdiagram.xml
    if is_library:
        bd = ('<?xml version="1.0" encoding="utf-8"?>\n<ModelInformation Version="1.0">\n  <Library>\n'
              f'    <P Name="ModelUUID">{new_uuid()}</P>\n'
              '    <P Name="LibraryType">BlockLibrary</P>\n'
              '    <P Name="LibraryBase" Ref="bdmxdata:LibraryBase_bd"/>\n'
              '    <P Name="SLXCompressionType">None</P>\n'
              '    <P Name="LastSavedArchitecture">win64</P>\n'
              '    <ConfigManagerSettings>\n'
              '      <P Name="ModifiedByFormat">%&lt;Auto&gt;</P>\n'
              '      <P Name="ModifiedDateFormat">%&lt;Auto&gt;</P>\n'
              '      <P Name="ModelVersionFormat">%&lt;AutoIncrement:1.0&gt;</P>\n'
              '    </ConfigManagerSettings>\n'
              '    <SimulationSettings>\n      <P Name="SimulationMode">normal</P>\n    </SimulationSettings>\n'
              '    <EngineSettings>\n      <P Name="ConfigurableSubsystemUsage">warning</P>\n    </EngineSettings>\n'
              '    <System Ref="system_root"/>\n  </Library>\n</ModelInformation>\n')
        configset = CONFIGSET_LIBRARY.replace("{SOLVER}", SOLVER_LIBRARY).replace("{DATAIO}", "")
    else:
        bd = ('<?xml version="1.0" encoding="utf-8"?>\n<ModelInformation Version="1.0">\n  <Model>\n'
              f'    <P Name="ModelUUID">{new_uuid()}</P>\n'
              '    <P Name="SLXCompressionType">None</P>\n'
              '    <P Name="LastSavedArchitecture">win64</P>\n'
              + (f'    <P Name="Description">{esc(description)}</P>\n' if description else "")
              + '    <ConfigManagerSettings>\n'
              '      <P Name="ModifiedByFormat">%&lt;Auto&gt;</P>\n'
              '      <P Name="ModifiedDateFormat">%&lt;Auto&gt;</P>\n'
              '      <P Name="ModelVersionFormat">%&lt;AutoIncrement:1.0&gt;</P>\n'
              '    </ConfigManagerSettings>\n'
              '    <EditorSettings>\n      <P Name="LibraryLinkDisplay">none</P>\n'
              '      <P Name="WideLines">on</P>\n      <P Name="ShowLineDimensions">on</P>\n'
              '    </EditorSettings>\n'
              '    <SimulationSettings>\n      <P Name="SimulationMode">normal</P>\n'
              '      <P Name="SimTabSimulationMode">normal</P>\n    </SimulationSettings>\n'
              '    <EngineSettings>\n      <P Name="ConfigurableSubsystemUsage">warning</P>\n    </EngineSettings>\n'
              '    <System Ref="system_root"/>\n  </Model>\n</ModelInformation>\n')
        configset = CONFIGSET_LIBRARY.replace("{SOLVER}", solver_xml).replace("{DATAIO}", dataio_xml)

    # --- relationships and content types
    bd_rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n'
               '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n')
    if is_library:
        bd_rels += ('  <Relationship Id="LibraryBase_bd" Target="bdmxdata/LibraryBase_bd.mxarray" '
                    'Type="http://schemas.mathworks.com/simulinkModel/2015/relationships/modelMxArray"/>\n')
    for sid in sorted(ssc_sids):
        bd_rels += (f'  <Relationship Id="SimscapeInstrumentationVariables_{sid}" '
                    f'Target="bdmxdata/SimscapeInstrumentationVariables_{sid}.mxarray" '
                    'Type="http://schemas.mathworks.com/simulinkModel/2015/relationships/modelMxArray"/>\n')
    bd_rels += ('  <Relationship Id="system_root" Target="systems/system_root.xml" '
                'Type="http://schemas.mathworks.com/simulink/2010/relationships/system"/>\n'
                '  <Relationship Id="windowsInfo" Target="windowsInfo.xml" '
                'Type="http://schemas.mathworks.com/simulinkModel/2019/relationships/windowsInfo"/>\n'
                '</Relationships>\n')

    def sys_rels(sysobj):
        if not sysobj.children:
            return None
        r = ('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n'
             '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n')
        for sid in sysobj.children:
            r += (f'  <Relationship Id="system_{sid}" Target="system_{sid}.xml" '
                  'Type="http://schemas.mathworks.com/simulink/2010/relationships/system"/>\n')
        return r + '</Relationships>\n'

    ctypes = ('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n'
              '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
              '  <Default ContentType="application/vnd.mathworks.matlab.mxarray+binary" Extension="mxarray"/>\n'
              '  <Default ContentType="image/png" Extension="png"/>\n'
              '  <Default ContentType="application/vnd.openxmlformats-package.relationships+xml" Extension="rels"/>\n'
              '  <Default ContentType="application/vnd.mathworks.simulink.configSetInfo+xml" Extension="xml"/>\n'
              '  <Override ContentType="application/vnd.openxmlformats-package.core-properties+xml" PartName="/metadata/coreProperties.xml"/>\n'
              '  <Override ContentType="application/vnd.mathworks.package.coreProperties+xml" PartName="/metadata/mwcoreProperties.xml"/>\n'
              '  <Override ContentType="application/vnd.mathworks.package.corePropertiesExtension+xml" PartName="/metadata/mwcorePropertiesExtension.xml"/>\n'
              '  <Override ContentType="application/vnd.mathworks.package.corePropertiesReleaseInfo+xml" PartName="/metadata/mwcorePropertiesReleaseInfo.xml"/>\n'
              '  <Override ContentType="application/vnd.mathworks.simulink.mdl+xml" PartName="/simulink/bddefaults.xml"/>\n'
              '  <Override ContentType="application/vnd.mathworks.simulink.mdl+xml" PartName="/simulink/blockdiagram.xml"/>\n'
              '  <Override ContentType="application/vnd.mathworks.simulink.configSet+xml" PartName="/simulink/configSet0.xml"/>\n'
              '  <Override ContentType="application/vnd.mathworks.simulink.mf0+xml" PartName="/simulink/modelDictionary.xml"/>\n')
    for key in sorted(systems, key=lambda k: (k != "root", int(k) if k != "root" else 0)):
        ctypes += f'  <Override ContentType="application/vnd.mathworks.simulink.mdl+xml" PartName="/simulink/systems/system_{key}.xml"/>\n'
    ctypes += ('  <Override ContentType="application/vnd.mathworks.simulink.blockDiagram+xml" PartName="/simulink/windowsInfo.xml"/>\n'
               '</Types>\n')

    root_rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n'
                 '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
                 '  <Relationship Id="Thumbnail" Target="metadata/thumbnail.png" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/thumbnail"/>\n'
                 '  <Relationship Id="blockDiagram" Target="simulink/blockdiagram.xml" Type="http://schemas.mathworks.com/simulink/2010/relationships/blockDiagram"/>\n'
                 '  <Relationship Id="blockDiagramDefaults" Target="simulink/bddefaults.xml" Type="http://schemas.mathworks.com/simulink/2017/relationships/blockDiagramDefaults"/>\n'
                 '  <Relationship Id="configSetInfo" Target="simulink/configSetInfo.xml" Type="http://schemas.mathworks.com/simulink/2014/relationships/configSetInfo"/>\n'
                 '  <Relationship Id="modelDictionary" Target="simulink/modelDictionary.xml" Type="http://schemas.mathworks.com/simulinkModel/2016/relationships/modelDictionary"/>\n'
                 '  <Relationship Id="rId1" Target="metadata/mwcoreProperties.xml" Type="http://schemas.mathworks.com/package/2012/relationships/coreProperties"/>\n'
                 '  <Relationship Id="rId2" Target="metadata/mwcorePropertiesExtension.xml" Type="http://schemas.mathworks.com/package/2014/relationships/corePropertiesExtension"/>\n'
                 '  <Relationship Id="rId3" Target="metadata/mwcorePropertiesReleaseInfo.xml" Type="http://schemas.mathworks.com/package/2019/relationships/corePropertiesReleaseInfo"/>\n'
                 '  <Relationship Id="rId4" Target="metadata/coreProperties.xml" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"/>\n'
                 '</Relationships>\n')

    core = ('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n'
            '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
            'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
            'xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n'
            f'  <cp:category>{"library" if is_library else "model"}</cp:category>\n'
            f'  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>\n'
            f'  <dc:creator>{esc(creator)}</dc:creator>\n'
            f'  <cp:lastModifiedBy>{esc(creator)}</cp:lastModifiedBy>\n'
            f'  <dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>\n'
            '  <cp:revision>1.0</cp:revision>\n'
            f'  <cp:version>{RELEASE}</cp:version>\n'
            '</cp:coreProperties>\n')
    mwcore = ('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n'
              '<mwcoreProperties xmlns="http://schemas.mathworks.com/package/2012/coreProperties">\n'
              '  <contentType>application/vnd.mathworks.simulink.model</contentType>\n'
              '  <contentTypeFriendlyName>Simulink Model</contentTypeFriendlyName>\n'
              f'  <matlabRelease>{RELEASE}</matlabRelease>\n'
              '</mwcoreProperties>\n')
    mwext = ('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n'
             '<mwcoreProperties xmlns="http://schemas.mathworks.com/package/2014/corePropertiesExtension">\n'
             f'  <uuid>{new_uuid()}</uuid>\n</mwcoreProperties>\n')
    mwrel = ('<?xml version="1.0" encoding="UTF-8"?>\n'
             f'<!-- Version information for MathWorks {RELEASE} Release -->\n'
             '<MathWorks_version_info>\n'
             f'  <version>{RELEASE_VERSION}</version>\n  <release>{RELEASE}</release>\n'
             '  <description>Update 5</description>\n  <date>Aug 03 2026</date>\n'
             '  <checksum>3557022610</checksum>\n</MathWorks_version_info>\n')
    model_dict = ('<?xml version="1.0" encoding="UTF-8"?>\n'
                  '<MF0 version="1.1" defaultPackage="slid" packageUris="http://schema.mathworks.com/mf0/slid/R2025a_20251111">\n'
                  f'  <System type="System" uuid="{new_uuid()}">\n'
                  f'    <Interface type="Interface" uuid="{new_uuid()}"/>\n'
                  '  </System>\n</MF0>\n')
    configset_info = ('<?xml version="1.0" encoding="utf-8"?>\n<ConfigSetInfo>\n'
                      '  <ConfigSet PartName="/simulink/configSet0.xml" Active="true">Configuration</ConfigSet>\n'
                      '</ConfigSetInfo>\n')
    configset_rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n'
                      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
                      '  <Relationship Id="configSet0" Target="configSet0.xml" Type="http://schemas.mathworks.com/simulink/2014/relationships/configSet"/>\n'
                      '</Relationships>\n')

    # --- zip
    stored, deflated = [], []
    stored.append(("metadata/thumbnail.png", tiny_png()))
    for key in sorted(systems, key=lambda k: (k != "root", int(k) if k != "root" else 0)):
        stored.append((f"simulink/systems/system_{key}.xml", systems[key].encode("utf-8")))
    if is_library:
        stored.append(("simulink/bdmxdata/LibraryBase_bd.mxarray", library_base_mxarray()))
    ivm = instrumentation_variables_mxarray()
    for sid in sorted(ssc_sids):
        stored.append((f"simulink/bdmxdata/SimscapeInstrumentationVariables_{sid}.mxarray", ivm))
    deflated.append(("[Content_Types].xml", ctypes.encode()))
    deflated.append(("_rels/.rels", root_rels.encode()))
    deflated.append(("simulink/_rels/blockdiagram.xml.rels", bd_rels.encode()))
    deflated.append(("simulink/_rels/configSetInfo.xml.rels", configset_rels.encode()))
    rr = sys_rels(root_system)
    if rr:
        deflated.append(("simulink/systems/_rels/system_root.xml.rels", rr.encode()))
    for sid, sysobj in root_system.all_systems():
        r = sys_rels(sysobj)
        if r:
            deflated.append((f"simulink/systems/_rels/system_{sid}.xml.rels", r.encode()))
    deflated.append(("metadata/coreProperties.xml", core.encode()))
    deflated.append(("metadata/mwcoreProperties.xml", mwcore.encode()))
    deflated.append(("metadata/mwcorePropertiesExtension.xml", mwext.encode()))
    deflated.append(("metadata/mwcorePropertiesReleaseInfo.xml", mwrel.encode()))
    stored.append(("simulink/bddefaults.xml", BDDEFAULTS.encode()))
    stored.append(("simulink/blockdiagram.xml", bd.encode()))
    stored.append(("simulink/configSet0.xml", configset.encode()))
    stored.append(("simulink/configSetInfo.xml", configset_info.encode()))
    stored.append(("simulink/modelDictionary.xml", model_dict.encode()))
    stored.append(("simulink/windowsInfo.xml", _windows_info().encode()))

    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with zipfile.ZipFile(path, "w") as z:
        for name, data in stored + deflated:
            zi = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            zi.compress_type = zipfile.ZIP_DEFLATED if (name, data) in deflated else zipfile.ZIP_STORED
            zi.external_attr = 0
            z.writestr(zi, data)
    return path
