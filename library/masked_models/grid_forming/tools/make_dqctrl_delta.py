#!/usr/bin/env python3
"""Make the delta-capacitor versions of the grid-forming and grid-following AFE blocks.

  grid_forming/grid_forming_dqctrl.slx      ->  grid_forming/grid_forming_dqctrl_delta.slx
  grid_following/grid_following_dqctrl.slx  ->  grid_following/grid_following_dqctrl_delta.slx

Each new library holds one masked block (grid_forming_dqctrl_delta_mod1,
grid_following_dqctrl_delta_mod1) equal to the block of the source library
apart from two things:

  1. power stage: library link to the Simscape block afe_ssc.afe_two_level_lcl_delta
     (filter capacitors in delta) instead of afe_ssc.afe_two_level_lcl. Same
     ports, same parameter names, same M (17x1). The capacitor parameters are
     Cf = p.hw.Cf/3 and Rcf = 3*p.hw.Rcf: p.hw.Cf and p.hw.Rcf keep the meaning
     they have in the star blocks (per-phase values of the star), so the same
     parameter struct p gives the same filter, the same resonance and the same
     control behaviour; only M(15:17) change (currents of the delta branches).
  2. control: the MATLAB Function is not copied. The block holds a library link
     to the MATLAB Function of the source library (as three_phase_pwm_modulator
     links the MATLAB Function of single_phase_pwm_modulator), so the control
     code stays in one place: update_grid_forming_dqctrl.m (or an edit of the
     MATLAB Function of grid_following_dqctrl) changes both blocks.

The .slx files are written as XML/JSON inside the zip without MATLAB: the source
library is copied part by part and only the parts above are changed (top block
name, mask type and description, the MATLAB Function block replaced by a link,
its system and Stateflow chart removed, the power-stage link, a new ModelUUID).

Run again after a change of the ports, the mask or the layout of a source block
(a change of the control code only needs nothing):

    python3 make_dqctrl_delta.py          (from any folder; writes both libraries and checks them)

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
MASKED = os.path.dirname(os.path.dirname(HERE))                  # library/masked_models
LIBROOT = os.path.dirname(MASKED)                                 # library
DELTA_SSC = os.path.join(LIBROOT, 'foundation', 'pwr_electronics', '+afe_ssc', 'afe_two_level_lcl_delta.ssc')

# name of the delta block in afe_ssc_lib.slx: ssc_build names a block after the first comment line
# of the component and wraps it at 20 characters per line (checked on the ten blocks of the
# pwr_electronics libraries, e.g. 'AFE Two-Level Bridge\nwith LCL Filter')
DELTA_TITLE = 'AFE Two-Level Bridge with LCL Filter, Delta Capacitors'
STAR_LINK = 'afe_ssc_lib/AFE Two-Level Bridge\nwith LCL Filter'

BLOCKS = [
    dict(kind='forming',
         src=os.path.join(MASKED, 'grid_forming', 'grid_forming_dqctrl.slx'),
         dst=os.path.join(MASKED, 'grid_forming', 'grid_forming_dqctrl_delta.slx'),
         src_lib='grid_forming_dqctrl', top_old='grid_forming_dqctrl_mod1',
         top_new='grid_forming_dqctrl_delta_mod1', mlf='afe_dq_forming_ctrl_pwm',
         mask_type='Grid-forming AFE (two-level bridge, LCL filter, delta capacitors)',
         description=(
             'Grid-forming AFE in one block with the filter capacitors in DELTA: grid_forming_dqctrl with the '
             'Simscape component afe_ssc.afe_two_level_lcl_delta (ideal two-level bridge, DC-link capacitor, LCL '
             'filter with delta capacitors) as power stage. Same ports, mask parameter p, control and Help as '
             'grid_forming_dqctrl, so the two blocks can be swapped. p.hw.Cf and p.hw.Rcf keep their meaning in '
             'grid_forming_dqctrl (per-phase values of the star): the block puts p.hw.Cf/3 and 3*p.hw.Rcf in each '
             'delta branch, so the same p gives the same filter and the same control behaviour. '
             'Control and PWM: library link to the MATLAB Function of grid_forming_dqctrl (source '
             'private/afe_dq_ctrl_pwm.m, loaded by update_grid_forming_dqctrl.m): a change of the control code '
             'there applies to this block too. Measurements to the control through a Unit Delay of one tc. '
             'Ports: ug_a/b/c left, Udc(+)/Udc(-) right, t_master and sync in, m (17x1 pu), ctrl_log (55x1) and '
             'sync_out out. m(1:14) as in grid_forming_dqctrl (m(4:6) = capacitor node voltages without zero '
             'sequence, the voltages of the equivalent star); m(15:17) = currents of the three delta capacitors '
             '[icf_ab; icf_bc; icf_ca] in pu of ibez, icf_ab from node a to node b; the current from line a into '
             'the capacitors is m(15) - m(17). Parameter p: struct with the fields hw, pwm, ctrl, e.g. '
             'grid_forming_param_example.m of this folder (400 V, 250 kW, 50 Hz, 4 kHz). Made by '
             'tools/make_dqctrl_delta.py from grid_forming_dqctrl.slx. Description and user guide: the Help of '
             'this block (note library/documentation/grid_forming_following_afe).')),
    dict(kind='following',
         src=os.path.join(MASKED, 'grid_following', 'grid_following_dqctrl.slx'),
         dst=os.path.join(MASKED, 'grid_following', 'grid_following_dqctrl_delta.slx'),
         src_lib='grid_following_dqctrl', top_old='grid_following_dqctrl_mod1',
         top_new='grid_following_dqctrl_delta_mod1', mlf='afe_dq_follower_ctrl_pwm',
         mask_type='Grid-following AFE (two-level bridge, LCL filter, delta capacitors)',
         description=(
             'Grid-following AFE (DC-link voltage control, FHT-PLL) in one block with the filter capacitors in '
             'DELTA: grid_following_dqctrl with the Simscape component afe_ssc.afe_two_level_lcl_delta (ideal '
             'two-level bridge, DC-link capacitor, LCL filter with delta capacitors) as power stage. Same ports, '
             'mask parameter p, control and Help as grid_following_dqctrl, so the two blocks can be swapped. '
             'p.hw.Cf and p.hw.Rcf keep their meaning in grid_following_dqctrl (per-phase values of the star): '
             'the block puts p.hw.Cf/3 and 3*p.hw.Rcf in each delta branch, so the same p gives the same filter '
             'and the same control behaviour. Control and PWM: library link to the MATLAB Function '
             'afe_dq_follower_ctrl_pwm of grid_following_dqctrl (afe_follower_ctrl_pwm): a change of the control '
             'code there applies to this block too. Measurements to the control through a Unit Delay of one tc. '
             'Ports: ug_a/b/c left, Udc(+)/Udc(-) right, t_master in, m (17x1 pu) and ctrl_log (45x1) out. '
             'm(1:14) as in grid_following_dqctrl (m(4:6) = capacitor node voltages without zero sequence, the '
             'voltages of the equivalent star); m(15:17) = currents of the three delta capacitors [icf_ab; '
             'icf_bc; icf_ca] in pu of ibez, icf_ab from node a to node b; the current from line a into the '
             'capacitors is m(15) - m(17). Parameter p: struct with the fields hw, pwm, ctrl, e.g. '
             'grid_following_param_example.m of this folder. Made by tools/make_dqctrl_delta.py from '
             'grid_following_dqctrl.slx. Description and user guide: the Help of this block (note '
             'library/documentation/grid_forming_following_afe).')),
]

# instance data of a library link to a subsystem, as R2026b saves it (power_meter_iec.slx)
SUBSYSTEM_LINK_INSTANCE = [
    ('ShowPortLabels', 'FromPortIcon'), ('SystemSampleTime', '-1'),
    ('RTWMemSecFuncInitTerm', 'Inherit from model'), ('RTWMemSecFuncExecute', 'Inherit from model'),
    ('RTWMemSecDataConstants', 'Inherit from model'), ('RTWMemSecDataInternal', 'Inherit from model'),
    ('RTWMemSecDataParameters', 'Inherit from model'), ('VariantActivationTime', 'update diagram'),
    ('EmptyChoice', 'off'), ('PassThrough', 'off'), ('PassThroughVariantControl', '(default)'),
    ('EmptyChoiceVariantControl', '(default)'), ('PropagateVariantConditions', 'off'),
    ('AllowFlexibleInterface', 'on'), ('ContentPreviewEnabled', 'on'), ('Latency', '0'),
    ('AutoFrameSizeCalculation', 'off')]

EMPTY_MACHINE = '''<?xml version="1.0" encoding="utf-8"?>
<Stateflow>
  <machine id="1">
    <P Name="sfVersion">{sfv}</P>
    <Children>
      <target id="2" name="sfun">
        <P Name="description">Default Simulink S-Function Target.</P>
      </target>
    </Children>
  </machine>
</Stateflow>
'''


def ssc_block_name(title, width=20):
    """Greedy word wrap of the component title, as ssc_build names the library block."""
    lines, cur = [], ''
    for w in title.split(' '):
        if cur and len(cur) + 1 + len(w) > width:
            lines.append(cur)
            cur = w
        else:
            cur = w if not cur else cur + ' ' + w
    lines.append(cur)
    return '\n'.join(lines)


def ssc_items(path, section):
    """(name, unit) of the declarations of a section (variables / parameters) of an .ssc file."""
    text = open(path, encoding='utf-8').read()
    m = re.search(r'^\s*%s\b[^\n]*\n(.*?)^\s*end\b' % section, text, re.S | re.M)
    out = []
    for line in m.group(1).splitlines():
        line = line.split('%')[0].strip()
        d = re.match(r'(\w+)\s*=\s*(.*?);?$', line)
        if not d:
            continue
        unit = re.findall(r"'([^']*)'", d.group(2))
        out.append((d.group(1), unit[0] if unit else None))
    return out


def xml_text(s):
    return html.escape(s, quote=False)


def power_stage_delta(block_xml, delta_link, delta_vars):
    """Turn the power_stage link to afe_two_level_lcl into a link to afe_two_level_lcl_delta."""
    b = block_xml
    star_link_xml = STAR_LINK
    assert b.count('<P Name="SourceBlock">%s</P>' % star_link_xml) == 1, 'power_stage: star link not found'
    name = delta_link.split('/', 1)[1]
    b = b.replace('<P Name="SourceBlock">%s</P>' % star_link_xml, '<P Name="SourceBlock">%s</P>' % delta_link)
    b = b.replace('<P Name="SourceType">%s</P>' % star_link_xml.split('/', 1)[1],
                  '<P Name="SourceType">%s</P>' % name)
    for old, new in [('<P Name="SourceFile">afe_ssc.afe_two_level_lcl</P>',
                      '<P Name="SourceFile">afe_ssc.afe_two_level_lcl_delta</P>'),
                     ('<P Name="ComponentPath">afe_ssc.afe_two_level_lcl</P>',
                      '<P Name="ComponentPath">afe_ssc.afe_two_level_lcl_delta</P>'),
                     ('<P Name="ComponentVariants">[&quot;afe_ssc.afe_two_level_lcl&quot;]</P>',
                      '<P Name="ComponentVariants">[&quot;afe_ssc.afe_two_level_lcl_delta&quot;]</P>'),
                     ('<P Name="ComponentVariantNames">[&quot;afe_two_level_lcl&quot;]</P>',
                      '<P Name="ComponentVariantNames">[&quot;afe_two_level_lcl_delta&quot;]</P>'),
                     ('<P Name="ClassName">afe_two_level_lcl</P>',
                      '<P Name="ClassName">afe_two_level_lcl_delta</P>'),
                     ('<P Name="Cf">p.hw.Cf</P>', '<P Name="Cf">p.hw.Cf/3</P>'),
                     ('<P Name="Rcf">p.hw.Rcf</P>', '<P Name="Rcf">3*p.hw.Rcf</P>')]:
        assert b.count(old) == 1, 'power_stage: %s not found once' % old
        b = b.replace(old, new)
    # variable targets: the entries of the star component replaced by those of the delta component
    inst = re.search(r'(\n *)<P Name="vdc_specify">.*?<P Name="(\w+)_nominal_unit">[^<]*</P>(?=\s*</InstanceData>)',
                     b, re.S)
    assert inst, 'power_stage: variable entries not found'
    ind = inst.group(1)
    rows = []
    for v, unit in delta_vars:
        rows += ['<P Name="%s_specify">off</P>' % v, '<P Name="%s_priority">None</P>' % v,
                 '<P Name="%s">0</P>' % v, '<P Name="%s_unit">%s</P>' % (v, unit),
                 '<P Name="%s_nominal_specify">off</P>' % v, '<P Name="%s_nominal_value">1</P>' % v,
                 '<P Name="%s_nominal_unit">%s</P>' % (v, unit)]
    b = b[:inst.start()] + ind + ind.join(rows) + b[inst.end():]
    return b


def mlf_link(block_xml, source_block, lib_version):
    """Replace the MATLAB Function subsystem by a library link to the one of the source library."""
    head = re.match(r'(<Block BlockType=")SubSystem(" Name="[^"]*" SID="\d+">)', block_xml)
    assert head, 'MATLAB Function block header not recognised'
    assert '<P Name="SFBlockType">MATLAB Function</P>' in block_xml, 'not a MATLAB Function block'
    ind = re.search(r'\n( *)<PortCounts', block_xml).group(1)
    keep = [re.search(r'<PortCounts[^>]*/>', block_xml).group(0),
            re.search(r'<P Name="Position">[^<]*</P>', block_xml).group(0),
            re.search(r'<P Name="ZOrder">[^<]*</P>', block_xml).group(0)]
    ports = re.search(r'<PortProperties>.*?</PortProperties>', block_xml, re.S)
    lines = [head.group(1) + 'Reference' + head.group(2)] + [ind + k for k in keep]
    lines += [ind + '<P Name="LibraryVersion">%s</P>' % lib_version,
              ind + '<P Name="SourceBlock">%s</P>' % xml_text(source_block),
              ind + '<P Name="SourceType">SubSystem</P>',
              ind + '<InstanceData>']
    lines += [ind + '  <P Name="%s">%s</P>' % (k, xml_text(v)) for k, v in SUBSYSTEM_LINK_INSTANCE]
    lines += [ind + '</InstanceData>']
    if ports:
        lines += [ind + ports.group(0)]
    lines += [ind[:-2] + '</Block>']
    return '\n'.join(lines)


def make(cfg, delta_link, delta_vars):
    zin = zipfile.ZipFile(cfg['src'])
    parts = {i.filename: (i, zin.read(i.filename)) for i in zin.infolist()}
    out = {}
    removed = []

    # ---- system_root: top block name, mask type and description
    root = parts['simulink/systems/system_root.xml'][1].decode('utf-8')
    assert root.count('Name="%s"' % cfg['top_old']) == 1
    root = root.replace('Name="%s"' % cfg['top_old'], 'Name="%s"' % cfg['top_new'])
    root, n1 = re.subn(r'<Type>[^<]*</Type>', '<Type>%s</Type>' % xml_text(cfg['mask_type']), root)
    root, n2 = re.subn(r'<Description>.*?</Description>',
                       lambda m: '<Description>%s</Description>' % xml_text(cfg['description']), root, flags=re.S)
    assert n1 == 1 and n2 == 1, 'mask type / description not found'
    out['simulink/systems/system_root.xml'] = root

    # ---- system_1: MATLAB Function -> library link, power stage -> delta
    s1 = parts['simulink/systems/system_1.xml'][1].decode('utf-8')
    m = re.search(r'<Block BlockType="SubSystem" Name="%s" SID="\d+">.*?</Block>' % cfg['mlf'], s1, re.S)
    assert m, 'MATLAB Function %s not found' % cfg['mlf']
    child = re.findall(r'<System Ref="(system_\d+)"/>', m.group(0))
    assert len(child) == 1
    rev = re.search(r'<cp:revision>([^<]*)</cp:revision>',
                    parts['metadata/coreProperties.xml'][1].decode()).group(1)
    source_block = '%s/%s/%s' % (cfg['src_lib'], cfg['top_old'], cfg['mlf'])
    s1 = s1[:m.start()] + mlf_link(m.group(0), source_block, rev) + s1[m.end():]
    m = re.search(r'<Block BlockType="Reference" Name="power_stage" SID="\d+">.*?</Block>', s1, re.S)
    assert m, 'power_stage not found'
    s1 = s1[:m.start()] + power_stage_delta(m.group(0), delta_link, delta_vars) + s1[m.end():]
    out['simulink/systems/system_1.xml'] = s1

    # ---- parts that belonged to the MATLAB Function: its system and its chart
    rels1 = parts['simulink/systems/_rels/system_1.xml.rels'][1].decode()
    assert re.findall(r'Target="([^"]+)"', rels1) == [child[0] + '.xml'], 'system_1 has other children'
    removed += ['simulink/systems/%s.xml' % child[0], 'simulink/systems/_rels/system_1.xml.rels']
    machine = parts['simulink/stateflow/machine.xml'][1].decode()
    charts = re.findall(r'<chart Ref="(chart_\d+)"/>', machine)
    assert len(charts) == 1
    removed += ['simulink/stateflow/%s.xml' % charts[0], 'simulink/stateflow/_rels/machine.xml.rels']
    sfv = re.search(r'<P Name="sfVersion">(\d+)</P>', machine).group(1)
    out['simulink/stateflow/machine.xml'] = EMPTY_MACHINE.format(sfv=sfv)
    ct = parts['[Content_Types].xml'][1].decode()
    for r in removed:
        ct, n = re.subn(r'\s*<Override [^>]*PartName="/%s"/>' % re.escape(r), '', ct)
    out['[Content_Types].xml'] = ct

    # ---- new model: UUID, version, dates
    bd = parts['simulink/blockDiagram.json'][1].decode()
    old_uuid = json.loads(bd)['BlockDiagram']['ModelUUID']
    bd = bd.replace(old_uuid, str(uuid.uuid5(uuid.NAMESPACE_URL, 'pwr-control/library/' + cfg['top_new'])))
    bd = re.sub(r'%<AutoIncrement:[0-9.]+>', '%<AutoIncrement:1.0>', bd)
    out['simulink/blockDiagram.json'] = bd
    cp = parts['metadata/coreProperties.xml'][1].decode()
    # dates: those of the source library (modified), so that a new run gives the same bytes
    now = re.search(r'<dcterms:modified[^>]*>([^<]*)<', cp).group(1)
    cp = re.sub(r'(<dcterms:created[^>]*>)[^<]*(<)', r'\g<1>%s\2' % now, cp)
    cp = re.sub(r'<cp:revision>[^<]*</cp:revision>', '<cp:revision>1.0</cp:revision>', cp)
    out['metadata/coreProperties.xml'] = cp

    # ---- write: same entry order, compression and date as the source
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w') as zout:
        for name, (info, data) in parts.items():
            if name in removed:
                continue
            zi = zipfile.ZipInfo(name, date_time=info.date_time)
            zi.compress_type = info.compress_type
            zi.external_attr = info.external_attr
            zi.create_system = info.create_system
            zout.writestr(zi, out[name].encode('utf-8') if name in out else data)
    with open(cfg['dst'], 'wb') as f:
        f.write(buf.getvalue())
    return removed


# ====================================================================== checks
n_fail = 0


def check(label, ok, detail=''):
    global n_fail
    if not ok:
        n_fail += 1
    print('   %-78s %s %s' % (label, 'OK' if ok else 'FAILED', detail))


def verify(cfg, delta_link, delta_vars, delta_pars, removed):
    print('%s' % os.path.relpath(cfg['dst'], MASKED))
    z = zipfile.ZipFile(cfg['dst'])
    names = z.namelist()
    src = zipfile.ZipFile(cfg['src'])
    check('every part of the source kept except the MATLAB Function system and chart',
          sorted(set(src.namelist()) - set(names)) == sorted(removed) and set(names) <= set(src.namelist()))
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
    defaults = re.findall(r'Extension="(\w+)"', ct)
    check('content types: overrides point to existing parts', all(o in names for o in over))
    check('content types: every part has a type',
          all(n in over or n.rsplit('.', 1)[-1] in defaults for n in names if n != '[Content_Types].xml'))
    ok = True
    for n in names:
        if n.endswith('.rels'):
            base = os.path.dirname(os.path.dirname(n))
            for t in re.findall(r'Target="([^"]+)"', z.read(n).decode()):
                target = os.path.normpath(os.path.join(base, t)).lstrip('/') if not t.startswith('/') else t[1:]
                if target not in names:
                    ok = False
                    print('      missing target', t, 'of', n)
    check('relationships: every target exists', ok)
    alltext = ' '.join(z.read(n).decode('utf-8', 'ignore') for n in names if not n.endswith('.mxarray'))
    gone = [os.path.basename(r)[:-len('.xml')] for r in removed if r.endswith('.xml')]     # system_3, chart_12
    check('no reference to the removed parts left (%s)' % ', '.join(gone),
          not any(re.search(r'\b%s\b' % g, alltext) for g in gone))
    check('no Stateflow chart left (control = library link)',
          not any('stateflow/chart_' in n for n in names) and '<chart' not in z.read('simulink/stateflow/machine.xml').decode())
    root = z.read('simulink/systems/system_root.xml').decode()
    check('top block renamed', 'Name="%s"' % cfg['top_new'] in root and cfg['top_old'] not in root)
    s1 = z.read('simulink/systems/system_1.xml').decode()
    s1src = src.read('simulink/systems/system_1.xml').decode()
    link = re.search(r'<Block BlockType="Reference" Name="%s".*?</Block>' % cfg['mlf'], s1, re.S)
    check('MATLAB Function replaced by a link', link is not None and 'SFBlockType' not in s1)
    src_root = src.read('simulink/systems/system_root.xml').decode()
    target = re.search(r'<P Name="SourceBlock">([^<]*)</P>', link.group(0)).group(1)
    lib, top, blk = target.split('/')
    check('link source exists: %s' % target,
          lib == cfg['src_lib'] and 'Name="%s"' % top in src_root and 'Name="%s"' % blk in s1src)
    pc_new = re.search(r'<PortCounts[^>]*/>', link.group(0)).group(0)
    pc_old = re.search(r'<Block BlockType="SubSystem" Name="%s".*?(<PortCounts[^>]*/>)' % cfg['mlf'], s1src, re.S).group(1)
    check('link has the ports of the MATLAB Function', pc_new == pc_old, pc_new)
    sids = lambda s: re.findall(r'SID="(\d+)"', s)
    check('same blocks (SIDs) and the same lines as the source',
          sids(s1) == sids(s1src) and re.findall(r'<Line>.*?</Line>', s1, re.S) == re.findall(r'<Line>.*?</Line>', s1src, re.S))
    ps = re.search(r'<Block BlockType="Reference" Name="power_stage".*?</Block>', s1, re.S).group(0)
    check('power stage links to the delta block', '<P Name="SourceBlock">%s</P>' % delta_link in ps,
          repr(delta_link.split('/', 1)[1]))
    check('power stage component afe_ssc.afe_two_level_lcl_delta',
          ps.count('afe_ssc.afe_two_level_lcl_delta') == 3 and 'afe_two_level_lcl<' not in ps)
    check('Cf = p.hw.Cf/3, Rcf = 3*p.hw.Rcf',
          '<P Name="Cf">p.hw.Cf/3</P>' in ps and '<P Name="Rcf">3*p.hw.Rcf</P>' in ps)
    inst = dict(re.findall(r'<P Name="(\w+)">([^<]*)</P>', re.search(r'<InstanceData>(.*?)</InstanceData>', ps, re.S).group(1)))
    pars = [k for k in inst if k + '_conf' in inst]
    check('instance parameters = parameters of the delta .ssc', pars == [p for p, _ in delta_pars], str(len(pars)))
    vars_ = [k[:-len('_specify')] for k in inst if k.endswith('_specify') and not k.endswith('_nominal_specify')]
    check('instance variables = variables of the delta .ssc', vars_ == [v for v, _ in delta_vars], str(len(vars_)))
    check('variable units = units of the delta .ssc', all(inst[v + '_unit'] == u for v, u in delta_vars))
    other = lambda s: re.sub(r'<Block BlockType="(SubSystem|Reference)" Name="(%s|power_stage)".*?</Block>' % cfg['mlf'], '', s, flags=re.S)
    check('rest of system_1 unchanged', other(s1) == other(s1src))
    bd = json.loads(z.read('simulink/blockDiagram.json'))['BlockDiagram']
    check('new ModelUUID', bd['ModelUUID'] != json.loads(src.read('simulink/blockDiagram.json'))['BlockDiagram']['ModelUUID'])
    check('library type kept', bd.get('LibraryType') == 'BlockLibrary')


def main():
    delta_vars = ssc_items(DELTA_SSC, 'variables')
    delta_pars = ssc_items(DELTA_SSC, 'parameters')
    delta_link = 'afe_ssc_lib/' + ssc_block_name(DELTA_TITLE)
    # the rule reproduces the name of the star block
    assert 'afe_ssc_lib/' + ssc_block_name('AFE Two-Level Bridge with LCL Filter') == STAR_LINK
    first = re.search(r'^component\s+\w+\s*\n%\s*(.*)$', open(DELTA_SSC).read(), re.M).group(1).strip()
    assert first == DELTA_TITLE, 'title of the delta .ssc changed: %r' % first
    for cfg in BLOCKS:
        removed = make(cfg, delta_link, delta_vars)
        verify(cfg, delta_link, delta_vars, delta_pars, removed)
    print('\n%d checks failed' % n_fail)
    return 0 if n_fail == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
