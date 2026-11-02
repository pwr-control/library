#!/usr/bin/env python3
"""Make the library pmsm_inverter_dqctrl.slx (block pmsm_inverter_dqctrl_mod1) without MATLAB.

  grid_forming/grid_forming_dqctrl.slx  ->  pmsm_inverter/pmsm_inverter_dqctrl.slx

The PMSM inverter is the grid-forming AFE block with a new control: the power stage is the same Simscape
component afe_ssc.afe_two_level_lcl (ideal two-level bridge, DC-link capacitor, output filter; the L filter
is the LCL filter with a very high Rcf and a small L2), the MATLAB Function holds the field-oriented control
of private/pmsm_dq_ctrl_pwm.m. The source library is copied part by part and these parts are changed:

  system_root  top block pmsm_inverter_dqctrl_mod1: 3 inputs (t_master, ref, enc), 2 outputs (m, ctrl_log),
               DC ports Udc(+)/Udc(-) on the LEFT and the machine ports u/v/w on the RIGHT (DC link on the
               left, machine on the right, as an inverter is drawn), new mask texts
  system_1     input sync and output sync_out removed; inputs ref and enc, each through a Unit Delay of
               p.pwm.tc (ref_delay, enc_delay: no algebraic loop when ref or enc come from the Simscape
               network, e.g. the encoder angle of the machine); MATLAB Function pmsm_dq_ctrl_pwm with 4 inputs
               and 2 outputs; PMIOPorts ug_a/b/c renamed u/v/w; power stage, gates, measurements and
               meas_delay unchanged (same SIDs, so the binary parts of the PMIOPorts and of the power stage
               stay valid)
  system_3     contents of the MATLAB Function: inputs M, t_master, ref, enc, outputs G, ctrl_log
  chart_12     Stateflow chart of the MATLAB Function: the script is private/pmsm_dq_ctrl_pwm.m, data
               M, t_master, ref ([2 1]), enc, p (parameter: the mask parameter), G, ctrl_log; same chart id,
               object count and therefore the same ids in machine.xml (the Stateflow id rule, see
               verify_stateflow)
  metadata     new ModelUUID, version 1.0

Run (python3, any folder) to make the library again from grid_forming_dqctrl.slx and the source of the
control; the checks at the end must all pass:

    python3 make_pmsm_inverter_dqctrl.py

A change of the control code alone does not need this script: in MATLAB, update_pmsm_inverter_dqctrl.m loads
private/pmsm_dq_ctrl_pwm.m into the block. This script overwrites what was changed in MATLAB (mask, layout).

Rev. 00, 2026-11-02.
"""
import html
import io
import json
import os
import re
import sys
import uuid
import zipfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)                                    # library/masked_models/pmsm_inverter
MASKED = os.path.dirname(FOLDER)                                  # library/masked_models
SRC = os.path.join(MASKED, 'grid_forming', 'grid_forming_dqctrl.slx')
DST = os.path.join(FOLDER, 'pmsm_inverter_dqctrl.slx')
CODE = os.path.join(FOLDER, 'private', 'pmsm_dq_ctrl_pwm.m')

TOP_OLD, TOP_NEW = 'grid_forming_dqctrl_mod1', 'pmsm_inverter_dqctrl_mod1'
MLF_OLD, MLF_NEW = 'afe_dq_forming_ctrl_pwm', 'pmsm_dq_ctrl_pwm'
FNAME = 'pmsm_dq_ctrl_pwm'                    # function name in the source file
INPUTS = ['M', 't_master', 'ref', 'enc']      # port inputs of the function, in this order
OUTPUTS = ['G', 'ctrl_log']
PARAMS = ['p']                                # mask parameter, scope Parameter (after the port inputs)
SIZES = {'ref': '[2 1]'}                      # fixed sizes (a grounded ref is 2x1 too); others inherited
NLOG = 44                                     # size of ctrl_log (NLOG in the source)

GITHUB_README = ('https://github.com/pwr-control/library/blob/dev/library/masked_models/'
                 'pmsm_inverter/README.md')
MASK_TYPE = 'PMSM inverter (two-level bridge, L or LC output filter, field-oriented control)'
MASK_PROMPT = 'Parameter struct p (see pmsm_inverter_param_example.m)'
MASK_VALUE = 'param.inv_mod(1)'
DESCRIPTION = (
    'Inverter of a permanent magnet synchronous machine (PMSM) in one block; the machine is NOT in the block, '
    'it is connected to u, v, w. Power stage: the Simscape component afe_ssc.afe_two_level_lcl (ideal '
    'two-level bridge, DC-link capacitor, LCL filter), the same as grid_forming_dqctrl. L filter (normal '
    'case): p.hw.Rcf very high (1e5 Ohm) switches the capacitor branch off, L2 is only a small leakage '
    '(p.hw.L2p = 0, p.hw.Lls2 = 1 uH); LC filter: p.hw.Cf, p.hw.Rcf. Control and PWM: one MATLAB Function '
    '(pmsm_dq_ctrl_pwm, source private/pmsm_dq_ctrl_pwm.m of this folder, loaded by '
    'update_pmsm_inverter_dqctrl.m): field-oriented control with MTPA and current limit, p.ctrl.mode = 0 '
    'torque reference, 1 speed control, 2 torque curve of the speed (generator), angle and speed from the '
    'encoder (p.ctrl.angle_src = 0), from a back-EMF (active flux) observer (1) or from an extended Kalman '
    'filter (2), SVPWM with dead-time compensation, same clock, carrier and gates as grid_forming_dqctrl. '
    'Measurements, ref and enc go to the control through Unit Delays of one tc (no algebraic loop). '
    'Ports: Udc(+)/Udc(-) left, u/v/w right (to the machine); inputs t_master [s], ref = [enable; reference] '
    '(enable > 0.5: bridge on; reference: torque [pu], speed [pu] or scale of the torque curve) and enc = '
    'electrical rotor angle [rad] (d axis from phase u; ground it without encoder); outputs m (17x1 pu of '
    'afe_ssc.afe_two_level_lcl, bases p.hw.ubez/ibez = bases of the machine) and ctrl_log (%dx1, indices in '
    'pmsm_inverter_log_index.m). Parameter p: struct with the fields hw, pwm, ctrl, e.g. '
    'pmsm_inverter_param_example.m of this folder (one 267 kW system of the wind generator of inv_psm). '
    'Made by tools/make_pmsm_inverter_dqctrl.py from grid_forming_dqctrl.slx. User guide: Help of this block '
    '(README.md of the folder).' % NLOG)
HELP = "web('%s', '-browser')" % GITHUB_README

# ports of the masked block: (name, side or signal direction, port number)
LCONN = ['Udc(+)', 'Udc(-)']
RCONN = ['u', 'v', 'w']
SIG_IN = ['t_master', 'ref', 'enc']
SIG_OUT = ['m', 'ctrl_log']

# SIDs of system_1 (template SIDs kept; 15 sync and 16 sync_out removed; 17..20 new)
SID = dict(t_master=2, mlf=3, gates=4, meas=5, meas_delay=6, power_stage=7, u=8, v=9, w=10,
           udc_p=11, udc_n=12, m=13, ctrl_log=14, ref=17, enc=18, ref_delay=19, enc_delay=20)
SID_HIGH = 20
# SIDs of system_3 (inside the MATLAB Function)
SID3 = dict(M='3::1', t_master='3::28', ref='3::31', enc='3::33', G='3::5', ctrl_log='3::30',
            sfun='3::25', demux='3::26', term='3::27')
SID3_HIGH = 33


def esc(text):
    return html.escape(text, quote=False).replace('"', '&quot;').replace("'", '&apos;')


def xml_text(s):
    return html.escape(s, quote=False)


def P(name, value, ind='    '):
    return '%s<P Name="%s">%s</P>\n' % (ind, name, esc(str(value)))


# ====================================================================== source of the control
def read_code():
    code = open(CODE, encoding='utf-8').read().replace('\r\n', '\n')
    sig = re.search(r'^function\s*\[(.*?)\]\s*=\s*(\w+)\s*\((.*?)\)', code, re.S | re.M)
    outs = [o for o in re.split(r'[\s,]+', sig.group(1).replace('...', ' ')) if o]
    ins = [i.strip() for i in sig.group(3).replace('...', ' ').split(',')]
    assert sig.group(2) == FNAME, 'function name %s' % sig.group(2)
    assert outs == OUTPUTS, 'outputs %s' % outs
    assert ins == INPUTS + PARAMS, 'inputs %s' % ins
    n = re.search(r'^NLOG\s*=\s*(\d+);', code, re.M)
    assert n and int(n.group(1)) == NLOG, 'NLOG of the source is not %d' % NLOG
    return code


# ====================================================================== system_root
def make_root(root):
    blk = re.search(r'<Block BlockType="SubSystem" Name="%s" SID="1">.*?</Block>' % TOP_OLD, root, re.S)
    assert blk, 'top block not found'
    b = blk.group(0).replace('Name="%s"' % TOP_OLD, 'Name="%s"' % TOP_NEW)
    b, n = re.subn(r'<PortCounts [^>]*/>', '<PortCounts in="%d" out="%d" lconn="%d" rconn="%d"/>'
                   % (len(SIG_IN), len(SIG_OUT), len(LCONN), len(RCONN)), b)
    assert n == 1
    labels = ([("LConn", k + 1, s) for k, s in enumerate(LCONN)] + [("RConn", k + 1, s) for k, s in enumerate(RCONN)]
              + [("input", k + 1, s) for k, s in enumerate(SIG_IN)] + [("output", k + 1, s) for k, s in enumerate(SIG_OUT)])
    display = '\n'.join("port_label('%s', %d, '%s');" % l for l in labels)
    subs = [(r'<Type>[^<]*</Type>', '<Type>%s</Type>' % esc(MASK_TYPE)),
            (r'<Display>.*?</Display>', '<Display>%s</Display>' % esc(display)),
            (r'<Description>.*?</Description>', '<Description>%s</Description>' % esc(DESCRIPTION)),
            (r'<Help>.*?</Help>', '<Help>%s</Help>' % esc(HELP)),
            (r'(<MaskParameter Name="p" Type="edit">\s*<Prompt>)[^<]*(</Prompt>\s*<Value>)[^<]*(</Value>)',
             r'\g<1>%s\g<2>%s\g<3>' % (esc(MASK_PROMPT), esc(MASK_VALUE))),
            (r'(<DialogControl Type="Edit" Name="p">\s*<Prompt>)[^<]*(</Prompt>)', r'\g<1>%s\g<2>' % esc(MASK_PROMPT))]
    for pat, rep in subs:
        b, n = re.subn(pat, lambda m, rep=rep, pat=pat: m.expand(rep) if '\\g<' in rep else rep, b, flags=re.S)
        assert n == 1, 'mask: %s not found once' % pat
    root = root[:blk.start()] + b + root[blk.end():]
    root, n = re.subn(r'<P Name="SIDHighWatermark">\d+</P>', '<P Name="SIDHighWatermark">%d</P>' % SID_HIGH, root)
    assert n == 1
    return root


# ====================================================================== system_1
def blocks_of(system_xml):
    """Top-level blocks of a system part: {SID: xml} (system parts hold no nested blocks)."""
    out = {}
    for m in re.finditer(r'  <Block BlockType="[^"]+" Name="[^"]*" SID="(\d+)">.*?\n  </Block>\n', system_xml, re.S):
        out[int(m.group(1))] = m.group(0)
    return out


def set_p(block, name, value):
    """Set (or add after ZOrder) the parameter name of a block XML."""
    if '<P Name="%s">' % name in block:
        return re.sub(r'<P Name="%s">[^<]*</P>' % re.escape(name), '<P Name="%s">%s</P>' % (name, esc(value)), block)
    return re.sub(r'(    <P Name="ZOrder">[^<]*</P>\n)', lambda m: m.group(1) + P(name, value), block, count=1)


def drop_p(block, name):
    return re.sub(r'    <P Name="%s">[^<]*</P>\n' % re.escape(name), '', block)


def pmio(block, name, port, side):
    b = re.sub(r'Name="[^"]*" SID=', 'Name="%s" SID=' % esc(name), block, count=1)
    b = drop_p(b, 'Port')
    if port != 1:
        b = re.sub(r'(    <P Name="LibrarySourceProduct"[^\n]*\n)', lambda m: m.group(1) + P('Port', port), b)
    b = re.sub(r'<P Name="Side">\w+</P>', '<P Name="Side">%s</P>' % side, b)
    return b


def inport(name, sid, port, pos, zorder):
    return ('  <Block BlockType="Inport" Name="%s" SID="%d">\n' % (esc(name), sid) + P('Position', pos)
            + P('ZOrder', zorder) + (P('Port', port) if port != 1 else '') + '  </Block>\n')


def unit_delay(name, sid, pos, zorder):
    return ('  <Block BlockType="UnitDelay" Name="%s" SID="%d">\n' % (name, sid) + P('Position', pos)
            + P('ZOrder', zorder) + P('SampleTime', 'p.pwm.tc') + '  </Block>\n')


def line(z, src, dst, points=None, conn=False):
    x = '  <Line%s>\n' % (' LineType="Connection"' if conn else '') + P('ZOrder', z) + P('Src', src)
    if points:
        x += P('Points', points)
    return x + P('Dst', dst) + '  </Line>\n'


def make_system_1(s1):
    blocks = blocks_of(s1)
    assert sorted(blocks) == list(range(2, 17)), 'blocks of system_1: %s' % sorted(blocks)
    b = {}
    b['t_master'] = set_p(blocks[2], 'Position', '[-105, 436, -75, 450]')
    mlf = blocks[3].replace('Name="%s"' % MLF_OLD, 'Name="%s"' % MLF_NEW)
    mlf = mlf.replace('<PortCounts in="3" out="3"/>', '<PortCounts in="4" out="2"/>')
    mlf = set_p(mlf, 'Position', '[-10, 371, 150, 563]')
    pp = re.search(r'    <PortProperties>.*?</PortProperties>\n', mlf, re.S)
    mlf = mlf[:pp.start()] + ('    <PortProperties>\n' + ''.join(
        '      <Port Type="out" Index="%d">\n        <P Name="PropagatedSignals">%s</P>\n      </Port>\n' % (k + 1, o)
        for k, o in enumerate(OUTPUTS)) + '    </PortProperties>\n') + mlf[pp.end():]
    b['mlf'] = mlf
    b['gates'] = set_p(blocks[4], 'Position', '[215, 404, 245, 434]')
    b['meas'] = blocks[5]
    b['meas_delay'] = blocks[6]
    b['power_stage'] = blocks[7]
    # physical ports: DC link on the left of the masked block, machine on the right (port numbers: left first)
    b['u'] = pmio(blocks[8], 'u', 3, 'Right')
    b['v'] = pmio(blocks[9], 'v', 4, 'Right')
    b['w'] = pmio(blocks[10], 'w', 5, 'Right')
    b['udc_p'] = pmio(blocks[11], 'Udc(+)', 1, 'Left')
    b['udc_n'] = pmio(blocks[12], 'Udc(-)', 2, 'Left')
    b['m'] = blocks[13]
    b['ctrl_log'] = set_p(blocks[14], 'Position', '[390, 508, 420, 522]')
    b['ref'] = inport('ref', SID['ref'], 2, '[-195, 484, -165, 498]', 21)
    b['enc'] = inport('enc', SID['enc'], 3, '[-195, 532, -165, 546]', 22)
    b['ref_delay'] = unit_delay('ref_delay', SID['ref_delay'], '[-105, 476, -75, 506]', 23)
    b['enc_delay'] = unit_delay('enc_delay', SID['enc_delay'], '[-105, 524, -75, 554]', 24)
    order = ['t_master', 'ref', 'enc', 'ref_delay', 'enc_delay', 'mlf', 'gates', 'meas', 'meas_delay',
             'power_stage', 'u', 'v', 'w', 'udc_p', 'udc_n', 'm', 'ctrl_log']
    S = SID
    lines = [line(1, '%d#out:1' % S['t_master'], '%d#in:2' % S['mlf']),
             ('  <Line>\n' + P('ZOrder', 2) + P('Src', '%d#out:1' % S['meas']) + P('Points', '[26, 0]')
              + '    <Branch>\n' + P('ZOrder', 17, '      ') + P('Dst', '%d#in:1' % S['m'], '      ') + '    </Branch>\n'
              + '    <Branch>\n' + P('ZOrder', 3, '      ') + P('Points', '[0, 111; -735, 0; 0, 89]', '      ')
              + P('Dst', '%d#in:1' % S['meas_delay'], '      ') + '    </Branch>\n  </Line>\n'),
             line(5, '%d#out:1' % S['meas_delay'], '%d#in:1' % S['mlf']),
             line(6, '%d#out:1' % S['mlf'], '%d#in:1' % S['gates']),
             line(7, '%d#out:2' % S['mlf'], '%d#in:1' % S['ctrl_log']),
             line(8, '%d#rconn:1' % S['gates'], '%d#lconn:4' % S['power_stage'], '[20, 0; 0, -216]', conn=True),
             line(9, '%d#rconn:3' % S['power_stage'], '%d#lconn:1' % S['meas'], conn=True),
             line(10, '%d#rconn:1' % S['u'], '%d#lconn:1' % S['power_stage'], conn=True),
             line(11, '%d#rconn:1' % S['v'], '%d#lconn:2' % S['power_stage'], conn=True),
             line(12, '%d#rconn:1' % S['w'], '%d#lconn:3' % S['power_stage'], conn=True),
             line(13, '%d#rconn:1' % S['udc_p'], '%d#rconn:1' % S['power_stage'], conn=True),
             line(14, '%d#rconn:1' % S['udc_n'], '%d#rconn:2' % S['power_stage'], conn=True),
             line(29, '%d#out:1' % S['ref'], '%d#in:1' % S['ref_delay']),
             line(30, '%d#out:1' % S['ref_delay'], '%d#in:3' % S['mlf']),
             line(31, '%d#out:1' % S['enc'], '%d#in:1' % S['enc_delay']),
             line(32, '%d#out:1' % S['enc_delay'], '%d#in:4' % S['mlf'])]
    return '<?xml version="1.0" encoding="utf-8"?>\n<System>\n' + ''.join(b[k] for k in order) + ''.join(lines) + '</System>\n'


# ====================================================================== system_3 (inside the MATLAB Function)
def make_system_3():
    S = SID3
    x = '<?xml version="1.0" encoding="utf-8"?>\n<System>\n' + P('SIDHighWatermark', SID3_HIGH, '  ')
    zin = {'M': -1, 't_master': 19, 'ref': 22, 'enc': 24}
    for k, n in enumerate(INPUTS):
        y = 101 + 35*k
        x += ('  <Block BlockType="Inport" Name="%s" SID="%s">\n' % (n, S[n]) + P('Position', '[20, %d, 40, %d]' % (y, y + 18))
              + P('ZOrder', zin[n]) + (P('Port', k + 1) if k else '') + '  </Block>\n')
    x += ('  <Block BlockType="Demux" Name=" Demux " SID="%s">\n' % S['demux'] + '    <PortCounts in="1" out="1"/>\n'
          + P('Position', '[270, 255, 320, 295]') + P('ZOrder', 17) + P('Outputs', 1) + '  </Block>\n')
    x += ('  <Block BlockType="S-Function" Name=" SFunction " SID="%s">\n' % S['sfun'] + P('Tag', 'Stateflow S-Function 2')
          + '    <PortCounts in="%d" out="%d"/>\n' % (len(INPUTS), len(OUTPUTS) + 1)
          + P('Position', '[180, 100, 230, 240]') + P('ZOrder', 16) + P('FunctionName', 'sf_sfun')
          + P('Parameters', ','.join(sorted(PARAMS))) + P('PortCounts', '[%d %d]' % (len(INPUTS), len(OUTPUTS) + 1))
          + P('SFunctionDeploymentMode', 'off') + P('EnableBusSupport', 'off') + P('SFcnIsStateOwnerBlock', 'off')
          + '    <PortProperties>\n' + ''.join('      <Port Type="out" Index="%d">\n        <P Name="Name">%s</P>\n      </Port>\n'
                                            % (k + 2, o) for k, o in enumerate(OUTPUTS)) + '    </PortProperties>\n  </Block>\n')
    x += ('  <Block BlockType="Terminator" Name=" Terminator " SID="%s">\n' % S['term'] + P('Position', '[460, 266, 480, 284]')
          + P('ZOrder', 18) + '  </Block>\n')
    zout = {'G': -5, 'ctrl_log': 21}
    for k, n in enumerate(OUTPUTS):
        y = 101 + 35*k
        x += ('  <Block BlockType="Outport" Name="%s" SID="%s">\n' % (n, S[n]) + P('Position', '[460, %d, 480, %d]' % (y, y + 18))
              + P('ZOrder', zout[n]) + (P('Port', k + 1) if k else '') + '  </Block>\n')
    z = 13
    for k, n in enumerate(INPUTS):
        z += 1
        x += '  <Line>\n' + P('ZOrder', z) + P('Src', '%s#out:1' % S[n]) + P('Dst', '%s#in:%d' % (S['sfun'], k + 1)) + '  </Line>\n'
    for k, n in enumerate(OUTPUTS):
        z += 1
        x += ('  <Line>\n' + P('Name', n) + P('ZOrder', z) + P('Labels', '[0, 0]') + P('Src', '%s#out:%d' % (S['sfun'], k + 2))
              + P('Dst', '%s#in:1' % S[n]) + '  </Line>\n')
    z += 1
    x += '  <Line>\n' + P('ZOrder', z) + P('Src', '%s#out:1' % S['demux']) + P('Dst', '%s#in:1' % S['term']) + '  </Line>\n'
    z += 1
    x += '  <Line>\n' + P('ZOrder', z) + P('Src', '%s#out:1' % S['sfun']) + P('Dst', '%s#in:1' % S['demux']) + '  </Line>\n'
    return x + '</System>\n'


# ====================================================================== Stateflow chart and machine
def data_blocks(chart):
    return {m.group(1): m.group(0) for m in
            re.finditer(r'    <data SSID="\d+" name="(\w+)">.*?\n    </data>\n', chart, re.S)}


def make_chart(chart, code):
    """Chart of the template with the new name, script and data. The template data serve as patterns:
    M and G as written by the MATLAB Function template, the inputs as t_master, the outputs as ctrl_log,
    the parameter as p."""
    d = data_blocks(chart)
    assert set(d) == {'M', 'G', 't_master', 'sync', 'ctrl_log', 'p', 'sync_out'}, sorted(d)
    pattern = {'M': d['M'], 't_master': d['t_master'], 'ref': d['t_master'], 'enc': d['t_master'],
               'p': d['p'], 'G': d['G'], 'ctrl_log': d['ctrl_log']}
    order = INPUTS + PARAMS + OUTPUTS                  # SSID 4.. in this order (ports in signature order)
    new = ''
    for k, n in enumerate(order):
        x = re.sub(r'<data SSID="\d+" name="\w+">', '<data SSID="%d" name="%s">' % (4 + k, n), pattern[n])
        x = re.sub(r'<P Name="size">[^<]*</P>', '<P Name="size">%s</P>' % SIZES.get(n, '-1'), x)
        new += x
    first = re.search(r'    <data SSID=', chart).start()
    last = list(re.finditer(r'\n    </data>\n', chart))[-1].end()
    assert all(first <= chart.find(v) < last for v in d.values())
    chart = chart[:first] + new + chart[last:]
    chart = re.sub(r'(<chart id="\d+">\s*<P Name="name">)[^<]*(</P>)', r'\g<1>%s/%s\g<2>' % (TOP_NEW, MLF_NEW), chart)
    chart = re.sub(r'(  <eml>\s*<P Name="name">)[^<]*(</P>)', r'\g<1>%s\g<2>' % FNAME, chart)
    chart = re.sub(r'<P Name="ssIdHighWaterMark">\d+</P>', '<P Name="ssIdHighWaterMark">%d</P>' % (3 + len(order)), chart)
    m = re.search(r'(<P Name="script">)(.*?)(</P>)', chart, re.S)
    chart = chart[:m.start(2)] + esc(code) + chart[m.end(2):]
    return chart


def make_machine(machine):
    machine, n = re.subn(r'(<instance id="\d+">\s*<P Name="machine">\d+</P>\s*<P Name="name">)[^<]*(</P>)',
                         r'\g<1>%s/%s\g<2>' % (TOP_NEW, MLF_NEW), machine)
    assert n == 1
    return machine


# ====================================================================== make
def make():
    code = read_code()
    zin = zipfile.ZipFile(SRC)
    parts = {i.filename: (i, zin.read(i.filename)) for i in zin.infolist()}
    txt = lambda n: parts[n][1].decode('utf-8')
    out = {}
    out['simulink/systems/system_root.xml'] = make_root(txt('simulink/systems/system_root.xml'))
    out['simulink/systems/system_1.xml'] = make_system_1(txt('simulink/systems/system_1.xml'))
    out['simulink/systems/system_3.xml'] = make_system_3()
    out['simulink/stateflow/chart_12.xml'] = make_chart(txt('simulink/stateflow/chart_12.xml'), code)
    out['simulink/stateflow/machine.xml'] = make_machine(txt('simulink/stateflow/machine.xml'))
    bd = txt('simulink/blockDiagram.json')
    old_uuid = json.loads(bd)['BlockDiagram']['ModelUUID']
    bd = bd.replace(old_uuid, str(uuid.uuid5(uuid.NAMESPACE_URL, 'pwr-control/library/' + TOP_NEW)))
    out['simulink/blockDiagram.json'] = re.sub(r'%<AutoIncrement:[0-9.]+>', '%<AutoIncrement:1.0>', bd)
    cp = txt('metadata/coreProperties.xml')
    now = re.search(r'<dcterms:modified[^>]*>([^<]*)<', cp).group(1)       # same bytes on every run
    cp = re.sub(r'(<dcterms:created[^>]*>)[^<]*(<)', r'\g<1>%s\2' % now, cp)
    out['metadata/coreProperties.xml'] = re.sub(r'<cp:revision>[^<]*</cp:revision>', '<cp:revision>1.0</cp:revision>', cp)
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w') as zout:          # same entry order, compression and date as the source
        for name, (info, data) in parts.items():
            zi = zipfile.ZipInfo(name, date_time=info.date_time)
            zi.compress_type = info.compress_type
            zi.external_attr = info.external_attr
            zi.create_system = info.create_system
            zout.writestr(zi, out[name].encode('utf-8') if name in out else data)
    with open(DST, 'wb') as f:
        f.write(buf.getvalue())
    return code


# ====================================================================== checks
n_fail = 0


def check(label, ok, detail=''):
    global n_fail
    if not ok:
        n_fail += 1
    print('   %-86s %s %s' % (label, 'OK' if ok else 'FAILED', detail))


def port_counts(block_xml):
    m = re.search(r'<PortCounts([^>]*)/>', block_xml)
    return {k: int(v) for k, v in re.findall(r'(\w+)="(\d+)"', m.group(1))} if m else {}


def verify_package(z, src):
    names = z.namelist()
    check('same parts as the source library', names == src.namelist())
    ok = True
    for n in names:
        data = z.read(n)
        try:
            if n.endswith('.xml') or n.endswith('.rels'):
                ET.fromstring(data)
            elif n.endswith('.json'):
                json.loads(data)
        except Exception as e:                     # noqa: BLE001
            ok = False
            print('      parse error in', n, e)
    check('every XML / JSON part parses', ok)
    ct = z.read('[Content_Types].xml').decode()
    over = re.findall(r'PartName="/([^"]+)"', ct)
    check('content types: overrides point to existing parts', all(o in names for o in over))
    ok = True
    for n in names:
        if n.endswith('.rels'):
            base = os.path.dirname(os.path.dirname(n))
            for t in re.findall(r'Target="([^"]+)"', z.read(n).decode()):
                if os.path.normpath(os.path.join(base, t)).lstrip('/') not in names:
                    ok = False
                    print('      missing target', t, 'of', n)
    check('relationships: every target exists', ok)
    ok = all(z.getinfo(n).compress_type == src.getinfo(n).compress_type for n in names)
    check('same compression of every part as the source', ok)
    texts = {n: z.read(n).decode('utf-8') for n in names if not n.endswith('.mxarray')}
    # the description and the code mention grid_forming_dqctrl on purpose: look at the rest only
    bare = {n: re.sub(r'<Description>.*?</Description>|<P Name="script">.*?</P>', '', t, flags=re.S)
            for n, t in texts.items()}
    left = [n for n, t in bare.items() if re.search(r'grid_forming|afe_dq|\bsync|ug_a|ug_b|ug_c', t)]
    check('no name of the grid-forming block left (grid_forming, afe_dq, sync, ug_a/b/c)', not left, ', '.join(left))
    bd = json.loads(texts['simulink/blockDiagram.json'])['BlockDiagram']
    check('new ModelUUID, library type kept', bd['ModelUUID'] != json.loads(src.read('simulink/blockDiagram.json'))['BlockDiagram']['ModelUUID']
          and bd.get('LibraryType') == 'BlockLibrary')
    return texts


def verify_systems(texts, src):
    root = texts['simulink/systems/system_root.xml']
    s1 = texts['simulink/systems/system_1.xml']
    s1src = src.read('simulink/systems/system_1.xml').decode()
    top = re.search(r'<Block BlockType="SubSystem" Name="%s" SID="1">.*?</Block>' % TOP_NEW, root, re.S)
    check('top block %s' % TOP_NEW, top is not None)
    top = top.group(0)
    blocks = blocks_of(s1)
    kinds = {sid: re.search(r'BlockType="([^"]+)" Name="([^"]*)"', x).groups() for sid, x in blocks.items()}
    ins = sorted((int(re.search(r'<P Name="Port">(\d+)</P>', blocks[s]).group(1)) if '<P Name="Port">' in blocks[s] else 1, n)
                 for s, (t, n) in kinds.items() if t == 'Inport')
    outs = sorted((int(re.search(r'<P Name="Port">(\d+)</P>', blocks[s]).group(1)) if '<P Name="Port">' in blocks[s] else 1, n)
                  for s, (t, n) in kinds.items() if t == 'Outport')
    pm = []
    for s, (t, n) in kinds.items():
        if t == 'PMIOPort':
            port = int(re.search(r'<P Name="Port">(\d+)</P>', blocks[s]).group(1)) if '<P Name="Port">' in blocks[s] else 1
            pm.append((port, re.search(r'<P Name="Side">(\w+)</P>', blocks[s]).group(1), n))
    pm.sort()
    check('inputs of the block: %s' % ', '.join(SIG_IN), [n for _, n in ins] == SIG_IN and [k for k, _ in ins] == [1, 2, 3])
    check('outputs of the block: %s' % ', '.join(SIG_OUT), [n for _, n in outs] == SIG_OUT and [k for k, _ in outs] == [1, 2])
    check('physical ports: Udc(+), Udc(-) left, u, v, w right, numbers 1..5',
          [k for k, _, _ in pm] == [1, 2, 3, 4, 5] and [n for _, s, n in pm if s == 'Left'] == LCONN
          and [n for _, s, n in pm if s == 'Right'] == RCONN)
    check('PortCounts of the top block match its ports', port_counts(top) == dict(
        **{'in': len(SIG_IN), 'out': len(SIG_OUT), 'lconn': len(LCONN), 'rconn': len(RCONN)}))
    labels = re.findall(r"port_label\(&apos;(\w+)&apos;, (\d+), &apos;([^&]*)&apos;\)", top)
    want = ([('LConn', str(k + 1), s) for k, s in enumerate(LCONN)] + [('RConn', str(k + 1), s) for k, s in enumerate(RCONN)]
            + [('input', str(k + 1), s) for k, s in enumerate(SIG_IN)] + [('output', str(k + 1), s) for k, s in enumerate(SIG_OUT)])
    check('mask port labels = ports', labels == want, str(len(labels)))
    check('mask parameter p (%s), Help, Type, description with ctrl_log %dx1' % (MASK_VALUE, NLOG),
          '<MaskParameter Name="p" Type="edit">' in top and '<Value>%s</Value>' % MASK_VALUE in top
          and esc(HELP) in top and esc(MASK_TYPE) in top and 'ctrl_log (%dx1' % NLOG in top)
    sids = [int(s) for s in re.findall(r'SID="(\d+)"', s1)]
    hw = int(re.search(r'<P Name="SIDHighWatermark">(\d+)</P>', root).group(1))
    check('SIDs of system_1 unique, below SIDHighWatermark %d' % hw, len(sids) == len(set(sids)) and max(sids) <= hw and 1 < min(sids))
    # lines: every endpoint exists and is in range, every input / connection port used once
    pc = {sid: port_counts(x) for sid, x in blocks.items()}
    for sid, (t, n) in kinds.items():
        if t in ('Inport',):
            pc[sid] = {'out': 1}
        elif t == 'Outport':
            pc[sid] = {'in': 1}
        elif t == 'PMIOPort':
            pc[sid] = {'rconn': 1}
        elif t == 'UnitDelay':
            pc[sid] = {'in': 1, 'out': 1}
    ends = re.findall(r'<P Name="(Src|Dst)">(\d+)#(\w+):(\d+)</P>', s1)
    ok = all(int(s) in pc and 1 <= int(k) <= pc[int(s)].get(kind, 0) for _, s, kind, k in ends)
    check('lines: every end is an existing port', ok, '%d ends' % len(ends))
    dst_in = [(s, k) for e, s, kind, k in ends if kind == 'in']
    n_in = sum(v.get('in', 0) for v in pc.values())
    check('lines: every signal input driven once', len(dst_in) == len(set(dst_in)) == n_in, '%d inputs' % n_in)
    phys = [(s, kind, k) for _, s, kind, k in ends if kind in ('lconn', 'rconn')]
    n_phys = sum(v.get('lconn', 0) + v.get('rconn', 0) for v in pc.values())
    check('lines: every physical port connected once', len(phys) == len(set(phys)) == n_phys, '%d ports' % n_phys)
    ps_new = re.search(r'<Block BlockType="Reference" Name="power_stage".*?</Block>', s1, re.S).group(0)
    ps_old = re.search(r'<Block BlockType="Reference" Name="power_stage".*?</Block>', s1src, re.S).group(0)
    check('power stage unchanged (afe_ssc.afe_two_level_lcl, parameters p.hw.*)', ps_new == ps_old)
    for nm in ('gates', 'meas', 'meas_delay'):
        a = re.search(r'<Block [^>]*Name="%s".*?</Block>' % nm, s1, re.S).group(0)
        b = re.search(r'<Block [^>]*Name="%s".*?</Block>' % nm, s1src, re.S).group(0)
        check('%s unchanged apart from its position' % nm, re.sub(r'<P Name="Position">[^<]*</P>', '', a)
              == re.sub(r'<P Name="Position">[^<]*</P>', '', b))
    for nm in ('ref_delay', 'enc_delay', 'meas_delay'):
        a = re.search(r'<Block BlockType="UnitDelay" Name="%s".*?</Block>' % nm, s1, re.S)
        check('%s: Unit Delay at p.pwm.tc' % nm, a is not None and '<P Name="SampleTime">p.pwm.tc</P>' in a.group(0))
    chain = [('ref', 'ref_delay', 3), ('enc', 'enc_delay', 4), ('meas', 'meas_delay', 1)]
    ok = True
    for a, d, k in chain:
        ok &= ('%d#out:1' % SID[a]) in s1 and ('%d#in:1' % SID[d]) in s1 and \
              re.search(r'<P Name="Src">%d#out:1</P>\s*<P Name="Dst">%d#in:%d</P>' % (SID[d], SID['mlf'], k), s1) is not None
    check('ref, enc, measurements reach the MATLAB Function through their delays (inputs 3, 4, 1)', ok)
    mlf = blocks[SID['mlf']]
    check('MATLAB Function %s: 4 inputs, 2 outputs, chart system system_3' % MLF_NEW,
          'Name="%s"' % MLF_NEW in mlf and port_counts(mlf) == {'in': 4, 'out': 2} and '<System Ref="system_3"/>' in mlf
          and '<P Name="SFBlockType">MATLAB Function</P>' in mlf)
    # PMIOPorts keep the SIDs of their binary parts
    rels = src.read('simulink/_rels/blockDiagram.json.rels').decode()
    ok = all('LibrarySourceProduct_%d' % s in rels and 'bdmxdata:LibrarySourceProduct_%d' % s in blocks[s]
             for s in (8, 9, 10, 11, 12)) and 'bdmxdata:SimscapeInstrumentationVariables_7' in blocks[7]
    check('PMIOPorts and power stage keep their binary parts (SIDs 7..12)', ok)


def verify_stateflow(texts, code):
    chart = texts['simulink/stateflow/chart_12.xml']
    machine = texts['simulink/stateflow/machine.xml']
    s3 = texts['simulink/systems/system_3.xml']
    script = html.unescape(re.search(r'<P Name="script">(.*?)</P>', chart, re.S).group(1))
    check('chart script = private/pmsm_dq_ctrl_pwm.m', script == code, '%d characters' % len(code))
    chart_id = int(re.search(r'<chart id="(\d+)">', chart).group(1))
    ssids = [int(s) for s in re.findall(r'SSID="(\d+)"', chart) if True]
    objs = re.findall(r'<(state|transition|junction|data) SSID="(\d+)"', chart)
    high = int(re.search(r'<P Name="ssIdHighWaterMark">(\d+)</P>', chart).group(1))
    inst = int(re.search(r'<instance id="(\d+)">', machine).group(1))
    target = int(re.search(r'<target id="(\d+)"', machine).group(1))
    mach_id = int(re.search(r'<machine id="(\d+)">', machine).group(1))
    check('Stateflow ids: chart id %d > max SSID %d = ssIdHighWaterMark' % (chart_id, max(ssids)),
          chart_id > max(int(s) for _, s in objs) == high)
    check('Stateflow ids: instance id %d = chart id + %d objects + 1, target id %d last, machine id %d'
          % (inst, len(objs), target, mach_id),
          inst == chart_id + len(objs) + 1 and target == inst + 1 and mach_id < chart_id)
    check('instance and chart name %s/%s' % (TOP_NEW, MLF_NEW),
          '<P Name="name">%s/%s</P>' % (TOP_NEW, MLF_NEW) in machine and '<P Name="name">%s/%s</P>' % (TOP_NEW, MLF_NEW) in chart
          and '<P Name="chart">%d</P>' % chart_id in machine and '<chart Ref="chart_%d"/>' % chart_id in machine)
    data = re.findall(r'<data SSID="(\d+)" name="(\w+)">\s*<P Name="scope">(\w+)</P>.*?<P Name="size">([^<]*)</P>', chart, re.S)
    check('chart data in signature order: inputs, parameter, outputs',
          [d[1] for d in data if d[2] == 'INPUT_DATA'] == INPUTS and [d[1] for d in data if d[2] == 'OUTPUT_DATA'] == OUTPUTS
          and [d[1] for d in data if d[2] == 'PARAMETER_DATA'] == PARAMS and len(data) == len(INPUTS + OUTPUTS + PARAMS))
    check('data sizes: ref [2 1], the others inherited', all(d[3] == SIZES.get(d[1], '-1') for d in data))
    check('chart: discrete, sample time p.pwm.tc, function name %s' % FNAME,
          '<P Name="sampleTime">p.pwm.tc</P>' in chart and '<P Name="updateMethod">DISCRETE</P>' in chart
          and re.search(r'<eml>\s*<P Name="name">%s</P>' % FNAME, chart) is not None)
    fn = int(re.search(r'<P Name="chartFileNumber">(\d+)</P>', chart).group(1))
    sf = re.search(r'<Block BlockType="S-Function" Name=" SFunction " SID="[^"]+">.*?</Block>', s3, re.S).group(0)
    check('S-Function: tag of chart file %d, ports [%d %d], Parameters = sorted parameter names'
          % (fn, len(INPUTS), len(OUTPUTS) + 1),
          '<P Name="Tag">Stateflow S-Function %d</P>' % fn in sf and port_counts(sf) == {'in': len(INPUTS), 'out': len(OUTPUTS) + 1}
          and '<P Name="PortCounts">[%d %d]</P>' % (len(INPUTS), len(OUTPUTS) + 1) in sf
          and '<P Name="Parameters">%s</P>' % ','.join(sorted(PARAMS)) in sf)
    blocks3 = {m.group(2): m.group(1) for m in re.finditer(r'<Block BlockType="(Inport|Outport)" Name="(\w+)"', s3)}
    check('system_3 ports = function ports', [n for n, t in blocks3.items() if t == 'Inport'] == INPUTS
          and [n for n, t in blocks3.items() if t == 'Outport'] == OUTPUTS)
    sids3 = re.findall(r'SID="3::(\d+)"', s3)
    check('system_3 SIDs unique, below SIDHighWatermark',
          len(sids3) == len(set(sids3)) and max(int(s) for s in sids3) <= int(re.search(r'SIDHighWatermark">(\d+)<', s3).group(1)))


def main():
    code = make()
    print(os.path.relpath(DST, MASKED))
    z = zipfile.ZipFile(DST)
    src = zipfile.ZipFile(SRC)
    texts = verify_package(z, src)
    verify_systems(texts, src)
    verify_stateflow(texts, code)
    print('\n%d checks failed' % n_fail)
    return 0 if n_fail == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
