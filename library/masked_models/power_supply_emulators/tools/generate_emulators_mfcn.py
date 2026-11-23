#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
generate_emulators_mfcn.py - writes the MATLAB Function copies of the two grid emulators

    ../three_phase_voltage_emulator_mfcn.slx
    ../three_phase_voltage_with_frt_emulator_mfcn.slx

next to the original libraries, which are not touched.

Each copy keeps the block name, the mask parameters (names, prompts, default values, dialog
order) and the output bus grid_emulator_outputs (same element names, same order) of the
original block. Inside the mask there is only:

    three_phase_voltage_emulator_mfcn:            Clock -> MATLAB Function -> Bus Creator
    three_phase_voltage_with_frt_emulator_mfcn:   Clock -> MATLAB Function -> Bus Creator,
                                                  plus one Integrator that holds the states
                                                  of the eight LVRT filters (dx -> x)

The code of the two MATLAB Function blocks is read from mfcn_src/grid_emulator.m and
mfcn_src/grid_emulator_frt.m; the mask parameters reach the code as data of scope Parameter.

No MATLAB is needed: the .slx container (a zip of XML parts) is written directly, in the
R2026a format of the original three_phase_voltage_with_frt_emulator.slx. Simulink re-saves
the files in its own format the first time they are saved.

Usage: python3 generate_emulators_mfcn.py
"""
import datetime
import os
import re
import struct
import uuid
import zipfile
import zlib
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
LIBDIR = os.path.dirname(HERE)
SRCDIR = os.path.join(HERE, "mfcn_src")

RELEASE = "R2026a"
RELEASE_VERSION = "26.1.0.3346908"
SF_VERSION = "82600000"
GITHUB = "https://github.com/pwr-control/library/blob/dev/library/masked_models/power_supply_emulators"
HELP = f"web('{GITHUB}/README.md', '-browser')"

# ----------------------------------------------------------------------------- the two blocks
# Mask parameters (name, prompt, default value): copies of the original masks, same order.
BASE_PARAMS = [
    ("freq", "Nominal Frequency [Hz]", "50"),
    ("ugrid_nom", "Nominal Voltage [V]", "690"),
    ("vp_xi_pu", "vp_xi_pu [pu]", "1"),
    ("vp_eta_pu", "vp_eta_pu [pu]", "0"),
    ("vn_xi_pu", "vn_xi_pu [pu]", "0"),
    ("vn_eta_pu", "vn_eta_pu [pu]", "0"),
    ("fcut_lvrt", "LVRT_flt_ss [Hz]", "50"),
]

FRT_PARAMS = [
    ("nominal_frequency_m", "Nominal Frequency [Hz]", "grid_emu.fgrid_nom"),
    ("nominal_voltage_m", "Nominal Voltage [V]", "grid_emu.us_secondary_nom"),
    ("Vemu_ref_norm_m", "Vemu_ref_norm", "grid_emu.Vemu_ref_norm"),
    ("vp_xi_pu_m", "Vp_xi_pu [pu]", "grid_emu.up_xi_pu_ref"),
    ("vp_eta_pu_m", "Vp_eta_pu [pu]", "grid_emu.up_eta_pu_ref"),
    ("vn_xi_pu_m", "Vn_xi_pu [pu]", "grid_emu.un_xi_pu_ref"),
    ("vn_eta_pu_m", "Vn_eta_pu [pu]", "grid_emu.un_eta_pu"),
    ("Am", "LVRT_flt_ss.A", "filters.afe.SOF_50Hz.ss_c.A"),
    ("Bm", "LVRT_flt_ss.B", "filters.afe.SOF_50Hz.ss_c.B"),
    ("Cm", "LVRT_flt_ss.C", "filters.afe.SOF_50Hz.ss_c.C"),
    ("enable_frt_1_m", "enable_frt_1", "frt_data.enable_frt_1"),
    ("enable_frt_2_m", "enable_frt_2", "frt_data.enable_frt_2"),
    ("start_time_LVRT_m", "Start_time_LVRT", "frt_data.start_time_LVRT"),
    ("end_time_LVRT_m", "End_time_LVRT", "frt_data.end_time_LVRT"),
    ("deepPOSxi_m", "deepPOSxi", "frt_data.deepPOSxi"),
    ("deepPOSeta_m", "deepPOSeta", "frt_data.deepPOSeta"),
    ("deepNEGxi_m", "deepNEGxi", "frt_data.deepNEGxi"),
    ("deepNEGeta_m", "deepNEGeta", "frt_data.deepNEGeta"),
    ("Amplitude_U_m", "Amplitude_U", "frt_data.Amplitude_U"),
    ("Amplitude_V_m", "Amplitude_V", "frt_data.Amplitude_V"),
    ("Amplitude_W_m", "Amplitude_W", "frt_data.Amplitude_W"),
    ("t_ramp_m", "t_ramp", "frt_data.t_ramp"),
    ("Phase_shift_m", "Phase_shift", "frt_data.Phase_shift"),
]

BASE_BUS = ["ua_grid_emu", "ub_grid_emu", "uc_grid_emu", "gamma_grid_emulator",
            "omega_grid_emulator"]
FRT_BUS = BASE_BUS + ["vp_xi", "vp_eta", "vn_xi", "vn_eta"]

FRT_INIT = """\
% MATLAB Function copy of three_phase_voltage_with_frt_emulator: checks of the parameters
if enable_frt_1_m == 1 && enable_frt_2_m == 1
    error(['enable_frt_1 and enable_frt_2 cannot be both 1: the original block has ', ...
           'two active variants in that case.']);
end
nflt = size(Am, 1);
if size(Am, 2) ~= nflt || ~isequal(size(Bm), [nflt 1]) || ~isequal(size(Cm), [1 nflt])
    error('LVRT_flt_ss: A must be n x n, B n x 1 and C 1 x n (single-input single-output filter).');
end
"""

BLOCKS = [
    dict(
        lib="three_phase_voltage_emulator_mfcn",
        block="three_phase_voltage_source_emulator",
        position="[305, 322, 475, 438]",
        mfcn="grid_emulator",
        src="grid_emulator.m",
        inputs=["t"],
        outputs=BASE_BUS,
        params=BASE_PARAMS,
        bus=BASE_BUS,
        integrator=None,
        mask_type="Three-phase voltage emulator (MATLAB Function)",
        description=(
            "Copy of three_phase_voltage_emulator/three_phase_voltage_source_emulator written "
            "as one MATLAB Function block: same parameters, same output bus "
            "grid_emulator_outputs (ua_grid_emu, ub_grid_emu, uc_grid_emu, "
            "gamma_grid_emulator, omega_grid_emulator).\n\n"
            "The grid angle and the first-order LVRT filters are written in closed form as "
            "functions of the simulation time, so the block has no states and 3 non-virtual "
            "blocks (the original has 44). The simulation must start at t = 0."),
        icon=("disp(sprintf('three-phase voltage\\nemulator\\nMATLAB Function'))\n"
              "port_label('output', 1, 'grid_emulator_outputs')"),
        init=None,
    ),
    dict(
        lib="three_phase_voltage_with_frt_emulator_mfcn",
        block="three_phase_voltage_source_with_frt_emulator",
        position="[160, 272, 330, 388]",
        mfcn="grid_emulator_frt",
        src="grid_emulator_frt.m",
        inputs=["t", "x"],
        outputs=FRT_BUS + ["dx"],
        params=FRT_PARAMS,
        bus=FRT_BUS,
        integrator="zeros(8*size(Am, 1), 1)",
        mask_type="Three-phase voltage emulator with FRT (MATLAB Function)",
        description=(
            "Copy of three_phase_voltage_with_frt_emulator/"
            "three_phase_voltage_source_with_frt_emulator written as one MATLAB Function "
            "block: same parameters, same output bus grid_emulator_outputs (ua_grid_emu, "
            "ub_grid_emu, uc_grid_emu, gamma_grid_emulator, omega_grid_emulator, vp_xi, "
            "vp_eta, vn_xi, vn_eta).\n\n"
            "Steps, rate limiters and variants are written as functions of the simulation "
            "time; the eight LVRT filters (A, B, C) keep their continuous states in the "
            "Integrator next to the function. 4 non-virtual blocks (the original has 123). "
            "The simulation must start at t = 0; enable_frt_1 and enable_frt_2 cannot be "
            "both 1."),
        icon=("disp(sprintf('three-phase voltage\\nemulator with FRT\\nMATLAB Function'))\n"
              "port_label('output', 1, 'grid_emulator_outputs')"),
        init=FRT_INIT,
    ),
]


# ----------------------------------------------------------------------------- helpers
def esc(text):
    return escape(str(text), {'"': "&quot;", "'": "&apos;"})


def esc_attr(text):
    return escape(str(text), {'"': "&quot;", "'": "&apos;", "\n": "&#xA;"})


def P(name, value, indent="    "):
    return f'{indent}<P Name="{name}">{esc(value)}</P>\n'


def new_uuid():
    return str(uuid.uuid4())


def port_y(top, height, k, n):
    """y of port k (1-based) of n ports on a block edge (Simulink spreads them evenly)."""
    return top + height * (2 * k - 1) / (2 * n)


def line(zorder, src, dst, name=None, points=None, indent="  "):
    x = f"{indent}<Line>\n"
    if name:
        x += P("Name", name, indent + "  ")
    x += P("ZOrder", zorder, indent + "  ")
    if name:
        x += P("Labels", "[0, 0]", indent + "  ")
    x += P("Src", src, indent + "  ")
    if points:
        x += P("Points", points, indent + "  ")
    x += P("Dst", dst, indent + "  ")
    return x + f"{indent}</Line>\n"


def read_function(path, name, inputs, outputs, params):
    """Read the MATLAB Function code and check it against the block interface: the
    signature lists the port inputs, then the mask parameters (scope Parameter), as
    Simulink requires for the parameters of a MATLAB Function block."""
    with open(path, encoding="utf-8") as fh:
        code = fh.read()
    sig = re.search(r"^function\s*\[(.*?)\]\s*=\s*(\w+)\s*\((.*?)\)", code, re.S | re.M)
    outs = [o.strip() for o in sig.group(1).replace("...", " ").replace(",", " ").split()]
    ins = [i.strip() for i in sig.group(3).replace("...", " ").split(",")]
    assert sig.group(2) == name, f"{path}: function name {sig.group(2)} != {name}"
    assert outs == outputs, f"{path}: outputs {outs} != {outputs}"
    assert ins == inputs + params, f"{path}: inputs {ins} != {inputs + params}"
    for p in params:
        assert re.search(r"\b%s\b" % re.escape(p), code), f"{path}: parameter {p} not used"
    return code.replace("\r\n", "\n")


# ----------------------------------------------------------------------------- mask
def mask_xml(spec):
    x = "    <Mask>\n"
    x += f"      <Type>{esc(spec['mask_type'])}</Type>\n"
    x += f'      <Display RunInitForIconRedraw="off">{esc(spec["icon"])}</Display>\n'
    x += f"      <Description>{esc(spec['description'])}</Description>\n"
    if spec["init"]:
        x += f"      <Initialization>{esc(spec['init'])}</Initialization>\n"
    x += f"      <Help>{esc(HELP)}</Help>\n"
    for name, prompt, value in spec["params"]:
        x += (f'      <MaskParameter Name="{esc_attr(name)}" Type="edit" ShowTooltip="off">\n'
              f"        <Prompt>{esc(prompt)}</Prompt>\n"
              f"        <Value>{esc(value)}</Value>\n"
              "      </MaskParameter>\n")
    # same dialog as the original: the edit fields sit in the description group
    x += ('      <DialogControl Type="Group" Name="DescGroupVar">\n'
          "        <Prompt>%&lt;MaskType&gt;</Prompt>\n"
          '        <DialogControl Type="Text" Name="DescTextVar">\n'
          "          <Prompt>%&lt;MaskDescription&gt;</Prompt>\n"
          "        </DialogControl>\n")
    for name, prompt, _ in spec["params"]:
        x += (f'        <DialogControl Type="Edit" Name="{esc_attr(name)}">\n'
              f"          <Prompt>{esc(prompt)}</Prompt>\n"
              '          <ControlOptions PromptLocation="left"/>\n'
              "        </DialogControl>\n")
    x += "      </DialogControl>\n    </Mask>\n"
    return x


# ----------------------------------------------------------------------------- Stateflow chart
def _data_xml(ssid, name, scope):
    if scope == "OUTPUT_DATA":
        type_extra, frame = "", "SF_FRAME_NO"
    else:
        type_extra = ('          <P Name="isSigned">1</P>\n'
                      '          <P Name="wordLength">16</P>\n')
        frame = "SF_FRAME_INHERITED"
    return (f'    <data SSID="{ssid}" name="{esc_attr(name)}">\n'
            f'      <P Name="scope">{scope}</P>\n'
            "      <props>\n"
            "        <array>\n"
            '          <P Name="size">-1</P>\n'
            "        </array>\n"
            "        <type>\n"
            '          <P Name="method">SF_INHERITED_TYPE</P>\n'
            '          <P Name="primitive">SF_DOUBLE_TYPE</P>\n'
            + type_extra +
            "        </type>\n"
            '        <P Name="complexity">SF_COMPLEX_INHERITED</P>\n'
            f'        <P Name="frame">{frame}</P>\n'
            "        <unit>\n"
            '          <P Name="name">inherit</P>\n'
            "        </unit>\n"
            "      </props>\n"
            '      <P Name="dataType">Inherit: Same as Simulink</P>\n'
            "    </data>\n")


def chart_xml(chart_id, chart_name, file_number, fname, script, inputs, outputs, params):
    data = ([(n, "INPUT_DATA") for n in inputs] + [(n, "OUTPUT_DATA") for n in outputs]
            + [(n, "PARAMETER_DATA") for n in params])
    ssid_high = 3 + len(data)
    x = ('<?xml version="1.0" encoding="utf-8"?>\n'
         f'<chart id="{chart_id}">\n'
         f'  <P Name="name">{esc(chart_name)}</P>\n'
         '  <P Name="screen">[1 1 3600 1200 1.180555555555556]</P>\n'
         f'  <P Name="viewObj">{chart_id}</P>\n'
         f'  <P Name="ssIdHighWaterMark">{ssid_high}</P>\n'
         '  <P Name="decomposition">CLUSTER_CHART</P>\n'
         '  <P Name="type">EML_CHART</P>\n'
         f'  <P Name="chartFileNumber">{file_number}</P>\n'
         '  <P Name="disableImplicitCasting">1</P>\n'
         "  <eml>\n"
         f'    <P Name="name">{esc(fname)}</P>\n'
         "  </eml>\n"
         "  <Children>\n"
         '    <state SSID="1">\n'
         '      <P Name="labelString">eML_blk_kernel()</P>\n'
         '      <P Name="position">[18 64.5 118 66]</P>\n'
         '      <P Name="fontSize">12</P>\n'
         '      <P Name="superState">SUBCHART</P>\n'
         f'      <P Name="subviewer">{chart_id}</P>\n'
         '      <P Name="type">FUNC_STATE</P>\n'
         '      <P Name="decomposition">CLUSTER_STATE</P>\n'
         "      <eml>\n"
         '        <P Name="isEML">1</P>\n'
         f'        <P Name="script">{esc(script)}</P>\n'
         '        <P Name="vectorOutputs1D">1</P>\n'
         "      </eml>\n"
         "    </state>\n")
    for i, (name, scope) in enumerate(data):
        x += _data_xml(4 + i, name, scope)
    x += ('    <transition SSID="2">\n'
          '      <P Name="labelString">{eML_blk_kernel();}</P>\n'
          '      <P Name="labelPosition">[28.125 13.875 102.544 14.964]</P>\n'
          '      <P Name="fontSize">12</P>\n'
          "      <src>\n"
          '        <P Name="intersection">[0 0 1 0 23.5747 14.625 0 0]</P>\n'
          "      </src>\n"
          "      <dst>\n"
          '        <P Name="SSID">3</P>\n'
          '        <P Name="intersection">[1 0 -1 0 23.5747 42.5747 0 0]</P>\n'
          "      </dst>\n"
          '      <P Name="midPoint">[23.5747 24.9468]</P>\n'
          '      <P Name="dataLimits">[21.175 25.975 14.625 42.575]</P>\n'
          f'      <P Name="subviewer">{chart_id}</P>\n'
          '      <P Name="drawStyle">SMART</P>\n'
          "      <slide>\n"
          '        <P Name="sticky">BOTH_STICK</P>\n'
          "      </slide>\n"
          '      <P Name="executionOrder">1</P>\n'
          "    </transition>\n"
          '    <junction SSID="3">\n'
          '      <P Name="position">[23.5747 49.5747 7]</P>\n'
          f'      <P Name="subviewer">{chart_id}</P>\n'
          '      <P Name="type">CONNECTIVE_JUNCTION</P>\n'
          "    </junction>\n"
          "  </Children>\n"
          "</chart>\n")
    return x


def machine_xml(machine_id, target_id, chart_id, instance_id, instance_name):
    return ('<?xml version="1.0" encoding="utf-8"?>\n<Stateflow>\n'
            f'  <machine id="{machine_id}">\n'
            f'    <P Name="sfVersion">{SF_VERSION}</P>\n'
            "    <Children>\n"
            f'      <target id="{target_id}" name="sfun">\n'
            '        <P Name="description">Default Simulink S-Function Target.</P>\n'
            "      </target>\n"
            f'      <chart Ref="chart_{chart_id}"/>\n'
            "    </Children>\n"
            "  </machine>\n"
            f'  <instance id="{instance_id}">\n'
            f'    <P Name="machine">{machine_id}</P>\n'
            f'    <P Name="name">{esc(instance_name)}</P>\n'
            f'    <P Name="chart">{chart_id}</P>\n'
            "  </instance>\n</Stateflow>\n")


# ----------------------------------------------------------------------------- systems
def mfcn_system_xml(sid, file_number, inputs, outputs, params):
    """Contents of the MATLAB Function subsystem: Inports -> ' SFunction ' -> Outports,
    output 1 of the S-function (call output) -> ' Demux ' -> ' Terminator '.
    The S-function receives the parameters (scope Parameter) through its Parameters list:
    names joined by commas, sorted by character code, as in every MATLAB Function block
    saved by Simulink."""
    nin, nout = len(inputs), len(outputs)
    k = 0
    in_sids, out_sids = [], []
    for _ in inputs:
        k += 1
        in_sids.append(f"{sid}::{k}")
    for _ in outputs:
        k += 1
        out_sids.append(f"{sid}::{k}")
    sfun, demux, term = f"{sid}::{k + 1}", f"{sid}::{k + 2}", f"{sid}::{k + 3}"
    high = k + 3
    zo = 0

    def z():
        nonlocal zo
        zo += 1
        return zo

    x = ('<?xml version="1.0" encoding="utf-8"?>\n<System>\n'
         + P("SIDHighWatermark", high, "  "))
    for i, (name, s) in enumerate(zip(inputs, in_sids)):
        y = 101 + 35 * i
        x += (f'  <Block BlockType="Inport" Name="{esc_attr(name)}" SID="{s}">\n'
              + P("Position", f"[20, {y}, 40, {y + 18}]") + P("ZOrder", z())
              + (P("Port", i + 1) if i else "") + "  </Block>\n")
    x += (f'  <Block BlockType="Demux" Name=" Demux " SID="{demux}">\n'
          '    <PortCounts in="1" out="1"/>\n'
          + P("Position", "[270, 230, 320, 270]") + P("ZOrder", z())
          + P("Outputs", 1) + "  </Block>\n")
    sf_h = max(60, 35 * max(nin, nout + 1))
    x += (f'  <Block BlockType="S-Function" Name=" SFunction " SID="{sfun}">\n'
          + P("Tag", f"Stateflow S-Function {file_number}")
          + f'    <PortCounts in="{nin}" out="{nout + 1}"/>\n'
          + P("Position", f"[180, 100, 230, {100 + sf_h}]") + P("ZOrder", z())
          + P("FunctionName", "sf_sfun")
          + (P("Parameters", ",".join(sorted(params))) if params else "")
          + P("PortCounts", f"[{nin} {nout + 1}]")
          + P("SFunctionDeploymentMode", "off") + P("EnableBusSupport", "off")
          + P("SFcnIsStateOwnerBlock", "off")
          + "    <PortProperties>\n")
    for i, name in enumerate(outputs):
        x += (f'      <Port Type="out" Index="{i + 2}">\n'
              + P("Name", name, "        ") + "      </Port>\n")
    x += "    </PortProperties>\n  </Block>\n"
    x += (f'  <Block BlockType="Terminator" Name=" Terminator " SID="{term}">\n'
          + P("Position", "[460, 241, 480, 259]") + P("ZOrder", z()) + "  </Block>\n")
    for i, (name, s) in enumerate(zip(outputs, out_sids)):
        y = 101 + 35 * i
        x += (f'  <Block BlockType="Outport" Name="{esc_attr(name)}" SID="{s}">\n'
              + P("Position", f"[460, {y}, 480, {y + 18}]") + P("ZOrder", z())
              + (P("Port", i + 1) if i else "")
              + P("VectorParamsAs1DForOutWhenUnconnected", "off") + "  </Block>\n")
    zl = 0
    for i, s in enumerate(in_sids):
        zl += 1
        x += line(zl, f"{s}#out:1", f"{sfun}#in:{i + 1}")
    for i, (name, s) in enumerate(zip(outputs, out_sids)):
        zl += 1
        x += line(zl, f"{sfun}#out:{i + 2}", f"{s}#in:1", name=name)
    zl += 1
    x += line(zl, f"{demux}#out:1", f"{term}#in:1")
    zl += 1
    x += line(zl, f"{sfun}#out:1", f"{demux}#in:1")
    return x + "</System>\n"


def inner_system_xml(spec, sids):
    """Contents of the masked subsystem."""
    outputs, bus = spec["outputs"], spec["bus"]
    nin, nout, nbus = len(spec["inputs"]), len(outputs), len(bus)
    # layout: MATLAB Function ports every 40 px
    top = 40
    mf_h = 40 * nout
    mf = (220, top, 440, top + mf_h)
    bc_h = 40 * nbus
    bc = (560, top, 565, top + bc_h)
    t_y = port_y(top, mf_h, 1, nin)
    x = ('<?xml version="1.0" encoding="utf-8"?>\n<System>\n'
         + P("Location", "[100, 100, 1100, 700]", "  ")
         + P("Open", "off", "  ")
         + P("ZoomFactor", "100", "  "))
    x += (f'  <Block BlockType="Clock" Name="Clock" SID="{sids["clock"]}">\n'
          + P("Position", f"[100, {t_y - 10:.0f}, 120, {t_y + 10:.0f}]")
          + P("ZOrder", 1) + "  </Block>\n")
    x += (f'  <Block BlockType="SubSystem" Name="{esc_attr(spec["mfcn"])}" SID="{sids["mfcn"]}">\n'
          f'    <PortCounts in="{nin}" out="{nout}"/>\n'
          + P("Position", f"[{mf[0]}, {mf[1]}, {mf[2]}, {mf[3]}]") + P("ZOrder", 2)
          + P("ErrorFcn", "Stateflow.Translate.translate")
          + P("PermitHierarchicalResolution", "ExplicitOnly")
          + P("TreatAsAtomicUnit", "on")
          + P("SFBlockType", "MATLAB Function")
          + P("TreatAsGroupedWhenPropagatingVariantConditions", "off")
          + "    <PortProperties>\n")
    for i, name in enumerate(outputs):
        x += (f'      <Port Type="out" Index="{i + 1}">\n'
              + P("Name", name, "        ") + "      </Port>\n")
    x += f'    </PortProperties>\n    <System Ref="system_{sids["mfcn"]}"/>\n  </Block>\n'
    if spec["integrator"]:
        iy = mf[3] + 55
        x += (f'  <Block BlockType="Integrator" Name="Integrator" SID="{sids["integrator"]}">\n'
              '    <PortCounts in="1" out="1"/>\n'
              + P("Position", f"[315, {iy - 15}, 345, {iy + 15}]") + P("ZOrder", 3)
              + P("BlockMirror", "on")
              + P("InitialCondition", spec["integrator"]) + "  </Block>\n")
    x += (f'  <Block BlockType="BusCreator" Name="Bus&#xA;Creator" SID="{sids["bus"]}">\n'
          f'    <PortCounts in="{nbus}" out="1"/>\n'
          + P("Position", f"[{bc[0]}, {bc[1]}, {bc[2]}, {bc[3]}]") + P("ZOrder", 4)
          + P("Inputs", nbus) + P("DisplayOption", "bar") + P("InheritFromInputs", "on")
          + "  </Block>\n")
    oy = port_y(top, bc_h, 1, 1)
    x += (f'  <Block BlockType="Outport" Name="grid_emulator_outputs" SID="{sids["out"]}">\n'
          + P("Position", f"[660, {oy - 7:.0f}, 690, {oy + 7:.0f}]") + P("ZOrder", 5)
          + P("VectorParamsAs1DForOutWhenUnconnected", "off") + "  </Block>\n")
    zl = 0
    zl += 1
    x += line(zl, f'{sids["clock"]}#out:1', f'{sids["mfcn"]}#in:1', name="t")
    for i, name in enumerate(bus):
        zl += 1
        x += line(zl, f'{sids["mfcn"]}#out:{i + 1}', f'{sids["bus"]}#in:{i + 1}', name=name)
    zl += 1
    x += line(zl, f'{sids["bus"]}#out:1', f'{sids["out"]}#in:1')
    if spec["integrator"]:
        # dx (last output) -> Integrator (mirrored, below the function) -> x (input 2)
        iy = mf[3] + 55
        y_dx = port_y(top, mf_h, nout, nout)
        y_x = port_y(top, mf_h, 2, nin)
        zl += 1
        x += line(zl, f'{sids["mfcn"]}#out:{nout}', f'{sids["integrator"]}#in:1', name="dx",
                  points=f"[25, 0; 0, {iy - y_dx:.0f}]")
        zl += 1
        x += line(zl, f'{sids["integrator"]}#out:1', f'{sids["mfcn"]}#in:2', name="x",
                  points=f"[-140, 0; 0, {y_x - iy:.0f}]")
    return x + "</System>\n"


# ----------------------------------------------------------------------------- binary parts
def library_base_mxarray(value="17F0F7"):
    """LibraryBase_bd: a 6-character MATLAB char array (same bytes as the originals)."""
    v = value.encode()
    body = (struct.pack("<II", 6, 8) + struct.pack("<II", 4, 0)
            + struct.pack("<II", 5, 8) + struct.pack("<II", 1, len(v))
            + struct.pack("<II", 1, 0)
            + struct.pack("<II", 16, len(v)) + v + b"\x00" * ((8 - len(v) % 8) % 8))
    return b"\x00\x01IM\x00\x00\x00\x00" + struct.pack("<II", 14, len(body)) + body


def tiny_png():
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00\x00")) + chunk(b"IEND", b""))


# ----------------------------------------------------------------------------- container
CONFIGSET = """<?xml version="1.0" encoding="utf-8"?>
<ConfigSet>
  <Object ObjectID="1" ClassName="Simulink.ConfigSet">
    <P Name="ExtraOptions" Class="char"/>
    <P Name="Name" Class="char">Configuration</P>
    <P Name="CurrentDlgPage" Class="char">Solver</P>
    <P Name="ConfigPrmDlgPosition" Class="double">[0.0, 0.0, 0.0, 0.0]</P>
    <P Name="Version" Class="char">26.0.0</P>
    <Array PropName="Components" Type="Simulink.ConfigComponent" Dimension="9*1">
      <Object ObjectID="2" ClassName="Simulink.SolverCC">
        <P Name="SolverName" Class="char">VariableStepAuto</P>
        <P Name="ODENIntegrationMethod" Class="char">ode3</P>
        <P Name="Version" Class="char">26.0.0</P>
      </Object>
      <Object ObjectID="3" ClassName="Simulink.DataIOCC">
        <P Name="Version" Class="char">26.0.0</P>
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

REL_HEAD = ('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n')
REL_SYSTEM = "http://schemas.mathworks.com/simulink/2010/relationships/system"


def windows_info():
    return ('<?xml version="1.0" encoding="utf-8"?>\n<WindowsInfo>\n'
            '  <Object PropName="BdWindowsInfo" ObjectID="1" ClassName="Simulink.BDWindowsInfo">\n'
            '    <Object PropName="WindowsInfo" ObjectID="2" ClassName="Simulink.WindowInfo">\n'
            '      <P Name="IsActive" Class="logical">1</P>\n'
            '      <P Name="Location" Class="double">[100.0, 100.0, 900.0, 600.0]</P>\n'
            '      <Array PropName="EditorsInfo" Type="Simulink.EditorInfo" Dimension="1*1">\n'
            '        <Object ObjectID="3">\n'
            '          <P Name="IsActive" Class="logical">1</P>\n'
            '          <P Name="IsTabbed" Class="logical">1</P>\n'
            '          <P Name="ViewObjType" Class="char">SimulinkTopLevel</P>\n'
            '          <P Name="LoadSaveID" Class="char">0</P>\n'
            '          <P Name="Extents" Class="double">[800.0, 500.0]</P>\n'
            '          <P Name="ZoomFactor" Class="double">1.0</P>\n'
            '          <P Name="Offset" Class="double">[0.0, 0.0]</P>\n'
            '          <P Name="SceneRectInView" Class="double">[0.0, 0.0, 800.0, 500.0]</P>\n'
            '        </Object>\n'
            '      </Array>\n'
            f'      <P Name="WindowUuid" Class="char">{new_uuid()}</P>\n'
            '    </Object>\n'
            f'    <P Name="BDUuid" Class="char">{new_uuid()}</P>\n'
            '  </Object>\n</WindowsInfo>\n')


def build(spec):
    script = read_function(os.path.join(SRCDIR, spec["src"]), spec["mfcn"], spec["inputs"],
                           spec["outputs"], [p[0] for p in spec["params"]])
    sids = {"root": 1, "clock": 2, "mfcn": 3, "bus": 4, "out": 5}
    if spec["integrator"]:
        sids["integrator"] = 6
    sid_high = max(sids.values())
    # Stateflow ids as Simulink numbers them (rule checked on every .slx of the repositories):
    # the loader gives the objects of a chart (state, transition, junction, data) the ids
    # after the chart id, so the instance id is chart id + objects + 1 and the target id
    # comes last; an instance id inside that range stops the loader with the assertion
    # fParserOldIds.find(std::make_pair(fCurrentChart, id)) == fParserOldIds.end().
    # Chart id above every SSID of the chart.
    n_objects = 3 + len(spec["inputs"]) + len(spec["outputs"]) + len(spec["params"])
    machine_id = 100
    chart_id = machine_id + 1
    instance_id = chart_id + n_objects + 1
    target_id = instance_id + 1
    file_number = 1
    chart_name = f'{spec["block"]}/{spec["mfcn"]}'

    root = ('<?xml version="1.0" encoding="utf-8"?>\n<System>\n'
            + P("Location", "[100, 100, 900, 600]", "  ")
            + P("Open", "on", "  ")
            + P("ReportName", "simulink-default.rpt", "  ")
            + P("SIDHighWatermark", sid_high, "  ")
            + f'  <Block BlockType="SubSystem" Name="{esc_attr(spec["block"])}" SID="{sids["root"]}">\n'
            '    <PortCounts out="1"/>\n'
            + P("Position", spec["position"]) + P("ZOrder", 1)
            + mask_xml(spec)
            + f'    <System Ref="system_{sids["root"]}"/>\n  </Block>\n</System>\n')

    systems = {
        "root": root,
        str(sids["root"]): inner_system_xml(spec, sids),
        str(sids["mfcn"]): mfcn_system_xml(sids["mfcn"], file_number, spec["inputs"],
                                           spec["outputs"], [p[0] for p in spec["params"]]),
    }
    sys_rels = {
        "root": [str(sids["root"])],
        str(sids["root"]): [str(sids["mfcn"])],
    }
    chart = chart_xml(chart_id, chart_name, file_number, spec["mfcn"], script, spec["inputs"],
                      spec["outputs"], [p[0] for p in spec["params"]])
    machine = machine_xml(machine_id, target_id, chart_id, instance_id, chart_name)

    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
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
          '    <EditorSettings>\n'
          '      <P Name="BrowserShowLibraryLinks">on</P>\n'
          '      <P Name="BrowserLookUnderMasks">on</P>\n'
          '    </EditorSettings>\n'
          '    <SimulationSettings>\n      <P Name="SimulationMode">normal</P>\n    </SimulationSettings>\n'
          '    <EngineSettings>\n      <P Name="ConfigurableSubsystemUsage">warning</P>\n    </EngineSettings>\n'
          '    <System Ref="system_root"/>\n  </Library>\n</ModelInformation>\n')
    bd_rels = (REL_HEAD
               + '  <Relationship Id="LibraryBase_bd" Target="bdmxdata/LibraryBase_bd.mxarray" '
               'Type="http://schemas.mathworks.com/simulinkModel/2015/relationships/modelMxArray"/>\n'
               '  <Relationship Id="stateflow_machine" Target="stateflow/machine.xml" '
               'Type="http://schemas.mathworks.com/simulinkModel/2014/relationships/stateflowMachine"/>\n'
               '  <Relationship Id="system_root" Target="systems/system_root.xml" '
               f'Type="{REL_SYSTEM}"/>\n'
               '  <Relationship Id="windowsInfo" Target="windowsInfo.xml" '
               'Type="http://schemas.mathworks.com/simulinkModel/2019/relationships/windowsInfo"/>\n'
               '</Relationships>\n')
    machine_rels = (REL_HEAD
                    + f'  <Relationship Id="chart_{chart_id}" Target="chart_{chart_id}.xml" '
                    'Type="http://schemas.mathworks.com/simulinkModel/2018/relationships/stateflowMachine"/>\n'
                    '</Relationships>\n')

    def rels_of(children):
        return REL_HEAD + "".join(
            f'  <Relationship Id="system_{c}" Target="system_{c}.xml" Type="{REL_SYSTEM}"/>\n'
            for c in children) + "</Relationships>\n"

    def sys_key(k):
        return (k != "root", int(k) if k != "root" else 0)

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
              '  <Override ContentType="application/vnd.mathworks.simulink.mf0+xml" PartName="/simulink/modelDictionary.xml"/>\n'
              f'  <Override ContentType="application/vnd.mathworks.stateflow.chart+xml" PartName="/simulink/stateflow/chart_{chart_id}.xml"/>\n'
              '  <Override ContentType="application/vnd.mathworks.stateflow.machine+xml" PartName="/simulink/stateflow/machine.xml"/>\n')
    for key in sorted(systems, key=sys_key):
        ctypes += ('  <Override ContentType="application/vnd.mathworks.simulink.mdl+xml" '
                   f'PartName="/simulink/systems/system_{key}.xml"/>\n')
    ctypes += ('  <Override ContentType="application/vnd.mathworks.simulink.blockDiagram+xml" PartName="/simulink/windowsInfo.xml"/>\n'
               '</Types>\n')

    root_rels = (REL_HEAD
                 + '  <Relationship Id="Thumbnail" Target="metadata/thumbnail.png" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/thumbnail"/>\n'
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
            '  <cp:category>library</cp:category>\n'
            f'  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>\n'
            '  <dc:creator>pwr-control</dc:creator>\n'
            '  <cp:lastModifiedBy>pwr-control</cp:lastModifiedBy>\n'
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
    configset_rels = (REL_HEAD
                      + '  <Relationship Id="configSet0" Target="configSet0.xml" Type="http://schemas.mathworks.com/simulink/2014/relationships/configSet"/>\n'
                      '</Relationships>\n')

    stored = [("metadata/thumbnail.png", tiny_png())]
    for key in sorted(systems, key=sys_key):
        stored.append((f"simulink/systems/system_{key}.xml", systems[key].encode("utf-8")))
    stored += [
        ("simulink/stateflow/machine.xml", machine.encode("utf-8")),
        (f"simulink/stateflow/chart_{chart_id}.xml", chart.encode("utf-8")),
        ("simulink/bdmxdata/LibraryBase_bd.mxarray", library_base_mxarray()),
        ("simulink/bddefaults.xml", BDDEFAULTS.encode()),
        ("simulink/blockdiagram.xml", bd.encode()),
        ("simulink/configSet0.xml", CONFIGSET.encode()),
        ("simulink/configSetInfo.xml", configset_info.encode()),
        ("simulink/modelDictionary.xml", model_dict.encode()),
        ("simulink/windowsInfo.xml", windows_info().encode()),
    ]
    deflated = [
        ("[Content_Types].xml", ctypes.encode()),
        ("_rels/.rels", root_rels.encode()),
        ("simulink/_rels/blockdiagram.xml.rels", bd_rels.encode()),
        ("simulink/_rels/configSetInfo.xml.rels", configset_rels.encode()),
        ("simulink/stateflow/_rels/machine.xml.rels", machine_rels.encode()),
    ]
    for key, children in sys_rels.items():
        deflated.append((f"simulink/systems/_rels/system_{key}.xml.rels",
                         rels_of(children).encode()))
    deflated += [
        ("metadata/coreProperties.xml", core.encode()),
        ("metadata/mwcoreProperties.xml", mwcore.encode()),
        ("metadata/mwcorePropertiesExtension.xml", mwext.encode()),
        ("metadata/mwcorePropertiesReleaseInfo.xml", mwrel.encode()),
    ]
    path = os.path.join(LIBDIR, spec["lib"] + ".slx")
    with zipfile.ZipFile(path, "w") as z:
        for items, mode in ((stored, zipfile.ZIP_STORED), (deflated, zipfile.ZIP_DEFLATED)):
            for name, data in items:
                zi = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                zi.compress_type = mode
                zi.external_attr = 0
                z.writestr(zi, data)
    return path


def main():
    for spec in BLOCKS:
        print("written", os.path.relpath(build(spec), LIBDIR))


if __name__ == "__main__":
    main()
