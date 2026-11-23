#!/usr/bin/env python3
"""Checks of lit_18_pulse, the line interphase transformer (LIT) of an 18-pulse diode rectifier.

Pure Python (numpy only, no Simscape), written because the .ssc file was not
compiled in MATLAB. The equations are not retyped: lit_18_pulse.ssc is read,
its parameters are evaluated and every equation becomes a linear form in the
variables, their der() and a constant, which is solved in a circuit together
with sources, loads and diodes. The reference is an independent netlist of the
six single-phase units, written from the connection list of the header:
internal nodes X1, X2, Y2, one current per coil section, coil voltage
R i + L di/dt + N um from the dotted end, ampere-turn balance per core.

  A. structure of the .ssc: ports and sides, parameters and UILayout, asserts
     on the defaults, equations = variables + outputs, der() equations =
     differentiated variables (the Simscape rule), branches, intermediates.
  B. phasor domain (der -> j w), a resistive star load in place of each bridge:
     1. no load: bridge terminals at the line voltage, no flux;
     2. ideal cores and zero impedances: equal sharing, bridges 1 and 2 at +20
        and -20 deg from bridge 3, bridge voltage (1 + 2 cos 20)/3 of the line,
        line current (1 + 2 cos 20) times a bridge current and in phase with
        the line voltage, core voltages in closed form, flux outputs;
     3. negative sequence: the shifts of bridges 1 and 2 swap;
     4. netlist with Y4-Y5 at the polarity of Y1: unequal sharing;
     5. defaults: .ssc = netlist, sharing; copper-loss coefficients of the
        header.
  C. time domain, backward Euler, the 18 diodes as switched conductances
     (Ron, Goff), DC terminals of the three bridges in parallel:
     1. .ssc = netlist sample by sample from t = 0 (RC DC link);
     2. rated power on an RC DC link: sharing, harmonic cancellation, shifts,
        energy balance, diode currents;
     3. current-stiff DC side and small leakages: line current harmonics
        18 m +- 1 at 1/h of the fundamental, the others cancelled;
     4. commutation loop at the turn-off of a diode (impressed DC voltage):
        incremental network of the diode pattern at that instant, which gives
        1.5 n_y23^2 Ls, against the step of the reverse voltage over the di/dt
        at the current zero in the simulation.
  D. reference values of test_lit_18_pulse.m (same circuit in Simscape).

Run:  python3 check_lit_18_pulse.py        (exit code 0 if all pass, about 1 min)
"""
import cmath
import math
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SSC = os.path.join(HERE, 'lit_18_pulse.ssc')
PH = ('a', 'b', 'c')
LINE = {'a': 'A', 'b': 'B', 'c': 'C'}
DEG = math.pi/180
C20 = math.cos(20*DEG)
CB = (1 + 2*C20)/3                    # bridge voltage / line voltage, ideal

n_checks = 0
n_failed = 0


def check(label, got, expected, tol=1e-6, rel=False):
    """Compare got with expected (absolute, or relative when rel=True)."""
    global n_checks, n_failed
    n_checks += 1
    if isinstance(expected, (bool, list, tuple, str)) or isinstance(got, (bool, list, tuple, str)):
        ok = (got == expected)
    else:
        err = abs(got - expected)
        if rel:
            err = err/max(abs(expected), 1e-300)
        ok = err <= tol
    if not ok:
        n_failed += 1
    fmt = (lambda x: f'{x:.6g}' if isinstance(x, (int, float, np.floating)) and not isinstance(x, bool) else str(x))
    print(f'   {label:64s} got {fmt(got)}, expected {fmt(expected)}'.ljust(112) + ('OK' if ok else 'FAIL'))
    return ok


def nxt(k):
    return PH[(PH.index(k) + 1) % 3]


def prv(k):
    return PH[(PH.index(k) - 1) % 3]


def wrap(a):
    return (a + 180.0) % 360.0 - 180.0


def ang(z):
    return math.degrees(cmath.phase(z))


# ================================================================== .ssc reader
def strip_comment(line):
    in_q = False
    for k, ch in enumerate(line):
        if ch == "'":
            in_q = not in_q
        elif ch == '%' and not in_q:
            return line[:k]
    return line


def depth(s):
    d, in_q = 0, False
    for ch in s:
        if ch == "'":
            in_q = not in_q
        elif not in_q:
            d += (ch in '([{') - (ch in ')]}')
    return d


def split_top(s, sep):
    """Split s at sep outside brackets and quotes."""
    out, buf, d, in_q = [], '', 0, False
    for ch in s:
        if ch == "'":
            in_q = not in_q
        elif not in_q:
            d += (ch in '([{') - (ch in ')]}')
        if ch == sep and d == 0 and not in_q:
            out.append(buf)
            buf = ''
        else:
            buf += ch
    out.append(buf)
    return out


def code_statements(text):
    """Code without comments, continuation lines (... or an open bracket) joined."""
    out, buf = [], ''
    for raw in text.splitlines():
        s = strip_comment(raw).rstrip()
        cont = s.endswith('...')
        if cont:
            s = s[:-3]
        buf = (buf + ' ' + s.strip()) if buf else s.strip()
        if cont or depth(buf) > 0:
            continue
        if buf:
            out.append(buf)
        buf = ''
    return out


def to_py(expr):
    """Simscape expression -> Python: {x, 'unit'} -> (x), ^ -> **, [a; b] -> [a, b], && || ~=."""
    e = expr
    while True:
        e2 = re.sub(r"\{([^{}]*?),\s*'[^']*'\s*\}", r'(\1)', e)
        if e2 == e:
            break
        e = e2
    e = e.replace('^', '**').replace('&&', ' and ').replace('||', ' or ').replace('~=', '!=')
    e = re.sub(r'\[([^\[\]]*)\]', lambda m: '[' + m.group(1).replace(';', ',') + ']', e)
    return e


class LF:
    """Linear form {key: coefficient}: key '1' the constant, 'der:x' the derivative of x."""

    def __init__(self, d=None):
        self.d = {k: v for k, v in (d or {}).items() if v != 0.0}

    @staticmethod
    def of(v):
        return v if isinstance(v, LF) else LF({'1': float(v)})

    def is_const(self):
        return all(k == '1' for k in self.d)

    def const(self):
        if not self.is_const():
            raise ValueError('not a constant: %s' % self.d)
        return self.d.get('1', 0.0)

    def __add__(self, o):
        o = LF.of(o)
        d = dict(self.d)
        for k, v in o.d.items():
            d[k] = d.get(k, 0.0) + v
        return LF(d)

    __radd__ = __add__

    def __neg__(self):
        return LF({k: -v for k, v in self.d.items()})

    def __pos__(self):
        return self

    def __sub__(self, o):
        return self + (-LF.of(o))

    def __rsub__(self, o):
        return LF.of(o) + (-self)

    def __mul__(self, o):
        o = LF.of(o)
        if o.is_const():
            c = o.const()
            return LF({k: v*c for k, v in self.d.items()})
        if self.is_const():
            return o*self
        raise ValueError('nonlinear product in an equation')

    __rmul__ = __mul__

    def __truediv__(self, o):
        return self*(1.0/LF.of(o).const())

    def __rtruediv__(self, o):
        return LF.of(o)*(1.0/self.const())


def der(x):
    out = {}
    for k, v in LF.of(x).d.items():
        if k == '1':
            continue
        if k.startswith('der:'):
            raise ValueError('second derivative')
        out['der:' + k] = v
    return LF(out)


class NodeRef:
    def __init__(self, name):
        self.v = LF({'v:' + name: 1.0})


MATH = {'pi': math.pi, 'sqrt': math.sqrt, 'cos': math.cos, 'sin': math.sin, 'exp': math.exp,
        'zeros': (lambda n, m=1: [0.0]*(n*m))}


def ev(expr, env):
    return eval(to_py(expr), {'__builtins__': {}}, env)


class SscModel:
    """lit_18_pulse.ssc as data: declarations, equations as text, rows as linear forms."""

    def __init__(self, path):
        text = open(path).read()
        self.text = text
        self.sides = dict(re.findall(r'%\s*(\w+)\s*:\s*(left|right|top|bottom)\b', text))
        self.blocks = {}
        cur = None
        for s in code_statements(text):
            if cur is None:
                m = re.match(r'^component\s+(\w+)$', s)
                if m:
                    self.name = m.group(1)
                    continue
                m = re.match(r'^(nodes|outputs|inputs|parameters|variables|intermediates|branches|equations|'
                             r'annotations)\s*(\(.*\))?$', s)
                if m:
                    cur = m.group(1) + (m.group(2) or '').replace(' ', '')
                    self.blocks.setdefault(cur, [])
                    continue
                if s == 'end':
                    continue
                raise ValueError('unexpected statement outside the blocks: ' + s)
            if s == 'end':
                cur = None
                continue
            for st in split_top(s, ';'):
                if st.strip():
                    self.blocks[cur].append(st.strip())
        b = self.blocks
        self.nodes = [st.split('=')[0].strip() for st in b.get('nodes', [])]
        self.node_domains = [st.split('=', 1)[1].strip() for st in b.get('nodes', [])]
        self.outputs = []
        for st in b.get('outputs', []):
            name, rhs = [x.strip() for x in st.split('=', 1)]
            m = re.match(r"^\{\s*zeros\((\d+)\s*,\s*1\)\s*,\s*'([^']*)'\s*\}$", rhs)
            self.outputs.append((name, int(m.group(1)) if m else 1, m.group(2) if m else None))
        self.params = {}
        for st in b.get('parameters', []):
            name, rhs = [x.strip() for x in st.split('=', 1)]
            m = re.match(r"^\{\s*(.*?)\s*,\s*'([^']*)'\s*\}$", rhs)
            self.params[name] = (m.group(1), m.group(2))
        self.private = [tuple(x.strip() for x in st.split('=', 1)) for st in b.get('parameters(Access=private)', [])]
        self.variables = {}
        for key, access in (('variables', 'public'), ('variables(Access=private)', 'private')):
            for st in b.get(key, []):
                name, rhs = [x.strip() for x in st.split('=', 1)]
                m = re.search(r"value\s*=\s*\{\s*(.*?)\s*,\s*'([^']*)'\s*\}", rhs)
                if m:
                    init, unit = m.group(1), m.group(2)
                else:
                    m = re.match(r"^\{\s*(.*?)\s*,\s*'([^']*)'\s*\}$", rhs)
                    init, unit = m.group(1), m.group(2)
                pr = re.search(r'priority\s*=\s*priority\.(\w+)', rhs)
                self.variables[name] = dict(init=init, unit=unit, priority=pr.group(1) if pr else None,
                                            access=access)
        self.intermediates = []
        for key in b:
            if key.startswith('intermediates'):
                self.intermediates += [tuple(x.strip() for x in st.split('=', 1)) for st in b[key]]
        self.branches = []
        for st in b.get('branches', []):
            m = re.match(r'^(\w+)\s*:\s*(\w+)\.i\s*->\s*(\w+)\.i$', st)
            self.branches.append(m.groups())
        self.asserts = []
        self.equations = []
        for st in b.get('equations', []):
            if st.startswith('assert'):
                self.asserts.append(split_top(st[st.index('(') + 1:st.rindex(')')], ',')[0].strip())
            else:
                lhs, rhs = st.split('==')
                self.equations.append((lhs.strip(), rhs.strip()))
        ann = ' '.join(b.get('annotations', []))
        self.uilayout = [(g, [x.strip() for x in names.split(',') if x.strip()])
                         for g, names in re.findall(r"UIGroup\('([^']*)'\s*,([^)]*)\)", ann)]

    def defaults(self):
        return {name: float(ev(expr, dict(MATH))) for name, (expr, unit) in self.params.items()}

    def param_values(self, p):
        """p: values of the public parameters (pu, SI); returns them with the private ones."""
        vals = dict(p)
        for name, expr in self.private:
            vals[name] = float(ev(expr, {**MATH, **vals}))
        return vals

    def rows(self, p, pre='L:'):
        env = dict(MATH)
        env.update(self.param_values(p))
        env['der'] = der
        for n in self.nodes:
            env[n] = NodeRef(n)
        for v in self.variables:
            env[v] = LF({pre + v: 1.0})
        for name, size, unit in self.outputs:
            env[name] = [LF({'%s%s(%d)' % (pre, name, j + 1): 1.0}) for j in range(size)]
        for name, expr in self.intermediates:
            env[name] = ev(expr, env)
        out = []
        for lhs, rhs in self.equations:
            l, r = ev(lhs, env), ev(rhs, env)
            if isinstance(l, list) or isinstance(r, list):
                assert len(l) == len(r), 'vector equation of different sizes'
                out += [LF.of(x) - y for x, y in zip(l, r)]
            else:
                out.append(LF.of(l) - r)
        return out

    def stamp(self, net, p, pre='L:'):
        """Add the component to a Net: its branches, then one row per scalar equation."""
        for var, a, b in self.branches:
            net.branch(pre + var, a, b)
        for lf in self.rows(p, pre):
            A = {k: v for k, v in lf.d.items() if k != '1' and not k.startswith('der:')}
            C = {k[4:]: v for k, v in lf.d.items() if k.startswith('der:')}
            net.eq(A, C, -lf.d.get('1', 0.0))


# ==================================================================== network
class Net:
    """Rows sum A x + sum C dx/dt = rhs plus one KCL row per node; diodes as switched conductances.

    Through-variable convention of Simscape: a branch 'i : X -> Y' carries i from
    node X to node Y through the element (i leaves X, enters Y).
    """

    def __init__(self):
        self.idx = {}
        self.rows = []           # (A, C, rhs(t) or constant, phasor)
        self.kcl = {}
        self.diodes = []

    def var(self, name):
        if name not in self.idx:
            self.idx[name] = len(self.idx)
        return name

    def node(self, n):
        if n != 'gnd':
            self.var('v:' + n)
            self.kcl.setdefault(n, {})

    def branch(self, ivar, nfrom, nto):
        self.var(ivar)
        for n, s in ((nfrom, 1.0), (nto, -1.0)):
            self.node(n)
            if n != 'gnd':
                self.kcl[n][ivar] = self.kcl[n].get(ivar, 0.0) + s

    def eq(self, A, C=None, rhs=0.0, phasor=0.0):
        for k in list(A) + list(C or {}):
            self.var(k)
        self.rows.append((dict(A), dict(C or {}), rhs, phasor))

    def vdiff(self, n1, n2, c=1.0):
        d = {}
        if n1 != 'gnd':
            d['v:' + n1] = c
        if n2 != 'gnd':
            d['v:' + n2] = d.get('v:' + n2, 0.0) - c
        return d

    def vsrc(self, name, npos, nneg, e, E=0.0):
        """V(npos) - V(nneg) = e(t), phasor E; the current name flows from nneg to npos inside the source."""
        self.branch(name, nneg, npos)
        self.eq(self.vdiff(npos, nneg), None, e, E)

    def rl(self, name, n1, n2, R, L):
        """Series R - L, current name from n1 to n2."""
        self.branch(name, n1, n2)
        A = self.vdiff(n1, n2)
        A[name] = -R
        self.eq(A, {name: -L} if L else None)

    def res(self, name, n1, n2, R):
        self.rl(name, n1, n2, R, 0.0)

    def cap(self, name, n1, n2, C):
        self.branch(name, n1, n2)
        self.eq({name: 1.0}, self.vdiff(n1, n2, -C))

    def diode(self, name, anode, cathode):
        self.node(anode)
        self.node(cathode)
        self.diodes.append((name, anode, cathode))

    def build(self):
        rows = list(self.rows) + [(dict(t), {}, 0.0, 0.0) for t in self.kcl.values()]
        self.kcl_row = {nd: len(self.rows) + j for j, nd in enumerate(self.kcl)}
        n = len(self.idx)
        assert len(rows) == n, 'system with %d rows and %d unknowns' % (len(rows), n)
        self.A = np.zeros((n, n))
        self.C = np.zeros((n, n))
        self.ph = np.zeros(n, complex)
        self.src = []
        for r, (a, c, rhs, ph) in enumerate(rows):
            for k, v in a.items():
                self.A[r, self.idx[k]] += v
            for k, v in c.items():
                self.C[r, self.idx[k]] += v
            self.ph[r] = ph
            if callable(rhs):
                self.src.append((r, rhs))
            elif rhs != 0.0:
                self.src.append((r, (lambda val: (lambda t: val))(rhs)))
        nd = len(self.diodes)
        self.E = np.zeros((nd, n))       # diode voltage = E x
        self.R = np.zeros((n, nd))       # KCL rows of anode (+) and cathode (-)
        for j, (name, an, ca) in enumerate(self.diodes):
            for nd_, s in ((an, 1.0), (ca, -1.0)):
                if nd_ != 'gnd':
                    self.E[j, self.idx['v:' + nd_]] = s
                    self.R[self.kcl_row[nd_], j] = s
        return n

    def phasor(self, w):
        assert not self.diodes
        self.build()
        x = np.linalg.solve(self.A + 1j*w*self.C, self.ph)
        return {k: x[i] for k, i in self.idx.items()}


def transient(net, h, nsteps, Ron=1e-3, Goff=1e-9, x0=None, nrec=0, maxit=60):
    """Backward Euler; diode state by iteration (on -> off if i < 0, off -> on if v > 0).

    Returns the times, x and the diode states of the last nrec steps, and the
    largest number of iterations of a step.
    """
    n = net.build()
    M0 = net.A + net.C/h
    Ch = net.C/h
    x = np.zeros(n) if x0 is None else x0
    nd = len(net.diodes)
    st = np.zeros(nd, bool)
    cache = {}
    T, X, S = [], [], []
    itmax = 0
    for s in range(1, nsteps + 1):
        t = s*h
        rhs = Ch @ x
        for r, f in net.src:
            rhs[r] += f(t)
        for it in range(maxit):
            key = st.tobytes()
            Minv = cache.get(key)
            if Minv is None:
                g = np.where(st, 1.0/Ron, Goff)
                Minv = np.linalg.inv(M0 + (net.R*g) @ net.E)
                cache[key] = Minv
            xn = Minv @ rhs
            v = net.E @ xn
            i = np.where(st, v/Ron, Goff*v)
            new = st.copy()
            new[st & (i < 0.0)] = False
            new[(~st) & (v > 0.0)] = True
            if (new == st).all():
                break
            st = new
        else:
            raise RuntimeError('diode states not converged at t = %g s' % t)
        itmax = max(itmax, it + 1)
        x = xn
        if s > nsteps - nrec:
            T.append(t)
            X.append(x)
            S.append(st.copy())
    return np.array(T), np.array(X), np.array(S), itmax


def diode_currents(net, X, S, Ron=1e-3, Goff=1e-9):
    v = X @ net.E.T
    return np.where(S, v/Ron, Goff*v), v


# ============================================================ circuit pieces
def pu_to_si(p):
    """Per-unit convention of the header, written again (not taken from the .ssc)."""
    Zb = p['V1']**2/p['Sr']
    Lb = Zb/(2*math.pi*p['fr'])
    s = dict(Zb=Zb, Lb=Lb, Rs=p['rs']*Zb, Ls=p['ls']*Lb)
    for c in ('x12', 'x23', 'y12', 'y23', 'y45'):
        s['R' + c] = p['r_' + c]*Zb
        s['L' + c] = p['l_' + c]*Lb
    s.update(Lmx=p['lm_x']*Lb, Rfex=p['rfe_x']*Zb, Lmy=p['lm_y']*Lb, Rfey=p['rfe_y']*Zb)
    return s


def lit_netlist(net, p, pre='N:', y4_like_y1=False):
    """The six single-phase units as connected in the header.

    X_k: tapped coil X1-X2-X3, line -> X2 through rs, ls; X3 = terminal k3 of
    bridge 3; X1 = Y5 of Y_k. Y_k: tapped coil Y1-Y2-Y3 and coil Y4-Y5; Y1 =
    terminal (k+1)1 of bridge 1, Y3 = terminal (k+1)2 of bridge 2, Y4 = Y2 of
    Y_(k-1). Dotted ends X1, X2 and Y1, Y2, Y5 (Y4 instead of Y5 with
    y4_like_y1). Coil from its dotted end: v(dot) - v(other) = R i + L di/dt +
    N um, i from the dotted end; core: um = dpsi/dt, psi = Lm (sum N i - um/Rfe).
    """
    s = pu_to_si(p)
    cores = {}

    def coil(name, ndot, nother, R, L, N, core):
        net.branch(name, ndot, nother)
        A = net.vdiff(ndot, nother)
        A[name] = -R
        A[core + ':um'] = -N
        net.eq(A, {name: -L})
        cores.setdefault(core, []).append((name, N))

    for k in PH:
        X1, X2, X3 = pre + 'X1' + k, pre + 'X2' + k, k + '3'
        Y1, Y2, Y3 = nxt(k) + '1', pre + 'Y2' + k, nxt(k) + '2'
        Y5, Y4 = X1, pre + 'Y2' + prv(k)
        net.rl(pre + 'is' + k, LINE[k], X2, s['Rs'], s['Ls'])
        coil(pre + 'ix12' + k, X1, X2, s['Rx12'], s['Lx12'], 1.0, pre + 'X' + k)
        coil(pre + 'ix23' + k, X2, X3, s['Rx23'], s['Lx23'], p['n_x23'], pre + 'X' + k)
        coil(pre + 'iy12' + k, Y1, Y2, s['Ry12'], s['Ly12'], p['n_y12'], pre + 'Y' + k)
        coil(pre + 'iy23' + k, Y2, Y3, s['Ry23'], s['Ly23'], p['n_y23'], pre + 'Y' + k)
        if y4_like_y1:
            coil(pre + 'iy45' + k, Y4, Y5, s['Ry45'], s['Ly45'], 1.0, pre + 'Y' + k)
        else:
            coil(pre + 'iy54' + k, Y5, Y4, s['Ry45'], s['Ly45'], 1.0, pre + 'Y' + k)
    for core, coils in cores.items():
        Lm, Rfe = (s['Lmx'], s['Rfex']) if core[len(pre)] == 'X' else (s['Lmy'], s['Rfey'])
        net.eq({core + ':um': 1.0}, {core + ':psi': -1.0})
        A = {core + ':psi': 1.0, core + ':um': Lm/Rfe}
        for name, N in coils:
            A[name] = A.get(name, 0.0) - Lm*N
        net.eq(A)


def terminal_currents(kind, val, pre=None):
    """Currents out of the LIT at the bridge terminals, [bridge 1..3][line a..c], from a value lookup."""
    if kind == 'ssc':
        pre = pre or 'L:'
        return [[val(pre + 'i%d%s' % (j, k)) for k in PH] for j in (1, 2, 3)]
    pre = pre or 'N:'
    return [[-val(pre + 'iy12' + prv(k)) for k in PH],
            [val(pre + 'iy23' + prv(k)) for k in PH],
            [val(pre + 'ix23' + k) for k in PH]]


def add_sources(net, p, scale=1.0, seq=1):
    """Ideal star source, neutral to ground, peak phasor sqrt(2/3) V1 at the line terminals."""
    E = math.sqrt(2.0/3.0)*p['V1']*scale
    w = 2*math.pi*p['fr']
    for j, k in enumerate(PH):
        phi = -seq*2*math.pi/3*j
        net.vsrc('src:' + k, LINE[k], 'gnd', (lambda phi: (lambda t: E*math.cos(w*t + phi)))(phi),
                 E*cmath.exp(1j*phi))


def add_bridges(net):
    for j in (1, 2, 3):
        for k in PH:
            net.diode('D%d%s+' % (j, k), '%s%d' % (k, j), 'P')
            net.diode('D%d%s-' % (j, k), 'N', '%s%d' % (k, j))


DIODES = ['D%d%s%s' % (j, k, s) for j in (1, 2, 3) for k in PH for s in '+-']


def build(model, p, kind='ssc', dc=None, scale=1.0, seq=1, loads=None, y4_like_y1=False):
    """Source + LIT (.ssc rows or netlist) + bridges or resistive star loads + DC side."""
    net = Net()
    add_sources(net, p, scale, seq)
    if kind == 'ssc':
        model.stamp(net, p)
    else:
        lit_netlist(net, p, y4_like_y1=y4_like_y1)
    if loads == 'open':
        pass
    elif loads is not None:
        for j in (1, 2, 3):
            for k in PH:
                net.res('R%d%s' % (j, k), '%s%d' % (k, j), 'n%d' % j, loads)
    else:
        add_bridges(net)
    if dc is not None:
        typ = dc[0]
        if typ == 'rc':
            net.cap('cdc', 'P', 'N', dc[2])
            net.res('rdc', 'P', 'N', dc[1])
        elif typ == 'rl':
            net.rl('ldc', 'P', 'N', dc[1], dc[2])
        elif typ == 'v':
            net.vsrc('vdc', 'P', 'N', dc[1])
    return net


def fourier(y, hs):
    """Peak phasors of harmonics hs of y sampled uniformly over exactly one period."""
    Y = np.fft.rfft(y)/len(y)*2
    return {h: Y[h] for h in hs}


# ===================================================================== part A
def part_a(model):
    print('\n=== A. structure of lit_18_pulse.ssc ===')
    nodes = model.nodes
    print('   %d nodes %s, outputs %s, %d parameters (+%d private), %d variables, %d branches, %d equations' % (
        len(nodes), nodes, [(n, s) for n, s, u in model.outputs], len(model.params), len(model.private),
        len(model.variables), len(model.branches), len(model.equations)))
    check('component name', model.name, 'lit_18_pulse')
    check('line terminals A, B, C on the left', [model.sides.get(n) for n in ('A', 'B', 'C')], ['left']*3)
    bt = ['%s%d' % (k, j) for j in (1, 2, 3) for k in PH]
    check('bridge terminals a1 .. c3 declared in this order', nodes[3:], bt)
    check('bridge terminals on the right', [model.sides.get(n) for n in bt], ['right']*9)
    check('every node electrical', all(d == 'foundation.electrical.electrical' for d in model.node_domains), True)
    check('output psi: 6 flux linkages in V*s', model.outputs, [('psi', 6, 'V*s')])
    check('output psi on the right (after the nodes, like the transformers)', model.sides.get('psi'), 'right')
    # parameters and dialog
    pnames = list(model.params)
    listed = [x for g, names in model.uilayout for x in names]
    check('every public parameter in the UILayout once', sorted(listed), sorted(pnames))
    units = {u for e, u in model.params.values()}
    check('parameter units in SI base units only', units <= {'V*A', 'V', 'Hz', '1'}, True)
    p = model.defaults()
    env = {**MATH, **model.param_values(p)}
    ok = [bool(ev(a, env)) for a in model.asserts]
    check('asserts true with the defaults (%d)' % len(ok), all(ok), True)
    check('default n_x23 = 2 cos 20 deg', p['n_x23'], 2*C20, 1e-12)
    check('default n_y12 = 2 cos 20 deg', p['n_y12'], 2*C20, 1e-12)
    check('default n_y23 = 1 + 2 cos 20 deg', p['n_y23'], 1 + 2*C20, 1e-12)
    # equation and variable counts
    nvar = len(model.variables)
    nout = sum(s for n, s, u in model.outputs)
    neq = 0
    nder = 0
    dvars = set()
    for lhs, rhs in model.equations:
        size = 6 if lhs == 'psi' else 1
        neq += size
        both = lhs + ' ' + rhs
        if 'der(' in both:
            nder += size
        dvars |= set(re.findall(r'der\((\w+)\)', both))
    check('equations = variables + outputs (%d + %d)' % (nvar, nout), neq, nvar + nout)
    check('der() equations = differentiated variables', nder, len(dvars))
    check('differentiated: 9 branch currents and 6 fluxes', sorted(dvars),
          sorted(['i%d%s' % (j, k) for j in (1, 2, 3) for k in PH] + ['psi' + c + k for c in 'xy' for k in PH]))
    used = set(re.findall(r'\b(\w+)\b', ' '.join(l + ' ' + r for l, r in model.equations)))
    check('every variable used in the equations', sorted(v for v in model.variables if v not in used), [])
    check('branches: i{j}{k} from the line terminal to terminal k{j}', model.branches,
          [('i%d%s' % (j, k), LINE[k], '%s%d' % (k, j)) for k in PH for j in (1, 2, 3)])
    check('branch currents public, initial 0 A, priority high',
          all(model.variables['i%d%s' % (j, k)]['access'] == 'public' and
              model.variables['i%d%s' % (j, k)]['priority'] == 'high' and
              float(model.variables['i%d%s' % (j, k)]['init']) == 0.0 for j in (1, 2, 3) for k in PH), True)
    check('intermediates iLk = i1k + i2k + i3k', model.intermediates,
          [('iL' + k, 'i1%s + i2%s + i3%s' % (k, k, k)) for k in PH])
    rows = model.rows(p)
    check('rows from the equations (scalar)', len(rows), nvar + nout)
    print('   linear forms of the equations built from the text: %d rows, %d with der()' % (
        len(rows), sum(any(k.startswith('der:') for k in r.d) for r in rows)))
    return p


# ===================================================================== part B
def ideal(p):
    q = dict(p)
    q.update(rs=0.0, ls=0.0, lm_x=1e7, lm_y=1e7, rfe_x=1e9, rfe_y=1e9)
    for c in ('x12', 'x23', 'y12', 'y23', 'y45'):
        q['r_' + c] = 0.0
        q['l_' + c] = 0.0
    return q


def phasor_case(model, p, kind='ssc', seq=1, loads=None, y4_like_y1=False):
    net = build(model, p, kind, seq=seq, loads=loads, y4_like_y1=y4_like_y1)
    x = net.phasor(2*math.pi*p['fr'])
    val = x.__getitem__
    Ib = np.array(terminal_currents(kind, val))
    Vb = np.array([[x['v:%s%d' % (k, j)] for k in PH] for j in (1, 2, 3)])
    VL = np.array([x['v:' + LINE[k]] for k in PH])
    IL = np.array([x['src:' + k] for k in PH])
    return x, Ib, Vb, VL, IL


def part_b(model, p):
    print('\n=== B. phasor domain (der -> j w), peak phasors ===')
    w = 2*math.pi*p['fr']
    Zb = p['V1']**2/p['Sr']
    Rload = 3*CB**2*Zb                     # each bridge loaded with Sr/3 at the ideal bridge voltage
    q = ideal(p)

    print('1) no load (bridge terminals open), defaults')
    x, Ib, Vb, VL, IL = phasor_case(model, p, loads='open')
    check('max |V(k j) - V(k)| / |V(k)| over the 9 terminals', max(abs(Vb[j, i] - VL[i])/abs(VL[i])
                                                                   for j in range(3) for i in range(3)), 0, 1e-12)
    check('max |psi| [V*s]', max(abs(x['L:psi(%d)' % m]) for m in range(1, 7)), 0, 1e-9)
    check('line current [A]', max(abs(IL)), 0, 1e-12)

    print('2) ideal cores, zero impedances, resistive star load R = 3 c^2 Zb per bridge, c = (1 + 2 cos 20)/3')
    x, Ib, Vb, VL, IL = phasor_case(model, q, loads=Rload)
    Ibar = np.mean(abs(Ib))
    check('bridge current spread (max - min)/mean, 9 terminals', (abs(Ib).max() - abs(Ib).min())/Ibar, 0, 1e-6)
    for i, k in enumerate(PH):
        check('line %s: phase(I bridge 1) - phase(I bridge 3) [deg]' % k, wrap(ang(Ib[0, i]) - ang(Ib[2, i])), 20, 1e-5)
        check('line %s: phase(I bridge 2) - phase(I bridge 3) [deg]' % k, wrap(ang(Ib[1, i]) - ang(Ib[2, i])), -20, 1e-5)
    check('|V bridge| / |V line| = (1 + 2 cos 20)/3, all terminals', abs(Vb).max()/abs(VL[0]), CB, 1e-6)
    check('   min over the terminals', abs(Vb).min()/abs(VL[0]), CB, 1e-6)
    check('phase(V a3) - phase(V A) [deg]', wrap(ang(Vb[2, 0]) - ang(VL[0])), 0, 1e-5)
    check('I line / I bridge 3 = 1 + 2 cos 20 (complex ratio, magnitude)', abs(IL[0]/Ib[2, 0]), 1 + 2*C20, 1e-6)
    check('phase(I line) - phase(V line) [deg] (unity power factor)', wrap(ang(IL[0]) - ang(VL[0])), 0, 1e-5)
    umx = (1 - CB)/q['n_x23']
    u = (1 - CB*cmath.exp(1j*20*DEG) + umx)/(1 - q['n_y12']*cmath.exp(1j*120*DEG))
    for i, k in enumerate(PH):
        check('|umx_%s / V_%s - (1 - c)/n_x23|' % (k, k), abs(x['L:umx' + k]/VL[i] - umx), 0, 1e-6)
        check('|umy_%s / V_%s - u| (u from the bridge-1 equation)' % (k, k), abs(x['L:umy' + k]/VL[i] - u), 0, 1e-6)
    v2 = 1 - CB*cmath.exp(-1j*20*DEG) + umx - u*(1 + q['n_y23']*cmath.exp(1j*120*DEG))
    check('closed forms satisfy the bridge-2 equation', abs(v2), 0, 1e-12)
    check('psi(1) = umxa/(j w), psi(4) = umya/(j w)', max(abs(x['L:psi(1)'] - x['L:umxa']/(1j*w)),
                                                            abs(x['L:psi(4)'] - x['L:umya']/(1j*w))), 0, 1e-12)
    Psrc = sum(0.5*(VL[i]*IL[i].conjugate()).real for i in range(3))
    Pload = sum(0.5*abs(Vb[j, i] - x['v:n%d' % (j + 1)])**2/Rload for j in range(3) for i in range(3))
    check('P source = P load (lossless), relative', Psrc, Pload, 1e-9, rel=True)
    check('P source / Sr (rated loading)', Psrc/p['Sr'], 1.0, 1e-6)
    Vph = p['V1']/math.sqrt(3)
    print('   coil voltages at %.4g kV (rms): X1-X2 %.0f V, X2-X3 %.0f V, Y4-Y5 %.0f V, Y1-Y2 %.0f V, Y2-Y3 %.0f V' % (
        p['V1']/1e3, umx*Vph, umx*q['n_x23']*Vph, abs(u)*Vph, abs(u)*q['n_y12']*Vph, abs(u)*q['n_y23']*Vph))
    Ir = p['Sr']/(math.sqrt(3)*p['V1'])
    i12, i3 = 2*C20/(1 + 2*C20)*Ir, Ir/(1 + 2*C20)
    sx = 0.5*(umx*Vph*i12 + umx*q['n_x23']*Vph*i3)
    sy = 0.5*(abs(u)*Vph*i12 + abs(u)*(q['n_y12'] + q['n_y23'])*Vph*i3)
    print('   coil currents at rated line current %.1f A: %.1f A (X1-X2, Y4-Y5), %.1f A (X2-X3, Y1-Y2, Y2-Y3); rating'
          ' 1/2 sum V I: X core %.1f kVA, Y core %.1f kVA, LIT %.1f %% of Sr' % (
              Ir, i12, i3, sx/1e3, sy/1e3, 100*3*(sx + sy)/p['Sr']))

    print('3) negative sequence, ideal')
    x, Ib, Vb, VL, IL = phasor_case(model, q, seq=-1, loads=Rload)
    check('bridge current spread', (abs(Ib).max() - abs(Ib).min())/np.mean(abs(Ib)), 0, 1e-6)
    check('line a: phase(I bridge 1) - phase(I bridge 3) [deg]', wrap(ang(Ib[0, 0]) - ang(Ib[2, 0])), -20, 1e-5)
    check('line a: phase(I bridge 2) - phase(I bridge 3) [deg]', wrap(ang(Ib[1, 0]) - ang(Ib[2, 0])), 20, 1e-5)

    print('4) netlist, ideal: dotted Y5 (as in the .ssc) and Y4 at the polarity of Y1')
    x1, Ib1, Vb1, VL1, IL1 = phasor_case(model, q, loads=Rload)
    x2, Ib2, Vb2, VL2, IL2 = phasor_case(model, q, kind='net', loads=Rload)
    check('.ssc = netlist: max |dI| / I over the 9 terminals', abs(Ib1 - Ib2).max()/abs(Ib1).max(), 0, 1e-6)
    check('.ssc = netlist: max |dV| / V over the 9 terminals', abs(Vb1 - Vb2).max()/abs(Vb1).max(), 0, 1e-6)
    x3, Ib3, Vb3, VL3, IL3 = phasor_case(model, q, kind='net', loads=Rload, y4_like_y1=True)
    r = abs(Ib3[:, 0])/abs(Ib3[2, 0])
    print('   Y4 like Y1: |I bridge 1, 2, 3| / |I bridge 3| = %.3f, %.3f, 1, phases %+.1f, %+.1f deg' % (
        r[0], r[1], wrap(ang(Ib3[0, 0]) - ang(Ib3[2, 0])), wrap(ang(Ib3[1, 0]) - ang(Ib3[2, 0]))))
    check('Y4 like Y1: max/min bridge current > 1.5 (no equal sharing)', bool(r.max()/r.min() > 1.5), True)

    print('5) defaults (rs %.3g, ls %.3g, coils r = l = %.3g, lm %g, rfe %g pu), same load' % (
        p['rs'], p['ls'], p['l_x12'], p['lm_x'], p['rfe_x']))
    x1, Ib1, Vb1, VL1, IL1 = phasor_case(model, p, loads=Rload)
    x2, Ib2, Vb2, VL2, IL2 = phasor_case(model, p, kind='net', loads=Rload)
    check('.ssc = netlist: max |dI| / I over the 9 terminals', abs(Ib1 - Ib2).max()/abs(Ib1).max(), 0, 1e-9)
    check('.ssc = netlist: max |dV| / V over the 9 terminals', abs(Vb1 - Vb2).max()/abs(Vb1).max(), 0, 1e-9)
    check('.ssc = netlist: line currents', abs(IL1 - IL2).max()/abs(IL1).max(), 0, 1e-9)
    for nm, a, b in (('psi X_a', x1['L:psi(1)'], x2['N:Xa:psi']), ('psi Y_c', x1['L:psi(6)'], x2['N:Yc:psi'])):
        check('.ssc = netlist: %s' % nm, abs(a - b)/abs(a), 0, 1e-9)
    spread = (abs(Ib1).max() - abs(Ib1).min())/np.mean(abs(Ib1))
    check('sharing spread with the defaults < 0.5 %', bool(spread < 5e-3), True)
    print('   spread %.3f %%, phases %+.3f / %+.3f deg, |V bridge|/|V line| %.4f' % (
        100*spread, wrap(ang(Ib1[0, 0]) - ang(Ib1[2, 0])), wrap(ang(Ib1[1, 0]) - ang(Ib1[2, 0])),
        np.mean(abs(Vb1))/abs(VL1[0])))
    # copper losses of the header: ideal cores and turns, coil resistances only
    qr = ideal(p)
    for c, val in (('x12', 1.0), ('x23', 2.0), ('y12', 3.0), ('y23', 4.0), ('y45', 5.0)):
        qr['r_' + c] = val*1e-4
    qr['rs'] = 6e-4
    x, Ib, Vb, VL, IL = phasor_case(model, qr, loads=Rload)
    Ilr = p['Sr']/(math.sqrt(3)*p['V1'])*math.sqrt(2)          # rated line current, peak
    s = pu_to_si(qr)
    pcu = 0.0
    for i, k in enumerate(PH):
        i1, i2, i3 = x['L:i1' + k], x['L:i2' + k], x['L:i3' + k]
        pcu += 0.5*(s['Rs']*abs(i1 + i2 + i3)**2 + (s['Rx12'] + s['Ry45'])*abs(i1 + i2)**2 + s['Rx23']*abs(i3)**2
                    + s['Ry12']*abs(i1)**2 + s['Ry23']*abs(i2)**2)
    scale = (Ilr/np.mean(abs(IL)))**2
    expected = qr['rs'] + 0.426*(qr['r_x12'] + qr['r_y45']) + 0.121*(qr['r_x23'] + qr['r_y12'] + qr['r_y23'])
    check('Pcu/Sr at rated current = rs + 0.426 (r_x12 + r_y45) + 0.121 (...)', pcu*scale/p['Sr'], expected, 2e-3, rel=True)
    check('   exact coefficients (2 cos 20/(1 + 2 cos 20))^2, (1/(1 + 2 cos 20))^2', pcu*scale/p['Sr'],
          qr['rs'] + (2*C20/(1 + 2*C20))**2*(qr['r_x12'] + qr['r_y45'])
          + (1/(1 + 2*C20))**2*(qr['r_x23'] + qr['r_y12'] + qr['r_y23']), 2e-3, rel=True)
    check('   power balance P source = P load + P cu', sum(0.5*(VL[i]*IL[i].conjugate()).real for i in range(3)),
          sum(0.5*abs(Vb[j, i] - x['v:n%d' % (j + 1)])**2/Rload for j in range(3) for i in range(3)) + pcu,
          1e-9, rel=True)


# ===================================================================== part C
def run_case(model, p, dc, nper, spp, kind='ssc', nrec_per=1, Ron=1e-3, Goff=1e-9, scale=1.0, vdc0=None):
    net = build(model, p, kind, dc=dc, scale=scale)
    net.build()
    x0 = np.zeros(len(net.idx))
    if vdc0 is not None:
        x0[net.idx['v:P']] = vdc0/2
        x0[net.idx['v:N']] = -vdc0/2
    if dc[0] == 'rl' and len(dc) > 3:
        x0[net.idx['ldc']] = dc[3]
    h = 1.0/(p['fr']*spp)
    T, X, S, itmax = transient(net, h, nper*spp, Ron, Goff, x0, nrec_per*spp)
    return net, T, X, S, itmax, h


def waveforms(net, X, S, kind='ssc', Ron=1e-3, Goff=1e-9):
    val = (lambda name: X[:, net.idx[name]])
    Ib = np.array(terminal_currents(kind, val))            # [bridge][line][sample]
    IL = Ib.sum(axis=0)
    vdc = X[:, net.idx['v:P']] - X[:, net.idx['v:N']]
    idd, vd = diode_currents(net, X, S, Ron, Goff)
    return Ib, IL, vdc, idd, vd


def turn_off(T, i, v, s, h, fit_us=20.0, after=(20.0, 120.0)):
    """First turn-off in the record (state on at sample e, off at e + 1): di/dt at the current zero (parabola
    through the fit_us before), step of the reverse voltage at the zero (line fitted 20 to 120 us after)."""
    m = max(4, int(round(fit_us*1e-6/h)))
    ev = np.where(s[:-1] & ~s[1:])[0]
    e = ev[ev >= m][0]
    sl = slice(e - m + 1, e + 1)
    pp = np.polyfit(T[sl], i[sl], 2)
    r = np.roots(pp).real
    r0 = r[np.argmin(abs(r - T[e]))]
    didt = -np.polyval(np.polyder(pp), r0)
    a0 = e + 1 + int(after[0]*1e-6/h)
    a1 = e + 1 + int(after[1]*1e-6/h)
    pr = np.polyfit(T[a0:a1], -v[a0:a1], 1)
    return e, didt, np.polyval(pr, r0), pr[0]


def part_c(model, p):
    print('\n=== C. time domain: backward Euler, diodes Ron 1 mOhm / Goff 1 nS, bridges in parallel on DC ===')
    Sr, V1, fr = p['Sr'], p['V1'], p['fr']
    Vd = 16.9e3                                            # DC voltage of the RC case, about 1.22 V1
    Rdc = Vd**2/Sr
    dc_rc = ('rc', Rdc, 2e-3)

    print('1) .ssc = netlist, defaults, RC DC link (R %.2f Ohm, 2 mF) precharged at %.1f kV, 3 periods from t = 0'
          % (Rdc, Vd/1e3))
    spp = 8000
    res = {}
    for kind in ('ssc', 'net'):
        net, T, X, S, itmax, h = run_case(model, p, dc_rc, 3, spp, kind=kind, nrec_per=3, vdc0=Vd)
        res[kind] = (waveforms(net, X, S, kind), S)
    (Ib1, IL1, vdc1, _, _), S1 = res['ssc']
    (Ib2, IL2, vdc2, _, _), S2 = res['net']
    check('same diode states at every step', bool((S1 == S2).all()), True)
    check('max |d i bridge terminal| / peak', abs(Ib1 - Ib2).max()/abs(Ib1).max(), 0, 1e-6)
    check('max |d Vdc| / Vdc', abs(vdc1 - vdc2).max()/Vd, 0, 1e-9)

    print('2) defaults at rated power, RC DC link, 20 periods, last one analysed (%d steps per period)' % spp)
    net, T, X, S, itmax, h = run_case(model, p, dc_rc, 20, spp, nrec_per=2, vdc0=Vd)
    Ib, IL, vdc, idd, vd = waveforms(net, X, S)
    last = slice(spp, 2*spp)
    check('steady state: Vdc mean of period 20 / period 19', vdc[last].mean()/vdc[:spp].mean(), 1.0, 2e-4)
    idc = np.array([sum(idd[last, DIODES.index('D%d%s+' % (j, k))] for k in PH).mean() for j in (1, 2, 3)])
    check('DC current sharing (max - min)/mean < 1 %', bool((idc.max() - idc.min())/idc.mean() < 0.01), True)
    H = fourier(IL[0, last], range(1, 40))
    I1 = abs(H[1])
    for hh in (5, 7, 11, 13):
        check('line current harmonic %d < 0.2 %% of the fundamental' % hh, bool(abs(H[hh])/I1 < 2e-3), True)
    for hh in (17, 19):
        check('line current harmonic %d > 2 %% (characteristic)' % hh, bool(abs(H[hh])/I1 > 0.02), True)
    F = [fourier(Ib[j, 0, last], [1])[1] for j in range(3)]
    check('phase(I a1) - phase(I a3) [deg]', wrap(ang(F[0]) - ang(F[2])), 20, 0.5)
    check('phase(I a2) - phase(I a3) [deg]', wrap(ang(F[1]) - ang(F[2])), -20, 0.5)
    check('|I a1| / |I a3| (fundamental)', abs(F[0])/abs(F[2]), 1.0, 0.01)
    check('|I a2| / |I a3| (fundamental)', abs(F[1])/abs(F[2]), 1.0, 0.01)
    # energy balance over the last period
    val = (lambda name: X[last, net.idx[name]])
    t = T[last]
    w = 2*math.pi*fr
    E_src = 0.0
    for j, k in enumerate(PH):
        E_src += h*np.sum(math.sqrt(2/3)*V1*np.cos(w*t - 2*math.pi/3*j)*val('src:' + k))
    s = pu_to_si(p)
    E_cu = 0.0
    for k in PH:
        i1, i2, i3 = val('L:i1' + k), val('L:i2' + k), val('L:i3' + k)
        E_cu += h*np.sum(s['Rs']*(i1 + i2 + i3)**2 + (s['Rx12'] + s['Ry45'])*(i1 + i2)**2 + s['Rx23']*i3**2
                         + s['Ry12']*i1**2 + s['Ry23']*i2**2)
    E_fe = h*sum(np.sum(val('L:umx' + k)**2)/s['Rfex'] + np.sum(val('L:umy' + k)**2)/s['Rfey'] for k in PH)
    E_d = h*np.sum(idd[last]*vd[last])
    E_r = h*np.sum(vdc[last]**2)/Rdc
    E_c = 0.5*2e-3*(vdc[last][-1]**2 - vdc[spp - 1]**2)
    check('energy balance: source = DC load + C + copper + iron + diodes', E_src, E_r + E_c + E_cu + E_fe + E_d,
          1e-3, rel=True)
    i = idd[last, DIODES.index('D3a+')]
    v = vd[last, DIODES.index('D3a+')]
    e, didt, step, ramp = turn_off(t, i, v, S[last, DIODES.index('D3a+')], h)
    thd = math.sqrt(sum(abs(H[hh])**2 for hh in range(2, 40)))/I1
    Pin = E_src*fr
    print('   Vdc %.0f V (ripple %.1f V p-p), Id per bridge %.2f / %.2f / %.2f A, P_in %.3f MW, line I1 %.2f A rms,'
          ' PF %.4f' % (vdc[last].mean(), np.ptp(vdc[last]), *idc, Pin/1e6, I1/math.sqrt(2),
                        Pin/(3*V1/math.sqrt(3)*math.sqrt(np.mean(IL[0, last]**2)))))
    print('   line harmonics, % of I1: ' + ', '.join('%d: %.3f' % (hh, 100*abs(H[hh])/I1)
                                                   for hh in (5, 7, 11, 13, 17, 19, 35, 37)) + ', THD(<40) %.2f %%' % (100*thd))
    print('   D3a+: mean %.2f A, rms %.2f A, peak %.2f A, conduction %.1f deg, di/dt at the zero %.4f A/us,'
          ' step %.0f V, then %.2f V/us; energy: copper %.0f W, iron %.0f W, diodes %.0f W; itmax %d' % (
              i.mean(), math.sqrt(np.mean(i**2)), i.max(), 360*np.mean(i > 1e-3*i.max()), didt/1e6, step, ramp/1e6,
              E_cu*fr, E_fe*fr, E_d*fr, itmax))

    print('3) current-stiff DC side (L 0.5 H, R %.1f Ohm), leakages 1e-4 pu (ls and coils): ideal 18-pulse spectrum'
          % Rdc)
    q = dict(p)
    q['ls'] = 1e-4
    for c in ('x12', 'x23', 'y12', 'y23', 'y45'):
        q['l_' + c] = 1e-4
    spp3 = 16000
    net, T, X, S, itmax, h = run_case(model, q, ('rl', Rdc, 0.5), 10, spp3, nrec_per=1)
    Ib, IL, vdc, idd, vd = waveforms(net, X, S)
    H = fourier(IL[0], range(1, 40))
    I1 = abs(H[1])
    for hh in (5, 7, 11, 13):
        check('harmonic %d / fundamental (cancelled)' % hh, abs(H[hh])/I1, 0, 1e-3)
    for hh, tol in ((17, 0.02), (19, 0.02), (35, 0.04), (37, 0.04)):
        check('harmonic %d / fundamental = 1/%d (relative)' % (hh, hh), abs(H[hh])/I1, 1/hh, tol, rel=True)
    i = idd[:, DIODES.index('D3a+')]
    print('   Vdc %.0f V, Id %.2f A, D3a+ conduction %.1f deg; harmonics x h: %s; itmax %d' % (
        vdc.mean(), np.mean(vdc)/Rdc, 360*np.mean(i > 1e-3*i.max()),
        ', '.join('%d: %.3f' % (hh, hh*abs(H[hh])/I1) for hh in (17, 19, 35, 37)), itmax))

    print('4) commutation loop, ls %.3g pu, coils 1e-4 pu, lm 1e4, rfe 1e6 pu, for two DC sides' % p['ls'])
    q = dict(p)
    for c in ('x12', 'x23', 'y12', 'y23', 'y45'):
        q['l_' + c] = 1e-4
    q.update(lm_x=1e4, lm_y=1e4, rfe_x=1e6, rfe_y=1e6)
    n = q['n_y23']
    Ls = pu_to_si(q)['Ls']
    sides = [('impressed DC voltage %.4g kV (short in the jump network)' % (Vd/1e3), ('v', Vd), 'short',
              1.5*n**2, '1.5 n_y23^2'),
             ('one smoothed DC current, L 0.5 H + R 95 Ohm (open in the jump network)', ('rl', 95.0, 0.5, 177.0),
              'open', 2*(n**2 - n + 1), '2 (n_y23^2 - n_y23 + 1)')]
    for label, dc, jump, fac, fname in sides:
        print('   DC side: ' + label)
        net, T, X, S, itmax, h = run_case(model, q, dc, 10, spp3, nrec_per=1)
        Ib, IL, vdc, idd, vd = waveforms(net, X, S)
        for nm in ('D3a+', 'D1a+', 'D2a+'):
            j = DIODES.index(nm)
            e, didt, step, ramp = turn_off(T, idd[:, j], vd[:, j], S[:, j], h)
            pattern = S[e + 1]
            L0, dIL0 = l_incremental(model, q, pattern, nm, coils=0.0, dc=jump)
            L1, dIL1 = l_incremental(model, q, pattern, nm, coils=None, dc=jump)
            print('   %s off at %.2f deg, %d diodes on: %s' % (nm, (T[e]*fr % 1)*360, pattern.sum(),
                                                             ' '.join(d for d, s_ in zip(DIODES, pattern) if s_)))
            check('%s: incremental L, zero coil leakage, / (%s Ls)' % (nm, fname), L0/(fac*Ls), 1.0, 1e-6)
            check('%s: sum of d iL^2 = %s' % (nm, fname), float(np.sum(np.array(dIL0)**2)), fac, 1e-6)
            if jump == 'short':
                own = n if nm[1] == '3' else n*C20
                check('%s: d iL of line a per A = n_y23 (bridge 3), n_y23 cos 20 (1, 2)' % nm, dIL0[0], own, 1e-6)
            elif nm == 'D3a+':
                check('D3a+: d iL per A = (n_y23, -(n_y23 - 1), -1)', float(np.max(np.abs(np.array(dIL0) -
                      np.array([n, -(n - 1), -1.0])))), 0, 1e-6)
            check('%s: step / (di/dt) in the simulation = incremental L (coils 1e-4)' % nm, step/didt, L1, 5e-3,
                  rel=True)
            print('      di/dt %.4f A/us, step %.0f V, L %.2f mH = %.4f Ls (incremental %.4f Ls); d iL = %s A per A' % (
                didt/1e6, step, step/didt*1e3, step/didt/Ls, L1/Ls, ', '.join('%+.4f' % d for d in dIL0)))
        print('      itmax %d' % itmax)
    print('   1.5 n_y23^2 = %.4f with an impressed DC voltage or a DC capacitor, 2 (n_y23^2 - n_y23 + 1) = %.4f'
          ' with one smoothed DC current' % (1.5*n**2, 2*(n**2 - n + 1)))


def l_incremental(model, p, pattern, port, coils=None, dc='short'):
    """Inductance seen by the diode port when it turns off: the other diodes of the pattern shorted, the rest
    open, sources shorted, DC side shorted (dc 'short': impressed voltage or capacitor) or open (dc 'open': one
    smoothed current), resistances zero, ideal cores. Returns L and the line-current changes per ampere of the
    port current."""
    q = dict(p)
    q.update(rs=0.0, lm_x=1e9, lm_y=1e9, rfe_x=1e12, rfe_y=1e12)
    for c in ('x12', 'x23', 'y12', 'y23', 'y45'):
        q['r_' + c] = 0.0
        if coils is not None:
            q['l_' + c] = coils
    net = Net()
    for k in PH:
        net.vsrc('src:' + k, LINE[k], 'gnd', 0.0)
    model.stamp(net, q)
    ends = {}
    for j in (1, 2, 3):
        for k in PH:
            ends['D%d%s+' % (j, k)] = ('%s%d' % (k, j), 'P')
            ends['D%d%s-' % (j, k)] = ('N', '%s%d' % (k, j))
    for nm, on in zip(DIODES, pattern):
        a, c = ends[nm]
        if nm == port:
            net.branch('port', a, c)
            net.eq({'port': 1.0}, None, (lambda t: t))       # forward current rising at 1 A/s
        elif on:
            net.res('r_' + nm, a, c, 1e-9)
    if dc == 'short':
        net.vsrc('vdc', 'P', 'N', 0.0)
    h = 1e-6
    net.build()
    rhs = np.zeros(len(net.idx))
    for r, f in net.src:
        rhs[r] += f(h)
    x = np.linalg.solve(net.A + net.C/h, rhs)
    a, c = ends[port]
    v = x[net.idx['v:' + a]] - x[net.idx['v:' + c]]
    dIL = [sum(x[net.idx['L:i%d%s' % (j, k)]] for j in (1, 2, 3))/h for k in PH]
    return -v, dIL


# ===================================================================== part D
def part_d(model, p):
    print('\n=== D. reference values of test_lit_18_pulse.m (defaults, %.4g kV %g Hz, L 0.5 H + R 95 Ohm on DC,'
          ' diodes Vf 0, Ron 1 mOhm, Goff 1 nS, 12 periods, last one) ===' % (p['V1']/1e3, p['fr']))
    spp = 16000
    net, T, X, S, itmax, h = run_case(model, p, ('rl', 95.0, 0.5), 12, spp, nrec_per=1)
    Ib, IL, vdc, idd, vd = waveforms(net, X, S)
    idc = [sum(idd[:, DIODES.index('D%d%s+' % (j, k))] for k in PH).mean() for j in (1, 2, 3)]
    Id = float(np.mean(X[:, net.idx['ldc']]))
    H = fourier(IL[0], range(1, 40))
    I1 = abs(H[1])
    F = [fourier(Ib[j, 0], [1])[1] for j in range(3)]
    i = idd[:, DIODES.index('D3a+')]
    ref = dict(Id=Id, Id1=idc[0], Id2=idc[1], Id3=idc[2], IL1=I1/math.sqrt(2),
               ILrms=math.sqrt(np.mean(IL[0]**2)), h5=100*abs(H[5])/I1, h7=100*abs(H[7])/I1,
               h11=100*abs(H[11])/I1, h13=100*abs(H[13])/I1, h17=100*abs(H[17])/I1, h19=100*abs(H[19])/I1,
               sh1=wrap(ang(F[0]) - ang(F[2])), sh2=wrap(ang(F[1]) - ang(F[2])),
               cond=360*np.mean(i > 1e-3*i.max()), Vdc=float(np.mean(vdc)))
    print('   ' + ', '.join('%s %.4f' % kv for kv in ref.items()))
    print('   MATLAB: ref = struct(' + ', '.join("'%s', %.5g" % kv for kv in ref.items()) + ');')
    check('DC current = sum of the three bridges (relative)', sum(idc), Id, 1e-4, rel=True)
    return ref


if __name__ == '__main__':
    model = SscModel(SSC)
    p = part_a(model)
    part_b(model, p)
    part_c(model, p)
    part_d(model, p)
    print(f'\n{n_checks} checks, {n_failed} failed')
    sys.exit(1 if n_failed else 0)
