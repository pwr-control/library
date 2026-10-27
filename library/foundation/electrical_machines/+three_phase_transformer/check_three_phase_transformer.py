#!/usr/bin/env python3
"""Sinusoidal steady-state check of transformer_Dd, transformer_Yyn and transformer_Dyn.

Pure Python (numpy only, no Simscape): the equations of the three .ssc files are
rebuilt one to one in the phasor domain (der() -> j*w, rms phasors) and solved
together with an ideal three-phase source and a few loads by a small nodal
solver. Every result is compared with a closed-form expectation computed on the
per-unit per-phase equivalent circuit (positive sequence) or on the sequence
networks of the model (single-phase loads), so the checks also prove that the
per-unit bases chosen for the delta coils (3*V^2/Sr) and the vector-group rules
(limb and sense of each secondary coil) are consistent:

  1. no load: secondary voltage, phase shift by clock number, no-load current
  2. three-phase short circuit: short-circuit impedance l1 + l2 (and r1 + r2)
  3. rated resistive load: voltage regulation, current ratio, power balance
  4. single-phase load a-n on the Yyn: neutral shift with N floating (three-limb
     core and bank of single-phase units) and with N grounded
  5. single-phase load a-n on the Dyn: no neutral shift, load current carried by
     two primary lines only (circulating current in the delta)
  6. single-phase load a-b on the Dd: 2/3 - 1/3 split between the coil across
     the load and the series of the other two, two primary lines loaded

Run:  python3 check_three_phase_transformer.py        (exit code 0 if all pass)
"""
import cmath
import math
import sys

import numpy as np

J = 1j
A120 = cmath.exp(J*2*math.pi/3)   # Fortescue operator a


# ------------------------------------------------------------------ nodal solver
class Circuit:
    """Linear phasor circuit: unknown node voltages and element currents.

    Through-variable convention of Simscape: a branch 'i : X -> Y' carries i from
    terminal X to terminal Y through the element, so i leaves node X and enters
    node Y. KCL of a node: sum of the currents leaving it into elements = 0.
    """

    def __init__(self):
        self.index = {}
        self.eqs = []           # (dict var -> coeff, rhs)
        self.kcl = {}           # node -> dict var -> coeff (currents leaving the node)
        self.grounds = set()

    def var(self, name):
        if name not in self.index:
            self.index[name] = len(self.index)
        return name

    def node(self, name):
        self.var('V:' + name)
        self.kcl.setdefault(name, {})
        return name

    def ground(self, name):
        self.node(name)
        self.grounds.add(name)

    def eq(self, coeffs, rhs=0.0):
        self.eqs.append(({self.var(k): v for k, v in coeffs.items()}, rhs))

    def branch(self, ivar, nfrom, nto):
        """Register the through variable ivar flowing nfrom -> nto through an element."""
        self.var(ivar)
        self.node(nfrom)
        self.node(nto)
        self.kcl[nfrom][ivar] = self.kcl[nfrom].get(ivar, 0) + 1
        self.kcl[nto][ivar] = self.kcl[nto].get(ivar, 0) - 1

    # ---- elements
    def vsource(self, name, npos, nneg, E):
        """Ideal source: V(npos) - V(nneg) = E; current name flows npos -> nneg inside."""
        self.branch(name, npos, nneg)
        self.eq({'V:' + npos: 1, 'V:' + nneg: -1}, E)

    def impedance(self, name, npos, nneg, Z):
        """Impedance Z: current name flows npos -> nneg through it."""
        self.branch(name, npos, nneg)
        self.eq({'V:' + npos: 1, 'V:' + nneg: -1, name: -Z}, 0)

    def solve(self):
        n = len(self.index)
        rows = list(self.eqs)
        for node, terms in self.kcl.items():
            if node in self.grounds:
                rows.append(({'V:' + node: 1}, 0))
            else:
                rows.append((dict(terms), 0))
        if len(rows) != n:
            raise RuntimeError('system is %d x %d' % (len(rows), n))
        M = np.zeros((n, n), dtype=complex)
        b = np.zeros(n, dtype=complex)
        for r, (terms, rhs) in enumerate(rows):
            for k, v in terms.items():
                M[r, self.index[k]] += v
            b[r] = rhs
        x = np.linalg.solve(M, b)
        return {k: x[i] for k, i in self.index.items()}


# ------------------------------------------------------------- transformer models
def derived(p, kind):
    """Private parameters of the .ssc components (same formulas)."""
    d = {}
    d['wb'] = 2*math.pi*p['fr']
    if kind == 'Dyn':
        d['Zb1'] = 3*p['V1']**2/p['Sr']
        d['Zb2'] = p['V2']**2/p['Sr']
        d['n21'] = p['V2']/(math.sqrt(3)*p['V1'])
    elif kind == 'Yyn':
        d['Zb1'] = p['V1']**2/p['Sr']
        d['Zb2'] = p['V2']**2/p['Sr']
        d['n21'] = p['V2']/p['V1']
        d['s2'] = 1 - p['clock']/3
    elif kind == 'Dd':
        d['Zb1'] = 3*p['V1']**2/p['Sr']
        d['Zb2'] = 3*p['V2']**2/p['Sr']
        d['n21'] = p['V2']/p['V1']
        d['s2'] = 1 - p['clock']/3
    else:
        raise ValueError(kind)
    d['R1'] = p['r1']*d['Zb1']
    d['L1'] = p['l1']*d['Zb1']/d['wb']
    d['R2'] = p['r2']*d['Zb2']
    d['L2'] = p['l2']*d['Zb2']/d['wb']
    d['Lm'] = p['lm']*d['Zb1']/d['wb']
    d['Lm0'] = p['lm0']*d['Zb1']/d['wb']
    d['Lc'] = (d['Lm'] - d['Lm0'])/3
    d['Rfe'] = p['rfe']*d['Zb1']
    return d


def add_core(ckt, t, d, w, i1, f2):
    """Common part of the three components: mmf balance and three-limb core.

    i1[k]: name of the primary coil current of limb k; f2[k]: dict var -> coeff
    of the demagnetizing mmf of the secondary coil(s) on limb k (primary turns).
    """
    for k in 'abc':
        # im_k == i1_k - f2_k - um_k/Rfe, um_k = der(psi_k)
        terms = {t + 'im' + k: 1, i1[k]: -1, t + 'psi' + k: J*w/d['Rfe']}
        for v, c in f2[k].items():
            terms[v] = terms.get(v, 0) + c
        ckt.eq(terms, 0)
        # psi_k == Lm*im_k - Lc*(ima + imb + imc)
        terms = {t + 'psi' + k: 1}
        for m in 'abc':
            terms[t + 'im' + m] = terms.get(t + 'im' + m, 0) + d['Lc']
        terms[t + 'im' + k] -= d['Lm']
        ckt.eq(terms, 0)


def add_Dyn(ckt, p, nodes, w, t='T.'):
    """transformer_Dyn: nodes = dict A, B, C, a, b, c, n."""
    d = derived(p, 'Dyn')
    n21 = d['n21']
    z1 = d['R1'] + J*w*d['L1']
    z2 = d['R2'] + J*w*d['L2']
    i1 = {'a': t + 'iAB', 'b': t + 'iBC', 'c': t + 'iCA'}
    ckt.branch(i1['a'], nodes['A'], nodes['B'])
    ckt.branch(i1['b'], nodes['B'], nodes['C'])
    ckt.branch(i1['c'], nodes['C'], nodes['A'])
    for x in 'abc':
        ckt.branch(t + 'i2' + x, nodes['n'], nodes[x])
    # primary delta coils: A.v - B.v == R1*iAB + L1*der(iAB) + der(psia) ...
    for (P, Q, k) in (('A', 'B', 'a'), ('B', 'C', 'b'), ('C', 'A', 'c')):
        ckt.eq({'V:' + nodes[P]: 1, 'V:' + nodes[Q]: -1, i1[k]: -z1, t + 'psi' + k: -J*w}, 0)
    # vector group: secondary coil x -> (limb, sense), as in the ssc
    clock = p['clock']
    if clock == 11:
        wiring = {'a': ('a', 1), 'b': ('b', 1), 'c': ('c', 1)}
    elif clock == 5:
        wiring = {'a': ('a', -1), 'b': ('b', -1), 'c': ('c', -1)}
    elif clock == 1:
        wiring = {'a': ('c', -1), 'b': ('a', -1), 'c': ('b', -1)}
    elif clock == 7:
        wiring = {'a': ('c', 1), 'b': ('a', 1), 'c': ('b', 1)}
    else:
        raise ValueError('Dyn clock must be 1, 5, 7 or 11')
    f2 = {'a': {}, 'b': {}, 'c': {}}
    for x in 'abc':
        limb, s = wiring[x]
        # a.v - n.v == e2a - R2*i2a - L2*der(i2a), e2a = s*n21*um_limb, um = der(psi)
        ckt.eq({'V:' + nodes[x]: 1, 'V:' + nodes['n']: -1,
                t + 'psi' + limb: -s*n21*J*w, t + 'i2' + x: z2}, 0)
        f2[limb][t + 'i2' + x] = s*n21
    add_core(ckt, t, d, w, i1, f2)
    return d


def add_Yyn(ckt, p, nodes, w, t='T.'):
    """transformer_Yyn: nodes = dict A, B, C, N, a, b, c, n."""
    d = derived(p, 'Yyn')
    n21, s2 = d['n21'], d['s2']
    z1 = d['R1'] + J*w*d['L1']
    z2 = d['R2'] + J*w*d['L2']
    i1 = {k: t + 'i1' + k for k in 'abc'}
    f2 = {}
    for X, x in (('A', 'a'), ('B', 'b'), ('C', 'c')):
        ckt.branch(i1[x], nodes[X], nodes['N'])
        ckt.branch(t + 'i2' + x, nodes['n'], nodes[x])
        # A.v - N.v == R1*i1a + L1*der(i1a) + der(psia)
        ckt.eq({'V:' + nodes[X]: 1, 'V:' + nodes['N']: -1, i1[x]: -z1, t + 'psi' + x: -J*w}, 0)
        # a.v - n.v == s2*n21*der(psia) - R2*i2a - L2*der(i2a)
        ckt.eq({'V:' + nodes[x]: 1, 'V:' + nodes['n']: -1,
                t + 'psi' + x: -s2*n21*J*w, t + 'i2' + x: z2}, 0)
        f2[x] = {t + 'i2' + x: s2*n21}
    add_core(ckt, t, d, w, i1, f2)
    return d


def add_Dd(ckt, p, nodes, w, t='T.'):
    """transformer_Dd: nodes = dict A, B, C, a, b, c."""
    d = derived(p, 'Dd')
    n21, s2 = d['n21'], d['s2']
    z1 = d['R1'] + J*w*d['L1']
    z2 = d['R2'] + J*w*d['L2']
    i1 = {'a': t + 'iAB', 'b': t + 'iBC', 'c': t + 'iCA'}
    i2 = {'a': t + 'i2ab', 'b': t + 'i2bc', 'c': t + 'i2ca'}
    f2 = {}
    for (P, Q, k) in (('A', 'B', 'a'), ('B', 'C', 'b'), ('C', 'A', 'c')):
        p_, q_ = P.lower(), Q.lower()
        ckt.branch(i1[k], nodes[P], nodes[Q])          # iAB : A.i -> B.i
        ckt.branch(i2[k], nodes[q_], nodes[p_])        # i2ab : b.i -> a.i
        # A.v - B.v == R1*iAB + L1*der(iAB) + der(psia)
        ckt.eq({'V:' + nodes[P]: 1, 'V:' + nodes[Q]: -1, i1[k]: -z1, t + 'psi' + k: -J*w}, 0)
        # a.v - b.v == s2*n21*der(psia) - R2*i2ab - L2*der(i2ab)
        ckt.eq({'V:' + nodes[p_]: 1, 'V:' + nodes[q_]: -1,
                t + 'psi' + k: -s2*n21*J*w, i2[k]: z2}, 0)
        f2[k] = {i2[k]: s2*n21}
    add_core(ckt, t, d, w, i1, f2)
    return d


# ---------------------------------------------------------------------- helpers
def source(ckt, V_ll, phase=0.0):
    """Ideal balanced star source, rms line-to-line V_ll, neutral node G grounded."""
    ckt.ground('G')
    E = V_ll/math.sqrt(3)*cmath.exp(J*phase)
    for X, rot in (('A', 1), ('B', A120**2), ('C', A120)):
        ckt.vsource('IS' + X, X, 'G', E*rot)


def src_currents(sol):
    """Currents delivered by the source into lines A, B, C (into the transformer).

    The source branch current IS flows X -> G inside the source, so the current
    pushed into the line is -IS.
    """
    return np.array([-sol['IS' + X] for X in 'ABC'])


def p_source(sol):
    return sum((sol['V:' + X]*np.conj(-sol['IS' + X])).real for X in 'ABC')


def p_losses(sol, d, w, t, i1names, i2names):
    pcu = sum(d['R1']*abs(sol[v])**2 for v in i1names) + sum(d['R2']*abs(sol[v])**2 for v in i2names)
    pfe = sum(abs(J*w*sol[t + 'psi' + k])**2/d['Rfe'] for k in 'abc')
    return pcu, pfe


def deg(z):
    return math.degrees(cmath.phase(z))


def wrap(a):
    return (a + 180) % 360 - 180


class Checker:
    def __init__(self):
        self.fail = 0

    def check(self, label, got, exp, tol, scale=None):
        """Relative check |got - exp| <= tol*max(|exp|, scale)."""
        ref = max(abs(exp), scale if scale is not None else 0.0, 1e-300)
        err = abs(got - exp)/ref
        ok = err <= tol
        self.fail += (not ok)
        print('   %-52s %-40s %s' % (label, 'got %.6g, expected %.6g' % (got, exp) if not isinstance(got, complex)
                                     else 'got %s, expected %s' % (fmt(got), fmt(exp)),
                                     'OK' if ok else 'FAIL (err %.2e)' % err))


def fmt(z):
    return '%.4g/_%.2fdeg' % (abs(z), deg(z))


# ------------------------------------------------------------------- the checks
def pu_equivalent(p):
    """Per-phase per-unit quantities, star base on both sides (positive sequence)."""
    z1 = p['r1'] + J*p['l1']
    z2 = p['r2'] + J*p['l2']
    zm = 1/(1/(J*p['lm']) + 1/p['rfe'])
    zm0 = 1/(1/(J*p['lm0']) + 1/p['rfe'])
    return z1, z2, zm, zm0


def run_kind(kind, p, chk):
    w = 2*math.pi*p['fr']
    Sr, V1, V2 = p['Sr'], p['V1'], p['V2']
    Ib1 = Sr/(math.sqrt(3)*V1)
    Ib2 = Sr/(math.sqrt(3)*V2)
    Zb2s = V2**2/Sr
    z1, z2, zm, zm0 = pu_equivalent(p)
    add = {'Dyn': add_Dyn, 'Yyn': add_Yyn, 'Dd': add_Dd}[kind]
    nodes = {k: k for k in 'ABCabc'}
    if kind in ('Yyn',):
        nodes['N'] = 'N'
    if kind in ('Yyn', 'Dyn'):
        nodes['n'] = 'n'
    t = 'T.'
    i1names = {'Dyn': ['T.iAB', 'T.iBC', 'T.iCA'], 'Dd': ['T.iAB', 'T.iBC', 'T.iCA'],
               'Yyn': ['T.i1a', 'T.i1b', 'T.i1c']}[kind]
    i2names = {'Dyn': ['T.i2a', 'T.i2b', 'T.i2c'], 'Yyn': ['T.i2a', 'T.i2b', 'T.i2c'],
               'Dd': ['T.i2ab', 'T.i2bc', 'T.i2ca']}[kind]
    shift_exp = wrap(-30*p['clock'])        # secondary lags the primary by clock*30 deg

    def build(ground_n=True, ground_N=False, ref_c=False):
        ckt = Circuit()
        source(ckt, V1)
        for nd in nodes.values():
            ckt.node(nd)
        d = add(ckt, p, nodes, w, t)
        if 'n' in nodes and ground_n:
            ckt.vsource('In', 'n', 'G', 0)   # secondary neutral to ground, In = current n -> G
        if 'N' in nodes and ground_N:
            ckt.vsource('IN', 'N', 'G', 0)
        if ref_c:
            # a delta secondary without a star-connected load floats: give it a
            # reference (corner c grounded), as a Simscape model needs anyway
            ckt.vsource('Iref', 'c', 'G', 0)
        return ckt, d

    floating = kind == 'Dd'

    print('\n=== transformer_%s, clock %d: Sr = %g kVA, %g/%g V, %g Hz ===' % (
        kind, p['clock'], Sr/1e3, V1, V2, p['fr']))

    # ---- 1. no load ---------------------------------------------------------
    ckt, d = build(ref_c=floating)
    sol = ckt.solve()
    Vab = sol['V:a'] - sol['V:b']
    VAB = sol['V:A'] - sol['V:B']
    I1 = src_currents(sol)
    print('1) no load')
    voc = zm/(z1 + zm)                       # pu open-circuit voltage
    chk.check('|u_ab| / V2', abs(Vab)/V2, abs(voc), 1e-9)
    chk.check('phase(u_ab) - phase(u_AB) [deg]', wrap(deg(Vab) - deg(VAB)), shift_exp, 1e-9, scale=360)
    chk.check('I_A / Ib1 (no-load current, pu)', abs(I1[0])/Ib1, abs(1/(z1 + zm)), 1e-9)
    chk.check('phase(I_A) - phase(u_AN) [deg]', wrap(deg(I1[0]) - deg(sol['V:A'])),
              deg(1/(z1 + zm)), 1e-9, scale=360)
    chk.check('sum of line currents [A]', abs(I1.sum()), 0.0, 1e-9, scale=Ib1)
    if 'n' in nodes:
        chk.check('neutral current n [A]', abs(sol['In']), 0.0, 1e-9, scale=Ib2)
    pcu, pfe = p_losses(sol, d, w, t, i1names, i2names)
    chk.check('power balance P_src - P_cu - P_fe [W]', p_source(sol) - pcu - pfe, 0.0, 1e-9, scale=Sr)
    chk.check('P_fe / Sr (pu)', pfe/Sr, abs(voc)**2/p['rfe'], 1e-9)

    # ---- 2. short circuit ---------------------------------------------------
    ckt, d = build(ref_c=floating)
    for x, y in (('a', 'b'), ('b', 'c')):
        ckt.vsource('Isc' + x + y, x, y, 0)
    sol = ckt.solve()
    I1 = src_currents(sol)
    zsc = z1 + 1/(1/zm + 1/z2)
    print('2) three-phase short circuit at the secondary')
    chk.check('Ib1 / I_A = |z_sc| (pu)', Ib1/abs(I1[0]), abs(zsc), 1e-9)
    chk.check('   ~ |(r1 + r2) + j (l1 + l2)|', abs(zsc), abs(z1 + z2), 2e-2)
    chk.check('phase of z_sc [deg]', wrap(deg(sol['V:A']) - deg(I1[0])), deg(zsc), 1e-9, scale=360)
    I2a = sol['T.i2ab'] - sol['T.i2ca'] if kind == 'Dd' else sol['T.i2a']   # line current out of a
    chk.check('secondary line current I_a / Ib2', abs(I2a)/Ib2, abs(1/zsc*zm/(zm + z2)), 1e-9)
    pcu, pfe = p_losses(sol, d, w, t, i1names, i2names)
    chk.check('power balance [W]', p_source(sol) - pcu - pfe, 0.0, 1e-9, scale=Sr)

    # ---- 3. rated balanced resistive load ------------------------------------
    ckt, d = build()
    R = Zb2s                                  # 1 pu per phase, star
    for x in 'abc':
        ckt.impedance('IL' + x, x, 'G', R)
    sol = ckt.solve()
    I1 = src_currents(sol)
    Ia = sol['ILa']
    zin = z1 + 1/(1/zm + 1/(z2 + 1))
    i1 = 1/zin
    v2 = i1*(1/(1/zm + 1/(z2 + 1)))*1/(z2 + 1)   # pu load voltage
    print('3) rated resistive load (1 pu per phase, star, neutral to ground)')
    chk.check('V_a / (V2/sqrt3) (regulation)', abs(sol['V:a'])/(V2/math.sqrt(3)), abs(v2), 1e-9)
    chk.check('phase(V_a) - phase(V_A) [deg]', wrap(deg(sol['V:a']) - deg(sol['V:A'])),
              wrap(shift_exp + deg(v2)), 1e-9, scale=360)
    chk.check('I_A / Ib1', abs(I1[0])/Ib1, abs(i1), 1e-9)
    chk.check('I_a / Ib2', abs(Ia)/Ib2, abs(v2), 1e-9)
    chk.check('line current ratio I_A/I_a = V2/V1', abs(I1[0])/abs(Ia), V2/V1*abs(i1)/abs(v2), 1e-9)
    Pload = 3*R*abs(Ia)**2
    pcu, pfe = p_losses(sol, d, w, t, i1names, i2names)
    chk.check('power balance P_src - P_load - P_cu - P_fe [W]', p_source(sol) - Pload - pcu - pfe, 0.0, 1e-9, scale=Sr)
    chk.check('P_cu / Sr ~ (r1 + r2) at ~1 pu current', pcu/Sr, (p['r1']*abs(i1)**2 + p['r2']*abs(v2)**2), 1e-9)
    print('   efficiency %.4f %%, P_cu %.0f W, P_fe %.0f W' % (100*Pload/p_source(sol), pcu, pfe))

    # ---- 4/5/6. single-phase load ------------------------------------------
    if kind == 'Yyn':
        for lm0, gnd_N, title in ((p['lm0'], False, 'three-limb core (lm0 = %g), N floating' % p['lm0']),
                                  (p['lm'], False, 'bank of single-phase units (lm0 = lm = %g), N floating' % p['lm']),
                                  (p['lm0'], True, 'three-limb core, N grounded (YNyn)')):
            q = dict(p)
            q['lm0'] = lm0
            z1, z2, zm, zm0 = pu_equivalent(q)
            ckt = Circuit()
            source(ckt, V1)
            for nd in nodes.values():
                ckt.node(nd)
            d = add_Yyn(ckt, q, nodes, w, t)
            ckt.vsource('In', 'n', 'G', 0)
            if gnd_N:
                ckt.vsource('IN', 'N', 'G', 0)
            R = Zb2s
            ckt.impedance('ILa', 'a', 'G', R)
            sol = ckt.solve()
            # sequence networks seen from the secondary (pu, star base)
            Z1 = z2 + 1/(1/z1 + 1/zm)
            Z0 = z2 + (1/(1/z1 + 1/zm0) if gnd_N else zm0)
            voc = zm/(z1 + zm)*cmath.exp(J*math.radians(shift_exp))
            I0 = voc/(2*Z1 + Z0 + 3*1.0)
            Vb_exp = A120**2*(voc - I0*Z1) + A120*(-I0*Z1) - I0*Z0
            Vc_exp = A120*(voc - I0*Z1) + A120**2*(-I0*Z1) - I0*Z0
            print('4) single-phase load 1 pu a-n, %s' % title)
            Ia = sol['ILa']
            V0 = (sol['V:a'] + sol['V:b'] + sol['V:c'])/3
            chk.check('I_a / Ib2', abs(Ia)/Ib2, abs(3*I0), 1e-9)
            chk.check('zero-sequence voltage V0 / Vph2 (neutral shift)', abs(V0)/(V2/math.sqrt(3)), abs(I0*Z0), 1e-9)
            chk.check('|V_bn| / Vph2', abs(sol['V:b'])/(V2/math.sqrt(3)), abs(Vb_exp), 1e-9)
            chk.check('|V_cn| / Vph2', abs(sol['V:c'])/(V2/math.sqrt(3)), abs(Vc_exp), 1e-9)
            chk.check('neutral current In = I_a', abs(sol['In']), abs(Ia), 1e-9)
            I1 = src_currents(sol)
            if not gnd_N:
                chk.check('sum of primary line currents (N floating) [A]', abs(I1.sum()), 0.0, 1e-9, scale=Ib1)
                VN = sol['V:N']
                print('   primary star point shift |V_N| / Vph1 = %.4f, secondary V0 / Vph2 = %.4f' % (
                    abs(VN)/(V1/math.sqrt(3)), abs(V0)/(V2/math.sqrt(3))))
            else:
                chk.check('primary neutral current IN = I_a*V2/V1 (zero seq. in the primary)',
                          abs(sol['IN']), abs(3*I0)*Ib2*V2/V1*abs(1/(1/z1 + 1/zm0)/z1), 1e-9)
            print('   |V_an| = %.4f, |V_bn| = %.4f, |V_cn| = %.4f pu; I_A, I_B, I_C = %.3f, %.3f, %.3f pu' % (
                abs(sol['V:a'])/(V2/math.sqrt(3)), abs(sol['V:b'])/(V2/math.sqrt(3)),
                abs(sol['V:c'])/(V2/math.sqrt(3)), *(abs(I1)/Ib1)))
            pcu, pfe = p_losses(sol, d, w, t, i1names, i2names)
            chk.check('power balance [W]', p_source(sol) - R*abs(Ia)**2 - pcu - pfe, 0.0, 1e-9, scale=Sr)

    if kind == 'Dyn':
        ckt, d = build()
        R = Zb2s
        ckt.impedance('ILa', 'a', 'G', R)
        sol = ckt.solve()
        Z1 = z2 + 1/(1/z1 + 1/zm)
        Z0 = z2 + 1/(1/z1 + 1/zm0)            # the delta closes the zero-sequence path
        voc = zm/(z1 + zm)*cmath.exp(J*math.radians(shift_exp))
        I0 = voc/(2*Z1 + Z0 + 3*1.0)
        Ia = sol['ILa']
        V0 = (sol['V:a'] + sol['V:b'] + sol['V:c'])/3
        I1 = src_currents(sol)
        print('5) single-phase load 1 pu a-n (delta carries the zero sequence)')
        chk.check('I_a / Ib2', abs(Ia)/Ib2, abs(3*I0), 1e-9)
        chk.check('zero-sequence voltage V0 / Vph2 (small: ~ |I0 (z1+z2)|)', abs(V0)/(V2/math.sqrt(3)), abs(I0*Z0), 1e-9)
        chk.check('   ~ |I0 (z1 + z2)| (within 5 %)', abs(V0)/(V2/math.sqrt(3)), abs(I0*(z1 + z2)), 5e-2)
        # which primary lines carry the load: coil of the limb of secondary coil a
        limb = {11: 'a', 5: 'a', 1: 'c', 7: 'c'}[p['clock']]
        lines = {'a': ('A', 'B', 'C'), 'c': ('C', 'A', 'B')}[limb]     # coil across the first two, idle third
        idx = {'A': 0, 'B': 1, 'C': 2}
        Iref = d['n21']*abs(Ia)
        # subtract the no-load (magnetizing) currents to isolate the load share
        ckt0, _ = build()
        I10 = src_currents(ckt0.solve())
        dI = I1 - I10
        chk.check('|I_%s - I_%s,noload| / (n21 |I_a|)' % (lines[0], lines[0]), abs(dI[idx[lines[0]]])/Iref, 1.0, 2e-2)
        chk.check('|I_%s - I_%s,noload| / (n21 |I_a|)' % (lines[1], lines[1]), abs(dI[idx[lines[1]]])/Iref, 1.0, 2e-2)
        chk.check('|I_%s - I_%s,noload| / (n21 |I_a|) (idle line)' % (lines[2], lines[2]), abs(dI[idx[lines[2]]])/Iref, 0.0, 2e-2, scale=1)
        chk.check('sum of primary line currents [A]', abs(I1.sum()), 0.0, 1e-9, scale=Ib1)
        chk.check('neutral current In = I_a', abs(sol['In']), abs(Ia), 1e-9)
        icirc = (sol['T.iAB'] + sol['T.iBC'] + sol['T.iCA'])/3
        print('   circulating (zero-sequence) current in the delta: %.4f of n21*I_a; |V_an|, |V_bn|, |V_cn| = %.4f, %.4f, %.4f pu' % (
            abs(icirc)/Iref, abs(sol['V:a'])/(V2/math.sqrt(3)), abs(sol['V:b'])/(V2/math.sqrt(3)), abs(sol['V:c'])/(V2/math.sqrt(3))))
        chk.check('circulating current / (n21 I_a /3)', abs(icirc)/(Iref/3), abs(1/(1/z1 + 1/zm0)/z1), 1e-9)
        pcu, pfe = p_losses(sol, d, w, t, i1names, i2names)
        chk.check('power balance [W]', p_source(sol) - R*abs(Ia)**2 - pcu - pfe, 0.0, 1e-9, scale=Sr)

    if kind == 'Dd':
        ckt, d = build(ref_c=True)
        R = 3*Zb2s                              # rated coil current in the loaded coil at no drop
        ckt.impedance('ILab', 'a', 'b', R)
        sol = ckt.solve()
        Iab = sol['ILab']
        Z1 = z2 + 1/(1/z1 + 1/zm)
        vocll = math.sqrt(3)*zm/(z1 + zm)*cmath.exp(J*math.radians(30 + shift_exp))   # u_ab / Vph2
        Iab_exp = vocll/(2*Z1 + 3.0)            # pu of Ib2
        print('6) single-phase load a-b (R = 3 pu star base)')
        chk.check('I_ab / Ib2', abs(Iab)/Ib2, abs(Iab_exp), 1e-9)
        chk.check('coil a-b current / I_ab (2/3)', abs(sol['T.i2ab'])/abs(Iab), 2/3, 1e-9)
        chk.check('coil b-c current / I_ab (1/3, series path)', abs(sol['T.i2bc'])/abs(Iab), 1/3, 1e-9)
        chk.check('coil c-a current / I_ab (1/3, series path)', abs(sol['T.i2ca'])/abs(Iab), 1/3, 1e-9)
        chk.check('I_c = i2ca - i2bc = 0 (idle terminal)', abs(sol['T.i2ca'] - sol['T.i2bc']), 0.0, 1e-9, scale=Ib2)
        I1 = src_currents(sol)
        ckt0, _ = build(ref_c=True)
        I10 = src_currents(ckt0.solve())
        dI = I1 - I10
        Iref = d['n21']*abs(Iab)
        chk.check('|I_A - I_A,noload| / (n21 |I_ab|)', abs(dI[0])/Iref, 1.0, 2e-2)
        chk.check('|I_B - I_B,noload| / (n21 |I_ab|)', abs(dI[1])/Iref, 1.0, 2e-2)
        chk.check('|I_C - I_C,noload| / (n21 |I_ab|) (idle line)', abs(dI[2])/Iref, 0.0, 2e-2, scale=1)
        psi0 = sol['T.psia'] + sol['T.psib'] + sol['T.psic']
        chk.check('zero-sequence flux psi_a + psi_b + psi_c [V*s]', abs(psi0), 0.0, 1e-9, scale=abs(sol['T.psia']))
        pcu, pfe = p_losses(sol, d, w, t, i1names, i2names)
        chk.check('power balance [W]', p_source(sol) - R*abs(Iab)**2 - pcu - pfe, 0.0, 1e-9, scale=Sr)


def main():
    base = dict(Sr=1e6, V1=690, V2=400, fr=50, r1=0.005, l1=0.025, r2=0.005, l2=0.025,
                lm=100, lm0=0.5, rfe=500)
    chk = Checker()
    for clock in (11, 1, 5, 7):
        run_kind('Dyn', dict(base, clock=clock), chk)
    for clock in (0, 6):
        run_kind('Yyn', dict(base, clock=clock), chk)
    for clock in (0, 6):
        run_kind('Dd', dict(base, clock=clock), chk)
    print('\n%s' % ('ALL CHECKS PASSED' if chk.fail == 0 else '%d CHECK(S) FAILED' % chk.fail))
    return 0 if chk.fail == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
