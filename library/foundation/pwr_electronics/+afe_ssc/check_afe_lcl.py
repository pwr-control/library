#!/usr/bin/env python3
"""Checks of the four AFE blocks with LCL filter.

  +afe_ssc/afe_two_level_lcl.ssc                       two-level, star capacitors, M 17x1
  +afe_ssc/afe_two_level_lcl_delta.ssc                 two-level, delta capacitors, M 17x1
  +afe_ttype_ssc/afe_three_level_ttype_lcl.ssc         three-level T-type, star, M 22x1
  +afe_ttype_ssc/afe_three_level_ttype_lcl_delta.ssc   three-level T-type, delta, M 22x1

Pure Python (numpy only, no Simscape), written because the .ssc files were not
compiled in MATLAB. Three parts:

  A. structure of the .ssc files. The text is parsed and, for cap_dc = on and
     off, the number of equations is compared with the number of variables
     plus outputs, and the number of equations containing der() with the
     number of differentiated variables (the Simscape rule "total size of
     differential equations must match the total size of differential
     variables", which ssc_build does not check when the structure depends
     on a parameter if). Every dynamic if (switch conditions) must have the
     same number of equations in both branches. Gate indices, branches, port
     sides, dialog groups and the size of M are checked; the star and delta
     blocks of each pair must have the same ports, parameters and M (so they
     can be swapped), the delta defaults must be the delta equivalent of the
     star defaults, and the block name of afe_two_level_lcl (first comment
     line = name of the library block that the masks of grid_forming_dqctrl
     and grid_following_dqctrl link to) must be unchanged.
  B. the equations of each .ssc against an independent circuit simulation.
     The same circuit is written as a netlist (switches as Ron/Goff
     conductances with the diode condition, the two coupled three-phase
     inductors from their positive- and zero-sequence inductances, the filter
     capacitors with series resistance in star or delta, the DC link, the
     grid as three ideal sources, a DC source with series resistance) and
     solved by modified nodal analysis with backward Euler at the step of the
     models (0.625 us), sine-triangle PWM at 4 kHz with 2 us dead time. At
     every step all the equations of the .ssc, translated to numpy (der(x) =
     backward difference), are evaluated on the solution of the circuit and
     their residuals must be zero to rounding; the currents at the ports given
     by the branches of the .ssc must be the currents of the circuit; M as
     written in the .ssc must be the circuit quantities it stands for (the new
     M(15:17) included). Two cases per block: cap_dc = on with np open, and
     cap_dc = off with the DC link outside the block and 1 uF + 1 Ohm from (-)
     (two-level) or np (T-type) to ground, which drives a zero-sequence current
     through the filter.
  C. physics of the simulated waveforms: star and delta (Cf/3, 3*Rcf) give the
     same currents and voltages; the fundamentals of i1, i2, of the capacitor
     currents and voltages follow the phasor model of the LCL filter driven
     by the fundamental of the simulated bridge voltage; the delta capacitor
     currents are 1/sqrt(3) of the star ones and lead them by 30 deg; the
     bridge voltage follows m*vdc/2 minus the dead-time error; the T-type
     gives three levels, its neutral-point current averaged over a carrier
     period follows sum(|m_x|*i1_x), and driven with two-level gate patterns
     it gives the waveforms of the two-level block.

Run:  python3 check_afe_lcl.py                  (exit code 0 if all checks pass)
      python3 check_afe_lcl.py --png figure.png   (also a figure, needs matplotlib)
"""
import math
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
PE = os.path.dirname(HERE)            # foundation/pwr_electronics
BLOCKS = {
    '2L star':  ('2L', False, os.path.join(PE, '+afe_ssc', 'afe_two_level_lcl.ssc')),
    '2L delta': ('2L', True,  os.path.join(PE, '+afe_ssc', 'afe_two_level_lcl_delta.ssc')),
    'TT star':  ('TT', False, os.path.join(PE, '+afe_ttype_ssc', 'afe_three_level_ttype_lcl.ssc')),
    'TT delta': ('TT', True,  os.path.join(PE, '+afe_ttype_ssc', 'afe_three_level_ttype_lcl_delta.ssc')),
}

n_checks = 0
n_failed = 0


def check(label, got, expected, tol=0.0, rel=False):
    """Compare got with expected (absolute, or relative when rel=True)."""
    global n_checks, n_failed
    n_checks += 1
    if isinstance(expected, (bool, list, tuple, str, dict)) or expected is None:
        ok = (got == expected)
    else:
        err = abs(got - expected)
        if rel:
            err = err/max(abs(expected), 1e-300)
        ok = err <= tol
    if not ok:
        n_failed += 1
    def fmt(x):
        if isinstance(x, (int, float, np.floating)) and not isinstance(x, bool):
            return f'{x:.6g}'
        x = str(x)
        return x if len(x) <= 24 else x[:21] + '...'
    if ok and isinstance(expected, (list, tuple, dict)) and len(str(expected)) > 24:
        txt = f'   {label:72s} equal ({len(expected)} items)'
    else:
        txt = f'   {label:72s} got {fmt(got)}, expected {fmt(expected)}'
    print(txt.ljust(124) + ('OK' if ok else 'FAIL'))
    return ok


def check_max(label, value, limit):
    """value <= limit."""
    global n_checks, n_failed
    n_checks += 1
    ok = bool(value <= limit)
    if not ok:
        n_failed += 1
    print(f'   {label:72s} {value:.3g} <= {limit:.3g}'.ljust(124) + ('OK' if ok else 'FAIL'))
    return ok


# ====================================================================== parser
def strip_comments(text):
    out = []
    for line in text.splitlines():
        in_q = False
        for k, ch in enumerate(line):
            if ch == "'":
                in_q = not in_q
            elif ch == '%' and not in_q:
                line = line[:k]
                break
        out.append(line.rstrip())
    return '\n'.join(out)


def parse_block(lines, i):
    """Statements from lines[i] to the 'else' or 'end' of this level.
    Items: ('eq', text), ('if', cond, then_items, else_items),
    ('let', [(name, expr)], items). Returns (items, next i, 'else' | 'end')."""
    items = []
    buf = ''
    depth = 0
    while i < len(lines):
        s = lines[i]
        if buf == '':
            if s == 'end':
                return items, i + 1, 'end'
            if s == 'else':
                return items, i + 1, 'else'
            if s.startswith('elseif'):
                raise ValueError('elseif not supported')
            if re.match(r'if\b', s):
                cond = s[2:].strip()
                then, i, stop = parse_block(lines, i + 1)
                els = []
                if stop == 'else':
                    els, i, stop = parse_block(lines, i)
                assert stop == 'end'
                items.append(('if', cond, then, els))
                continue
            if s == 'let':
                decls = []
                i += 1
                while lines[i] != 'in':
                    m = re.fullmatch(r'(\w+)\s*=\s*(.+);', lines[i])
                    decls.append((m.group(1), m.group(2)))
                    i += 1
                body, i, stop = parse_block(lines, i + 1)
                assert stop == 'end'
                items.append(('let', decls, body))
                continue
        buf += ' ' + s
        depth += s.count('[') - s.count(']')
        i += 1
        if depth == 0 and s.endswith(';'):
            items.append(('eq', buf.strip()[:-1].strip()))
            buf = ''
    raise ValueError('unterminated block')


class Ssc:
    """Parsed .ssc component (the subset of the language used here)."""
    SIMPLE = ('nodes', 'inputs', 'outputs', 'parameters', 'variables', 'branches', 'annotations')
    INIT = re.compile(r'equations\s*\(\s*Initial\s*=\s*true\s*\)')

    def __init__(self, path):
        raw = open(path, encoding='utf-8').read()
        m = re.search(r'^component\s+(\w+)\s*\n\s*%\s*(.+?)\s*$', raw, re.M)
        self.name, self.title = m.group(1), m.group(2)
        lines = [l.strip() for l in strip_comments(raw).splitlines() if l.strip()]
        k = next(j for j, l in enumerate(lines) if l.startswith('component '))
        sec = {}
        self.intermediates = []
        self.equations = []
        self.initial = []            # (condition or None, items)
        self.cond_annotations = []   # (condition, lines)
        i = k + 1
        while lines[i] != 'end':
            s = lines[i]
            if s in self.SIMPLE:
                body, i = self._until_end(lines, i + 1)
                sec.setdefault(s, []).extend(body)
            elif s.startswith('intermediates'):
                body, i = self._until_end(lines, i + 1)
                self.intermediates = [tuple(x.strip() for x in re.fullmatch(r'(\w+)\s*=\s*(.+);', b).groups())
                                      for b in body]
            elif s == 'equations':
                self.equations, i, stop = parse_block(lines, i + 1)
                assert stop == 'end'
            elif self.INIT.fullmatch(s):
                items, i, stop = parse_block(lines, i + 1)
                self.initial.append((None, items))
            elif s.startswith('if '):
                cond = s[3:].strip()
                i += 1
                while lines[i] != 'end':
                    t = lines[i]
                    if self.INIT.fullmatch(t):
                        items, i, stop = parse_block(lines, i + 1)
                        self.initial.append((cond, items))
                    elif t == 'annotations':
                        body, i = self._until_end(lines, i + 1)
                        self.cond_annotations.append((cond, body))
                    else:
                        raise ValueError('unexpected line in a conditional section: ' + t)
                i += 1
            else:
                raise ValueError('unexpected line: ' + s)
        self.nodes = [re.match(r'(\w+)\s*=\s*foundation\.electrical\.electrical', l).group(1) for l in sec['nodes']]
        self.inputs = dict(self._signal(l) for l in sec['inputs'])
        self.outputs = dict(self._signal(l) for l in sec['outputs'])
        self.params = {}
        self.onoff_pkg = None
        for l in sec['parameters']:
            m = re.match(r'(\w+)\s*=\s*\{\s*([-+0-9.eE]+)\s*,', l)
            if m:
                self.params[m.group(1)] = float(m.group(2))
                continue
            m = re.match(r'(\w+)\s*=\s*(\w+)\.onoff\.(on|off)\s*;', l)
            self.params[m.group(1)] = m.group(3)
            self.onoff_pkg = m.group(2)
        self.onoff_params = [p for p, v in self.params.items() if isinstance(v, str)]
        self.variables = [re.match(r'(\w+)\s*=', l).group(1) for l in sec['variables']]
        self.branches = [re.match(r'(\w+)\s*:\s*(\w+)\.i\s*->\s*(\w+)\.i\s*;', l).groups() for l in sec['branches']]
        ann = ' '.join(sec['annotations'])
        self.sides = dict(re.findall(r'(\w+)\s*:\s*Side\s*=\s*(\w+)', ann))
        self.ui = [(g, [x.strip() for x in lst.split(',') if x.strip()])
                   for g, lst in re.findall(r'UIGroup\("([^"]+)"\s*,([^)]*)\)', ann)]
        self.raw = raw
        self.text = strip_comments(raw)

    @staticmethod
    def _until_end(lines, i):
        body = []
        while lines[i] != 'end':
            body.append(lines[i])
            i += 1
        return body, i + 1

    @staticmethod
    def _signal(line):
        m = re.match(r'(\w+)\s*=\s*\{\s*(zeros\((\d+)\s*,\s*1\)|0)', line)
        return m.group(1), (int(m.group(3)) if m.group(3) else 1)


ONOFF_RE = re.compile(r'\(?\s*(\w+)\s*==\s*\w+\.onoff\.(on|off)\s*\)?$')


def split_eq(stmt):
    parts = stmt.split('==')
    assert len(parts) == 2, 'not one == in: ' + stmt
    return parts[0].strip(), parts[1].strip()


def bracket_rows(expr):
    m = re.fullmatch(r'\[(.*)\]', expr.strip(), re.S)
    return [e.strip() for e in m.group(1).split(';') if e.strip()] if m else None


def count(items, config):
    """(equations, der equations, differentiated variables, dynamic ifs) for
    config = {onoff parameter: 'on' | 'off'}."""
    n_eq = n_der = n_dyn = 0
    dervars = set()
    for it in items:
        if it[0] == 'eq':
            lhs, rhs = split_eq(it[1])
            rows = bracket_rows(rhs)
            n_eq += len(rows) if rows else 1
            ders = re.findall(r'(\w+)\.der\b', it[1])
            if ders:
                n_der += 1
                dervars |= set(ders)
            continue
        if it[0] == 'let':
            sub = count(it[2], config)
        else:
            m = ONOFF_RE.match(it[1])
            if m:
                sub = count(it[2] if config[m.group(1)] == m.group(2) else it[3], config)
            else:
                a, b = count(it[2], config), count(it[3], config)
                if a[0] != b[0] or a[1] != b[1]:
                    raise AssertionError('dynamic if with unequal branches: ' + it[1])
                sub = (a[0], a[1], a[2] | b[2], a[3] + 1)
        n_eq += sub[0]
        n_der += sub[1]
        dervars |= sub[2]
        n_dyn += sub[3]
    return n_eq, n_der, dervars, n_dyn


# ====================================================================== A
def part_a(sscs):
    print('\n=== A. structure of the .ssc files ===')
    for key, c in sscs.items():
        kind, delta, path = BLOCKS[key]
        n_out = sum(c.outputs.values())
        print(f'\n{key}: {c.name} "{c.title}"  {os.path.relpath(path, PE)}')
        print(f'   nodes {c.nodes}, G[{c.inputs["G"]}], M[{c.outputs["M"]}], {len(c.variables)} variables, '
              f'{len(c.branches)} branches, {len(c.intermediates)} intermediates, onoff {c.onoff_params}')
        for val in ('on', 'off'):
            config = {p: val for p in c.onoff_params}
            n_eq, n_der, dervars, n_dyn = count(c.equations, config)
            tag = f'cap_dc={val}'
            check(f'{tag}: equations = variables + outputs ({len(c.variables)} + {n_out})',
                  n_eq, len(c.variables) + n_out)
            check(f'{tag}: der() equations = differentiated variables', n_der, len(dervars))
            check(f'{tag}: differentiated variables declared', sorted(dervars - set(c.variables)), [])
            n_states = 9 + (0 if val == 'off' else (1 if kind == '2L' else 2))
            check(f'{tag}: number of states (inductors, capacitors, DC link)', len(dervars), n_states)
            check(f'{tag}: dynamic ifs (one per switch) = size of G', n_dyn, c.inputs['G'])
        n_ini = sum(count(items, {p: 'on' for p in c.onoff_params})[0] for cond, items in c.initial)
        check('initial equations (Vdc0/2 per bank, T-type only)', n_ini, 2 if kind == 'TT' else 0)
        gidx = [int(k) for k in re.findall(r'G\((\d+)\)', c.text)]
        check('every gate index used once, 1..size(G)', sorted(gidx), list(range(1, c.inputs['G'] + 1)))
        check('size of G', c.inputs['G'], 6 if kind == '2L' else 12)
        check('size of M', c.outputs['M'], 17 if kind == '2L' else 22)
        check('branch currents declared as variables', all(b[0] in c.variables for b in c.branches), True)
        check('branch nodes declared', all(b[1] in c.nodes and b[2] in c.nodes for b in c.branches), True)
        n_br = (1 + 6 if kind == '2L' else 2 + 9) + (3 if delta else 2)
        check('branches (DC link + switches + filter capacitors)', len(c.branches), n_br)
        check('nodes', c.nodes, ['a', 'b', 'c', 'p', 'n'] if kind == '2L' else ['a', 'b', 'c', 'p', 'np', 'n'])
        check('every port has a Side annotation', sorted(c.sides), sorted(c.nodes + list(c.inputs) + list(c.outputs)))
        check('AC ports and G on the left, DC ports and M on the right',
              all(c.sides[x] == 'left' for x in ('a', 'b', 'c', 'G')) and
              all(c.sides[x] == 'right' for x in c.nodes + ['M'] if x not in ('a', 'b', 'c')), True)
        in_ui = [p for g, lst in c.ui for p in lst]
        check('every parameter in one dialog group', sorted(in_ui), sorted(c.params))
        for cond, body in c.cond_annotations:
            for m in re.finditer(r'\[([\w,\s]+)\]\s*:\s*ExternalAccess\s*=\s*none', ' '.join(body)):
                names = [x.strip() for x in m.group(1).split(',')]
                check(f'hidden parameters exist: {", ".join(names)}', all(x in c.params for x in names), True)
        names = c.variables + [n for n, e in c.intermediates] + list(c.params)
        check('no name used twice (variables, intermediates, parameters)', len(names), len(set(names)))
        check('onoff enumeration of the own package', c.onoff_pkg,
              'afe_ssc' if kind == '2L' else 'afe_ttype_ssc')
    print('\nInterfaces of the pairs and block names')
    s, d = sscs['2L star'], sscs['2L delta']
    check('afe_two_level_lcl: block name unchanged (library link of the masks)', s.title,
          'AFE Two-Level Bridge with LCL Filter')
    for a, b in (('2L star', '2L delta'), ('TT star', 'TT delta')):
        s, d = sscs[a], sscs[b]
        check(f'{a} / {b}: same ports and sides', (s.nodes, s.sides), (d.nodes, d.sides))
        check(f'{a} / {b}: same G and M sizes', (s.inputs, s.outputs), (d.inputs, d.outputs))
        check(f'{a} / {b}: same parameter names', sorted(s.params), sorted(d.params))
        check(f'{a} / {b}: delta Cf = star Cf / 3', d.params['Cf'], s.params['Cf']/3, 1e-12, rel=True)
        check(f'{a} / {b}: delta Rcf = 3 * star Rcf', d.params['Rcf'], 3*s.params['Rcf'], 1e-12, rel=True)
        check(f'{a} / {b}: other defaults equal',
              {k: v for k, v in s.params.items() if k not in ('Cf', 'Rcf')},
              {k: v for k, v in d.params.items() if k not in ('Cf', 'Rcf')})
    s2, st = sscs['2L star'], sscs['TT star']
    common = [k for k in s2.params if k not in ('cap_dc', 'Cdc', 'Rdc')]
    check('T-type / two-level: same filter, switch and base parameters',
          {k: st.params.get(k) for k in common}, {k: s2.params[k] for k in common})
    check('T-type banks in series = two-level DC link (Cdc1*Cdc2/(Cdc1+Cdc2) = Cdc)',
          st.params['Cdc1']*st.params['Cdc2']/(st.params['Cdc1'] + st.params['Cdc2']), s2.params['Cdc'], 1e-12, rel=True)
    check('T-type banks in series: Rdc1 + Rdc2 = Rdc', st.params['Rdc1'] + st.params['Rdc2'], s2.params['Rdc'],
          1e-12, rel=True)
    # resonance of the default filter (positive sequence)
    p = s2.params
    L1 = p['L1p'] + p['Lls1']
    L2 = p['L2p'] + p['Lls2']
    f_res = math.sqrt((L1 + L2)/(L1*L2*p['Cf']))/(2*math.pi)
    f_res_d = math.sqrt((L1 + L2)/(L1*L2*3*d.params['Cf']))/(2*math.pi)
    print(f'   default LCL: L1 = {L1*1e6:.0f} uH, L2 = {L2*1e6:.0f} uH, Cf = {p["Cf"]*1e6:.0f} uF star '
          f'-> f_res = {f_res:.1f} Hz (delta 3*Cf: {f_res_d:.1f} Hz)')
    check('f_res of the defaults = 1.02 kHz (value written in the delta headers)', round(f_res/1e3, 2), 1.02)


# ====================================================================== circuit
class Circuit:
    """Modified nodal analysis with backward Euler and switch + diode pairs
    (conductance 1/Ron when the gate is on or the voltage is negative, Goff
    otherwise; the mode is iterated until it agrees with the solution)."""

    def __init__(self, h, Ron, Goff):
        self.h, self.Ron, self.Goff = h, Ron, Goff
        self.nix = {'gnd': -1}
        self.gel = []        # (name, n1, n2, g, outside)
        self.sw = []         # (name, col, emi)
        self.br = []         # dict(kind, name, n1, n2, outside, ...)

    def n(self, name):
        if name not in self.nix:
            self.nix[name] = len(self.nix) - 1
        return self.nix[name]

    def g(self, name, a, b, g, outside=False):
        self.gel.append((name, self.n(a), self.n(b), g, outside))

    def switch(self, name, col, emi):
        self.sw.append((name, self.n(col), self.n(emi)))

    def vsrc(self, name, a, b, values, outside=True):
        self.br.append(dict(kind='V', name=name, n1=self.n(a), n2=self.n(b), values=values, outside=outside))

    def cap(self, name, a, b, C, R, v0, outside=False):
        self.br.append(dict(kind='C', name=name, n1=self.n(a), n2=self.n(b), C=C, R=R, v0=v0, outside=outside))

    def ind3(self, names, froms, tos, R, Lp, L0, Lls, i0):
        """Three-phase inductor from its sequence inductances: self Ls, mutual Mm
        with Ls - Mm = Lp + Lls (positive sequence), Ls + 2 Mm = L0 + Lls (zero)."""
        lpos, lzero = Lp + Lls, L0 + Lls
        Ls, Mm = (2*lpos + lzero)/3, (lzero - lpos)/3
        L = Mm*np.ones((3, 3)) + (Ls - Mm)*np.eye(3)
        first = len(self.br)
        for k in range(3):
            self.br.append(dict(kind='L', name=names[k], n1=self.n(froms[k]), n2=self.n(tos[k]),
                                R=R, i0=i0[k], group=first, L=L, k=k, outside=False))

    def run(self, gates, nsteps):
        """gates: bool array [n_switch, nsteps] (column 0 unused). Returns a record."""
        h, Ron, Goff = self.h, self.Ron, self.Goff
        Nn = len(self.nix) - 1
        Nb = len(self.br)
        N = Nn + Nb
        A0 = np.zeros((N, N))

        def stamp_g(A, a, b, g):
            if a >= 0:
                A[a, a] += g
            if b >= 0:
                A[b, b] += g
            if a >= 0 and b >= 0:
                A[a, b] -= g
                A[b, a] -= g
        for name, a, b, gval, out in self.gel:
            stamp_g(A0, a, b, gval)
        groups = {}
        for k, e in enumerate(self.br):
            r = Nn + k
            if e['n1'] >= 0:
                A0[e['n1'], r] += 1
                A0[r, e['n1']] += 1
            if e['n2'] >= 0:
                A0[e['n2'], r] -= 1
                A0[r, e['n2']] -= 1
            if e['kind'] == 'C':
                A0[r, r] -= e['R'] + h/e['C']
            elif e['kind'] == 'L':
                groups.setdefault(e['group'], []).append(k)
        for gfirst, ks in groups.items():
            L = self.br[ks[0]]['L']
            R = self.br[ks[0]]['R']
            for ii, ki in enumerate(ks):
                for jj, kj in enumerate(ks):
                    A0[Nn + ki, Nn + kj] -= L[ii, jj]/h + (R if ii == jj else 0.0)
        col = np.array([s[1] for s in self.sw])
        emi = np.array([s[2] for s in self.sw])
        vrows = np.array([Nn + k for k, e in enumerate(self.br) if e['kind'] == 'V'], dtype=int)
        vvals = np.array([e['values'] for e in self.br if e['kind'] == 'V'])
        crows = np.array([Nn + k for k, e in enumerate(self.br) if e['kind'] == 'C'], dtype=int)
        cks = np.array([k for k, e in enumerate(self.br) if e['kind'] == 'C'], dtype=int)
        Cv = np.array([e['C'] for e in self.br if e['kind'] == 'C'])
        lgroups = [(np.array(ks), Nn + np.array(ks), self.br[ks[0]]['L']) for ks in groups.values()]
        cache = {}
        x_all = np.zeros((nsteps, N))
        vc_all = np.zeros((nsteps, len(cks)))
        isw_all = np.zeros((nsteps, len(self.sw)))
        cond_all = np.zeros((nsteps, len(self.sw)), dtype=bool)
        # initial states
        vc = np.array([e['v0'] for e in self.br if e['kind'] == 'C'], dtype=float)
        ib = np.zeros(Nb)
        for k, e in enumerate(self.br):
            if e['kind'] == 'L':
                ib[k] = e['i0']
        vc_all[0] = vc
        x_all[0, Nn:] = ib
        b = np.zeros(N)
        guess = gates[:, 1].copy()
        n_iter = 0
        n_fail = 0
        for step in range(1, nsteps):
            b[:] = 0.0
            b[vrows] = vvals[:, step]
            b[crows] = vc
            for ks, rows, L in lgroups:
                b[rows] = -(L @ ib[ks])/h
            gon = gates[:, step]
            cond = gon | guess
            for it in range(80):
                key = cond.tobytes()
                ent = cache.get(key)
                if ent is None:
                    A = A0.copy()
                    for s in range(len(self.sw)):
                        stamp_g(A, col[s], emi[s], 1.0/Ron if cond[s] else Goff)
                    ent = (A, np.linalg.inv(A))
                    cache[key] = ent
                A, Ai = ent
                x = Ai @ b
                x += Ai @ (b - A @ x)              # one step of iterative refinement
                xv = np.append(x[:Nn], 0.0)        # index -1 = ground
                vsw = xv[col] - xv[emi]
                new = gon | (vsw < 0)
                n_iter += 1
                if np.array_equal(new, cond):
                    break
                if it < 40:
                    cond = new
                else:                              # flip the most violated one only
                    bad = np.where(new != cond)[0]
                    j = bad[np.argmax(np.abs(vsw[bad]))]
                    cond = cond.copy()
                    cond[j] = new[j]
            else:
                n_fail += 1
            gsw = np.where(cond, 1.0/Ron, Goff)
            isw_all[step] = gsw*vsw
            cond_all[step] = cond
            x_all[step] = x
            ib = x[Nn:]
            vc = vc + h*ib[cks]/Cv
            vc_all[step] = vc
            guess = vsw < 0
        rec = Record(self, x_all, vc_all, isw_all, cond_all, Nn)
        rec.n_iter, rec.n_fail, rec.n_modes = n_iter, n_fail, len(cache)
        return rec


class Record:
    def __init__(self, ckt, x, vc, isw, cond, Nn):
        self.ckt, self.x, self.Nn = ckt, x, Nn
        self.V = {name: (x[:, ix] if ix >= 0 else np.zeros(len(x))) for name, ix in ckt.nix.items()}
        self.I = {e['name']: x[:, Nn + k] for k, e in enumerate(ckt.br)}
        cnames = [e['name'] for e in ckt.br if e['kind'] == 'C']
        self.vc = {nm: vc[:, k] for k, nm in enumerate(cnames)}
        self.isw = {s[0]: isw[:, k] for k, s in enumerate(ckt.sw)}
        self.cond = cond
        for name, a, b, g, out in ckt.gel:
            va = x[:, a] if a >= 0 else 0.0
            vb = x[:, b] if b >= 0 else 0.0
            self.I[name] = g*(va - vb)

    def leaving_block(self, node):
        """Current leaving the block at a port = sum of the currents flowing from
        that node into the elements outside the block."""
        ix = self.ckt.nix[node]
        tot = np.zeros(len(self.x))
        for name, a, b, g, out in self.ckt.gel:
            if out and ix in (a, b):
                tot += self.I[name] if ix == a else -self.I[name]
        for e in self.ckt.br:
            if e['outside'] and ix in (e['n1'], e['n2']):
                tot += self.I[e['name']] if ix == e['n1'] else -self.I[e['name']]
        return tot


# ====================================================================== test bench
H = 0.625e-6         # step of the local solver of the models
FPWM = 4e3           # carrier frequency
TD = 2e-6            # dead time
F0 = 50.0
W0 = 2*math.pi*F0
EDC = 700.0          # DC source
RS = 10e-3           # DC source series resistance
I2_TARGET = 0.5      # grid current, pu of ibez, in phase with the grid voltage
SHIFT = np.array([0.0, -2*math.pi/3, 2*math.pi/3])


def test_params(c):
    """Parameters of the test: the defaults of the .ssc, with zero-sequence
    inductances different from the positive-sequence ones (so that the mutual
    terms of the inductor equations matter)."""
    P = dict((k, v) for k, v in c.params.items() if not isinstance(v, str))
    P['L10'] = 0.5*P['L1p']
    P['L20'] = 0.5*P['L2p']
    if 'Vdc0' in P:
        P['Vdc0'] = EDC
    return P


def phasor_design(P, delta):
    """Steady-state phasors (phase a, peak) for i2 = I2_TARGET*ibez in phase with the grid."""
    E = P['ubez']
    Z1 = P['R1'] + 1j*W0*(P['L1p'] + P['Lls1'])
    Z2 = P['R2'] + 1j*W0*(P['L2p'] + P['Lls2'])
    Zcy = (P['Rcf'] + 1/(1j*W0*P['Cf']))/(3 if delta else 1)
    I2 = I2_TARGET*P['ibez']
    Vk = E + Z2*I2
    Ic = Vk/Zcy
    I1 = I2 + Ic
    Vm = Vk + Z1*I1
    return dict(E=E, I1=I1, I2=I2, Vk=Vk, Ic=Ic, Vm=Vm, Zcy=Zcy, Z1=Z1, Z2=Z2)


def references(nsteps, P, delta):
    t = np.arange(nsteps)*H
    d = phasor_design(P, delta)
    m = abs(d['Vm'])/(EDC/2)
    dl = np.angle(d['Vm'])
    mref = np.array([m*np.cos(W0*t + dl + s) for s in SHIFT])
    return t, d, m, mref


def carrier(t):
    ph = (t*FPWM) % 1.0
    return 1.0 - np.abs(2.0*ph - 1.0)          # triangle 0 -> 1 -> 0, peak at half period


def make_gates(kind, t, mref, two_level_patterns=False):
    c = carrier(t)
    cd = carrier(t - TD)
    m = mref
    md = mref    # the reference is smooth: m(t - TD) ~ m(t), the dead time comes from the carrier
    if kind == '2L' or two_level_patterns:
        up = c[None, :] < (1 + m)/2
        upd = cd[None, :] < (1 + md)/2
        g_up = up & upd                 # turn-on delayed by TD
        g_lo = (~up) & (~upd)
        if kind == '2L':
            G = np.empty((6, len(t)), dtype=bool)
            G[0::2] = g_up
            G[1::2] = g_lo
        else:                           # T-type with two-level patterns: P = Q1+Q2, N = Q3+Q4
            G = np.empty((12, len(t)), dtype=bool)
            G[0::4] = g_up
            G[1::4] = g_up
            G[2::4] = g_lo
            G[3::4] = g_lo
        return G
    # three-level: m >= 0: Q2 on, Q4 off, Q1 while c < m, Q3 = not Q1;
    #              m < 0:  Q3 on, Q1 off, Q4 while c < -m, Q2 = not Q4
    q1 = (m >= 0) & (c[None, :] < m)
    q4 = (m < 0) & (c[None, :] < -m)
    q1d = (md >= 0) & (cd[None, :] < md)
    q4d = (md < 0) & (cd[None, :] < -md)
    G = np.empty((12, len(t)), dtype=bool)
    G[0::4] = q1 & q1d
    G[1::4] = (~q4) & (~q4d)
    G[2::4] = (~q1) & (~q1d)
    G[3::4] = q4 & q4d
    return G


def build(kind, delta, cap_on, P, nsteps, d):
    """Netlist of the block (and of the test circuit around it)."""
    ckt = Circuit(H, P['Ron'], P['Goff'])
    t = np.arange(nsteps)*H
    # DC source with series resistance (outside)
    ckt.vsrc('Edc', 'ps', 'n', np.full(nsteps, EDC))
    ckt.g('Rs', 'ps', 'p', 1/RS, outside=True)
    # switches in the order of G
    if kind == '2L':
        for x in 'abc':
            ckt.switch(f'i_{x}h', 'p', 'm' + x)
            ckt.switch(f'i_{x}l', 'm' + x, 'n')
        ckt.cap('cdc', 'p', 'n', P['Cdc'], P['Rdc'], EDC, outside=not cap_on)
    else:
        for x in 'abc':
            ckt.switch(f'iq1_{x}', 'p', 'm' + x)
            ckt.switch(f'iq2_{x}', 'np', 'cs' + x)
            ckt.switch(f'iq3_{x}', 'm' + x, 'cs' + x)
            ckt.switch(f'iq4_{x}', 'm' + x, 'n')
        ckt.cap('cdc1', 'p', 'np', P['Cdc1'], P['Rdc1'], EDC/2, outside=not cap_on)
        ckt.cap('cdc2', 'np', 'n', P['Cdc2'], P['Rdc2'], EDC/2, outside=not cap_on)
    if not cap_on:      # path to ground: zero-sequence current through the filter
        ckt.cap('cg', 'n' if kind == '2L' else 'np', 'gnd', 1e-6, 1.0, 0.0, outside=True)
    ph = np.exp(1j*SHIFT)
    ckt.ind3(['L1a', 'L1b', 'L1c'], ['ma', 'mb', 'mc'], ['ka', 'kb', 'kc'],
             P['R1'], P['L1p'], P['L10'], P['Lls1'], (d['I1']*ph).real)
    if delta:
        Vk = d['Vk']*ph
        for nm, (i, j) in (('cab', (0, 1)), ('cbc', (1, 2)), ('cca', (2, 0))):
            Ib = (Vk[i] - Vk[j])/(P['Rcf'] + 1/(1j*W0*P['Cf']))
            ckt.cap(nm, 'k' + 'abc'[i], 'k' + 'abc'[j], P['Cf'], P['Rcf'], (Ib/(1j*W0*P['Cf'])).real)
    else:
        for k, x in enumerate('abc'):
            Ic = d['Ic']*ph[k]
            ckt.cap('c' + x, 'k' + x, 'st', P['Cf'], P['Rcf'], (Ic/(1j*W0*P['Cf'])).real)
    ckt.ind3(['L2a', 'L2b', 'L2c'], ['ka', 'kb', 'kc'], ['ta', 'tb', 'tc'],
             P['R2'], P['L2p'], P['L20'], P['Lls2'], (d['I2']*ph).real)
    for k, x in enumerate('abc'):
        ckt.vsrc('g' + x, 't' + x, 'gnd', d['E']*np.cos(W0*t + SHIFT[k]))
    return ckt


def ssc_variables(c, kind, delta, cap_on, rec):
    """Values of the variables of the .ssc taken from the circuit."""
    V = rec.V
    z = np.zeros(len(rec.x))
    v = {}
    if kind == '2L':
        v['vdc'] = V['p'] - V['n']
        v['vcap'] = rec.vc['cdc'] if cap_on else v['vdc']
        v['ic'] = rec.I['cdc'] if cap_on else z
        for x in 'abc':
            v['vm_' + x] = V['m' + x]
            v[f'i_{x}h'] = rec.isw[f'i_{x}h']
            v[f'i_{x}l'] = rec.isw[f'i_{x}l']
    else:
        v['vc1'] = rec.vc['cdc1'] if cap_on else V['p'] - V['np']
        v['vc2'] = rec.vc['cdc2'] if cap_on else V['np'] - V['n']
        v['ic1'] = rec.I['cdc1'] if cap_on else z
        v['ic2'] = rec.I['cdc2'] if cap_on else z
        for x in 'abc':
            v['vm_' + x] = V['m' + x]
            v['vs_' + x] = V['cs' + x]
            for q in (1, 2, 3, 4):
                v[f'iq{q}_{x}'] = rec.isw[f'iq{q}_{x}']
    for x in 'abc':
        v['i1_' + x] = rec.I['L1' + x]
        v['vk_' + x] = V['k' + x]
        v['i2_' + x] = rec.I['L2' + x]
    if delta:
        for xy in ('ab', 'bc', 'ca'):
            v['vc_' + xy] = rec.vc['c' + xy]
            v['icf_' + xy] = rec.I['c' + xy]
    else:
        v['vn'] = V['st']
        for x in 'abc':
            v['vc_' + x] = rec.vc['c' + x]
        v['j_ab'] = rec.I['ca']
        v['j_bc'] = -rec.I['cc']
    nodes = {'a': V['ta'], 'b': V['tb'], 'c': V['tc'], 'p': V['p'], 'n': V['n']}
    if kind == 'TT':
        nodes['np'] = V['np']
    missing = set(c.variables) - set(v)
    assert not missing, f'variables without a circuit value: {missing}'
    return v, nodes


def m_expected(kind, delta, cap_on, rec, P):
    """M from the circuit quantities (independent of the .ssc text)."""
    V, I = rec.V, rec.I
    z = np.zeros(len(rec.x))
    ib, ub, ud = P['ibez'], P['ubez'], P['udc_nom']
    i1 = [I['L1' + x] for x in 'abc']
    i2 = [I['L2' + x] for x in 'abc']
    vk = [V['k' + x] for x in 'abc']
    vt = [V['t' + x] for x in 'abc']
    if delta:
        uc = [u - sum(vk)/3 for u in vk]
        icf = [I['cab'], I['cbc'], I['cca']]
    else:
        uc = [u - V['st'] for u in vk]
        icf = [I['ca'], I['cb'], I['cc']]
    ug = [u - sum(vt)/3 for u in vt]
    vdc = V['p'] - V['n']
    rows = [x/ib for x in i1] + [x/ub for x in uc] + [x/ib for x in i2] + [x/ub for x in ug] + [vdc/ud]
    if kind == '2L':
        rows += [(I['cdc'] if cap_on else z)/ib]
        rows += [x/ib for x in icf]
    else:
        ic1 = I['cdc1'] if cap_on else z
        ic2 = I['cdc2'] if cap_on else z
        i_np = -(rec.isw['iq2_a'] + rec.isw['iq2_b'] + rec.isw['iq2_c'])     # through Q2 into np
        rows += [(ic1 + ic2)/2/ib] + [x/ib for x in icf]
        rows += [(V['p'] - V['np'])/ud, (V['np'] - V['n'])/ud, i_np/ib, ic1/ib, ic2/ib]
    return np.array(rows)


def to_py(expr, nodes):
    e = re.sub(r'\b(\w+)\.der\b', r'der__\1', expr)
    e = re.sub(r'\b(' + '|'.join(sorted(nodes, key=len, reverse=True)) + r')\.v\b', r'node__\1', e)
    e = re.sub(r'\bG\((\d+)\)', lambda m: 'G[%d]' % (int(m.group(1)) - 1), e)
    return e.replace('||', '|').replace('&&', '&')


def evaluate(c, P, config, var, nodes, G, h):
    """Residuals of the equations of the .ssc (steps 1..N-1), M of the .ssc,
    the port currents of the branches and the residuals of the initial equations."""
    ns = dict(P)
    sl = slice(1, None)
    for k, val in var.items():
        ns[k] = val[sl]
        ns['der__' + k] = np.diff(val)/h
    for k, val in nodes.items():
        ns['node__' + k] = val[sl]
    ns['G'] = G[:, sl]
    for name, expr in c.intermediates:
        ns[name] = eval(to_py(expr, c.nodes), {}, ns)
    out = []

    def walk(items, ns, out):
        for it in items:
            if it[0] == 'eq':
                lhs, rhs = split_eq(it[1])
                if lhs == 'M':
                    continue
                a = np.broadcast_to(eval(to_py(lhs, c.nodes), {}, ns), ns['G'][0].shape).astype(float)
                b = np.broadcast_to(eval(to_py(rhs, c.nodes), {}, ns), ns['G'][0].shape).astype(float)
                out.append((it[1], a - b, max(1.0, np.max(np.abs(a)), np.max(np.abs(b)))))
            elif it[0] == 'let':
                ns2 = dict(ns)
                for name, expr in it[1]:
                    ns2[name] = eval(to_py(expr, c.nodes), {}, ns2)
                walk(it[2], ns2, out)
            else:
                m = ONOFF_RE.match(it[1])
                if m:
                    walk(it[2] if config[m.group(1)] == m.group(2) else it[3], ns, out)
                else:
                    cond = eval(to_py(it[1], c.nodes), {}, ns)
                    ra, rb = [], []
                    walk(it[2], ns, ra)
                    walk(it[3], ns, rb)
                    for (la, xa, sa), (lb, xb, sb) in zip(ra, rb):
                        out.append((la + '  |  ' + lb, np.where(cond, xa, xb), max(sa, sb)))
    walk(c.equations, ns, out)
    meq = [it for it in c.equations if it[0] == 'eq' and split_eq(it[1])[0] == 'M'][0]
    M = np.array([np.broadcast_to(eval(to_py(r, c.nodes), {}, ns), ns['G'][0].shape)
                  for r in bracket_rows(split_eq(meq[1])[1])])
    leaving = {nd: np.zeros(len(ns['G'][0])) for nd in c.nodes}
    for vname, A, B in c.branches:
        leaving[B] = leaving[B] + ns[vname]
        leaving[A] = leaving[A] - ns[vname]
    # initial equations at step 0
    ns0 = dict(P)
    for k, val in var.items():
        ns0[k] = val[0]
    ini = []
    for cond, items in c.initial:
        mm = ONOFF_RE.match(cond) if cond else None
        if mm and config[mm.group(1)] != mm.group(2):
            continue
        for it in items:
            lhs, rhs = split_eq(it[1])
            ini.append((it[1], eval(to_py(lhs, c.nodes), {}, ns0) - eval(to_py(rhs, c.nodes), {}, ns0)))
    return out, M, leaving, ini


def simulate(key, c, cap_on, t_end, two_level_patterns=False, Pover=None):
    kind, delta, path = BLOCKS[key]
    P = test_params(c)
    if Pover:
        P.update(Pover)
    nsteps = int(round(t_end/H)) + 1
    t, d, m, mref = references(nsteps, P, delta)
    G = make_gates(kind, t, mref, two_level_patterns)
    ckt = build(kind, delta, cap_on, P, nsteps, d)
    rec = ckt.run(G, nsteps)
    rec.t, rec.d, rec.m, rec.mref, rec.G, rec.P = t, d, m, mref, G, P
    return rec


def part_b_one(key, c, rec, cap_on, label):
    kind, delta, path = BLOCKS[key]
    P = rec.P
    config = {p: ('on' if cap_on else 'off') for p in c.onoff_params}
    var, nodes = ssc_variables(c, kind, delta, cap_on, rec)
    Gv = np.where(rec.G, 15.0, -10.0)
    res, M, leaving, ini = evaluate(c, P, config, var, nodes, Gv, H)
    print(f'\n{key}, {label}: {len(rec.t) - 1} steps, {rec.n_modes} switch patterns, '
          f'{rec.n_iter/(len(rec.t) - 1):.2f} solves per step, mode iteration failures {rec.n_fail}')
    check('   mode iteration converged at every step', rec.n_fail, 0)
    worst = max(res, key=lambda r: np.max(np.abs(r[1]))/r[2])
    rmax = max(np.max(np.abs(r[1]))/r[2] for r in res)
    print(f'   {len(res)} scalar equations (M apart); worst relative residual {rmax:.2e} in: {worst[0][:90]}')
    check_max('   all .ssc equations satisfied by the circuit (max |residual|/scale)', rmax, 1e-9)
    # diode conduction actually exercised (gate off, current through the diode)
    gate_off_cond = (rec.cond & ~rec.G.T)[1:]
    check('   antiparallel diodes conduct with the gate off (dead time)', bool(gate_off_cond.any()), True)
    # port currents
    errs = []
    for nd in c.nodes:
        circ = rec.leaving_block({'a': 'ta', 'b': 'tb', 'c': 'tc'}.get(nd, nd))[1:]
        errs.append(np.max(np.abs(leaving[nd] - circ)))
    check_max('   port currents of the .ssc branches = circuit (max error, A)', max(errs), 1e-6*P['ibez'])
    check_max('   current out of terminal a = grid-side inductor current i2_a (A)',
              np.max(np.abs(leaving['a'] - var['i2_a'][1:])), 1e-6*P['ibez'])
    if kind == 'TT' and cap_on:
        check_max('   np open: no current at the np port (A)', np.max(np.abs(leaving['np'])), 1e-6*P['ibez'])
    # M
    Me = m_expected(kind, delta, cap_on, rec, P)[:, 1:]
    check('   size of M', M.shape[0], Me.shape[0])
    err = np.max(np.abs(M - Me), axis=1)
    check_max('   M(1:14) of the .ssc = circuit quantities (max error, pu)', np.max(err[:14]), 1e-9)
    check_max('   M(15:17), filter capacitor currents, = circuit (max error, pu)', np.max(err[14:17]), 1e-9)
    if kind == 'TT':
        check_max('   M(18:22), split DC link, = circuit (max error, pu)', np.max(err[17:22]), 1e-9)
    if delta:
        check_max('   M(15) - M(17) = M(1) - M(7): line current into the delta (pu)',
                  np.max(np.abs(M[14] - M[16] - (M[0] - M[6]))), 1e-9)
    else:
        check_max('   M(15) + M(16) + M(17) = 0 (floating star point, pu)', np.max(np.abs(M[14] + M[15] + M[16])), 1e-9)
        check_max('   M(15:17) = M(1:3) - M(7:9) (pu)', np.max(np.abs(M[14:17] - (M[0:3] - M[6:9]))), 1e-9)
    if not cap_on:
        i0 = (var['i1_a'] + var['i1_b'] + var['i1_c'])
        i0g = (var['i2_a'] + var['i2_b'] + var['i2_c'])
        print(f'   zero-sequence current through the filter (path to ground): peak {np.max(np.abs(i0)):.2f} A')
        check('   zero-sequence current flows (> 0.5 A peak)', bool(np.max(np.abs(i0)) > 0.5), True)
        check_max('   it passes the floating capacitors: sum(i1) = sum(i2) (A)', np.max(np.abs(i0 - i0g)), 1e-6)
    for lab, r in ini:
        check(f'   initial equation {lab}', float(r), 0.0, 1e-9)
    return M


# ====================================================================== C
def window(rec, periods=1):
    n = int(round(periods/F0/H))
    return slice(len(rec.t) - n, len(rec.t))


def harmonic(x, tt, k=1):
    """Phasor (peak, cosine reference) of harmonic k of x over the second half
    of tt, which holds two fundamental periods sampled uniformly. The inductor
    currents still carry a slowly decaying DC offset from the start (time
    constant (L1 + L2)/(R1 + R2 + Ron), about 0.1 s), which would leak into a
    plain DFT: the offset and its slope are taken from the means of the two
    periods (the means are not affected by the harmonics) and removed first."""
    n = len(x)//2
    m1, m2 = np.mean(x[:n]), np.mean(x[n:])
    t2 = tt[n:]
    xw = x[n:] - (m2 + (m2 - m1)*F0*(t2 - t2.mean()))
    return 2.0/n*np.sum(xw*np.exp(-1j*k*W0*t2))


def part_c(sscs, runs, Ms):
    print('\n=== C. physics of the simulated waveforms ===')
    # ---- star / delta equivalence
    for kind in ('2L', 'TT'):
        rs, rd = runs[kind + ' star'], runs[kind + ' delta']
        Msr, Mdl = Ms[kind + ' star'], Ms[kind + ' delta']
        print(f'\n{kind}: star block vs delta block (delta Cf = Cf/3, Rcf = 3*Rcf), same gates')
        check_max('   i1 abc, max difference (pu)', np.max(np.abs(Msr[0:3] - Mdl[0:3])), 1e-6)
        check_max('   i2 abc, max difference (pu)', np.max(np.abs(Msr[6:9] - Mdl[6:9])), 1e-6)
        check_max('   capacitor voltages M(4:6) (equivalent star), max difference (pu)',
                  np.max(np.abs(Msr[3:6] - Mdl[3:6])), 1e-6)
        check_max('   vdc, max difference (pu)', np.max(np.abs(Msr[12] - Mdl[12])), 1e-6)
        check_max('   star icf_a = delta icf_ab - icf_ca, max difference (pu)',
                  np.max(np.abs(Msr[14] - (Mdl[14] - Mdl[16]))), 1e-6)
    # fundamental-based checks
    for key, rec in runs.items():
        if key.endswith('2Lpat'):
            continue
        kind, delta, path = BLOCKS[key]
        P, M = rec.P, Ms[key]
        n = int(round(1/F0/H))
        sl = slice(len(rec.t) - 2*n, len(rec.t))     # two periods, the phasors are of the last one
        slm = slice(sl.start - 1, sl.stop - 1)       # M is defined from step 1
        tt = rec.t[sl]
        F = lambda x: harmonic(x, tt)
        vm = [rec.V['m' + x][sl] for x in 'abc']
        Vm = F(vm[0] - (vm[0] + vm[1] + vm[2])/3)
        E = F(rec.V['ta'][sl])
        Z1 = P['R1'] + 1j*W0*(P['L1p'] + P['Lls1'])
        Z2 = P['R2'] + 1j*W0*(P['L2p'] + P['Lls2'])
        Zc = P['Rcf'] + 1/(1j*W0*P['Cf'])
        Zcy = Zc/3 if delta else Zc
        Vk = (Vm/Z1 + E/Z2)/(1/Z1 + 1/Z2 + 1/Zcy)
        I1p = (Vm - Vk)/Z1
        I2p = (Vk - E)/Z2
        Icfp = (Vk - Vk*np.exp(-2j*math.pi/3))/Zc if delta else Vk/Zc
        I1s, I2s = F(M[0][slm])*P['ibez'], F(M[6][slm])*P['ibez']
        Ucs, Icfs = F(M[3][slm])*P['ubez'], F(M[14][slm])*P['ibez']
        print(f'\n{key}: fundamentals of the last period vs the LCL phasor model fed with the simulated bridge voltage')
        print(f'   bridge |Vm| = {abs(Vm):.2f} V, |I1| = {abs(I1s):.2f} A ({abs(I1p):.2f}), |I2| = {abs(I2s):.2f} A '
              f'({abs(I2p):.2f}), |Uc| = {abs(Ucs):.2f} V ({abs(Vk):.2f}), |Icf| = {abs(Icfs):.3f} A ({abs(Icfp):.3f})')
        check_max('   i1: |simulated - phasor| / |phasor|', abs(I1s - I1p)/abs(I1p), 2e-3)
        check_max('   i2: |simulated - phasor| / |phasor|', abs(I2s - I2p)/abs(I2p), 2e-3)
        check_max('   capacitor voltage M(4): |simulated - phasor| / |phasor|', abs(Ucs - Vk)/abs(Vk), 2e-3)
        check_max('   capacitor current M(15): |simulated - phasor| / |phasor|', abs(Icfs - Icfp)/abs(Icfp), 5e-3)
        if delta:
            Icy = F(M[14][slm] - M[16][slm])*P['ibez']           # line current into the delta
            check('   delta: |icf_ab| / |icf_a,line| = 1/sqrt(3)', abs(Icfs)/abs(Icy), 1/math.sqrt(3), 2e-3, rel=True)
            check('   delta: icf_ab leads the line current of phase a by 30 deg',
                  math.degrees(np.angle(Icfs/Icy)), 30.0, 0.2)
        # bridge voltage vs modulation index and dead time
        vdc = np.mean((rec.V['p'] - rec.V['n'])[len(rec.t) - n:])
        Vref = rec.m*vdc/2*np.exp(1j*np.angle(rec.d['Vm']))
        dv = 4/math.pi*TD*FPWM*vdc*(1.0 if kind == '2L' else 0.5)
        # conduction drop: one switch (Ron) in a two-level leg; Ron in P and N, 2*Ron in O for
        # the T-type, about 1.2*Ron on the fundamental at m = 0.93
        Vexp = Vref - dv*np.exp(1j*np.angle(I1s)) - (1.0 if kind == '2L' else 1.2)*P['Ron']*I1s
        print(f'   bridge voltage: m*vdc/2 = {abs(Vref):.2f} V, dead-time error (4/pi)*td*fpwm*vdc'
              f'{"/2" if kind == "TT" else ""} = {dv:.2f} V, simulated {abs(Vm):.2f} V, expected {abs(Vexp):.2f} V')
        # the dead-time error of the T-type is less regular (current ripple around the zero
        # crossings, change of switch pair at the zero crossings of m): wider band
        check_max('   bridge voltage: |simulated - expected| / |m*vdc/2|', abs(Vm - Vexp)/abs(Vref),
                  3e-3 if kind == '2L' else 6e-3)
    # ---- T-type: levels and neutral point
    for key in ('TT star', 'TT delta'):
        rec, M = runs[key], Ms[key]
        P = rec.P
        print(f'\n{key}: three levels and neutral point')
        sl = window(rec)
        lev = []
        for x in 'abc':
            u = (rec.V['m' + x] - rec.V['np'])[sl]
            v1 = (rec.V['p'] - rec.V['np'])[sl]
            v2 = (rec.V['np'] - rec.V['n'])[sl]
            near = (np.abs(u - v1) < 5) | (np.abs(u) < 5) | (np.abs(u + v2) < 5)
            lev.append(np.mean(near))
            if x == 'a':
                frac = [np.mean(np.abs(u - v1) < 5), np.mean(np.abs(u) < 5), np.mean(np.abs(u + v2) < 5)]
        print(f'   leg a at +vdc1 / 0 / -vdc2: {frac[0]*100:.1f} / {frac[1]*100:.1f} / {frac[2]*100:.1f} % of the period')
        check_max('   time with a midpoint more than 5 V away from the three levels (%)', 100*(1 - min(lev)), 0.1)
        check('   the three levels are used', all(f > 0.05 for f in frac), True)
        # carrier-period averages over the last two periods
        ncar = int(round(1/FPWM/H))
        n0 = window(rec, 2).start
        nper = (len(rec.t) - n0)//ncar
        idx = n0 + np.arange(nper*ncar)
        Mr = M[:, idx - 1]
        inp = Mr[19].reshape(nper, ncar).mean(axis=1)*P['ibez']
        i1 = [Mr[k].reshape(nper, ncar).mean(axis=1)*P['ibez'] for k in range(3)]
        mm = [np.abs(rec.mref[k][idx].reshape(nper, ncar).mean(axis=1)) for k in range(3)]
        pred = sum(mm[k]*i1[k] for k in range(3))
        err = np.max(np.abs(inp - pred))/P['ibez']
        print(f'   neutral-point current, carrier averages: peak {np.max(np.abs(inp)):.1f} A, '
              f'mean over the period {np.mean(inp):.2f} A')
        check_max('   carrier average of i_np = sum(|m_x| * i1_x), max error (pu)', err, 0.02)
        check_max('   mean of i_np over the period (pu)', abs(np.mean(inp))/P['ibez'], 0.01)
        vd = (Mr[17] - Mr[18])*P['udc_nom']
        vdc = np.mean(Mr[12])*P['udc_nom']
        print(f'   neutral-point unbalance vdc1 - vdc2: {np.min(vd):.2f} .. {np.max(vd):.2f} V, mean {np.mean(vd):.2f} V')
        check_max('   mean unbalance |mean(vdc1 - vdc2)| / vdc', abs(np.mean(vd))/vdc, 0.01)
        tt = rec.t[idx]
        Vu3 = harmonic(vd, tt, 3)
        In3 = harmonic(Mr[19]*P['ibez'], tt, 3)
        Zb = 1/(3j*W0*P['Cdc1']) + P['Rdc1']
        print(f'   150 Hz: |i_np| = {abs(In3):.1f} A, |vdc1 - vdc2| = {abs(Vu3):.2f} V '
              f'(|i_np|*|1/(j*3w*Cdc1) + Rdc1| = {abs(In3*Zb):.2f} V: the np current flows into the two banks)')
        check_max('   150 Hz unbalance = -i_np*(1/(j*3w*Cdc1) + Rdc1): relative error', abs(Vu3 + In3*Zb)/abs(In3*Zb), 1e-2)
        check_max('   M(14) = (M(21) + M(22))/2', np.max(np.abs(M[13] - (M[20] + M[21])/2)), 1e-12)
    # ---- T-type with two-level patterns = two-level block
    r2, rt = runs['2L star'], runs['TT star 2Lpat']
    M2, Mt = Ms['2L star'], Ms['TT star 2Lpat']
    print('\nT-type star driven with two-level patterns (P = Q1+Q2, N = Q3+Q4) vs two-level star, same gates')
    check_max('   i1, i2 abc: max difference (pu)', max(np.max(np.abs(M2[0:3] - Mt[0:3])), np.max(np.abs(M2[6:9] - Mt[6:9]))), 1e-4)
    check_max('   M(1:17): max difference (pu)', np.max(np.abs(M2[0:17] - Mt[0:17])), 1e-4)
    check_max('   neutral-point current only leakage (pu)', np.max(np.abs(Mt[19])), 1e-5)


# ====================================================================== figure
def figure(runs, Ms, path):
    try:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
    except ImportError:
        print('matplotlib not installed: no figure')
        return
    ncar = int(round(1/FPWM/H))
    n = int(round(1/F0/H))

    def avg(x):
        # carrier-period average (centred); after the end of the record the last
        # fundamental period is continued periodically, so that the average of the
        # last carrier half-period is not pulled towards zero
        xe = np.concatenate([x, x[len(x) - n:len(x) - n + ncar]])
        return np.convolve(xe, np.ones(ncar)/ncar, mode='same')[:len(x)]

    def headroom(a, top=0.45):
        # room above the curves for the legend
        lo, hi = a.get_ylim()
        a.set_ylim(lo, hi + top*(hi - lo))

    fig, ax = plt.subplots(3, 2, figsize=(13, 10.5))
    cols = ['tab:blue', 'tab:orange', 'tab:green']
    for j, kind in enumerate(('2L', 'TT')):
        rs, rd = runs[kind + ' star'], runs[kind + ' delta']
        Ms_, Md = Ms[kind + ' star'], Ms[kind + ' delta']
        P = rs.P
        sl = slice(len(rs.t) - n, len(rs.t))
        slm = slice(sl.start - 1, sl.stop - 1)
        t = rs.t[sl]*1e3
        name = 'two-level' if kind == '2L' else 'three-level T-type'
        for k in range(3):
            ax[0, j].plot(t, Ms_[k][slm]*P['ibez'], color=cols[k], lw=0.5, alpha=0.6)
            ax[0, j].plot(t, Ms_[6 + k][slm]*P['ibez'], color=cols[k], lw=1.3, label=f'i2_{"abc"[k]}')
        ax[0, j].set_title(f'{name}, star: i1 (thin) and i2 (thick), M(1:3) and M(7:9)', fontsize=10)
        ax[0, j].set_ylabel('A')
        headroom(ax[0, j], 0.25)
        ax[0, j].legend(ncol=3, fontsize=7, loc='upper center')
        for k, nm in enumerate(('a', 'b', 'c')):
            x = Ms_[14 + k]*P['ibez']
            ax[1, j].plot(t, x[slm], color=cols[k], lw=0.4, alpha=0.3)
            ax[1, j].plot(t, avg(x)[slm], color=cols[k], lw=1.6, label=f'star icf_{nm}')
        for k, nm in enumerate(('ab', 'bc', 'ca')):
            x = Md[14 + k]*rd.P['ibez']
            ax[1, j].plot(t, avg(x)[slm], color=cols[k], lw=1.6, ls='--', label=f'delta icf_{nm}')
        ax[1, j].set_title('filter capacitor currents M(15:17): star (raw thin, average thick), '
                           'delta (average, dashed)', fontsize=10)
        ax[1, j].set_ylabel('A')
        headroom(ax[1, j], 0.45)
        ax[1, j].legend(ncol=2, fontsize=7, loc='upper center')
        ax[0, j].set_xlabel('t (ms)')
        ax[1, j].set_xlabel('t (ms)')
    # leg voltages, 1 ms around the peak of i1_a
    r2, rt = runs['2L star'], runs['TT star']
    k0 = len(r2.t) - n + int(round(0.002/H))
    z = slice(k0, k0 + int(round(1e-3/H)))
    tz = r2.t[z]*1e3
    ax[2, 0].plot(tz, (r2.V['ma'] - (r2.V['p'] + r2.V['n'])/2)[z], lw=1.0, color='0.4', label='two-level: vm_a - (p + n)/2')
    ax[2, 0].plot(tz, (rt.V['ma'] - rt.V['np'])[z], lw=1.0, color='tab:red', label='T-type: vm_a - np')
    ax[2, 0].set_title('leg a voltage, 1 ms: two levels and three levels', fontsize=10)
    ax[2, 0].set_ylabel('V')
    ax[2, 0].set_xlabel('t (ms)')
    ax[2, 0].legend(fontsize=7, loc='lower right')
    Mt, P = Ms['TT star'], rt.P
    sl = slice(len(rt.t) - n, len(rt.t))
    slm = slice(sl.start - 1, sl.stop - 1)
    t = rt.t[sl]*1e3
    inp = Mt[19]*P['ibez']
    ax[2, 1].plot(t, inp[slm], lw=0.3, color='tab:red', alpha=0.35)
    ax[2, 1].plot(t, avg(inp)[slm], lw=1.6, color='tab:red', label='i_np, M(20) (raw thin, average thick)')
    ax[2, 1].set_ylabel('A')
    ax[2, 1].set_xlabel('t (ms)')
    a2 = ax[2, 1].twinx()
    a2.plot(t, ((Mt[17] - Mt[18])*P['udc_nom'])[slm], lw=1.4, color='k', label='vdc1 - vdc2, M(18) - M(19)')
    a2.set_ylabel('V')
    ax[2, 1].set_title('T-type: neutral-point current and unbalance (np open, 2 x 14.4 mF)', fontsize=10)
    headroom(ax[2, 1], 0.35)
    headroom(a2, 0.35)
    h1, l1 = ax[2, 1].get_legend_handles_labels()
    h2, l2 = a2.get_legend_handles_labels()
    a2.legend(h1 + h2, l1 + l2, ncol=2, fontsize=7, loc='upper center')    # on the twin axes: drawn on top
    fig.suptitle('check_afe_lcl.py, last period: 400 V grid, i2 = 0.5 pu, vdc 700 V, sine-triangle PWM 4 kHz, '
                 '2 us dead time, backward Euler 0.625 us, default filter (star 360 uF / delta 120 uF)', fontsize=10)
    fig.tight_layout()
    fig.savefig(path, dpi=120)
    print(f'figure: {path}')


# ====================================================================== main
def main():
    png = None
    if '--png' in sys.argv:
        png = sys.argv[sys.argv.index('--png') + 1]
    np.set_printoptions(linewidth=140)
    sscs = {key: Ssc(path) for key, (kind, delta, path) in BLOCKS.items()}
    part_a(sscs)
    print('\n=== B. the .ssc equations on an independent circuit simulation ===')
    print(f'grid 400 V 50 Hz (ideal), DC source {EDC:.0f} V + {RS*1e3:.0f} mOhm, i2 = {I2_TARGET} pu in phase with '
          f'the grid, sine-triangle PWM {FPWM/1e3:.0f} kHz, dead time {TD*1e6:.0f} us, backward Euler {H*1e6} us;')
    print('L10 = 0.5*L1p and L20 = 0.5*L2p (mutual terms of the inductors active), other parameters = defaults.')
    runs, Ms = {}, {}
    for key, c in sscs.items():
        rec = simulate(key, c, True, 0.06)
        runs[key] = rec
        Ms[key] = part_b_one(key, c, rec, True, 'cap_dc = on, np open, 60 ms')
    for key, c in sscs.items():
        rec = simulate(key, c, False, 0.02)
        part_b_one(key, c, rec, False, 'cap_dc = off, DC link outside, 1 uF + 1 Ohm to ground, 20 ms')
    rec = simulate('TT star', sscs['TT star'], True, 0.06, two_level_patterns=True)
    runs['TT star 2Lpat'] = rec
    Ms['TT star 2Lpat'] = part_b_one('TT star', sscs['TT star'], rec, True, 'two-level gate patterns, 60 ms')
    part_c(sscs, runs, Ms)
    if png:
        figure(runs, Ms, png)
    print(f'\n{n_checks} checks, {n_failed} failed')
    return 0 if n_failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
