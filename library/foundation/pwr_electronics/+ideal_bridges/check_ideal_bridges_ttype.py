#!/usr/bin/env python3
"""Checks of half_bridge_ttype, full_bridge_ttype and three_phase_bridge_ttype.

Pure Python (numpy only, no Simscape), written because the .ssc files were not
compiled in MATLAB. Three parts:

  A. structure of the .ssc files (all five of the package, the two-level ones
     too): the text is parsed and, for each combination of the on/off
     parameters cap_dc and ind_ac, the number of equations is compared with the
     number of variables plus outputs, and the number of equations containing
     der() with the number of differentiated variables (the Simscape rule
     "total size of differential equations must match the total size of
     differential variables", which ssc_build does not check when the structure
     depends on a parameter if). Every dynamic if (gate / diode conditions) must
     have the same number of equations in both branches; the gate indices,
     branch variables and port sides are checked too.
  B. one T-type leg at an operating point: the switch, common-emitter and
     midpoint equations of the .ssc are rebuilt one to one (piecewise-linear
     switch + antiparallel diode, Ron / Goff) and solved by enumerating the
     diode states for an imposed inductor current and imposed DC potentials.
     The 16 gate patterns are scanned; the states P, O, N, the freewheeling
     through the diodes with all gates off, the dead-time commutations (one
     switch on) and the three shoot-through patterns are compared with their
     closed-form values, so the signs of the switch voltages, the orientation
     of the diodes and the KCLs of the .ssc are verified.
  C. half_bridge_ttype in the time domain: the complete component (split DC
     link with ESR, leg, inductor) with an ideal 800 V source across + and -
     and a resistive load from a to np, three-level carrier PWM with dead
     time, backward Euler at 0.5 us. The three levels of the midpoint voltage,
     the fundamental of the midpoint voltage and of the current, the neutral-
     point voltage ripple (load current into the two banks in parallel) and
     the power balance are compared with closed-form values. With matplotlib
     installed a figure is saved next to the output (--png <file>).

Run:  python3 check_ideal_bridges_ttype.py        (exit code 0 if all pass)
      python3 check_ideal_bridges_ttype.py --png check_ideal_bridges_ttype.png
"""
import itertools
import math
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SSC_FILES = ['half_bridge_ttype.ssc', 'full_bridge_ttype.ssc',
             'three_phase_bridge_ttype.ssc', 'full_bridge.ssc',
             'three_phase_bridge.ssc']

n_checks = 0
n_failed = 0


def check(label, got, expected, tol=1e-6, rel=False):
    """Compare got with expected (absolute, or relative when rel=True)."""
    global n_checks, n_failed
    n_checks += 1
    if isinstance(expected, (bool, list, tuple, str)) or isinstance(got, (bool, list, tuple, str)) or expected is None or got is None:
        ok = (got == expected)
    else:
        err = abs(got - expected)
        if rel:
            err = err/max(abs(expected), 1e-300)
        ok = err <= tol
    if not ok:
        n_failed += 1
    fmt = (lambda x: f'{x:.6g}' if isinstance(x, (int, float, np.floating)) and not isinstance(x, bool) else str(x))
    print(f'   {label:60s} got {fmt(got)}, expected {fmt(expected)}'.ljust(110) + ('OK' if ok else 'FAIL'))
    return ok


# ======================================================================== A
def strip_comments(text):
    out = []
    for line in text.splitlines():
        # a % outside quotes starts a comment ('1/Ohm' etc. contain no %)
        in_q = False
        for k, ch in enumerate(line):
            if ch == "'":
                in_q = not in_q
            elif ch == '%' and not in_q:
                line = line[:k]
                break
        out.append(line.rstrip())
    return '\n'.join(out)


def split_statements(block):
    """Statements of an equations block: 'if cond', 'else', 'end', or an
    equation (terminated by ; at bracket depth 0, may span lines)."""
    stmts = []
    buf = ''
    depth = 0
    for line in block.splitlines():
        s = line.strip()
        if not s:
            continue
        if buf == '' and (s.startswith('if ') or s == 'else' or s == 'end' or s.startswith('elseif ')):
            stmts.append(s)
            continue
        buf += ' ' + s
        depth += s.count('[') - s.count(']')
        if depth == 0 and s.endswith(';'):
            stmts.append(buf.strip())
            buf = ''
    if buf.strip():
        raise ValueError('unterminated statement: ' + buf)
    return stmts


def eq_size(stmt):
    """Size of an equation: number of elements of a [a; b; c] side, else 1."""
    m = re.search(r'\[(.*)\]', stmt, re.S)
    if m:
        return len([e for e in m.group(1).split(';') if e.strip()])
    return 1


class Section:
    """Parsed .ssc component (the subset of the language used here)."""

    def __init__(self, path):
        text = strip_comments(open(path, encoding='utf-8').read())
        self.name = re.search(r'^\s*component\s+(\w+)', text, re.M).group(1)
        self.nodes = re.findall(r'^\s*(\w+)\s*=\s*foundation\.electrical\.electrical', text, re.M)
        blk = lambda key: re.search(r'^\s*' + key + r'\s*\n(.*?)^\s*end\s*$', text, re.M | re.S)
        self.inputs = self._sizes(blk('inputs').group(1))
        self.outputs = self._sizes(blk('outputs').group(1))
        self.parameters = re.findall(r'^\s*(\w+)\s*=', blk('parameters').group(1), re.M)
        self.variables = re.findall(r'^\s*(\w+)\s*=', blk('variables').group(1), re.M)
        self.intermediates = re.findall(r'^\s*(\w+)\s*=', blk(r'intermediates\s*\([^)]*\)').group(1), re.M)
        self.branches = re.findall(r'^\s*(\w+)\s*:\s*(\w+)\.i\s*->\s*(\w+)\.i', blk('branches').group(1), re.M)
        self.equations = split_statements(self._nested_block(text, 'equations'))
        m = re.search(r'^\s*equations\s*\(\s*Initial\s*=\s*true\s*\)\s*\n(.*?)^\s*end\s*$', text, re.M | re.S)
        self.initial = split_statements(m.group(1)) if m else []
        self.onoff_params = [p for p in self.parameters
                             if re.search(r'^\s*' + p + r'\s*=\s*ideal_bridges\.onoff', text, re.M)]
        self.sides = dict(re.findall(r'^\s*(\w+)\s*:\s*Side\s*=\s*(\w+)', text, re.M))
        self.text = text

    @staticmethod
    def _nested_block(text, key):
        """Body of the block 'key ... end' whose body contains if/else/end."""
        lines = text.splitlines()
        start = next(k for k, l in enumerate(lines) if re.fullmatch(r'\s*' + key + r'\s*', l))
        depth = 0
        for k in range(start + 1, len(lines)):
            s = lines[k].strip()
            if s.startswith('if ') or s.startswith('if('):
                depth += 1
            elif s == 'end':
                if depth == 0:
                    return '\n'.join(lines[start + 1:k])
                depth -= 1
        raise ValueError('unterminated block ' + key)

    @staticmethod
    def _sizes(block):
        out = {}
        for m in re.finditer(r'^\s*(\w+)\s*=\s*\{\s*(zeros\((\d+),\s*1\)|0)', block, re.M):
            out[m.group(1)] = int(m.group(3)) if m.group(3) else 1
        return out

    def count(self, config):
        """(equations, der equations, differentiated variables, n dynamic ifs)
        of the main equations block for config = {param: 'on'/'off'}."""
        stmts = self.equations
        pos = 0

        def parse_block():
            """Parse statements until else/end; return (n_eq, n_der, dervars)."""
            nonlocal pos
            n_eq = 0
            n_der = 0
            dervars = set()
            n_dyn = 0
            while pos < len(stmts):
                s = stmts[pos]
                if s == 'else' or s == 'end':
                    return n_eq, n_der, dervars, n_dyn
                if s.startswith('if '):
                    cond = s[3:].strip()
                    pos += 1
                    a = parse_block()
                    assert stmts[pos] == 'else', 'if without else at ' + s
                    pos += 1
                    b = parse_block()
                    assert stmts[pos] == 'end'
                    pos += 1
                    m = re.fullmatch(r'\(?\s*(\w+)\s*==\s*ideal_bridges\.onoff\.(on|off)\s*\)?', cond)
                    if m:                                   # parametric if
                        take = a if config[m.group(1)] == m.group(2) else b
                    else:                                   # dynamic if
                        n_dyn += 1
                        if a[0] != b[0] or a[1] != b[1]:
                            raise AssertionError(f'dynamic if with unequal branches: {cond}')
                        take = a
                    n_eq += take[0]
                    n_der += take[1]
                    dervars |= take[2]
                    n_dyn += take[3]
                    continue
                # plain equation
                assert '==' in s, 'not an equation: ' + s
                n_eq += eq_size(s)
                ders = re.findall(r'(\w+)\.der\b', s)
                if ders:
                    n_der += 1
                    dervars |= set(ders)
                pos += 1
            return n_eq, n_der, dervars, n_dyn

        res = parse_block()
        assert pos == len(stmts), 'unbalanced if/end'
        return res


def part_a():
    print('\n=== A. structure of the .ssc files ===')
    for fname in SSC_FILES:
        c = Section(os.path.join(HERE, fname))
        print(f'{c.name}: {len(c.nodes)} nodes {c.nodes}, G[{c.inputs["G"]}], outputs {c.outputs}, '
              f'{len(c.variables)} variables, {len(c.branches)} branches, '
              f'{len(c.intermediates)} intermediates, onoff {c.onoff_params}')
        n_out = sum(c.outputs.values())
        for values in itertools.product(['on', 'off'], repeat=len(c.onoff_params)):
            config = dict(zip(c.onoff_params, values))
            n_eq, n_der, dervars, n_dyn = c.count(config)
            tag = ' '.join(f'{k}={v}' for k, v in config.items())
            check(f'{tag}: equations = variables + outputs ({len(c.variables)} + {n_out})', n_eq, len(c.variables) + n_out)
            check(f'{tag}: der() equations = differentiated variables', n_der, len(dervars))
            undeclared = dervars - set(c.variables)
            check(f'{tag}: differentiated variables declared', len(undeclared), 0)
        # dynamic ifs: one per switch, the same number as the gate size
        n_sw = c.count(dict((p, 'on') for p in c.onoff_params))[3]
        check('dynamic ifs (switches) = size of G', n_sw, c.inputs['G'])
        gmax = max(int(k) for k in re.findall(r'G\((\d+)\)', c.text))
        check('highest gate index used = size of G', gmax, c.inputs['G'])
        check('every gate index used once', sorted(set(int(k) for k in re.findall(r'G\((\d+)\)', c.text))),
              list(range(1, c.inputs['G'] + 1)))
        # branches: variables declared, nodes declared
        check('branch currents declared as variables', all(b[0] in c.variables for b in c.branches), True)
        check('branch nodes declared', all(b[1] in c.nodes and b[2] in c.nodes for b in c.branches), True)
        # one branch per switch of the outer rails + neutral pair + capacitors
        n_ac = len([n for n in c.nodes if n in ('a', 'b', 'c')])
        if 'ttype' in c.name:
            check('branches = 2 capacitor + 3 per leg', len(c.branches), 2 + 3*n_ac)
            check('size of G = 4 per leg', c.inputs['G'], 4*n_ac)
            check('output V = [vdc; vdc1; vdc2]', c.outputs['V'], 3)
            check('initial equations (bank voltages)', len(c.initial), 2)
            check('np is a node on the left side', c.sides.get('np'), 'left')
        else:
            check('branches = 1 capacitor + 2 per leg', len(c.branches), 1 + 2*n_ac)
            check('size of G = 2 per leg', c.inputs['G'], 2*n_ac)
        check('output I = number of AC terminals', c.outputs['I'], n_ac)
        check('every port has a Side annotation', sorted(c.sides), sorted(c.nodes + list(c.inputs) + list(c.outputs)))
        # parameters hidden when off: the names must exist
        for m in re.finditer(r'\[([\w,\s]+)\]\s*:\s*ExternalAccess\s*=\s*none', c.text):
            names = [x.strip() for x in m.group(1).split(',')]
            check(f'hidden parameters exist: {", ".join(names)}', all(x in c.parameters for x in names), True)


# ======================================================================== B
RON = 1e-3
GOFF = 1e-6


def solve_leg(gates, i_a, vp, vnp, vn, Ron=RON, Goff=GOFF):
    """One T-type leg of the .ssc at an operating point.

    Unknowns vm (midpoint), vs (common emitter of Q2/Q3); the inductor current
    i_a (midpoint -> terminal) and the DC potentials are imposed. Equations of
    the .ssc:  v1 = vp - vm, v2 = vnp - vs, v3 = vm - vs, v4 = vm - vn,
    ik = vk/Ron if (gate k on or vk < 0) else vk*Goff,  i2 + i3 == 0,
    i_a == i1 - i4 - i3.  The diode states (conducting <=> vk < 0 with the
    gate off) are enumerated; the consistent one is returned.
    """
    sols = []
    off = [k for k in range(4) if not gates[k]]
    for diodes in itertools.product([False, True], repeat=len(off)):
        dstate = dict(zip(off, diodes))
        g = [1.0/Ron if (gates[k] or dstate.get(k, False)) else Goff for k in range(4)]
        # i1 = g1 (vp - vm); i2 = g2 (vnp - vs); i3 = g3 (vm - vs); i4 = g4 (vm - vn)
        # i2 + i3 = 0:            g2 vnp - g2 vs + g3 vm - g3 vs = 0
        # i_a = i1 - i4 - i3:     g1 vp - g1 vm - g4 vm + g4 vn - g3 vm + g3 vs = i_a
        A = np.array([[g[2], -(g[1] + g[2])],
                      [-(g[0] + g[3] + g[2]), g[2]]])
        rhs = np.array([-g[1]*vnp, i_a - g[0]*vp - g[3]*vn])
        vm, vs = np.linalg.solve(A, rhs)
        v = [vp - vm, vnp - vs, vm - vs, vm - vn]
        ok = all((v[k] < 0) == dstate[k] for k in off)
        if ok:
            i = [g[k]*v[k] for k in range(4)]
            sols.append(dict(vm=vm, vs=vs, v=v, i=i, i_np=i[2], diodes=dstate))
    return sols


def part_b():
    print('\n=== B. one T-type leg at an operating point (Vdc = 800 V, np = 0, Ron = 1 mOhm, Goff = 1 uS) ===')
    vp, vnp, vn = 400.0, 0.0, -400.0
    names = ['Q1', 'Q2', 'Q3', 'Q4']

    def one(gates, i_a):
        sols = solve_leg(gates, i_a, vp, vnp, vn)
        check(f'{"".join(n if g else "--" for n, g in zip(names, gates))}, i_a = {i_a:+.0f} A: one consistent solution',
              len(sols), 1)
        return sols[0]

    print('1) states P, O, N (the ones of the three-level modulation)')
    for i_a in (100.0, -100.0):
        s = one([1, 1, 0, 0], i_a)                       # P = {Q1, Q2}
        check(f'   P: vm = (+) - Ron*i_a  [i_a = {i_a:+.0f}]', s['vm'], vp - RON*i_a, 1e-3)
        check(f'   P: i1 = i_a', s['i'][0], i_a, 1e-2)
        check(f'   P: |i_np| leakage only', abs(s['i_np']) < 1e-2, True)
        s = one([0, 1, 1, 0], i_a)                       # O = {Q2, Q3}
        check(f'   O: vm = np - 2*Ron*i_a  [i_a = {i_a:+.0f}]', s['vm'], vnp - 2*RON*i_a, 1e-3)
        check(f'   O: i_np = -i_a (leg fed from np)', s['i_np'], -i_a, 1e-2)
        check(f'   O: vs halfway between np and vm', s['vs'], (vnp + s['vm'])/2, 1e-6)
        s = one([0, 0, 1, 1], i_a)                       # N = {Q3, Q4}
        check(f'   N: vm = (-) - Ron*i_a  [i_a = {i_a:+.0f}]', s['vm'], vn - RON*i_a, 1e-3)
        check(f'   N: i4 = -i_a', s['i'][3], -i_a, 1e-2)
        check(f'   N: Q2 blocking (v2 > 0)', s['v'][1] > 0, True)

    print('2) all gates off: freewheeling through D4 (i_a > 0) and D1 (i_a < 0)')
    s = one([0, 0, 0, 0], 100.0)
    check('   i_a > 0: D4 conducts, vm = (-) - Ron*i_a', s['vm'], vn - RON*100.0, 1e-3)
    check('   i_a > 0: D4 conducting', s['diodes'][3], True)
    check('   i_a > 0: neutral pair blocks (D3 forward, Q2 leakage only), |i_np| < 10 mA', abs(s['i_np']) < 1e-2, True)
    s = one([0, 0, 0, 0], -100.0)
    check('   i_a < 0: D1 conducts, vm = (+) - Ron*i_a', s['vm'], vp - RON*(-100.0), 1e-3)
    check('   i_a < 0: D1 conducting', s['diodes'][0], True)
    check('   i_a < 0: neutral pair blocks (D2 forward, Q3 leakage only), |i_np| < 10 mA', abs(s['i_np']) < 1e-2, True)
    s = one([0, 0, 0, 0], 0.0)
    check('   i_a = 0: midpoint floats between the rails', (vn < s['vm'] < vp), True)

    print('3) dead-time intervals of the three-level modulation (one switch on)')
    s = one([0, 1, 0, 0], 100.0)                         # Q2 alone, positive half-wave, i_a > 0
    check('   Q2 alone, i_a > 0: clamped to np through Q2 + D3', s['vm'], vnp - 2*RON*100.0, 1e-3)
    s = one([0, 1, 0, 0], -100.0)
    check('   Q2 alone, i_a < 0: clamped to (+) through D1', s['vm'], vp + RON*100.0, 1e-3)
    s = one([0, 0, 1, 0], -100.0)                        # Q3 alone, negative half-wave, i_a < 0
    check('   Q3 alone, i_a < 0: clamped to np through Q3 + D2', s['vm'], vnp + 2*RON*100.0, 1e-3)
    s = one([0, 0, 1, 0], 100.0)
    check('   Q3 alone, i_a > 0: clamped to (-) through D4', s['vm'], vn - RON*100.0, 1e-3)

    print('4) shoot-through patterns (i_a = 0)')
    s = one([1, 0, 1, 0], 0.0)                           # Q1 + Q3: upper bank through D2
    check('   Q1 + Q3: upper bank shorted, i_np = (vp - np)/(3 Ron)', s['i_np'], (vp - vnp)/(3*RON), 1e-3, rel=True)
    check('   Q1 + Q3: D2 conducting', s['diodes'][1], True)
    s = one([0, 1, 0, 1], 0.0)                           # Q2 + Q4: lower bank through D3
    check('   Q2 + Q4: lower bank shorted, i_np = -(np - vn)/(3 Ron)', s['i_np'], -(vnp - vn)/(3*RON), 1e-3, rel=True)
    check('   Q2 + Q4: D3 conducting', s['diodes'][2], True)
    s = one([1, 0, 0, 1], 0.0)                           # Q1 + Q4: whole link
    check('   Q1 + Q4: link shorted, i1 = (vp - vn)/(2 Ron)', s['i'][0], (vp - vn)/(2*RON), 1e-3, rel=True)
    check('   Q1 + Q4: no neutral current (midpoint at np)', abs(s['i_np']) < 1.0, True)

    print('5) scan of the 16 gate patterns, i_a = 0: which ones short a bank')
    print('      pattern      vm [V]    i_np [A]      short')
    shorted = []
    for bits in itertools.product([0, 1], repeat=4):
        s = solve_leg(list(bits), 0.0, vp, vnp, vn)
        assert len(s) == 1
        s = s[0]
        big = max(abs(x) for x in s['i']) > 1e3
        if big:
            shorted.append(bits)
        print(f'      {"".join(n if g else "--" for n, g in zip(names, bits)):12s} {s["vm"]:8.1f} {s["i_np"]:12.1f}      {"yes" if big else "-"}')
    expected = [b for b in itertools.product([0, 1], repeat=4)
                if (b[0] and b[3]) or (b[0] and b[2]) or (b[1] and b[3])]
    check('shorting patterns = (Q1&Q4) | (Q1&Q3) | (Q2&Q4)', shorted, expected)


# ======================================================================== C
def part_c(png=None):
    print('\n=== C. half_bridge_ttype in the time domain: 800 V source, load 4 Ohm from a to np, 10 kHz three-level PWM ===')
    Vdc, Cdc1, Rdc1, Cdc2, Rdc2 = 800.0, 4e-3, 1e-3, 4e-3, 1e-3
    L, RL, Rload = 1e-3, 10e-3, 4.0
    Ron, Goff = RON, GOFF
    f1, fpwm, M, dead = 50.0, 10e3, 0.8, 1e-6
    h = 0.5e-6
    T1 = 1/f1
    n_per = 2
    N = int(round(n_per*T1/h))
    vp, vn = Vdc, 0.0                                   # (-) is the reference
    w = 2*math.pi*f1
    # closed-form steady state used for the initial condition of the banks: the net neutral-point current
    # i_load*|m| has a fundamental in phase with the current, the np voltage lags it by 90 deg, so at t = 0
    # (m = 0 rising) the neutral point is at its minimum. Without this the np offset would decay with
    # tau = (C1 + C2)*(Rload + RL)/d_PN^2 ~ 130 ms (half bridge: the np offset drives a DC load current).
    u1_cf = M*Vdc/2 - 4/math.pi*dead*fpwm*Vdc/2
    z = complex(Rload + RL, w*L)
    i1_cf = u1_cf/abs(z)
    phi_cf = math.atan2(w*L, Rload + RL)
    th = np.linspace(0, 2*math.pi, 20001)[:-1]
    inp1_cf = 2/len(th)*np.sum(i1_cf*np.sin(th - phi_cf)*M*np.abs(np.sin(th))*np.exp(-1j*th))
    r1_cf = abs(inp1_cf)/(w*(Cdc1 + Cdc2))
    vnp0 = Vdc/2 + r1_cf*math.cos(np.angle(inp1_cf) - math.pi/2)   # np ripple r1*cos(wt + ang - 90 deg) at t = 0

    def gates_of(t):
        c = 2*abs((t*fpwm) % 1.0 - 0.5)                  # triangle carrier in [0, 1]
        m = M*math.sin(2*math.pi*f1*t)
        dt = dead*fpwm                                   # dead time as a carrier fraction
        if m >= 0:
            return [c < m - dt, True, c >= m + dt, False]
        return [False, c <= 1 + m - dt, True, c > 1 + m + dt]

    # unknowns: vm vs vnp va iL vc1 vc2 ic1 ic2 i1 i2 i3 i4
    idx = dict(vm=0, vs=1, vnp=2, va=3, iL=4, vc1=5, vc2=6, ic1=7, ic2=8, i1=9, i2=10, i3=11, i4=12)
    x = np.zeros(13)
    x[idx['vc1']] = Vdc - vnp0
    x[idx['vc2']] = vnp0
    x[idx['vnp']] = vnp0
    diodes = [False]*4
    log = np.zeros((N, 8))                               # t, vm, vnp, iL, vc1, vc2, i_src, i_np(net)

    def build(g, xprev):
        A = np.zeros((13, 13))
        b = np.zeros(13)
        r = 0
        # i1 = g1 (vp - vm)
        A[r, idx['i1']] = 1; A[r, idx['vm']] = g[0]; b[r] = g[0]*vp; r += 1
        # i2 = g2 (vnp - vs)
        A[r, idx['i2']] = 1; A[r, idx['vnp']] = -g[1]; A[r, idx['vs']] = g[1]; r += 1
        # i3 = g3 (vm - vs)
        A[r, idx['i3']] = 1; A[r, idx['vm']] = -g[2]; A[r, idx['vs']] = g[2]; r += 1
        # i4 = g4 (vm - vn)
        A[r, idx['i4']] = 1; A[r, idx['vm']] = -g[3]; b[r] = -g[3]*vn; r += 1
        # i2 + i3 = 0
        A[r, idx['i2']] = 1; A[r, idx['i3']] = 1; r += 1
        # iL = i1 - i4 - i3
        A[r, idx['iL']] = 1; A[r, idx['i1']] = -1; A[r, idx['i4']] = 1; A[r, idx['i3']] = 1; r += 1
        # vm - va = L (iL - iLp)/h + RL iL
        A[r, idx['vm']] = 1; A[r, idx['va']] = -1; A[r, idx['iL']] = -(L/h + RL); b[r] = -L/h*xprev[idx['iL']]; r += 1
        # va - vnp = Rload iL
        A[r, idx['va']] = 1; A[r, idx['vnp']] = -1; A[r, idx['iL']] = -Rload; r += 1
        # KCL np: ic1 + i3 + iL = ic2
        A[r, idx['ic1']] = 1; A[r, idx['i3']] = 1; A[r, idx['iL']] = 1; A[r, idx['ic2']] = -1; r += 1
        # ic1 = C1 (vc1 - vc1p)/h ;  vp - vnp = vc1 + Rdc1 ic1
        A[r, idx['ic1']] = 1; A[r, idx['vc1']] = -Cdc1/h; b[r] = -Cdc1/h*xprev[idx['vc1']]; r += 1
        A[r, idx['vnp']] = -1; A[r, idx['vc1']] = -1; A[r, idx['ic1']] = -Rdc1; b[r] = -vp; r += 1
        # ic2 = C2 (vc2 - vc2p)/h ;  vnp - vn = vc2 + Rdc2 ic2
        A[r, idx['ic2']] = 1; A[r, idx['vc2']] = -Cdc2/h; b[r] = -Cdc2/h*xprev[idx['vc2']]; r += 1
        A[r, idx['vnp']] = 1; A[r, idx['vc2']] = -1; A[r, idx['ic2']] = -Rdc2; b[r] = vn; r += 1
        assert r == 13
        return A, b

    max_iter = 0
    for k in range(N):
        t = (k + 1)*h
        gates = gates_of(t)
        xprev = x
        for it in range(20):                             # iterate on the diode states
            g = [1.0/Ron if (gates[j] or diodes[j]) else Goff for j in range(4)]
            A, b = build(g, xprev)
            x = np.linalg.solve(A, b)
            v = [vp - x[idx['vm']], x[idx['vnp']] - x[idx['vs']], x[idx['vm']] - x[idx['vs']], x[idx['vm']] - vn]
            new = [(v[j] < 0) and not gates[j] for j in range(4)]
            if new == diodes:
                break
            diodes = new
        else:
            raise RuntimeError(f'diode iteration did not converge at t = {t}')
        max_iter = max(max_iter, it + 1)
        log[k] = [t, x[idx['vm']], x[idx['vnp']], x[idx['iL']], x[idx['vc1']], x[idx['vc2']],
                  x[idx['ic1']] + x[idx['i1']],      # current into (+) from the source
                  x[idx['iL']] + x[idx['i3']]]       # net current into np: load current + neutral pair

    # steady state: the last fundamental period
    sel = log[:, 0] > (n_per - 1)*T1 - 1e-12
    t = log[sel, 0]
    vm = log[sel, 1]
    vnp = log[sel, 2]
    u = vm - vnp
    i = log[sel, 3]
    inp = log[sel, 7]

    def fund(y):
        c = 2/len(y)*np.sum(y*np.exp(-1j*w*t))
        return abs(c), math.degrees(np.angle(c))

    # three levels: (+), np, (-) at every instant (np moves with its ripple)
    dist = np.min(np.abs(np.stack([vm - vp, vm - vnp, vm - vn], axis=1)), axis=1)
    check('midpoint on one of the three levels (+), np, (-): fraction of samples', np.mean(dist < 2.0), 1.0, 0.002)
    check('midpoint voltage: highest value = (+) (band 2 V)', np.max(vm), vp, 2.0)
    check('midpoint voltage: lowest value = (-) (band 2 V)', np.min(vm), vn, 2.0)
    # Q3 (Q2) is on for 1 - |m| - dt of the carrier period and the two dead times clamp the midpoint to np
    # while sign(i) = sign(m): the np level lasts 1 - |m| + dt per carrier period on average
    check('fraction of samples at the np level = 1 - mean|m| + dead time', np.mean(np.abs(vm - vnp) < 2.0),
          1 - 2*M/math.pi + dead*fpwm, 0.005)
    u1, phu = fund(u)
    # the outer switch is on for |m| - dt of the carrier period: the dead time takes a square wave of
    # amplitude dt*Vdc/2 in phase with the current, fundamental (4/pi)*dt*Vdc/2
    check('fundamental of the midpoint voltage = m*Vdc/2 - (4/pi)*dt*Vdc/2', u1, u1_cf, 0.005, rel=True)
    i1, phi = fund(i)
    check('fundamental of the current = U1/|R + jwL|', i1, u1/abs(z), 0.01, rel=True)
    check('current lags the voltage by atan(wL/R) [deg]', (phu - phi + 540) % 360 - 180,
          math.degrees(math.atan2(w*L, Rload + RL)), 1.0)
    # neutral point: the load current returns to np; in the O state it is taken back by the leg, in the P and
    # N states it flows into the two banks (in parallel, (+) and (-) held by the source): the net np current
    # averaged over the carrier is i_load*|m| and its fundamental charges C1 + C2
    inp1, _ = fund(inp)
    th = np.linspace(0, 2*math.pi, 20001)[:-1]
    i_th = i1*np.sin(th - math.radians(phu - phi))
    m_th = M*np.abs(np.sin(th))*(1 - 2*dead*fpwm)
    inp1_expected = abs(2/len(th)*np.sum(i_th*m_th*np.exp(-1j*th)))
    check('net neutral-point current: fundamental = fund(i_load*|m|)', inp1, inp1_expected, 0.03, rel=True)
    # KCL of np with the two capacitor equations: the mean of the net np current is the drift of the banks
    drift = (Cdc2*(log[sel, 5][-1] - log[sel, 5][0]) - Cdc1*(log[sel, 4][-1] - log[sel, 4][0]))/(t[-1] - t[0])
    check('mean np current = (C2 dvc2 - C1 dvc1)/T (KCL of np) [A]', np.mean(inp), drift, 1e-3)
    check('mean np current ~ 0 once the np offset has settled [A]', np.mean(inp), 0.0, 0.3)
    vnp_shift = (log[sel, 4] - log[sel, 5])/2
    r1, _ = fund(vnp_shift)
    check('neutral-point voltage ripple at f1 = I_np1/(w (C1 + C2))', r1, inp1/(w*(Cdc1 + Cdc2)), 0.03, rel=True)
    check('mean of the two bank voltages = Vdc/2', np.mean(log[sel, 4] + log[sel, 5])/2, Vdc/2, 0.5)
    # power balance over the period
    p_src = Vdc*np.mean(log[sel, 6])
    p_load = Rload*np.mean(i**2)
    p_rl = RL*np.mean(i**2)
    check('source power = load + inductor losses (+ Ron, ESR) [relative]', p_src, p_load + p_rl, 0.02, rel=True)
    print(f'   max diode iterations per step {max_iter}, P_load = {p_load:.1f} W, I1 = {i1:.2f} A, U1 = {u1:.1f} V, '
          f'I_np1 = {inp1:.2f} A, np ripple = {r1:.2f} V')

    if png:
        try:
            import matplotlib
            matplotlib.use('Agg')
            import matplotlib.pyplot as plt
        except ImportError:
            print('   matplotlib not available, no figure')
            return
        fig, ax = plt.subplots(3, 1, figsize=(9, 8.5))
        ax[0].plot((t - t[0])*1e3, u, lw=0.6, label='v_m - v_np')
        ax[0].plot((t - t[0])*1e3, M*Vdc/2*np.sin(w*t), 'k--', lw=0.8, label='m Vdc/2')
        ax[0].set_ylabel('V'); ax[0].legend(loc='upper right'); ax[0].set_title('half_bridge_ttype: midpoint voltage (three levels)')
        ax[1].plot((t - t[0])*1e3, i, lw=0.8)
        ax[1].set_ylabel('i_a [A]'); ax[1].set_title('inductor current (load 4 Ohm from a to np)')
        ax[2].plot((log[:, 0])*1e3, log[:, 4], lw=0.8, label='v_c1 (upper bank)')
        ax[2].plot((log[:, 0])*1e3, log[:, 5], lw=0.8, label='v_c2 (lower bank)')
        ax[2].set_ylabel('V'); ax[2].set_xlabel('t [ms]'); ax[2].legend(loc='upper right')
        ax[2].set_title('bank voltages: neutral-point ripple of the half bridge (load current into C1 || C2)')
        for a in ax:
            a.grid(True, lw=0.3)
        fig.tight_layout()
        fig.savefig(png, dpi=130)
        print(f'   figure saved: {png}')


if __name__ == '__main__':
    png = None
    if '--png' in sys.argv:
        png = sys.argv[sys.argv.index('--png') + 1]
    part_a()
    part_b()
    part_c(png)
    print(f'\n{n_checks} checks, {n_failed} failed')
    sys.exit(1 if n_failed else 0)
