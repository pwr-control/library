#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
make_afe_uvw_ctrl.py - writes the library afe_uvw_ctrl.slx and its test bench test/test_afe_uvw_ctrl.slx
without MATLAB, then checks both files.

Library (../afe_uvw_ctrl.slx): five masked blocks, one MATLAB Function each, the code read from ../src:

    grid_voltage_sequences          src/grid_voltage_sequences.m
    frt_vde4110                     src/frt_vde4110.m
    grid_current_sequences_q_ctrl   src/grid_current_sequences_q_ctrl.m
    current_ctrl_uvw                src/current_ctrl_uvw.m
    islanding_detector              src/islanding_detector.m

Every block: masked subsystem (one mask parameter, the struct p) -> Inports -> MATLAB Function block (the
function of the source file; p is a data of scope Parameter) -> Outports. The MATLAB Function inherits
the sample time. 2 non-virtual blocks per block (atomic subsystem + S-function).

Test bench (../test/test_afe_uvw_ctrl.slx): a fixed-step discrete model (step tb.ts) with the five
library blocks in the chain of the model afe_uvw_three_phase, a MATLAB Function test_source
(test/afe_uvw_ctrl_test_source.m: grid voltage, PLL angle, references), a MATLAB Function rl_plant
(test/afe_uvw_ctrl_test_plant.m: RL branches between converter and grid) behind a Unit Delay (the
measurement of the next period), the grid current = -stack current (Gain -1, the model's sign), and one
To Workspace tb_log (50 signals, Mux). Variables p and tb from test/afe_uvw_ctrl_test_param.m;
test/afe_uvw_ctrl_test_run.m runs and checks it.

The .slx container (zip of XML parts, R2026a format, loaded by R2026b) is written directly; Simulink saves
it in its own format on the first save. The Stateflow parts follow the rules checked on every .slx of the
repositories: the ids of a chart's objects follow the chart id, the instance id is chart id + objects + 1,
the next chart starts after it, the target id comes last; the mask parameter is an argument of the
function after the port inputs and the S-function lists it in Parameters.

The files are the same on every run (fixed UUIDs and date), so that running the script again gives no
git diff. A change of the MATLAB code alone does not need this script: in MATLAB,
update_afe_uvw_ctrl.m loads the sources into the blocks of both files.

Usage:  python3 make_afe_uvw_ctrl.py            writes and checks both files
        python3 make_afe_uvw_ctrl.py --check    checks the existing files only

Rev. 00, 2026-11-04.
"""
import collections
import hashlib
import itertools
import os
import posixpath
import re
import struct
import sys
import uuid
import zipfile
import zlib
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)                               # library/masked_models/afe_uvw_ctrl
SRC = os.path.join(PKG, 'src')
TEST = os.path.join(PKG, 'test')
LIB = 'afe_uvw_ctrl'
TEST_MODEL = 'test_afe_uvw_ctrl'
LIB_PATH = os.path.join(PKG, LIB + '.slx')
TEST_PATH = os.path.join(TEST, TEST_MODEL + '.slx')

RELEASE = 'R2026a'
RELEASE_VERSION = '26.1.0.3346908'
SF_VERSION = '82600000'
FIXED_DATE = '2026-11-04T12:00:00Z'
GITHUB = 'https://github.com/pwr-control/library/blob/dev/library/masked_models/afe_uvw_ctrl/README.md'

MASK_PARAM = ('p', 'Parameter struct p (see afe_uvw_ctrl_param_example.m)', 'param.afe.uvw')
TAIL = (' Source src/{src} of library/masked_models/afe_uvw_ctrl (update_afe_uvw_ctrl.m loads it into the '
        'block). The block inherits its sample time: run it at p.ts (triggered or discrete subsystem clocked '
        'at p.ts, as the control of the model, or a fixed-step discrete model). Parameter p: one struct for '
        'the five blocks, see afe_uvw_ctrl_param_example.m. User guide: Help of the block (README.md of the '
        'folder).')

# ---------------------------------------------------------------------------- the five blocks
BLOCKS = [
    dict(name='grid_voltage_sequences', src='grid_voltage_sequences.m',
         inputs=['ug_abc', 'theta', 'omega_pu'], outputs=['v_seq_avg', 'v_seq', 'ug_ab'],
         icon='grid voltage\\nsequences',
         mask_type='Grid voltage sequences (MATLAB Function)',
         description=(
             'Positive- and negative-sequence components of the grid voltage in the frames turned by +theta '
             'and -theta (xi/eta), averaged over a window of grid period / p.vseq.avg_order that follows the '
             'measured pulsation (half period with avg_order 2: the 100 Hz ripple of the other sequence is '
             'removed). Inputs: ug_abc [3x1] pu, theta [rad] angle of the PLL, omega_pu [pu] pulsation of the '
             'PLL. Outputs: v_seq_avg [4x1] = [pos_xi; pos_eta; neg_xi; neg_eta] averaged (zero before '
             'p.vseq.t_enable), v_seq [4x1] the same unfiltered, ug_ab [2x1] = [alpha; beta] (Clarke, '
             'amplitude invariant). MATLAB Function version of the subsystem grid_voltage_sequences of the model '
             'afe_uvw_three_phase (pwr-control/modelization-and-control).')),
    dict(name='frt_vde4110', src='frt_vde4110.m',
         inputs=['v_seq_avg', 'i_react_ref', 'enable', 'reset'],
         outputs=['i_grid_ref', 'frt_active', 'pwr_lim_enable', 'frt_log'],
         icon='fault ride-through\\nVDE-AR-N 4110',
         mask_type='Fault ride-through VDE-AR-N 4110 (MATLAB Function)',
         description=(
             'Fault detection and reactive current references for the fault ride-through. A fault is detected '
             'when the positive sequence leaves [p.frt.v_pos_low, p.frt.v_pos_high] or the negative sequence '
             'exceeds p.frt.v_neg_max while the voltage changes faster than p.frt.v_pos_dot_max (double-'
             'integrator observers); state machine IDLE / ACTIVE / EXCEEDED (fault longer than p.frt.t_hold_max, '
             'left with reset). During the fault: pwr_lim_enable when the voltage is below p.frt.pwrlim_v_pos, '
             'and i_grid_ref = [pos_eta; neg_xi; neg_eta] = normal reactive references + p.frt.k_frt_ref times '
             'the change of the voltage sequences against their pre-fault averages (p.frt.t_avg_prefault, '
             'frozen during the fault), limited and low-pass filtered (p.frt.f_lpf_ref). Inputs: v_seq_avg [4x1] '
             'from grid_voltage_sequences, i_react_ref [2x1] = [pos; neg] reactive grid current references in '
             'normal operation [pu], enable (> 0.5 detector on), reset (> 0.5 leaves EXCEEDED). Outputs: '
             'i_grid_ref [3x1] pu -> grid_current_sequences_q_ctrl, frt_active (0/1), pwr_lim_enable (0/1, for '
             'the DC-link control), frt_log [10x1] = [state; exceeded; red_dyn; v_pos_dot; v_neg_dot; '
             'v_prefault (4); |v_neg|]. MATLAB Function version of the subsystem FRT-VDE4110 of the model '
             'afe_uvw_three_phase.')),
    dict(name='grid_current_sequences_q_ctrl', src='grid_current_sequences_q_ctrl.m',
         inputs=['ig_abc', 'theta', 'omega_pu', 'i_grid_ref'], outputs=['i_stack_ref', 'i_seq_avg', 'i_seq'],
         icon='grid current sequences\\nreactive current control',
         mask_type='Grid current sequences and reactive current control (MATLAB Function)',
         description=(
             'Sequence components of the grid current (same transformation and moving average as '
             'grid_voltage_sequences) and three PI controllers with clamped integrators that make the averaged '
             'positive-sequence eta and negative-sequence xi and eta grid currents follow i_grid_ref; the '
             'outputs are the stack current references for current_ctrl_uvw. Error = p.iseq.err_sign * '
             '(reference - measured): err_sign = -1 when the grid current is measured towards the converter '
             '(the model), +1 otherwise. Inputs: ig_abc [3x1] pu, theta [rad], omega_pu [pu], i_grid_ref [3x1] '
             '= [pos_eta; neg_xi; neg_eta] pu (frt_vde4110). Outputs: i_stack_ref [3x1] = [pos_eta; neg_xi; '
             'neg_eta] pu, i_seq_avg [4x1] = [pos_xi; pos_eta; neg_xi; neg_eta] averaged, i_seq [4x1] '
             'unfiltered. MATLAB Function version of the subsystem grid_current_sequences_and_reactive_pwr_ctrl '
             'of the model afe_uvw_three_phase.')),
    dict(name='current_ctrl_uvw', src='current_ctrl_uvw.m',
         inputs=['i_xi_ref', 'i_stack_ref', 'is_abc', 'theta'], outputs=['u_abg', 'i_abc_ref', 'is_xe'],
         icon='per-phase resonant\\ncurrent control',
         mask_type='Per-phase resonant current control (MATLAB Function)',
         description=(
             'Current control of the stack (converter) current, one resonant PI per phase: the references of '
             'the sequence frames (xi from the DC-link control, [pos_eta; neg_xi; neg_eta] from '
             'grid_current_sequences_q_ctrl) become three phase current references; per phase d = kp*e + '
             'ki*s/(s^2 + 2*delta*w*s + w^2)*e (forward Euler with p.ts, w = p.ictrl.omega_res, delta = '
             'p.ictrl.delta_res); the three outputs are divided by the length of the previous alpha/beta vector '
             '(limited to [p.ictrl.mag_lim, p.ictrl.mag_scale_max]) and transformed to alpha/beta, one step late '
             'as the model when p.ictrl.out_delay = 1; a PI on the zero-sequence current gives u_gamma. Inputs: '
             'i_xi_ref [pu], i_stack_ref [3x1] pu, is_abc [3x1] pu, theta [rad]. Outputs: u_abg [3x1] = '
             '[u_alpha; u_beta; u_gamma] pu for the modulator, i_abc_ref [3x1] pu, is_xe [2x1] = [xi; eta] stack '
             'current in the positive frame (log). MATLAB Function version of the subsystem current_ctrl of the '
             'model afe_uvw_three_phase.')),
    dict(name='islanding_detector', src='islanding_detector.m',
         inputs=['ug_ab', 'theta', 'omega_pu', 'enable'], outputs=['island', 'crit', 'idet_log'],
         icon='islanding detector\\n(passive)',
         mask_type='Passive islanding detector (MATLAB Function)',
         description=(
             'Passive islanding detection from the grid voltage and the PLL frequency: six criteria, each with '
             'its threshold and its on-delay (the condition must hold for the whole delay): under-voltage '
             '(p.island.u_min, t_trip_u_min), over-voltage (u_max, t_trip_u_max), under- and over-frequency '
             '(f_min, f_max, t_trip_f), rate of change of frequency (rocof_max [Hz/s], t_trip_rocof, from a '
             'double-integrator observer on the PLL pulsation) and voltage harmonics sqrt(u5^2 + u7^2)/u1 > '
             'h_max (t_trip_h). The frequency and harmonic criteria are blocked below p.island.u_valid (a grid '
             'fault is handled by frt_vde4110). Output latched until enable = 0 when p.island.latch = 1. '
             'Inputs: ug_ab [2x1] = [alpha; beta] pu (grid_voltage_sequences), theta [rad], omega_pu [pu], '
             'enable (0 also resets). Outputs: island (0/1), crit = bit mask of the criteria that tripped (1 U<, '
             '2 U>, 4 f<, 8 f>, 16 ROCOF, 32 harmonics), idet_log [8x1] = [u1; u5; u7; harmonic ratio; f [pu]; '
             'ROCOF [Hz/s]; longest running criterion [s]; time since detection [s]]. New block: the model only '
             'measures the 7th harmonic.')),
]
LIB_PORTS = {b['name']: (len(b['inputs']), len(b['outputs'])) for b in BLOCKS}

# the two MATLAB Functions of the test bench
TEST_MLF = dict(
    source=dict(name='test_source', src='afe_uvw_ctrl_test_source.m', inputs=['t'],
                outputs=['ug_abc', 'theta', 'omega_pu', 'enable', 'reset', 'i_xi_ref', 'i_react_ref'],
                params=['tb']),
    plant=dict(name='rl_plant', src='afe_uvw_ctrl_test_plant.m', inputs=['u_abg', 'ug_abc'],
               outputs=['is_abc'], params=['tb']),
)
# the 50 logged signals (Mux inputs): (signal name, width) - the same order in afe_uvw_ctrl_test_run.m
LOG = [('v_seq_avg', 4), ('i_grid_ref', 3), ('frt_active', 1), ('pwr_lim_enable', 1), ('frt_log', 10),
       ('i_stack_ref', 3), ('i_seq_avg', 4), ('u_abg', 3), ('i_abc_ref', 3), ('is_xe', 2), ('is_abc', 3),
       ('island', 1), ('crit', 1), ('idet_log', 8), ('theta', 1), ('omega_pu', 1), ('i_xi_ref', 1)]
assert sum(w for _, w in LOG) == 50


# ---------------------------------------------------------------------------- helpers
def esc(text):
    return escape(str(text), {'"': '&quot;', "'": '&apos;'})


def esc_attr(text):
    return escape(str(text), {'"': '&quot;', "'": '&apos;', '\n': '&#xA;'})


def P(name, value, indent='    '):
    return f'{indent}<P Name="{name}">{esc(value)}</P>\n'


_uuid_count = itertools.count(1)
_uuid_seed = ['']


def new_uuid():
    """UUID from a counter: the same on every run (no git diff when nothing changed)."""
    return str(uuid.UUID(bytes=hashlib.md5(f'{_uuid_seed[0]}/{next(_uuid_count)}'.encode()).digest(),
                         version=4))


def read_function(path, name, inputs, outputs, params):
    """The MATLAB code of a block, checked against the interface: the signature lists the port inputs,
    then the parameters (scope Parameter), as Simulink saves every MATLAB Function block."""
    with open(path, encoding='utf-8') as fh:
        code = fh.read().replace('\r\n', '\n')
    sig = re.search(r'^function\s*\[?(.*?)\]?\s*=\s*(\w+)\s*\((.*?)\)', code, re.S | re.M)
    outs = [o.strip() for o in sig.group(1).replace('...', ' ').replace(',', ' ').split()]
    ins = [i.strip() for i in sig.group(3).replace('...', ' ').split(',')]
    assert sig.group(2) == name, f'{path}: function name {sig.group(2)} != {name}'
    assert outs == outputs, f'{path}: outputs {outs} != {outputs}'
    assert ins == inputs + params, f'{path}: inputs {ins} != {inputs + params}'
    return code


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


class Charts:
    """The MATLAB Functions of one file, in the order of their chartFileNumber."""

    def __init__(self):
        self.items = []

    def add(self, path, fname, script, inputs, outputs, params):
        self.items.append(dict(path=path, fname=fname, script=script, inputs=inputs, outputs=outputs,
                               params=params, file_number=len(self.items) + 1))
        return self.items[-1]


# ---------------------------------------------------------------------------- systems
class System:
    def __init__(self, sids, charts, location='[100, 100, 1500, 800]'):
        self.sids = sids
        self.charts = charts
        self.blocks = []            # (sid, xml)
        self.lines = []
        self.children = {}          # sid -> System
        self.location = location
        self.zorder = 0

    def z(self):
        self.zorder += 1
        return self.zorder

    def add(self, xml, sid):
        self.blocks.append((sid, xml))
        return sid

    def inport(self, name, port, position):
        sid = self.sids()
        return self.add(f'  <Block BlockType="Inport" Name="{esc_attr(name)}" SID="{sid}">\n'
                        + P('Position', position) + P('ZOrder', self.z())
                        + (P('Port', port) if port != 1 else '') + '  </Block>\n', sid)

    def outport(self, name, port, position):
        sid = self.sids()
        return self.add(f'  <Block BlockType="Outport" Name="{esc_attr(name)}" SID="{sid}">\n'
                        + P('Position', position) + P('ZOrder', self.z())
                        + (P('Port', port) if port != 1 else '')
                        + P('VectorParamsAs1DForOutWhenUnconnected', 'off') + '  </Block>\n', sid)

    def digital_clock(self, name, sample_time, position):
        sid = self.sids()
        return self.add(f'  <Block BlockType="DigitalClock" Name="{esc_attr(name)}" SID="{sid}">\n'
                        + P('Position', position) + P('ZOrder', self.z()) + P('SampleTime', sample_time)
                        + '  </Block>\n', sid)

    def unit_delay(self, name, initial, position, mirror=False):
        sid = self.sids()
        return self.add(f'  <Block BlockType="UnitDelay" Name="{esc_attr(name)}" SID="{sid}">\n'
                        + P('Position', position) + P('ZOrder', self.z())
                        + (P('BlockMirror', 'on') if mirror else '')
                        + P('InitialCondition', initial) + P('SampleTime', '-1') + '  </Block>\n', sid)

    def gain(self, name, value, position, mirror=False):
        sid = self.sids()
        return self.add(f'  <Block BlockType="Gain" Name="{esc_attr(name)}" SID="{sid}">\n'
                        + P('Position', position) + P('ZOrder', self.z())
                        + (P('BlockMirror', 'on') if mirror else '') + P('Gain', value) + '  </Block>\n', sid)

    def mux(self, name, n, position):
        sid = self.sids()
        return self.add(f'  <Block BlockType="Mux" Name="{esc_attr(name)}" SID="{sid}">\n'
                        f'    <PortCounts in="{n}" out="1"/>\n'
                        + P('Position', position) + P('ZOrder', self.z())
                        + P('Inputs', n) + P('DisplayOption', 'bar') + '  </Block>\n', sid)

    def to_workspace(self, name, varname, position):
        sid = self.sids()
        return self.add(f'  <Block BlockType="ToWorkspace" Name="{esc_attr(name)}" SID="{sid}">\n'
                        '    <PortCounts in="1"/>\n'
                        + P('Position', position) + P('ZOrder', self.z())
                        + P('VariableName', varname) + P('MaxDataPoints', 'inf')
                        + P('SampleTime', '-1') + P('SaveFormat', 'Array') + '  </Block>\n', sid)

    def library_ref(self, name, source_block, nin, nout, position, params):
        """Instance of a masked block of the library. params = [(name, value)]."""
        sid = self.sids()
        idata = P('ContentPreviewEnabled', 'on', '      ') + ''.join(P(k, v, '      ') for k, v in params)
        return self.add(f'  <Block BlockType="Reference" Name="{esc_attr(name)}" SID="{sid}">\n'
                        f'    <PortCounts in="{nin}" out="{nout}"/>\n'
                        + P('Position', position) + P('ZOrder', self.z())
                        + P('LibraryVersion', '1.0') + P('SourceBlock', source_block)
                        + '    <P Name="SourceType"/>\n'
                        + '    <InstanceData>\n' + idata + '    </InstanceData>\n  </Block>\n', sid)

    def subsystem(self, name, position, nin, nout, child, mask_xml='', sid=None):
        """A (masked) virtual subsystem whose content is the System child; sid may be reserved
        beforehand so that the block gets a lower SID than its content."""
        if sid is None:
            sid = self.sids()
        pc = ' '.join(f'{k}="{v}"' for k, v in (('in', nin), ('out', nout)) if v)
        xml = (f'  <Block BlockType="SubSystem" Name="{esc_attr(name)}" SID="{sid}">\n'
               f'    <PortCounts {pc}/>\n'
               + P('Position', position) + P('ZOrder', self.z())
               + mask_xml
               + f'    <System Ref="system_{sid}"/>\n  </Block>\n')
        self.children[sid] = child
        return self.add(xml, sid)

    def mlf(self, name, path, position, src_path, inputs, outputs, params):
        """A MATLAB Function block: the atomic subsystem, its inner system (Inports, ' SFunction ',
        ' Demux ', ' Terminator ', Outports) and the Stateflow chart of its code."""
        script = read_function(src_path, os.path.splitext(os.path.basename(src_path))[0], inputs, outputs,
                               params)
        chart = self.charts.add(path, os.path.splitext(os.path.basename(src_path))[0], script, inputs,
                                outputs, params)
        sid = self.sids()
        nin, nout = len(inputs), len(outputs)
        xml = (f'  <Block BlockType="SubSystem" Name="{esc_attr(name)}" SID="{sid}">\n'
               f'    <PortCounts in="{nin}" out="{nout}"/>\n'
               + P('Position', position) + P('ZOrder', self.z())
               + P('ErrorFcn', 'Stateflow.Translate.translate')
               + P('PermitHierarchicalResolution', 'ExplicitOnly')
               + P('TreatAsAtomicUnit', 'on')
               + P('SFBlockType', 'MATLAB Function')
               + P('TreatAsGroupedWhenPropagatingVariantConditions', 'off')
               + '    <PortProperties>\n')
        for i, o in enumerate(outputs):
            xml += f'      <Port Type="out" Index="{i + 1}">\n' + P('Name', o, '        ') + '      </Port>\n'
        xml += f'    </PortProperties>\n    <System Ref="system_{sid}"/>\n  </Block>\n'
        self.children[sid] = MlfSystem(sid, chart['file_number'], inputs, outputs, params)
        return self.add(xml, sid)

    def sig(self, src, dst, name=None):
        """Signal line src 'SID#out:1' -> dst 'SID#in:1' or a list of destinations (branches)."""
        xml = '  <Line>\n'
        if name:
            xml += P('Name', name) + P('Labels', '[0, 0]')
        xml += P('ZOrder', self.z()) + P('Src', src)
        if isinstance(dst, (list, tuple)):
            for d in dst:
                xml += f'    <Branch>\n{P("ZOrder", self.z(), "      ")}{P("Dst", d, "      ")}    </Branch>\n'
        else:
            xml += P('Dst', dst)
        self.lines.append(xml + '  </Line>\n')

    def xml(self, root=False, sid_high=None):
        out = '<?xml version="1.0" encoding="utf-8"?>\n<System>\n' + P('Location', self.location, '  ')
        if root:
            out += P('Open', 'on', '  ') + P('ReportName', 'simulink-default.rpt', '  ')
            out += P('SIDHighWatermark', sid_high, '  ')
        else:
            out += P('Open', 'off', '  ')
        out += P('ZoomFactor', '100', '  ')
        for _, b in self.blocks:
            out += b
        for ln in self.lines:
            out += ln
        return out + '</System>\n'

    def all_systems(self):
        for sid, child in self.children.items():
            yield sid, child
            if isinstance(child, System):
                yield from child.all_systems()


class MlfSystem:
    """Contents of a MATLAB Function block (SIDs 'N::k'): Inports -> ' SFunction ' -> Outports, output 1
    of the S-function (the call output) -> ' Demux ' -> ' Terminator '. The S-function lists the
    parameters (scope Parameter) in Parameters, comma-joined, sorted by character code."""

    def __init__(self, sid, file_number, inputs, outputs, params):
        self.sid, self.file_number = sid, file_number
        self.inputs, self.outputs, self.params = inputs, outputs, params
        self.children = {}

    def all_systems(self):
        return iter(())

    def xml(self):
        sid, inputs, outputs, params = self.sid, self.inputs, self.outputs, self.params
        nin, nout = len(inputs), len(outputs)
        in_sids = [f'{sid}::{k + 1}' for k in range(nin)]
        out_sids = [f'{sid}::{nin + k + 1}' for k in range(nout)]
        k = nin + nout
        sfun, demux, term = f'{sid}::{k + 1}', f'{sid}::{k + 2}', f'{sid}::{k + 3}'
        zo = itertools.count(1)
        x = '<?xml version="1.0" encoding="utf-8"?>\n<System>\n' + P('SIDHighWatermark', k + 3, '  ')
        for i, (name, s) in enumerate(zip(inputs, in_sids)):
            y = 101 + 35*i
            x += (f'  <Block BlockType="Inport" Name="{esc_attr(name)}" SID="{s}">\n'
                  + P('Position', f'[20, {y}, 40, {y + 18}]') + P('ZOrder', next(zo))
                  + (P('Port', i + 1) if i else '') + '  </Block>\n')
        x += (f'  <Block BlockType="Demux" Name=" Demux " SID="{demux}">\n'
              '    <PortCounts in="1" out="1"/>\n'
              + P('Position', '[270, 230, 320, 270]') + P('ZOrder', next(zo)) + P('Outputs', 1) + '  </Block>\n')
        sf_h = max(60, 35*max(nin, nout + 1))
        x += (f'  <Block BlockType="S-Function" Name=" SFunction " SID="{sfun}">\n'
              + P('Tag', f'Stateflow S-Function {self.file_number}')
              + f'    <PortCounts in="{nin}" out="{nout + 1}"/>\n'
              + P('Position', f'[180, 100, 230, {100 + sf_h}]') + P('ZOrder', next(zo))
              + P('FunctionName', 'sf_sfun')
              + (P('Parameters', ','.join(sorted(params))) if params else '')
              + P('PortCounts', f'[{nin} {nout + 1}]')
              + P('SFunctionDeploymentMode', 'off') + P('EnableBusSupport', 'off')
              + P('SFcnIsStateOwnerBlock', 'off') + '    <PortProperties>\n')
        for i, name in enumerate(outputs):
            x += f'      <Port Type="out" Index="{i + 2}">\n' + P('Name', name, '        ') + '      </Port>\n'
        x += '    </PortProperties>\n  </Block>\n'
        x += (f'  <Block BlockType="Terminator" Name=" Terminator " SID="{term}">\n'
              + P('Position', '[460, 241, 480, 259]') + P('ZOrder', next(zo)) + '  </Block>\n')
        for i, (name, s) in enumerate(zip(outputs, out_sids)):
            y = 101 + 35*i
            x += (f'  <Block BlockType="Outport" Name="{esc_attr(name)}" SID="{s}">\n'
                  + P('Position', f'[460, {y}, 480, {y + 18}]') + P('ZOrder', next(zo))
                  + (P('Port', i + 1) if i else '')
                  + P('VectorParamsAs1DForOutWhenUnconnected', 'off') + '  </Block>\n')
        zl = itertools.count(1)

        def line(src, dst, name=None):
            s = '  <Line>\n'
            if name:
                s += P('Name', name) + P('Labels', '[0, 0]')
            return s + P('ZOrder', next(zl)) + P('Src', src) + P('Dst', dst) + '  </Line>\n'

        for i, s in enumerate(in_sids):
            x += line(f'{s}#out:1', f'{sfun}#in:{i + 1}')
        for i, (name, s) in enumerate(zip(outputs, out_sids)):
            x += line(f'{sfun}#out:{i + 2}', f'{s}#in:1', name)
        x += line(f'{demux}#out:1', f'{term}#in:1')
        x += line(f'{sfun}#out:1', f'{demux}#in:1')
        return x + '</System>\n'


# ---------------------------------------------------------------------------- mask
def mask_xml(spec):
    inputs, outputs = spec['inputs'], spec['outputs']
    icon = f"disp(sprintf('{spec['icon']}'))\n"
    icon += ''.join(f"port_label('input', {k + 1}, '{n}')\n" for k, n in enumerate(inputs))
    icon += ''.join(f"port_label('output', {k + 1}, '{n}')\n" for k, n in enumerate(outputs))
    name, prompt, value = MASK_PARAM
    desc = spec['description'] + TAIL.format(src=spec['src'])
    return ('    <Mask>\n'
            f"      <Type>{esc(spec['mask_type'])}</Type>\n"
            f'      <Display RunInitForIconRedraw="off">{esc(icon.rstrip())}</Display>\n'
            f'      <Description>{esc(desc)}</Description>\n'
            f"      <Help>{esc(f'web({GITHUB!r}, {chr(39)}-browser{chr(39)})')}</Help>\n"
            f'      <MaskParameter Name="{name}" Type="edit" ShowTooltip="off">\n'
            f'        <Prompt>{esc(prompt)}</Prompt>\n'
            f'        <Value>{esc(value)}</Value>\n'
            '      </MaskParameter>\n'
            '      <DialogControl Type="Group" Name="DescGroupVar">\n'
            '        <Prompt>%&lt;MaskType&gt;</Prompt>\n'
            '        <DialogControl Type="Text" Name="DescTextVar">\n'
            '          <Prompt>%&lt;MaskDescription&gt;</Prompt>\n'
            '        </DialogControl>\n'
            f'        <DialogControl Type="Edit" Name="{name}">\n'
            f'          <Prompt>{esc(prompt)}</Prompt>\n'
            '          <ControlOptions PromptLocation="left"/>\n'
            '        </DialogControl>\n'
            '      </DialogControl>\n'
            '    </Mask>\n')


# ---------------------------------------------------------------------------- Stateflow
def _data_xml(ssid, name, scope):
    if scope == 'OUTPUT_DATA':
        type_extra, frame = '', 'SF_FRAME_NO'
    else:
        type_extra = P('isSigned', 1, '          ') + P('wordLength', 16, '          ')
        frame = 'SF_FRAME_INHERITED'
    return (f'    <data SSID="{ssid}" name="{esc_attr(name)}">\n'
            + P('scope', scope, '      ')
            + '      <props>\n        <array>\n' + P('size', -1, '          ') + '        </array>\n'
            '        <type>\n' + P('method', 'SF_INHERITED_TYPE', '          ')
            + P('primitive', 'SF_DOUBLE_TYPE', '          ') + type_extra + '        </type>\n'
            + P('complexity', 'SF_COMPLEX_INHERITED', '        ') + P('frame', frame, '        ')
            + '        <unit>\n' + P('name', 'inherit', '          ') + '        </unit>\n      </props>\n'
            + P('dataType', 'Inherit: Same as Simulink', '      ') + '    </data>\n')


def chart_xml(chart_id, c):
    data = ([(n, 'INPUT_DATA') for n in c['inputs']] + [(n, 'OUTPUT_DATA') for n in c['outputs']]
            + [(n, 'PARAMETER_DATA') for n in c['params']])
    x = ('<?xml version="1.0" encoding="utf-8"?>\n'
         f'<chart id="{chart_id}">\n'
         + P('name', c['path'], '  ') + P('screen', '[1 1 3600 1200 1.180555555555556]', '  ')
         + P('viewObj', chart_id, '  ') + P('ssIdHighWaterMark', 3 + len(data), '  ')
         + P('decomposition', 'CLUSTER_CHART', '  ') + P('type', 'EML_CHART', '  ')
         + P('chartFileNumber', c['file_number'], '  ') + P('disableImplicitCasting', 1, '  ')
         + '  <eml>\n' + P('name', c['fname']) + '  </eml>\n'
         '  <Children>\n'
         '    <state SSID="1">\n'
         + P('labelString', 'eML_blk_kernel()', '      ') + P('position', '[18 64.5 118 66]', '      ')
         + P('fontSize', 12, '      ') + P('superState', 'SUBCHART', '      ')
         + P('subviewer', chart_id, '      ') + P('type', 'FUNC_STATE', '      ')
         + P('decomposition', 'CLUSTER_STATE', '      ')
         + '      <eml>\n' + P('isEML', 1, '        ') + P('script', c['script'], '        ')
         + P('vectorOutputs1D', 1, '        ') + '      </eml>\n    </state>\n')
    for i, (name, scope) in enumerate(data):
        x += _data_xml(4 + i, name, scope)
    x += ('    <transition SSID="2">\n'
          + P('labelString', '{eML_blk_kernel();}', '      ')
          + P('labelPosition', '[28.125 13.875 102.544 14.964]', '      ') + P('fontSize', 12, '      ')
          + '      <src>\n' + P('intersection', '[0 0 1 0 23.5747 14.625 0 0]', '        ') + '      </src>\n'
          '      <dst>\n' + P('SSID', 3, '        ')
          + P('intersection', '[1 0 -1 0 23.5747 42.5747 0 0]', '        ') + '      </dst>\n'
          + P('midPoint', '[23.5747 24.9468]', '      ')
          + P('dataLimits', '[21.175 25.975 14.625 42.575]', '      ') + P('subviewer', chart_id, '      ')
          + P('drawStyle', 'SMART', '      ') + '      <slide>\n' + P('sticky', 'BOTH_STICK', '        ')
          + '      </slide>\n' + P('executionOrder', 1, '      ') + '    </transition>\n'
          '    <junction SSID="3">\n' + P('position', '[23.5747 49.5747 7]', '      ')
          + P('subviewer', chart_id, '      ') + P('type', 'CONNECTIVE_JUNCTION', '      ')
          + '    </junction>\n  </Children>\n</chart>\n')
    return x


def stateflow_parts(charts, machine_id=100):
    """machine.xml and the chart files. Ids as Simulink numbers them: the objects of a chart (state,
    transition, junction, data) take the ids after the chart id, the instance comes next, the next chart
    after it, the target last."""
    parts = {}
    ids = []
    next_id = machine_id + 1
    for c in charts.items:
        n_objects = 3 + len(c['inputs']) + len(c['outputs']) + len(c['params'])
        chart_id = next_id
        instance_id = chart_id + n_objects + 1
        next_id = instance_id + 1
        ids.append((chart_id, instance_id, c))
        parts[f'simulink/stateflow/chart_{chart_id}.xml'] = chart_xml(chart_id, c)
    target_id = next_id
    m = ('<?xml version="1.0" encoding="utf-8"?>\n<Stateflow>\n'
         f'  <machine id="{machine_id}">\n' + P('sfVersion', SF_VERSION) + '    <Children>\n'
         f'      <target id="{target_id}" name="sfun">\n'
         + P('description', 'Default Simulink S-Function Target.', '        ') + '      </target>\n')
    for chart_id, _, _ in ids:
        m += f'      <chart Ref="chart_{chart_id}"/>\n'
    m += '    </Children>\n  </machine>\n'
    for chart_id, instance_id, c in ids:
        m += (f'  <instance id="{instance_id}">\n' + P('machine', machine_id) + P('name', c['path'])
              + P('chart', chart_id) + '  </instance>\n')
    parts['simulink/stateflow/machine.xml'] = m + '</Stateflow>\n'
    rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n')
    for chart_id, _, _ in ids:
        rels += (f'  <Relationship Id="chart_{chart_id}" Target="chart_{chart_id}.xml" '
                 'Type="http://schemas.mathworks.com/simulinkModel/2018/relationships/stateflowMachine"/>\n')
    parts['simulink/stateflow/_rels/machine.xml.rels'] = rels + '</Relationships>\n'
    return parts


# ---------------------------------------------------------------------------- container
def library_base_mxarray(value='17F0F7'):
    """LibraryBase_bd: a 6-character MATLAB char array (same bytes as the libraries saved by Simulink)."""
    v = value.encode()
    body = (struct.pack('<II', 6, 8) + struct.pack('<II', 4, 0) + struct.pack('<II', 5, 8)
            + struct.pack('<II', 1, len(v)) + struct.pack('<II', 1, 0)
            + struct.pack('<II', 16, len(v)) + v + b'\x00'*((8 - len(v) % 8) % 8))
    return b'\x00\x01IM\x00\x00\x00\x00' + struct.pack('<II', 14, len(body)) + body


def tiny_png():
    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(b'\x00\x00\x00\x00\x00')) + chunk(b'IEND', b''))


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
SOLVER_LIBRARY = ('        <P Name="SolverName" Class="char">VariableStepAuto</P>\n'
                  '        <P Name="ODENIntegrationMethod" Class="char">ode3</P>\n')
SOLVER_TEST = ('        <P Name="StartTime" Class="char">0.0</P>\n'
               '        <P Name="StopTime" Class="char">tb.t_end</P>\n'
               '        <P Name="SolverType" Class="char">Fixed-step</P>\n'
               '        <P Name="SolverName" Class="char">FixedStepDiscrete</P>\n'
               '        <P Name="FixedStep" Class="char">tb.ts</P>\n'
               '        <P Name="SolverMode" Class="char">SingleTasking</P>\n')
DATAIO_TEST = ('        <P Name="SaveTime" Class="char">on</P>\n'
               '        <P Name="TimeSaveName" Class="char">tout</P>\n'
               '        <P Name="SaveOutput" Class="char">off</P>\n'
               '        <P Name="SaveFormat" Class="char">Dataset</P>\n'
               '        <P Name="SignalLogging" Class="char">off</P>\n'
               '        <P Name="ReturnWorkspaceOutputs" Class="char">on</P>\n'
               '        <P Name="ReturnWorkspaceOutputsName" Class="char">out</P>\n'
               '        <P Name="LimitDataPoints" Class="char">off</P>\n')
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
REL_SYSTEM = 'http://schemas.mathworks.com/simulink/2010/relationships/system'


def windows_info():
    return ('<?xml version="1.0" encoding="utf-8"?>\n<WindowsInfo>\n'
            '  <Object PropName="BdWindowsInfo" ObjectID="1" ClassName="Simulink.BDWindowsInfo">\n'
            '    <Object PropName="WindowsInfo" ObjectID="2" ClassName="Simulink.WindowInfo">\n'
            '      <P Name="IsActive" Class="logical">1</P>\n'
            '      <P Name="Location" Class="double">[100.0, 100.0, 1400.0, 800.0]</P>\n'
            '      <Array PropName="EditorsInfo" Type="Simulink.EditorInfo" Dimension="1*1">\n'
            '        <Object ObjectID="3">\n'
            '          <P Name="IsActive" Class="logical">1</P>\n'
            '          <P Name="IsTabbed" Class="logical">1</P>\n'
            '          <P Name="ViewObjType" Class="char">SimulinkTopLevel</P>\n'
            '          <P Name="LoadSaveID" Class="char">0</P>\n'
            '          <P Name="Extents" Class="double">[1300.0, 700.0]</P>\n'
            '          <P Name="ZoomFactor" Class="double">1.0</P>\n'
            '          <P Name="Offset" Class="double">[0.0, 0.0]</P>\n'
            '          <P Name="SceneRectInView" Class="double">[0.0, 0.0, 1300.0, 700.0]</P>\n'
            '        </Object>\n      </Array>\n'
            f'      <P Name="WindowUuid" Class="char">{new_uuid()}</P>\n    </Object>\n'
            f'    <P Name="BDUuid" Class="char">{new_uuid()}</P>\n  </Object>\n</WindowsInfo>\n')


def write_slx(path, root, charts, is_library, description=None):
    _uuid_seed[0] = os.path.basename(path)
    systems = {'root': root.xml(root=True, sid_high=root.sids.high)}
    for sid, s in root.all_systems():
        systems[str(sid)] = s.xml()
    sf = stateflow_parts(charts)
    if is_library:
        bd = ('<?xml version="1.0" encoding="utf-8"?>\n<ModelInformation Version="1.0">\n  <Library>\n'
              + P('ModelUUID', new_uuid()) + P('LibraryType', 'BlockLibrary')
              + '    <P Name="LibraryBase" Ref="bdmxdata:LibraryBase_bd"/>\n'
              + P('SLXCompressionType', 'None') + P('LastSavedArchitecture', 'win64')
              + '    <ConfigManagerSettings>\n' + P('ModifiedByFormat', '%<Auto>', '      ')
              + P('ModifiedDateFormat', '%<Auto>', '      ')
              + P('ModelVersionFormat', '%<AutoIncrement:1.0>', '      ') + '    </ConfigManagerSettings>\n'
              '    <EditorSettings>\n' + P('BrowserShowLibraryLinks', 'on', '      ')
              + P('BrowserLookUnderMasks', 'on', '      ') + '    </EditorSettings>\n'
              '    <SimulationSettings>\n' + P('SimulationMode', 'normal', '      ') + '    </SimulationSettings>\n'
              '    <EngineSettings>\n' + P('ConfigurableSubsystemUsage', 'warning', '      ')
              + '    </EngineSettings>\n    <System Ref="system_root"/>\n  </Library>\n</ModelInformation>\n')
        configset = CONFIGSET.replace('{SOLVER}', SOLVER_LIBRARY).replace('{DATAIO}', '')
    else:
        bd = ('<?xml version="1.0" encoding="utf-8"?>\n<ModelInformation Version="1.0">\n  <Model>\n'
              + P('ModelUUID', new_uuid()) + P('SLXCompressionType', 'None')
              + P('LastSavedArchitecture', 'win64')
              + (P('Description', description) if description else '')
              + '    <ConfigManagerSettings>\n' + P('ModifiedByFormat', '%<Auto>', '      ')
              + P('ModifiedDateFormat', '%<Auto>', '      ')
              + P('ModelVersionFormat', '%<AutoIncrement:1.0>', '      ') + '    </ConfigManagerSettings>\n'
              '    <EditorSettings>\n' + P('LibraryLinkDisplay', 'none', '      ')
              + P('WideLines', 'on', '      ') + P('ShowLineDimensions', 'on', '      ') + '    </EditorSettings>\n'
              '    <SimulationSettings>\n' + P('SimulationMode', 'normal', '      ')
              + P('SimTabSimulationMode', 'normal', '      ') + '    </SimulationSettings>\n'
              '    <EngineSettings>\n' + P('ConfigurableSubsystemUsage', 'warning', '      ')
              + '    </EngineSettings>\n    <System Ref="system_root"/>\n  </Model>\n</ModelInformation>\n')
        configset = CONFIGSET.replace('{SOLVER}', SOLVER_TEST).replace('{DATAIO}', DATAIO_TEST)

    def sys_key(k):
        return (k != 'root', int(k) if k != 'root' else 0)

    bd_rels = REL_HEAD
    if is_library:
        bd_rels += ('  <Relationship Id="LibraryBase_bd" Target="bdmxdata/LibraryBase_bd.mxarray" '
                    'Type="http://schemas.mathworks.com/simulinkModel/2015/relationships/modelMxArray"/>\n')
    bd_rels += ('  <Relationship Id="stateflow_machine" Target="stateflow/machine.xml" '
                'Type="http://schemas.mathworks.com/simulinkModel/2014/relationships/stateflowMachine"/>\n'
                f'  <Relationship Id="system_root" Target="systems/system_root.xml" Type="{REL_SYSTEM}"/>\n'
                '  <Relationship Id="windowsInfo" Target="windowsInfo.xml" '
                'Type="http://schemas.mathworks.com/simulinkModel/2019/relationships/windowsInfo"/>\n'
                '</Relationships>\n')
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
    for name in sorted(sf):
        if name.endswith('.xml') and 'chart_' in name:
            ctypes += f'  <Override ContentType="application/vnd.mathworks.stateflow.chart+xml" PartName="/{name}"/>\n'
    ctypes += '  <Override ContentType="application/vnd.mathworks.stateflow.machine+xml" PartName="/simulink/stateflow/machine.xml"/>\n'
    for key in sorted(systems, key=sys_key):
        ctypes += f'  <Override ContentType="application/vnd.mathworks.simulink.mdl+xml" PartName="/simulink/systems/system_{key}.xml"/>\n'
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
            f'  <cp:category>{"library" if is_library else "model"}</cp:category>\n'
            f'  <dcterms:created xsi:type="dcterms:W3CDTF">{FIXED_DATE}</dcterms:created>\n'
            '  <dc:creator>pwr-control</dc:creator>\n  <cp:lastModifiedBy>pwr-control</cp:lastModifiedBy>\n'
            f'  <dcterms:modified xsi:type="dcterms:W3CDTF">{FIXED_DATE}</dcterms:modified>\n'
            f'  <cp:revision>1.0</cp:revision>\n  <cp:version>{RELEASE}</cp:version>\n</cp:coreProperties>\n')
    mwcore = ('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n'
              '<mwcoreProperties xmlns="http://schemas.mathworks.com/package/2012/coreProperties">\n'
              '  <contentType>application/vnd.mathworks.simulink.model</contentType>\n'
              '  <contentTypeFriendlyName>Simulink Model</contentTypeFriendlyName>\n'
              f'  <matlabRelease>{RELEASE}</matlabRelease>\n</mwcoreProperties>\n')
    mwext = ('<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>\n'
             '<mwcoreProperties xmlns="http://schemas.mathworks.com/package/2014/corePropertiesExtension">\n'
             f'  <uuid>{new_uuid()}</uuid>\n</mwcoreProperties>\n')
    mwrel = ('<?xml version="1.0" encoding="UTF-8"?>\n'
             f'<!-- Version information for MathWorks {RELEASE} Release -->\n<MathWorks_version_info>\n'
             f'  <version>{RELEASE_VERSION}</version>\n  <release>{RELEASE}</release>\n'
             '  <description>Update 5</description>\n  <date>Aug 03 2026</date>\n'
             '  <checksum>3557022610</checksum>\n</MathWorks_version_info>\n')
    model_dict = ('<?xml version="1.0" encoding="UTF-8"?>\n'
                  '<MF0 version="1.1" defaultPackage="slid" packageUris="http://schema.mathworks.com/mf0/slid/R2025a_20251111">\n'
                  f'  <System type="System" uuid="{new_uuid()}">\n'
                  f'    <Interface type="Interface" uuid="{new_uuid()}"/>\n  </System>\n</MF0>\n')
    configset_info = ('<?xml version="1.0" encoding="utf-8"?>\n<ConfigSetInfo>\n'
                      '  <ConfigSet PartName="/simulink/configSet0.xml" Active="true">Configuration</ConfigSet>\n'
                      '</ConfigSetInfo>\n')
    configset_rels = (REL_HEAD + '  <Relationship Id="configSet0" Target="configSet0.xml" '
                      'Type="http://schemas.mathworks.com/simulink/2014/relationships/configSet"/>\n'
                      '</Relationships>\n')

    def rels_of(children):
        return REL_HEAD + ''.join(
            f'  <Relationship Id="system_{c}" Target="system_{c}.xml" Type="{REL_SYSTEM}"/>\n'
            for c in children) + '</Relationships>\n'

    stored = [('metadata/thumbnail.png', tiny_png())]
    for key in sorted(systems, key=sys_key):
        stored.append((f'simulink/systems/system_{key}.xml', systems[key].encode('utf-8')))
    for name in sorted(sf):
        if not name.endswith('.rels'):
            stored.append((name, sf[name].encode('utf-8')))
    if is_library:
        stored.append(('simulink/bdmxdata/LibraryBase_bd.mxarray', library_base_mxarray()))
    stored += [('simulink/bddefaults.xml', BDDEFAULTS.encode()), ('simulink/blockdiagram.xml', bd.encode()),
               ('simulink/configSet0.xml', configset.encode()),
               ('simulink/configSetInfo.xml', configset_info.encode()),
               ('simulink/modelDictionary.xml', model_dict.encode()),
               ('simulink/windowsInfo.xml', windows_info().encode())]
    deflated = [('[Content_Types].xml', ctypes.encode()), ('_rels/.rels', root_rels.encode()),
                ('simulink/_rels/blockdiagram.xml.rels', bd_rels.encode()),
                ('simulink/_rels/configSetInfo.xml.rels', configset_rels.encode()),
                ('simulink/stateflow/_rels/machine.xml.rels', sf['simulink/stateflow/_rels/machine.xml.rels'].encode())]
    if root.children:
        deflated.append(('simulink/systems/_rels/system_root.xml.rels', rels_of(root.children).encode()))
    for sid, s in root.all_systems():
        if s.children:
            deflated.append((f'simulink/systems/_rels/system_{sid}.xml.rels', rels_of(s.children).encode()))
    deflated += [('metadata/coreProperties.xml', core.encode()), ('metadata/mwcoreProperties.xml', mwcore.encode()),
                 ('metadata/mwcorePropertiesExtension.xml', mwext.encode()),
                 ('metadata/mwcorePropertiesReleaseInfo.xml', mwrel.encode())]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with zipfile.ZipFile(path, 'w') as z:
        for items, mode in ((stored, zipfile.ZIP_STORED), (deflated, zipfile.ZIP_DEFLATED)):
            for name, data in items:
                zi = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                zi.compress_type = mode
                zi.external_attr = 0
                z.writestr(zi, data)
    return path


# ---------------------------------------------------------------------------- the library
def block_height(nin, nout):
    return 30*max(nin, nout) + 30


def build_library():
    sids = SidPool()
    charts = Charts()
    root = System(sids, charts, location='[100, 100, 900, 800]')
    root_sids = [sids() for _ in BLOCKS]           # the five masked blocks take SIDs 1..5
    y = 40
    for spec, sid in zip(BLOCKS, root_sids):
        nin, nout = len(spec['inputs']), len(spec['outputs'])
        h = block_height(nin, nout)
        inner = System(sids, charts, location='[100, 100, 900, 600]')
        # Inports -> MATLAB Function -> Outports
        mh = 40*max(nin, nout)
        in_sids = [inner.inport(n, k + 1, f'[40, {60 + 40*k + mh//max(nin, nout)//2 - 7}, 70, {60 + 40*k + mh//max(nin, nout)//2 + 7}]')
                   for k, n in enumerate(spec['inputs'])]
        mlf = inner.mlf(spec['name'], f"{spec['name']}/{spec['name']}", f'[200, 60, 420, {60 + mh}]',
                        os.path.join(SRC, spec['src']), spec['inputs'], spec['outputs'], [MASK_PARAM[0]])
        out_sids = [inner.outport(n, k + 1, f'[520, {60 + 40*k + mh//max(nin, nout)//2 - 7}, 550, {60 + 40*k + mh//max(nin, nout)//2 + 7}]')
                    for k, n in enumerate(spec['outputs'])]
        for k, s in enumerate(in_sids):
            inner.sig(f'{s}#out:1', f'{mlf}#in:{k + 1}')
        for k, (n, s) in enumerate(zip(spec['outputs'], out_sids)):
            inner.sig(f'{mlf}#out:{k + 1}', f'{s}#in:1', name=n)
        root.subsystem(spec['name'], f'[100, {y}, 330, {y + h}]', nin, nout, inner, mask_xml(spec), sid=sid)
        y += h + 40
    return root, charts


# ---------------------------------------------------------------------------- the test bench
def build_test():
    sids = SidPool()
    charts = Charts()
    s = System(sids, charts, location='[40, 40, 1800, 900]')
    src, pl = TEST_MLF['source'], TEST_MLF['plant']

    clk = s.digital_clock('t', 'tb.ts', '[40, 190, 70, 210]')
    so = s.mlf(src['name'], src['name'], '[130, 60, 300, 340]', os.path.join(TEST, src['src']),
               src['inputs'], src['outputs'], src['params'])
    vseq = s.library_ref('grid_voltage_sequences', f'{LIB}/grid_voltage_sequences', 3, 3, '[420, 60, 640, 180]',
                         [('p', 'p')])
    frt = s.library_ref('frt_vde4110', f'{LIB}/frt_vde4110', 4, 4, '[760, 60, 980, 210]', [('p', 'p')])
    qc = s.library_ref('grid_current_sequences_q_ctrl', f'{LIB}/grid_current_sequences_q_ctrl', 4, 3,
                       '[1100, 60, 1320, 210]', [('p', 'p')])
    cc = s.library_ref('current_ctrl_uvw', f'{LIB}/current_ctrl_uvw', 4, 3, '[1440, 60, 1660, 210]',
                       [('p', 'p')])
    isl = s.library_ref('islanding_detector', f'{LIB}/islanding_detector', 4, 3, '[760, 420, 980, 540]',
                        [('p', 'p')])
    plant = s.mlf(pl['name'], pl['name'], '[1440, 300, 1660, 380]', os.path.join(TEST, pl['src']),
                  pl['inputs'], pl['outputs'], pl['params'])
    ud = s.unit_delay('is_delay', 'zeros(3, 1)', '[1520, 430, 1580, 470]', mirror=True)
    neg = s.gain('ig = -is', '-1', '[1180, 430, 1230, 470]', mirror=True)
    mux = s.mux('log', len(LOG), f'[1760, 60, 1765, {60 + 30*len(LOG)}]')
    tw = s.to_workspace('tb_log', 'tb_log', '[1820, 260, 1900, 290]')

    # ---- source: time in, seven signals out
    s.sig(f'{clk}#out:1', f'{so}#in:1', name='t')
    s.sig(f'{so}#out:1', [f'{vseq}#in:1', f'{plant}#in:2'], name='ug_abc')
    s.sig(f'{so}#out:2', [f'{vseq}#in:2', f'{qc}#in:2', f'{cc}#in:4', f'{isl}#in:2', f'{mux}#in:15'], name='theta')
    s.sig(f'{so}#out:3', [f'{vseq}#in:3', f'{qc}#in:3', f'{isl}#in:3', f'{mux}#in:16'], name='omega_pu')
    s.sig(f'{so}#out:4', [f'{frt}#in:3', f'{isl}#in:4'], name='enable')
    s.sig(f'{so}#out:5', f'{frt}#in:4', name='reset')
    s.sig(f'{so}#out:6', [f'{cc}#in:1', f'{mux}#in:17'], name='i_xi_ref')
    s.sig(f'{so}#out:7', f'{frt}#in:2', name='i_react_ref')
    # ---- the chain of the model
    s.sig(f'{vseq}#out:1', [f'{frt}#in:1', f'{mux}#in:1'], name='v_seq_avg')
    s.sig(f'{vseq}#out:3', f'{isl}#in:1', name='ug_ab')
    s.sig(f'{frt}#out:1', [f'{qc}#in:4', f'{mux}#in:2'], name='i_grid_ref')
    s.sig(f'{frt}#out:2', f'{mux}#in:3', name='frt_active')
    s.sig(f'{frt}#out:3', f'{mux}#in:4', name='pwr_lim_enable')
    s.sig(f'{frt}#out:4', f'{mux}#in:5', name='frt_log')
    s.sig(f'{qc}#out:1', [f'{cc}#in:2', f'{mux}#in:6'], name='i_stack_ref')
    s.sig(f'{qc}#out:2', f'{mux}#in:7', name='i_seq_avg')
    s.sig(f'{cc}#out:1', [f'{plant}#in:1', f'{mux}#in:8'], name='u_abg')
    s.sig(f'{cc}#out:2', f'{mux}#in:9', name='i_abc_ref')
    s.sig(f'{cc}#out:3', f'{mux}#in:10', name='is_xe')
    # ---- plant -> Unit Delay -> stack current measurement, grid current = -stack current
    s.sig(f'{plant}#out:1', f'{ud}#in:1')
    s.sig(f'{ud}#out:1', [f'{cc}#in:3', f'{neg}#in:1', f'{mux}#in:11'], name='is_abc')
    s.sig(f'{neg}#out:1', f'{qc}#in:1', name='ig_abc')
    # ---- islanding detector and log
    s.sig(f'{isl}#out:1', f'{mux}#in:12', name='island')
    s.sig(f'{isl}#out:2', f'{mux}#in:13', name='crit')
    s.sig(f'{isl}#out:3', f'{mux}#in:14', name='idet_log')
    s.sig(f'{mux}#out:1', f'{tw}#in:1')
    # unused outputs of the library blocks: v_seq, i_seq -> terminators
    for blk, port, nm in ((vseq, 2, 'v_seq'), (qc, 3, 'i_seq')):
        t_sid = sids()
        s.add(f'  <Block BlockType="Terminator" Name="{nm}_end" SID="{t_sid}">\n'
              + P('Position', f'[{700 if blk == vseq else 1380}, {170 if blk == vseq else 200}, '
                  f'{720 if blk == vseq else 1400}, {188 if blk == vseq else 218}]')
              + P('ZOrder', s.z()) + '  </Block>\n', t_sid)
        s.sig(f'{blk}#out:{port}', f'{t_sid}#in:1', name=nm)
    return s, charts


TEST_DESCRIPTION = (
    'Test bench of library/masked_models/afe_uvw_ctrl: the five blocks (grid_voltage_sequences, frt_vde4110, '
    'grid_current_sequences_q_ctrl, current_ctrl_uvw, islanding_detector) in the chain of the model '
    'afe_uvw_three_phase, fed by the MATLAB Function test_source (grid voltage with a dip and a frequency '
    'ramp, PLL angle, references; afe_uvw_ctrl_test_source.m) and closed on the MATLAB Function rl_plant '
    '(three RL branches, afe_uvw_ctrl_test_plant.m) through a Unit Delay; grid current = -stack current. '
    'Fixed-step discrete, step tb.ts. Variables p and tb from afe_uvw_ctrl_test_param.m; run and check with '
    'afe_uvw_ctrl_test_run.m (it also compares the model with the same functions called in a MATLAB loop). '
    'Generated by tools/make_afe_uvw_ctrl.py.')


# ---------------------------------------------------------------------------- checks
def P_of(el, name):
    e = el.find(f"P[@Name='{name}']")
    return None if e is None else (e.text or '')


class Slx:
    def __init__(self, path):
        self.z = zipfile.ZipFile(path)
        self.names = set(self.z.namelist())
        self.systems = {}
        for n in self.names:
            m = re.match(r'simulink/systems/system_(\w+)\.xml$', n)
            if m:
                self.systems['system_' + m.group(1)] = ET.fromstring(self.z.read(n))

    def read(self, name):
        return self.z.read(name).decode('utf-8')

    def blocks(self, sysname):
        return self.systems[sysname].findall('Block')


DEFAULT_PORTS = {'Inport': (0, 1), 'Outport': (1, 0), 'Terminator': (1, 0), 'DigitalClock': (0, 1),
                 'UnitDelay': (1, 1), 'Gain': (1, 1), 'ToWorkspace': (1, 0)}


def check_file(path, is_library, src_dirs, lib_ports=None):
    """Structure of the written file; returns the list of errors (empty when all is well)."""
    slx = Slx(path)
    errors = []
    err = errors.append
    names = slx.names
    # content types and relationships
    ct = ET.fromstring(slx.read('[Content_Types].xml'))
    ns = {'c': 'http://schemas.openxmlformats.org/package/2006/content-types'}
    overrides = {o.get('PartName').lstrip('/') for o in ct.findall('c:Override', ns)}
    defaults = {d.get('Extension') for d in ct.findall('c:Default', ns)}
    for o in overrides:
        if o not in names:
            err(f'content type for a missing part: {o}')
    for n in names:
        ext = n.rsplit('.', 1)[-1]
        if n != '[Content_Types].xml' and n not in overrides and ext not in defaults:
            err(f'part without content type: {n}')
        if n.startswith(('simulink/systems/system_', 'simulink/stateflow/chart_')) and n.endswith('.xml') \
                and n not in overrides:
            err(f'system or chart part without its override: {n}')
        if n.endswith(('.xml', '.rels')):
            try:
                el = ET.fromstring(slx.read(n))
            except ET.ParseError as e:
                err(f'{n}: {e}')
                continue
            if n.endswith('.rels'):
                folder = posixpath.dirname(posixpath.dirname(n))
                for r in el:
                    target = posixpath.normpath(posixpath.join(folder, r.get('Target')))
                    if target not in names:
                        err(f'{n}: relationship to a missing part {target}')
    # SIDs, ports, lines
    sid_seen = {}
    paths = {}                                       # block path -> element, for the MATLAB Functions
    for sysname, s in slx.systems.items():
        ports = {}
        for b in s.findall('Block'):
            sid = b.get('SID')
            if sid in sid_seen:
                err(f'duplicate SID {sid} in {sysname} and {sid_seen[sid]}')
            sid_seen[sid] = sysname
            pc = b.find('PortCounts')
            if pc is not None:
                ports[sid] = (int(pc.get('in', 0)), int(pc.get('out', 0)))
            else:
                ports[sid] = DEFAULT_PORTS.get(b.get('BlockType'), (0, 0))
            ref = b.find('System')
            if ref is not None and ref.get('Ref') not in slx.systems:
                err(f'{sysname}: block {b.get("Name")} refers to the missing {ref.get("Ref")}')
        driven = collections.Counter()
        used = set()
        for ln in s.findall('Line'):
            src = P_of(ln, 'Src')
            dsts = [P_of(ln, 'Dst')] if P_of(ln, 'Dst') else [P_of(br, 'Dst') for br in ln.findall('Branch')]
            for ref, kind in [(src, 1)] + [(d, 0) for d in dsts]:
                sid, port = ref.split('#')
                port = int(port.split(':')[1])
                if sid not in ports:
                    err(f'{sysname}: line to a missing block {sid}')
                elif not 1 <= port <= ports[sid][kind]:
                    err(f'{sysname}: port {port} out of range on block {sid}')
                if kind == 0:
                    driven[(sid, port)] += 1
                else:
                    used.add((sid, port))
        free = is_library and sysname == 'system_root'          # library root: blocks stand alone
        for sid, (nin, nout) in ports.items():
            for k in range(1, nin + 1):
                if driven[(sid, k)] != 1 and not free:
                    err(f'{sysname}: input {k} of block {sid} driven {driven[(sid, k)]} times')
            for k in range(1, nout + 1):
                if (sid, k) not in used and not free:
                    err(f'{sysname}: output {k} of block {sid} not connected')
        # port blocks in the order of their numbers
        for kind in ('Inport', 'Outport'):
            nums = [int(P_of(b, 'Port') or 1) for b in s.findall('Block') if b.get('BlockType') == kind]
            if nums != list(range(1, len(nums) + 1)):
                err(f'{sysname}: {kind} blocks not in port order {nums}')
        high = P_of(s, 'SIDHighWatermark')
        if high is not None and ports:
            local = [int(x.rsplit(':', 1)[-1]) for x in ports]
            if int(high) < max(local):
                err(f'{sysname}: SIDHighWatermark {high} < {max(local)}')

    # MATLAB Function blocks <-> charts <-> sources
    def walk(sysname, prefix):
        for b in slx.blocks(sysname):
            path = prefix + b.get('Name')
            paths[path] = (b, sysname)
            ref = b.find('System')
            if ref is not None and P_of(b, 'SFBlockType') != 'MATLAB Function':
                walk(ref.get('Ref'), path + '/')
    walk('system_root', '')
    machine = ET.fromstring(slx.read('simulink/stateflow/machine.xml'))
    instances = {P_of(i, 'name'): (int(i.get('id')), int(P_of(i, 'chart'))) for i in machine.findall('instance')}
    charts = {}
    for n in names:
        if re.match(r'simulink/stateflow/chart_\d+\.xml$', n):
            c = ET.fromstring(slx.read(n))
            charts[int(c.get('id'))] = c
    mlfs = {p: b for p, (b, _) in paths.items() if P_of(b, 'SFBlockType') == 'MATLAB Function'}
    if set(mlfs) != set(instances):
        err(f'MATLAB Function blocks {sorted(mlfs)} != Stateflow instances {sorted(instances)}')
    n_mlf = 0
    for path, b in mlfs.items():
        n_mlf += 1
        msys = b.find('System').get('Ref')
        sfun = [x for x in slx.blocks(msys) if x.get('BlockType') == 'S-Function'][0]
        num = P_of(sfun, 'Tag').split()[-1]
        chart = next((c for c in charts.values() if P_of(c, 'chartFileNumber') == num), None)
        if chart is None:
            err(f'{path}: no chart with chartFileNumber {num}')
            continue
        if P_of(chart, 'name') != path:
            err(f'chart name {P_of(chart, "name")} != block path {path}')
        if path in instances and instances[path][1] != int(chart.get('id')):
            err(f'instance of {path} does not point to chart {chart.get("id")}')
        data = collections.defaultdict(list)
        for d in chart.find('Children').findall('data'):
            data[P_of(d, 'scope')].append(d.get('name'))
        ins = [n for _, n in sorted((int(P_of(x, 'Port') or 1), x.get('Name')) for x in slx.blocks(msys)
                                    if x.get('BlockType') == 'Inport')]
        outs = [n for _, n in sorted((int(P_of(x, 'Port') or 1), x.get('Name')) for x in slx.blocks(msys)
                                     if x.get('BlockType') == 'Outport')]
        if ins != data['INPUT_DATA']:
            err(f'{path}: chart inputs {data["INPUT_DATA"]} != Inports {ins}')
        if outs != data['OUTPUT_DATA']:
            err(f'{path}: chart outputs {data["OUTPUT_DATA"]} != Outports {outs}')
        if P_of(sfun, 'PortCounts') != f'[{len(ins)} {len(outs) + 1}]':
            err(f'{path}: S-function PortCounts {P_of(sfun, "PortCounts")}')
        pc = b.find('PortCounts')
        if (int(pc.get('in', 0)), int(pc.get('out', 0))) != (len(ins), len(outs)):
            err(f'{path}: PortCounts of the block do not match its ports')
        want = ','.join(sorted(data['PARAMETER_DATA']))
        if (P_of(sfun, 'Parameters') or '') != want:
            err(f'{path}: S-function Parameters {P_of(sfun, "Parameters")!r} != {want!r}')
        script = chart.find('.//eml/P[@Name="script"]').text
        fname = P_of(chart.find('eml'), 'name')
        src_file = next((os.path.join(d, fname + '.m') for d in src_dirs
                         if os.path.exists(os.path.join(d, fname + '.m'))), None)
        if src_file is None:
            err(f'{path}: source {fname}.m not found')
        else:
            with open(src_file, encoding='utf-8') as fh:
                if fh.read().replace('\r\n', '\n') != script:
                    err(f'{path}: the script in the .slx differs from {os.path.relpath(src_file, PKG)}')
            sig = re.search(r'^function\s*\[?(.*?)\]?\s*=\s*(\w+)\s*\((.*?)\)', script, re.S | re.M)
            args = [a.strip() for a in sig.group(3).replace('...', ' ').split(',')]
            if args != data['INPUT_DATA'] + data['PARAMETER_DATA']:
                err(f'{path}: function arguments {args} != inputs + parameters')
        # the mask parameter of the enclosing block is the parameter of the chart (library)
        if is_library:
            parent = paths[path.split('/')[0]][0]
            mask_names = [m.get('Name') for m in parent.findall('Mask/MaskParameter')]
            if data['PARAMETER_DATA'] != mask_names:
                err(f'{path}: chart parameters {data["PARAMETER_DATA"]} != mask parameters {mask_names}')
    # Stateflow ids
    ids = [int(machine.find('machine').get('id'))]
    expected_next = ids[0] + 1
    for cid in sorted(charts):
        chart = charts[cid]
        objs = [o for o in chart.find('Children') if o.get('SSID')]
        if cid != expected_next:
            err(f'chart id {cid}: expected {expected_next} (previous instance + 1)')
        iid = next((i for i, (ii, cc) in instances.items() if cc == cid), None)
        iid = instances[iid][0] if iid is not None else None
        if iid != cid + len(objs) + 1:
            err(f'chart {cid}: instance id {iid} != chart id + {len(objs)} objects + 1')
        if cid <= max(int(o.get('SSID')) for o in objs):
            err(f'chart id {cid} not above the SSIDs of its objects')
        ids += [cid] + list(range(cid + 1, cid + len(objs) + 1)) + [iid]
        expected_next = (iid or cid) + 1
    for t in machine.iter('target'):
        if int(t.get('id')) < expected_next:
            err(f'target id {t.get("id")} before the last instance')
        ids.append(int(t.get('id')))
    if len(set(ids)) != len(ids):
        err(f'Stateflow ids not unique: {sorted(ids)}')
    # library: the five masked blocks; test: the references and their ports
    root_blocks = slx.blocks('system_root')
    if is_library:
        if [b.get('Name') for b in root_blocks] != [s['name'] for s in BLOCKS]:
            err('root blocks of the library are not the five blocks')
        for b in root_blocks:
            if b.find('Mask') is None or [m.get('Name') for m in b.findall('Mask/MaskParameter')] != [MASK_PARAM[0]]:
                err(f'{b.get("Name")}: mask with the parameter {MASK_PARAM[0]} expected')
            if not (b.findtext('Mask/Help') or '').startswith('web('):
                err(f'{b.get("Name")}: no Help')
    else:
        for b in root_blocks:
            if b.get('BlockType') == 'Reference':
                lib, blk = P_of(b, 'SourceBlock').split('/')
                pc = b.find('PortCounts')
                if lib != LIB or blk not in lib_ports:
                    err(f'{b.get("Name")}: unknown source block {P_of(b, "SourceBlock")}')
                elif (int(pc.get('in', 0)), int(pc.get('out', 0))) != lib_ports[blk]:
                    err(f'{b.get("Name")}: PortCounts differ from the library block {blk}')
        mux = [b for b in root_blocks if b.get('BlockType') == 'Mux'][0]
        if int(P_of(mux, 'Inputs')) != len(LOG):
            err('Mux of the log has not the right number of inputs')
    return errors, n_mlf


def main():
    check_only = '--check' in sys.argv[1:]
    if not check_only:
        root, charts = build_library()
        write_slx(LIB_PATH, root, charts, is_library=True)
        print('written', os.path.relpath(LIB_PATH, PKG))
        root, charts = build_test()
        write_slx(TEST_PATH, root, charts, is_library=False, description=TEST_DESCRIPTION)
        print('written', os.path.relpath(TEST_PATH, PKG))
    ok = True
    for path, is_lib in ((LIB_PATH, True), (TEST_PATH, False)):
        errors, n_mlf = check_file(path, is_lib, [SRC, TEST], LIB_PORTS)
        print(f'{os.path.relpath(path, PKG)}: {n_mlf} MATLAB Function blocks, {len(errors)} errors'
              + ('' if is_lib else '') )
        for e in errors:
            print('   ', e)
        ok &= not errors
    if ok:
        print('all checks passed; non-virtual blocks per library block: 2 (atomic subsystem + S-function)')
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
