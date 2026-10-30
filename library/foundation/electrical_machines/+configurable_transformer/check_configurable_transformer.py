#!/usr/bin/env python3
"""Sinusoidal steady-state check of configurable_transformer.

Pure Python (numpy only, no Simscape), the method of
../+three_phase_transformer/check_three_phase_transformer.py, whose nodal
solver and phasor models of transformer_Dd, transformer_Yyn and transformer_Dyn
are reused: the equations of configurable_transformer.ssc are rebuilt one to one in
the phasor domain (der() -> j*w, rms phasors) and solved with ideal three-phase
sources and loads.

  1. Each library transformer against the configuration of configurable_transformer
     that stands for it, with the same sources and loads (no load, balanced
     load, unbalanced load with the neutral grounded and floating,
     single-phase loads, short circuit): node voltages, source and load
     currents and limb fluxes agree to rounding.
       transformer_Dyn clock 1, 5, 7, 11   one primary in delta, star secondary
       transformer_Yyn clock 0, 6          one primary in star, star secondary
       transformer_Dd  clock 0, 6          one primary in delta, delta secondary
       tri_monophase_transformer           two primaries in star, clock2 = 0,
         ws [1 -1 0], [1 -1/2 -1/2],       single-phase secondary
         [1 0 0]
  2. The configurations no library block has, against closed forms on the
     per-unit equivalent circuit (positive sequence): no-load ratio and phase
     shift of primary 2 and of a three-phase secondary for each pair of
     connections and each clock number, the clock numbers the asserts refuse,
     short-circuit impedance between each pair of windings, two primaries
     sharing a rated load (matched and unmatched sources), single-phase
     output at no load, power balance.
  3. A single-phase load on a star secondary equals the single-phase
     secondary, for primary 1 in star and in delta, with one and with two
     primaries: across a-b equals ws = [1 -1 0] with coils of half the r3, l3
     of the single-phase winding (the TELEMA bench), across a-n equals
     ws = [1 0 0] at V3/sqrt(3) with a coil of a third of r3, l3.

Run:  python3 check_configurable_transformer.py        (exit code 0 if all pass)
"""
import cmath
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True                 # no __pycache__ in the library folders
sys.path.insert(0, os.path.join(HERE, '..', '+three_phase_transformer'))
import check_three_phase_transformer as ctp   # noqa: E402

J = 1j
SQ3 = math.sqrt(3)
A120 = ctp.A120
CONN = {'star': 0, 'delta': 1}
IEC = {'star': 'Y', 'delta': 'D'}
TOL = 1e-9


# ---------------------------------------------------------------- configurable_transformer
def placement(clock, d1, dw):
    """p0, p1, p2 of the ssc: phase j of the winding on limb k with P(j,k) = p[(k - j) mod 3]."""
    q = (clock + d1 - dw)/2
    sq = math.cos(math.pi*q)
    return [sq*(1 + 2*math.cos(2*math.pi*(q + m)/3))/3 for m in range(3)]


def clock_assert(clock, d1, dw, what):
    """The asserts of the ssc on a clock number (ValueError where Simscape stops)."""
    if abs(clock - round(clock)) >= 1e-9:
        raise ValueError('%s clock number must be an integer' % what)
    if d1 == dw and not math.cos(math.pi*clock) > 0.5:
        raise ValueError('%s clock number must be even' % what)
    if d1 != dw and not math.cos(math.pi*clock) < -0.5:
        raise ValueError('%s clock number must be odd' % what)


def add_configurable(ckt, p, nodes, w, t='S.'):
    """configurable_transformer.ssc; p: the block parameters ('primaries' 1 or 2, connections as strings).

    nodes maps the ports of the configuration (A1, B1, C1, N1, A2, ..., a, b, c, n, s1, s2) to
    circuit nodes; the hidden ports are not used (connected to the reference in the ssc).
    """
    Sr, wb = p['Sr'], 2*math.pi*p['fr']
    d1 = CONN[p['conn1']]
    V1c = p['V1'] if d1 else p['V1']/SQ3
    psi = {k: t + 'psi' + k for k in 'abc'}
    f2 = {k: {} for k in 'abc'}            # mmf of primary 2 on limb k: var -> coeff (primary-1 turns)
    f3 = {k: {} for k in 'abc'}            # mmf of the secondary (demagnetizing)
    d = {'i1': [], 'i2': [], 'i3': []}

    def coil(npos, nneg, ivar, z, n, pk, j, out, fk):
        """Coil j of a winding: npos - nneg == +-(z i) + n sum_k P(j,k) um_k, mmf into fk."""
        terms = {'V:' + nodes[npos]: 1, 'V:' + nodes[nneg]: -1, ivar: z if out else -z}
        for k, y in enumerate('abc'):
            c = n*pk[(k - j) % 3]
            terms[psi[y]] = terms.get(psi[y], 0) - c*J*w
            fk[y][ivar] = fk[y].get(ivar, 0) + c
        ckt.eq(terms, 0)

    # primary 1: coil of limb k, current into A1 (B1, C1); u = R1 i + L1 di/dt + um_k
    Zb = (3 if d1 else 1)*p['V1']**2/Sr
    d['R1'] = p['r1']*Zb
    z1 = d['R1'] + J*w*p['l1']*Zb/wb
    ends = (('A1', 'B1'), ('B1', 'C1'), ('C1', 'A1')) if d1 else (('A1', 'N1'), ('B1', 'N1'), ('C1', 'N1'))
    i1 = {}
    for j, (x, (P, Q)) in enumerate(zip('abc', ends)):
        i1[x] = t + 'i1' + x
        ckt.branch(i1[x], nodes[P], nodes[Q])
        ckt.eq({'V:' + nodes[P]: 1, 'V:' + nodes[Q]: -1, i1[x]: -z1, psi[x]: -J*w}, 0)
        d['i1'].append(i1[x])

    # primary 2
    if p['primaries'] == 2:
        d2 = CONN[p['conn2']]
        clock_assert(p['clock2'], d1, d2, 'Primary 2')
        n2 = (p['V2'] if d2 else p['V2']/SQ3)/V1c
        Zb = (3 if d2 else 1)*p['V2']**2/Sr
        d['R2'] = p['r2']*Zb
        z2 = d['R2'] + J*w*p['l2']*Zb/wb
        pk = placement(p['clock2'], d1, d2)
        ends = (('A2', 'B2'), ('B2', 'C2'), ('C2', 'A2')) if d2 else (('A2', 'N2'), ('B2', 'N2'), ('C2', 'N2'))
        for j, (x, (P, Q)) in enumerate(zip('abc', ends)):
            iv = t + 'i2' + x
            ckt.branch(iv, nodes[P], nodes[Q])
            coil(P, Q, iv, z2, n2, pk, j, False, f2)
            d['i2'].append(iv)
        d['n2'] = n2
    else:
        d['R2'] = 0.0

    # secondary, current out of a, b, c (s1) towards the load: u = n sum P um - R3 i - L3 di/dt
    if p['secondary'] == 'single_phase':
        ws = p['ws']
        gw = math.sqrt((ws[0] - (ws[1] + ws[2])/2)**2 + 3/4*(ws[2] - ws[1])**2)
        if not gw > 0:
            raise ValueError('ws must have a non-zero positive-sequence component')
        n3 = p['V3']/(gw*V1c)
        Zb = p['V3']**2/Sr
        d['R3'] = p['r3']*Zb
        z3 = d['R3'] + J*w*p['l3']*Zb/wb
        iv = t + 'i3'
        ckt.branch(iv, nodes['s2'], nodes['s1'])
        terms = {'V:' + nodes['s1']: 1, 'V:' + nodes['s2']: -1, iv: z3}
        for k, y in enumerate('abc'):
            terms[psi[y]] = -n3*ws[k]*J*w
            f3[y][iv] = n3*ws[k]
        ckt.eq(terms, 0)
        d['i3'].append(iv)
    else:
        dw = CONN[p['secondary']]
        clock_assert(p['clock3'], d1, dw, 'Secondary')
        n3 = (p['V3'] if dw else p['V3']/SQ3)/V1c
        Zb = (3 if dw else 1)*p['V3']**2/Sr
        d['R3'] = p['r3']*Zb
        z3 = d['R3'] + J*w*p['l3']*Zb/wb
        pk = placement(p['clock3'], d1, dw)
        # branch (from, to): star i3a : n -> a, delta i3a : b -> a; the coil voltage is to - from
        ends = (('b', 'a'), ('c', 'b'), ('a', 'c')) if dw else (('n', 'a'), ('n', 'b'), ('n', 'c'))
        for j, (x, (F, T)) in enumerate(zip('abc', ends)):
            iv = t + 'i3' + x
            ckt.branch(iv, nodes[F], nodes[T])
            coil(T, F, iv, z3, n3, pk, j, True, f3)
            d['i3'].append(iv)
    d['n3'] = n3

    # core, on the base of the primary-1 coil
    Zm = (3 if d1 else 1)*p['V1']**2/Sr
    Lm, Lm0 = p['lm']*Zm/wb, p['lm0']*Zm/wb
    Lc = (Lm - Lm0)/3
    d['Rfe'] = p['rfe']*Zm
    for k in 'abc':
        # im_k == i1_k + f2_k - f3_k - um_k/Rfe
        terms = {t + 'im' + k: 1, i1[k]: -1, psi[k]: J*w/d['Rfe']}
        for v, c in f2[k].items():
            terms[v] = terms.get(v, 0) - c
        for v, c in f3[k].items():
            terms[v] = terms.get(v, 0) + c
        ckt.eq(terms, 0)
        # psi_k == Lm*im_k - Lc*(ima + imb + imc)
        terms = {psi[k]: 1}
        for m in 'abc':
            terms[t + 'im' + m] = Lc
        terms[t + 'im' + k] -= Lm
        ckt.eq(terms, 0)
    return d


# -------------------------------------------------------- tri_monophase_transformer
def add_tri_mono(ckt, p, nodes, w, t='T.'):
    """tri_monophase_transformer.ssc, one to one (two star primaries, single-phase secondary)."""
    Sr, wb, ws = p['Sr'], 2*math.pi*p['fr'], p['ws']
    Zb1, Zb2, Zb3 = p['V1']**2/Sr, p['V2']**2/Sr, p['V3']**2/Sr
    gw = math.sqrt((ws[0] - (ws[1] + ws[2])/2)**2 + 3/4*(ws[2] - ws[1])**2)
    n2 = p['V2']/p['V1']
    n3 = SQ3*p['V3']/(gw*p['V1'])
    d = {'R1': p['r1']*Zb1, 'R2': p['r2']*Zb2, 'R3': p['r3']*Zb3, 'n3': n3}
    z1 = d['R1'] + J*w*p['l1']*Zb1/wb
    z2 = d['R2'] + J*w*p['l2']*Zb2/wb
    z3 = d['R3'] + J*w*p['l3']*Zb3/wb
    Lm, Lm0 = p['lm']*Zb1/wb, p['lm0']*Zb1/wb
    Lc = (Lm - Lm0)/3
    d['Rfe'] = p['rfe']*Zb1
    d['i1'] = [t + 'i1' + k for k in 'abc']
    d['i2'] = [t + 'i2' + k for k in 'abc']
    d['i3'] = [t + 'i3']
    ckt.branch(t + 'i3', nodes['s2'], nodes['s1'])
    terms = {'V:' + nodes['s1']: 1, 'V:' + nodes['s2']: -1, t + 'i3': z3}
    for k, x in enumerate('abc'):
        terms[t + 'psi' + x] = -n3*ws[k]*J*w
    ckt.eq(terms, 0)
    for k, (X, x) in enumerate(zip('ABC', 'abc')):
        ckt.branch(t + 'i1' + x, nodes[X + '1'], nodes['N1'])
        ckt.branch(t + 'i2' + x, nodes[X + '2'], nodes['N2'])
        ckt.eq({'V:' + nodes[X + '1']: 1, 'V:' + nodes['N1']: -1, t + 'i1' + x: -z1, t + 'psi' + x: -J*w}, 0)
        ckt.eq({'V:' + nodes[X + '2']: 1, 'V:' + nodes['N2']: -1, t + 'i2' + x: -z2, t + 'psi' + x: -n2*J*w}, 0)
        # im == i1 + n2 i2 - n3 ws i3 - der(psi)/Rfe
        ckt.eq({t + 'im' + x: 1, t + 'i1' + x: -1, t + 'i2' + x: -n2, t + 'i3': n3*ws[k],
                t + 'psi' + x: J*w/d['Rfe']}, 0)
        terms = {t + 'psi' + x: 1}
        for m in 'abc':
            terms[t + 'im' + m] = Lc
        terms[t + 'im' + x] -= Lm
        ckt.eq(terms, 0)
    return d


# ---------------------------------------------------------------------- helpers
def source(ckt, tag, nodes3, V_ll, phase_deg=0.0):
    """Ideal balanced star source on nodes3 (A, B, C), neutral G grounded, rms line-to-line V_ll.

    Source branch 'I<tag><X>' flows X -> G inside the source: the current into the line is minus it.
    """
    ckt.ground('G')
    E = V_ll/SQ3*cmath.exp(J*math.radians(phase_deg))
    for X, rot in zip(nodes3, (1, A120**2, A120)):
        ckt.vsource('I' + tag + X, X, 'G', E*rot)


def anchor(ckt, node):
    """Reference for a floating network (a zero voltage source to G that carries no current)."""
    ckt.vsource('Iref' + node, node, 'G', 0)


def line_currents(sol, tag, nodes3):
    return [-sol['I' + tag + X] for X in nodes3]


def p_sources(sol):
    """Power delivered by every source 'I<tag><X>' of the circuit (X -> G)."""
    return sum((sol['V:' + k[2:]]*(-sol[k]).conjugate()).real
               for k in sol if k.startswith('IP') and k[2:] and ('V:' + k[2:]) in sol)


def losses(sol, d, w, t):
    pcu = (sum(d['R1']*abs(sol[v])**2 for v in d['i1']) + sum(d['R2']*abs(sol[v])**2 for v in d['i2'])
           + sum(d['R3']*abs(sol[v])**2 for v in d['i3']))
    pfe = sum(abs(J*w*sol[t + 'psi' + k])**2/d['Rfe'] for k in 'abc')
    return pcu + pfe


def p_loads(sol, loads):
    return sum(Z.real*abs(sol[name])**2 for name, Z in loads)


def deg(z):
    return math.degrees(cmath.phase(z))


def wrap(a):
    return (a + 180) % 360 - 180


def zpar(*z):
    return 1/sum(1/x for x in z)


class Checker(ctp.Checker):
    def same(self, label, sa, sb, keys_a, keys_b, scale):
        """max |a - b| over the paired keys, relative to scale."""
        err = max(abs(sa[ka] - sb[kb]) for ka, kb in zip(keys_a, keys_b))/scale
        self.check(label, err, 0.0, TOL, scale=1)

    def balance(self, label, sol, d, w, t, loads):
        """Sources = loads + copper and core losses of the transformer."""
        ps = p_sources(sol)
        self.check(label, ps - p_loads(sol, loads) - losses(sol, d, w, t), 0.0, TOL, scale=max(abs(ps), 1.0))


def pu(p):
    """Per-unit coil impedances (each on its own winding base) and magnetizing branch."""
    z = {k: p['r' + k] + J*p['l' + k] for k in '123'}
    zm = zpar(J*p['lm'], p['rfe'])
    return z, zm


# --------------------------------------------- 1. equivalence with the library blocks
def compare_three_phase(chk, kind, clock):
    p_lib = dict(Sr=630e3, V1=690, V2=400, fr=50, r1=0.004, l1=0.028, r2=0.006, l2=0.022,
                 lm=150, lm0=0.6, rfe=400, clock=clock)
    conn1, sec = {'Dyn': ('delta', 'star'), 'Yyn': ('star', 'star'), 'Dd': ('delta', 'delta')}[kind]
    p_cfg = dict(primaries=1, conn1=conn1, conn2='star', clock2=0, secondary=sec, clock3=clock, ws=[1, -1, 0],
                 Sr=p_lib['Sr'], V1=p_lib['V1'], V2=400, V3=p_lib['V2'], fr=p_lib['fr'],
                 r1=p_lib['r1'], l1=p_lib['l1'], r2=0.005, l2=0.03, r3=p_lib['r2'], l3=p_lib['l2'],
                 lm=p_lib['lm'], lm0=p_lib['lm0'], rfe=p_lib['rfe'])
    add_lib = {'Dyn': ctp.add_Dyn, 'Yyn': ctp.add_Yyn, 'Dd': ctp.add_Dd}[kind]
    w = 2*math.pi*p_lib['fr']
    Zb = p_lib['V2']**2/p_lib['Sr']
    Ib = p_lib['Sr']/(SQ3*p_lib['V2'])
    has_n = sec == 'star'
    has_N = conn1 == 'star'
    print('\n=== transformer_%s clock %d = configurable_transformer: one primary %s, secondary %s, clock3 %d ===' % (
        kind, clock, conn1, sec, clock))

    def loads_noload(ckt):
        anchor(ckt, 'n' if has_n else 'c')
        return []

    def loads_balanced(ckt):
        for x in 'abc':
            ckt.impedance('IL' + x, x, 'G', Zb)
        if has_n:
            anchor(ckt, 'n')
        return [('IL' + x, Zb) for x in 'abc']

    def loads_unbalanced_float(ckt):
        Z = {'a': Zb*(1 + 0.2j), 'b': Zb*(0.6 + 0.5j), 'c': Zb*2.0}
        for x in 'abc':
            ckt.impedance('IL' + x, x, 'G', Z[x])
        return [('IL' + x, Z[x]) for x in 'abc']

    def loads_unbalanced_grounded(ckt):
        lst = loads_unbalanced_float(ckt)
        if has_n:
            anchor(ckt, 'n')
        return lst

    def loads_single(ckt):
        if has_n:          # a-n
            ckt.impedance('ILa', 'a', 'n', Zb)
            anchor(ckt, 'n')
            return [('ILa', Zb)]
        ckt.impedance('ILab', 'a', 'b', 3*Zb)
        anchor(ckt, 'c')
        return [('ILab', 3*Zb)]

    def loads_short(ckt):
        ckt.vsource('Iscab', 'a', 'b', 0)
        ckt.vsource('Iscbc', 'b', 'c', 0)
        if has_n:
            anchor(ckt, 'n')
        else:
            anchor(ckt, 'c')
        return []

    cases = [('no load', loads_noload), ('balanced load 1 pu', loads_balanced),
             ('unbalanced RL load, star point floating', loads_unbalanced_float),
             ('unbalanced RL load, n grounded' if has_n else 'unbalanced RL load (again)', loads_unbalanced_grounded),
             ('single-phase load ' + ('a-n' if has_n else 'a-b'), loads_single),
             ('three-phase short circuit', loads_short)]
    if has_N:
        cases.append(('single-phase load a-n, primary neutral grounded (YNyn)', 'YN'))
    for title, build_loads in cases:
        sols = []
        for which in ('lib', 'cfg'):
            ckt = ctp.Circuit()
            source(ckt, 'P', 'ABC', p_lib['V1'])
            if build_loads == 'YN':
                ckt.impedance('ILa', 'a', 'n', Zb)
                anchor(ckt, 'n')
                ckt.vsource('IN', 'N', 'G', 0)
                loads = [('ILa', Zb)]
            else:
                loads = build_loads(ckt)
            if which == 'lib':
                nodes = {k: k for k in 'ABCabc'}
                if has_N:
                    nodes['N'] = 'N'
                if has_n:
                    nodes['n'] = 'n'
                add_lib(ckt, p_lib, nodes, w, 'T.')
            else:
                nodes = {'A1': 'A', 'B1': 'B', 'C1': 'C', 'a': 'a', 'b': 'b', 'c': 'c'}
                if has_N:
                    nodes['N1'] = 'N'
                if has_n:
                    nodes['n'] = 'n'
                d = add_configurable(ckt, p_cfg, nodes, w, 'S.')
            sols.append(ckt.solve())
        lib, cfg = sols
        vkeys = [k for k in lib if k.startswith('V:') and k in cfg]
        ikeys = [k for k in lib if (k.startswith('IP') or k.startswith('IL') or k.startswith('Isc')
                                    or k.startswith('IN') or k.startswith('Iref')) and k in cfg]
        vscale = max(abs(lib[k]) for k in vkeys)
        iscale = max(max(abs(lib[k]) for k in ikeys), Ib)
        print('%s' % title)
        chk.same('node voltages (%d nodes), max |difference| / max |V|' % len(vkeys), lib, cfg, vkeys, vkeys, vscale)
        chk.same('source and load currents (%d), max |diff.| / max(|I|, Ib)' % len(ikeys), lib, cfg, ikeys, ikeys,
                 iscale)
        chk.same('limb fluxes psi_a, psi_b, psi_c, max |diff.| / max |psi|', lib, cfg,
                 ['T.psi' + k for k in 'abc'], ['S.psi' + k for k in 'abc'], max(abs(lib['T.psi' + k]) for k in 'abc'))
        chk.balance('power balance of configurable_transformer [W]', cfg, d, w, 'S.', loads)


def compare_tri_mono(chk, ws, p_over=None, title=''):
    p = dict(Sr=450e3, V1=380, V2=390, V3=1000, fr=50/3, ws=ws, r1=0.004, l1=0.032, r2=0.006, l2=0.027,
             r3=0.005, l3=0.030, lm=120, lm0=0.5, rfe=600)
    if p_over:
        p.update(p_over)
    p_cfg = dict(p, primaries=2, conn1='star', conn2='star', clock2=0, secondary='single_phase', clock3=0)
    w = 2*math.pi*p['fr']
    Zb3 = p['V3']**2/p['Sr']
    I3b = p['Sr']/p['V3']
    print('\n=== tri_monophase_transformer ws %s = configurable_transformer: two primaries star, clock2 0, '
          'single-phase%s ===' % (ws, title))
    cases = (('no load, N1 N2 floating', None, False), ('rated load 1 pu, N1 N2 floating', Zb3, False),
             ('load 0.8 + j0.6 pu, N1 N2 floating', Zb3*(0.8 + 0.6j), False),
             ('rated load 1 pu, N1 N2 grounded', Zb3, True), ('short circuit, N1 N2 floating', 0.0, False))
    for label, ZL, gnd in cases:
        sols = []
        for which in ('lib', 'cfg'):
            ckt = ctp.Circuit()
            source(ckt, 'P', ('A1', 'B1', 'C1'), p['V1'])
            source(ckt, 'P', ('A2', 'B2', 'C2'), p['V2']*0.985, -2.0)       # second grid former, not matched
            anchor(ckt, 's2')
            loads = []
            if ZL is not None:
                if ZL == 0:
                    ckt.vsource('ILs', 's1', 's2', 0)
                else:
                    ckt.impedance('ILs', 's1', 's2', ZL)
                    loads = [('ILs', ZL)]
            if gnd:
                ckt.vsource('IN1', 'N1', 'G', 0)
                ckt.vsource('IN2', 'N2', 'G', 0)
            nodes = {k: k for k in ('A1', 'B1', 'C1', 'N1', 'A2', 'B2', 'C2', 'N2', 's1', 's2')}
            if which == 'lib':
                add_tri_mono(ckt, p, nodes, w, 'T.')
            else:
                d = add_configurable(ckt, p_cfg, nodes, w, 'S.')
            sols.append(ckt.solve())
        lib, cfg = sols
        vkeys = [k for k in lib if k.startswith('V:') and k in cfg]
        ikeys = [k for k in lib if k.startswith('I') and not k.startswith('T.') and k in cfg]
        print(label)
        chk.same('node voltages (%d nodes)' % len(vkeys), lib, cfg, vkeys, vkeys, max(abs(lib[k]) for k in vkeys))
        chk.same('source and load currents (%d)' % len(ikeys), lib, cfg, ikeys, ikeys,
                 max(max(abs(lib[k]) for k in ikeys), I3b))
        chk.same('limb fluxes', lib, cfg, ['T.psi' + k for k in 'abc'], ['S.psi' + k for k in 'abc'],
                 max(abs(lib['T.psi' + k]) for k in 'abc'))
        chk.balance('power balance of configurable_transformer [W]', cfg, d, w, 'S.', loads)


# ------------------------------------------------------- 2. new configurations
BASE = dict(Sr=500e3, V1=690, V2=400, V3=1000, fr=50, r1=0.004, l1=0.030, r2=0.006, l2=0.025, r3=0.005, l3=0.035,
            lm=100, lm0=0.5, rfe=500)


def ports(p):
    """Visible ports of a configuration, mapped to circuit nodes of the same name."""
    names = ['A1', 'B1', 'C1'] + (['N1'] if p['conn1'] == 'star' else [])
    if p['primaries'] == 2:
        names += ['A2', 'B2', 'C2'] + (['N2'] if p['conn2'] == 'star' else [])
    if p['secondary'] == 'single_phase':
        names += ['s1', 's2']
    else:
        names += ['a', 'b', 'c'] + (['n'] if p['secondary'] == 'star' else [])
    return {k: k for k in names}


def reference_floating(ckt, p, fed1=True, fed2=False, sec_loaded=False):
    """Anchors of the windings that no source or grounded load references."""
    if not fed1:
        anchor(ckt, 'N1' if p['conn1'] == 'star' else 'A1')
    if p['primaries'] == 2 and not fed2:
        anchor(ckt, 'N2' if p['conn2'] == 'star' else 'A2')
    if not sec_loaded:
        if p['secondary'] == 'single_phase':
            anchor(ckt, 's2')
        else:
            anchor(ckt, 'n' if p['secondary'] == 'star' else 'c')


def u_ll(sol, X, Y):
    return sol['V:' + X] - sol['V:' + Y]


def check_clock_numbers(chk):
    z, zm = pu(BASE)
    voc = zm/(z['1'] + zm)
    w = 2*math.pi*BASE['fr']
    print('\n=== no-load ratio and phase shift for each pair of connections and each clock number ===')
    print('    (primary 1 fed at V1, the others open: |u| = V |zm/(z1 + zm)|, lagging clock*30 deg; the clock')
    print('    numbers of the wrong parity are refused by the asserts of the ssc)')
    for conn1 in ('star', 'delta'):
        for connw in ('star', 'delta'):
            for h in range(12):
                valid = (h % 2 == 0) == (conn1 == connw)
                for role in ('secondary', 'primary 2'):
                    if role == 'secondary':
                        p = dict(BASE, primaries=1, conn1=conn1, conn2='star', clock2=0, secondary=connw, clock3=h,
                                 ws=[1, -1, 0])
                        ends = ('a', 'b')
                        tag = '%s%s%d' % (IEC[conn1], IEC[connw].lower(), h)
                    else:
                        p = dict(BASE, primaries=2, conn1=conn1, conn2=connw, clock2=h, secondary='star',
                                 clock3=0 if conn1 == 'star' else 11, ws=[1, -1, 0])
                        ends = ('A2', 'B2')
                        tag = '%s+%s%d' % (IEC[conn1], IEC[connw], h)
                    ckt = ctp.Circuit()
                    source(ckt, 'P', ('A1', 'B1', 'C1'), BASE['V1'])
                    reference_floating(ckt, p)
                    try:
                        add_configurable(ckt, p, ports(p), w)
                        refused = ''
                    except ValueError as e:
                        refused = str(e)
                    if not valid or refused:
                        chk.check('%-5s %-9s refused: %s' % (tag, role, refused or 'NO'), 0.0 if
                                  (refused and not valid) else 1.0, 0.0, TOL, scale=1)
                        continue
                    sol = ckt.solve()
                    r = u_ll(sol, *ends)/u_ll(sol, 'A1', 'B1')
                    V = BASE['V3'] if role == 'secondary' else BASE['V2']
                    chk.check('%-5s %-9s |u_%s%s/u_A1B1| / (V/V1)' % (tag, role, *ends), abs(r)*BASE['V1']/V,
                              abs(voc), TOL)
                    chk.check('%-5s %-9s phase(u_%s%s/u_A1B1) [deg]' % (tag, role, *ends), wrap(deg(r) - deg(voc)),
                              wrap(-30*h), TOL, scale=360)


def check_short_circuits(chk):
    z, zm = pu(BASE)
    w = 2*math.pi*BASE['fr']
    print('\n=== short-circuit impedance between each pair of windings (pu on Sr) ===')
    for conn1, conn2, clock2, sec, clock3 in (('star', 'star', 0, 'star', 0), ('star', 'delta', 11, 'delta', 1),
                                              ('delta', 'star', 1, 'star', 11), ('delta', 'delta', 6, 'delta', 0),
                                              ('star', 'delta', 1, 'star', 6), ('delta', 'star', 7, 'delta', 6)):
        p = dict(BASE, primaries=2, conn1=conn1, conn2=conn2, clock2=clock2, secondary=sec, clock3=clock3,
                 ws=[1, -1, 0])
        cfg = '%s+%s%d %s%d' % (IEC[conn1], IEC[conn2], clock2, IEC[sec].lower(), clock3)
        V = {'1': BASE['V1'], '2': BASE['V2'], '3': BASE['V3']}
        port = {'1': ('A1', 'B1', 'C1'), '2': ('A2', 'B2', 'C2'), '3': ('a', 'b', 'c')}
        for fed, shorted in (('1', '3'), ('1', '2'), ('2', '3'), ('3', '1')):
            ckt = ctp.Circuit()
            source(ckt, 'P', port[fed], V[fed])
            X, Y, Z = port[shorted]
            ckt.vsource('IscXY', X, Y, 0)
            ckt.vsource('IscYZ', Y, Z, 0)
            anchor(ckt, X)
            for k in '12':
                if k not in (fed, shorted) and k in '12':
                    anchor(ckt, ('N' + k if p['conn' + k] == 'star' else 'A' + k))
            if '3' not in (fed, shorted):
                anchor(ckt, 'n' if sec == 'star' else 'c')
            d = add_configurable(ckt, p, ports(p), w)
            sol = ckt.solve()
            I = line_currents(sol, 'P', port[fed])
            Ib = BASE['Sr']/(SQ3*V[fed])
            zsc = z[fed] + zpar(zm, z[shorted])
            chk.check('%-22s fed %s, %s shorted: Ib/|I| = |z%s + zm || z%s|' % (cfg, fed, shorted, fed, shorted),
                      Ib/abs(I[0]), abs(zsc), TOL)
            chk.check('%-22s    angle of z_sc [deg]' % '', wrap(deg(sol['V:' + port[fed][0]]) - deg(I[0])), deg(zsc),
                      TOL, scale=360)
            chk.balance('%-22s    power balance [W]' % '', sol, d, w, 'S.', [])


def check_two_primaries_load(chk):
    z, zm = pu(BASE)
    w = 2*math.pi*BASE['fr']
    print('\n=== two primaries sharing a balanced load on the secondary (T network of z1, z2, z3, zm) ===')
    for conn1, conn2, clock2, sec, clock3, e2 in (('star', 'star', 0, 'star', 0, 1.0),
                                                  ('star', 'delta', 1, 'star', 0, 1.0),
                                                  ('star', 'delta', 11, 'delta', 11, 1.0),
                                                  ('delta', 'star', 11, 'star', 11, 1.0),
                                                  ('delta', 'delta', 0, 'delta', 6, 1.0),
                                                  ('star', 'delta', 1, 'star', 0, 1.03*cmath.exp(J*math.radians(2))),
                                                  ('delta', 'star', 5, 'delta', 4, 0.97*cmath.exp(J*math.radians(-3)))):
        p = dict(BASE, primaries=2, conn1=conn1, conn2=conn2, clock2=clock2, secondary=sec, clock3=clock3,
                 ws=[1, -1, 0])
        zl = 0.9 + 0.3j
        ckt = ctp.Circuit()
        source(ckt, 'P', ('A1', 'B1', 'C1'), BASE['V1'])
        source(ckt, 'P', ('A2', 'B2', 'C2'), BASE['V2']*abs(e2), deg(e2) - 30*clock2)
        Zl = zl*BASE['V3']**2/BASE['Sr']
        if sec == 'star':
            for x in 'abc':
                ckt.impedance('IL' + x, x, 'n', Zl)
            anchor(ckt, 'n')
        else:
            for x in 'abc':
                ckt.impedance('IL' + x, x, 'G', Zl)
        d = add_configurable(ckt, p, ports(p), w)
        sol = ckt.solve()
        # pu T network: (1 - um)/z1 + (e2 - um)/z2 = um/zm + um/(z3 + zl)
        um = (1/z['1'] + e2/z['2'])/(1/z['1'] + 1/z['2'] + 1/zm + 1/(z['3'] + zl))
        i1, i2, i3 = (1 - um)/z['1'], (e2 - um)/z['2'], um/(z['3'] + zl)
        Ib = {k: BASE['Sr']/(SQ3*BASE['V' + k]) for k in '123'}
        I1 = line_currents(sol, 'P', ('A1', 'B1', 'C1'))
        I2 = line_currents(sol, 'P', ('A2', 'B2', 'C2'))
        cfg = '%s+%s%d %s%d, e2 %.2f/_%.0f deg' % (IEC[conn1], IEC[conn2], clock2, IEC[sec].lower(), clock3, abs(e2),
                                                    deg(e2))
        print(cfg)
        chk.check('I_A1 / Ib1', abs(I1[0])/Ib['1'], abs(i1), TOL)
        chk.check('I_A2 / Ib2', abs(I2[0])/Ib['2'], abs(i2), TOL)
        chk.check('phase(I_A2) - phase(u_A1) [deg]', wrap(deg(I2[0]) - deg(sol['V:A1'])), wrap(deg(i2) - 30*clock2),
                  TOL, scale=360)
        Ia = sol['ILa']
        chk.check('I_a / Ib3 (load)', abs(Ia)/Ib['3'], abs(i3), TOL)
        chk.check('phase(I_a) - phase(u_A1) [deg]', wrap(deg(Ia) - deg(sol['V:A1'])), wrap(deg(i3) - 30*clock3),
                  TOL, scale=360)
        chk.balance('power balance [W]', sol, d, w, 'S.', [('IL' + x, Zl) for x in 'abc'])


def check_single_phase_no_load(chk):
    z, zm = pu(BASE)
    voc = zm/(z['1'] + zm)
    w = 2*math.pi*BASE['fr']
    print('\n=== single-phase secondary at no load: |u_s1s2| = V3 |zm/(z1 + zm)|, phase arg(g) (+30 deg delta) ===')
    for conn1 in ('star', 'delta'):
        for ws in ([1, -1, 0], [1, -0.5, -0.5], [1, 0, 0], [0, 1, -1], [-1, 0, 1], [0.5, -1, 0.5]):
            p = dict(BASE, primaries=1, conn1=conn1, conn2='star', clock2=0, secondary='single_phase', clock3=0,
                     ws=ws)
            ckt = ctp.Circuit()
            source(ckt, 'P', ('A1', 'B1', 'C1'), BASE['V1'])
            reference_floating(ckt, p)
            add_configurable(ckt, p, ports(p), w)
            sol = ckt.solve()
            us = u_ll(sol, 's1', 's2')
            g = ws[0] + ws[1]*A120**2 + ws[2]*A120
            ph = deg(g) + (30 if conn1 == 'delta' else 0) + deg(voc)
            chk.check('%-5s ws %-16s |u_s1s2| / V3' % (conn1, ws), abs(us)/BASE['V3'], abs(voc), TOL)
            chk.check('%-5s ws %-16s phase(u_s1s2/u_A1) [deg]' % (conn1, ws), wrap(deg(us) - deg(sol['V:A1'])),
                      wrap(ph), TOL, scale=360)


# ------------------------------------- 3. single-phase load on a star secondary
def check_star_vs_single_phase(chk):
    w = 2*math.pi*BASE['fr']
    print('\n=== single-phase load on a star secondary = single-phase secondary ===')
    for primaries in (1, 2):
        for conn1 in ('star', 'delta'):
            for ws, across, k3, kz in (([1, -1, 0], ('a', 'b'), 1.0, 0.5), ([1, 0, 0], ('a', 'n'), 1/SQ3, 1/3)):
                conn2 = 'star' if conn1 == 'star' else 'delta'
                common = dict(BASE, primaries=primaries, conn1=conn1, conn2=conn2, clock2=0)
                p_single = dict(common, secondary='single_phase', clock3=0, ws=ws)
                # same turns per coil: star V3s = V3/k3; each coil r3, l3 = kz times those of the single-phase winding
                p_star = dict(common, secondary='star', clock3=0 if conn1 == 'star' else 11, ws=[1, -1, 0],
                              V3=BASE['V3']/k3, r3=BASE['r3']*kz, l3=BASE['l3']*kz)
                ZL = 0.85*BASE['V3']**2/BASE['Sr']*(1 + 0.3j)
                for gnd in ((False, True) if conn1 == 'star' else (False,)):
                    sols, ds = [], []
                    for p in (p_single, p_star):
                        ckt = ctp.Circuit()
                        source(ckt, 'P', ('A1', 'B1', 'C1'), BASE['V1'])
                        if primaries == 2:
                            source(ckt, 'P', ('A2', 'B2', 'C2'), BASE['V2']*1.01, 1.0)
                        if gnd:
                            ckt.vsource('IN1', 'N1', 'G', 0)
                        if p['secondary'] == 'single_phase':
                            ckt.impedance('ILs', 's1', 's2', ZL)
                            anchor(ckt, 's2')
                        else:
                            ckt.impedance('ILs', across[0], across[1], ZL)
                            anchor(ckt, across[1])
                        ds.append(add_configurable(ckt, p, ports(p), w))
                        sols.append(ckt.solve())
                    s1p, s3p = sols
                    label = '%d primar%s, primary 1 %s%s, ws %s = star loaded %s-%s' % (
                        primaries, 'y' if primaries == 1 else 'ies', conn1, ', N1 grounded' if gnd else '', ws,
                        *across)
                    print(label)
                    u1 = u_ll(s1p, 's1', 's2')
                    u3 = u_ll(s3p, *across)
                    chk.check('load voltage, star / single-phase', abs(u3 - u1)/abs(u1), 0.0, TOL, scale=1)
                    chk.check('load current, star / single-phase', abs(s3p['ILs'] - s1p['ILs'])/abs(s1p['ILs']), 0.0,
                              TOL, scale=1)
                    keys = [k for k in s1p if k.startswith('IP') and k in s3p]
                    chk.same('source currents (%d)' % len(keys), s1p, s3p, keys, keys,
                             max(abs(s1p[k]) for k in keys))
                    chk.same('limb fluxes', s1p, s3p, ['S.psi' + k for k in 'abc'], ['S.psi' + k for k in 'abc'],
                             max(abs(s1p['S.psi' + k]) for k in 'abc'))
                    chk.balance('power balance, single-phase [W]', s1p, ds[0], w, 'S.', [('ILs', ZL)])


def main():
    chk = Checker()
    print('check_configurable_transformer.py: configurable_transformer.ssc rebuilt in the phasor domain')
    for clock in (11, 1, 5, 7):
        compare_three_phase(chk, 'Dyn', clock)
    for clock in (0, 6):
        compare_three_phase(chk, 'Yyn', clock)
    for clock in (0, 6):
        compare_three_phase(chk, 'Dd', clock)
    for ws in ([1, -1, 0], [1, -0.5, -0.5], [1, 0, 0]):
        compare_tri_mono(chk, ws)
    compare_tri_mono(chk, [1, -1, 0], dict(Sr=450e3, V1=380, V2=380, V3=1500, fr=50, r1=0.005, l1=0.03, r2=0.005,
                                           l2=0.03, r3=0.005, l3=0.03, lm=100, lm0=0.5, rfe=500),
                     ', TELEMA 1500 V 50 Hz')
    check_clock_numbers(chk)
    check_short_circuits(chk)
    check_two_primaries_load(chk)
    check_single_phase_no_load(chk)
    check_star_vs_single_phase(chk)
    print('\n%s' % ('ALL CHECKS PASSED' if chk.fail == 0 else '%d CHECK(S) FAILED' % chk.fail))
    return 0 if chk.fail == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
