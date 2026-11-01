#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
slxsim - runs a Simulink library block stored in an .slx file (XML format) without MATLAB.

The block diagram is read from the .slx (blocks, parameters, lines, Goto/From tags,
Variant Source conditions, library references inside the same file, MATLAB Function
scripts) and simulated with a fixed-step fourth-order Runge-Kutta solver that follows the
Simulink conventions that matter for the grid emulators:

- Integrator states are the continuous states (initial condition 0 unless given);
- Step blocks switch at the major time steps (t >= Time), their output is held in the
  minor steps (zero-crossing mode), so a step time on the grid is hit exactly;
- Rate Limiter in continuous mode: y = u at the first major step, then
  y = y_prev + min(max(u - y_prev, F*dt), R*dt), dt = t - t_last_major (also in the minor
  steps); y_prev and t_last_major are updated at the major steps;
- MATLAB Function blocks: their script (simple assignments only) is translated to Python.

Only the block types used by the two grid emulators are supported.
"""
import re
import zipfile
import html
import xml.etree.ElementTree as ET
import numpy as np

# ----------------------------------------------------------------------------- MATLAB expressions
_FUNCS = {'sqrt': 'np.sqrt', 'cos': 'np.cos', 'sin': 'np.sin', 'mod': 'np.mod', 'exp': 'np.exp',
          'abs': 'np.abs'}


def matlab_to_python(expr):
    """Translate a scalar MATLAB expression (arithmetic, ||, &&, ~, ==) to Python."""
    e = expr.strip()
    e = e.replace('||', ' or ').replace('&&', ' and ')
    e = re.sub(r'~=', '!=', e)
    e = re.sub(r'~', ' not ', e)
    e = e.replace('^', '**')
    e = re.sub(r'\bpi\b', 'np.pi', e)
    for f, g in _FUNCS.items():
        e = re.sub(r'\b%s\s*\(' % f, g + '(', e)
    return e


def meval(expr, ws):
    """Evaluate a MATLAB expression in the workspace ws (dict name -> value). Scalars are
    numpy floats, so that x/0 gives Inf as in MATLAB."""
    env = {k: (np.float64(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else v)
           for k, v in ws.items()}
    with np.errstate(divide='ignore', invalid='ignore'):
        return eval(matlab_to_python(expr), {'np': np, '__builtins__': {}}, env)


def mtimes(a, b):
    """MATLAB a*b for scalars, vectors (column) and matrices stored as numpy arrays."""
    a = np.asarray(a, dtype=float)
    b = np.asarray(b, dtype=float)
    if a.size == 1 or b.size == 1:
        return a * b
    if b.ndim == 1:
        b = b.reshape(-1, 1)
    r = np.atleast_2d(a) @ b
    return r


def as_out(v):
    v = np.asarray(v, dtype=float)
    if v.size == 1:
        return float(v.reshape(-1)[0])
    return v.reshape(-1)


# ----------------------------------------------------------------------------- parsing
class Block:
    def __init__(self, el):
        self.type = el.get('BlockType')
        self.name = html.unescape(el.get('Name'))
        self.sid = el.get('SID')
        self.p = {}
        for c in el.findall('P'):
            self.p[c.get('Name')] = c.text if c.text is not None else ''
        ref = el.find('System')
        self.system = ref.get('Ref') if ref is not None else None
        self.variant_controls = [c.text for c in el.findall("Array[@PropName='VariantControls']/Cell")]
        pc = el.find('PortCounts')
        self.n_in = int(pc.get('in', 0)) if pc is not None else 0
        self.n_out = int(pc.get('out', 0)) if pc is not None else 0
        self.mask = el.find('Mask')


class System:
    def __init__(self, name, xml):
        self.name = name
        root = ET.fromstring(xml)
        self.blocks = {}
        for el in root.findall('Block'):
            b = Block(el)
            self.blocks[b.sid] = b
        # line table: (dst_sid, in_port) -> (src_sid, out_port, line_name)
        self.src_of = {}
        for ln in root.findall('Line'):
            self._line(ln, None, None)

    def _line(self, el, src, name):
        s = el.find("P[@Name='Src']")
        if s is not None:
            sid, port = s.text.rsplit('#', 1)
            src = (sid, int(port.split(':')[1]))
        n = el.find("P[@Name='Name']")
        if n is not None:
            name = html.unescape(n.text)
        d = el.find("P[@Name='Dst']")
        if d is not None:
            sid, port = d.text.rsplit('#', 1)
            self.src_of[(sid, int(port.split(':')[1]))] = (src[0], src[1], name)
        for br in el.findall('Branch'):
            self._line(br, src, name)


class Library:
    def __init__(self, path):
        z = zipfile.ZipFile(path)
        self.systems = {}
        for n in z.namelist():
            m = re.match(r'simulink/systems/(system_[^/]+)\.xml$', n)
            if m:
                self.systems[m.group(1)] = System(m.group(1), z.read(n).decode('utf-8'))
        # MATLAB Function scripts: chartFileNumber -> (script, input names, output names)
        self.charts = {}
        for n in z.namelist():
            if re.match(r'simulink/stateflow/chart_\d+\.xml$', n):
                root = ET.fromstring(z.read(n).decode('utf-8'))
                num = root.find("P[@Name='chartFileNumber']").text
                script = root.find('.//eml/P[@Name="script"]').text
                ins, outs, pars = [], [], []
                for d in root.find('Children').findall('data'):
                    scope = d.find("P[@Name='scope']").text
                    {'INPUT_DATA': ins, 'OUTPUT_DATA': outs, 'PARAMETER_DATA': pars}.get(scope, []).append(d.get('name'))
                self.charts[num] = (script, ins, outs, pars)
        # block paths inside the library (for $bdroot references)
        self.paths = {}
        self._index('system_root', '')

    def _index(self, sysname, prefix):
        for b in self.systems[sysname].blocks.values():
            path = (prefix + '/' if prefix else '') + b.name
            self.paths[path] = (sysname, b.sid)
            if b.type == 'SubSystem' and b.system and b.p.get('SFBlockType') != 'MATLAB Function':
                self._index(b.system, path)

    def root_block(self):
        bl = list(self.systems['system_root'].blocks.values())
        assert len(bl) == 1
        return bl[0]


# ----------------------------------------------------------------------------- MATLAB Function
class MatlabFunction:
    """Python translation of a MATLAB Function script made of assignments."""

    def __init__(self, script, ins, outs, pars):
        self.ins, self.outs, self.pars = ins, outs, pars
        body = []
        for line in script.split('\n'):
            line = line.split('%')[0].strip()
            if not line or line.startswith('function') or line == 'end':
                continue
            line = line.rstrip(';')
            lhs, rhs = line.split('=', 1)
            body.append((lhs.strip(), self._translate(rhs)))
        self.body = body

    @staticmethod
    def _translate(rhs):
        # the scripts of the emulators use scalars only (A, B, C of the first-order
        # LVRT filter are 1x1), so MATLAB '*' is the Python '*'
        return matlab_to_python(rhs)

    def __call__(self, values):
        ws = dict(values)
        for lhs, rhs in self.body:
            ws[lhs] = eval(rhs, {'np': np, 'mtimes': mtimes, '__builtins__': {}}, ws)
        return [as_out(ws[o]) for o in self.outs]


# ----------------------------------------------------------------------------- simulation
class Simulator:
    def __init__(self, lib, mask_ws):
        self.lib = lib
        self.ws = dict(mask_ws)
        self.pcache = {}
        self.root = lib.root_block()
        self.mlf = {}
        # Goto tags (unique in the two emulators)
        self.goto = {}
        for sname, s in lib.systems.items():
            for b in s.blocks.values():
                if b.type == 'Goto':
                    tag = b.p['GotoTag']
                    assert tag not in self.goto, 'duplicate Goto tag ' + tag
                    self.goto[tag] = (sname, b.sid)
        self.int_state = {}     # (ctx, sid) -> np.array
        self.rl_state = {}      # (ctx, sid) -> [y_prev, t_last] (None before the first major step)
        self.step_mode = {}     # (ctx, sid) -> bool (held in the minor steps)
        self.integrators = []   # list of (ctx, sysname, sid)
        self.ratelimiters = []
        self.steps = []
        self.sys_ctx = {}       # system name -> list of instance contexts
        self.ctx_sys = {}       # instance context -> system name
        self._collect(self.root.system, ('root',))

    # context = tuple of SIDs of the subsystem instances from the root
    def _collect(self, sysname, ctx):
        s = self.lib.systems[sysname]
        self.sys_ctx.setdefault(sysname, []).append(ctx)
        self.ctx_sys[ctx] = sysname
        for b in s.blocks.values():
            if b.type == 'SubSystem' and b.p.get('SFBlockType') != 'MATLAB Function':
                self._collect(b.system, ctx + (b.sid,))
            elif b.type == 'Reference':
                tsys, tsid = self._resolve(b)
                tb = self.lib.systems[tsys].blocks[tsid]
                self._collect(tb.system, ctx + (b.sid,))
            elif b.type == 'Integrator':
                self.integrators.append((ctx, sysname, b.sid))
            elif b.type == 'RateLimiter':
                self.ratelimiters.append((ctx, sysname, b.sid))
            elif b.type == 'Step':
                self.steps.append((ctx, sysname, b.sid))

    def _resolve(self, b):
        src = b.p['SourceBlock']
        assert src.startswith('$bdroot/'), src
        return self.lib.paths[src[len('$bdroot/'):]]

    # system of an instance context
    def _system_of(self, ctx):
        return self.ctx_sys[ctx]

    def param(self, b, name, default=None):
        """Block parameter evaluated in the mask workspace (constant during a run: cached)."""
        key = (id(b), name)
        if key not in self.pcache:
            self.pcache[key] = meval(b.p.get(name, default), self.ws)
        return self.pcache[key]

    # value of output port `port` of block `sid` in context `ctx`
    def out(self, ctx, sid, port):
        key = (ctx, sid, port)
        if key in self.cache:
            return self.cache[key]
        sysname = self._system_of(ctx)
        b = self.lib.systems[sysname].blocks[sid]
        v = self._eval(ctx, sysname, b, port)
        self.cache[key] = v
        return v

    def inp(self, ctx, sysname, sid, port):
        src = self.lib.systems[sysname].src_of[(sid, port)]
        return self.out(ctx, src[0], src[1])

    def _eval(self, ctx, sysname, b, port):
        t = self.t
        typ = b.type
        if typ == 'Constant':
            return as_out(self.param(b, 'Value'))
        if typ == 'Gain':
            k = np.asarray(self.param(b, 'Gain'), dtype=float)
            u = self.inp(ctx, sysname, b.sid, 1)
            if b.p.get('Multiplication', '').startswith('Matrix'):
                return as_out(mtimes(k, u))
            return as_out(k * np.asarray(u))
        if typ == 'Sum':
            signs = [c for c in b.p.get('Inputs', '++') if c in '+-']
            if not signs:
                signs = ['+'] * int(b.p['Inputs'])
            acc = 0.0
            for i, sg in enumerate(signs):
                u = np.asarray(self.inp(ctx, sysname, b.sid, i + 1), dtype=float)
                acc = acc + (u if sg == '+' else -u)
            return as_out(acc)
        if typ == 'Integrator':
            return as_out(self.int_state[(ctx, b.sid)])
        if typ == 'Step':
            on = self.step_mode[(ctx, b.sid)]
            return float(self.param(b, 'FinalValue', '1') if on else self.param(b, 'InitialValue', '0'))
        if typ == 'RateLimiter':
            u = self.inp(ctx, sysname, b.sid, 1)
            st = self.rl_state[(ctx, b.sid)]
            if st is None:
                return u                              # continuous mode: y(0) = u(0)
            y_prev, t_last = st
            dt = t - t_last
            r = self.param(b, 'RisingSlewLimit') * dt
            f = self.param(b, 'FallingSlewLimit') * dt
            return float(y_prev + min(max(u - y_prev, f), r))
        if typ == 'Goto':
            return self.inp(ctx, sysname, b.sid, 1)
        if typ == 'From':
            gsys, gsid = self.goto[b.p['GotoTag']]
            ctxs = self.sys_ctx[gsys]
            assert len(ctxs) == 1, 'Goto in a system with several instances'
            return self.out(ctxs[0], gsid, 1)
        if typ == 'Inport':
            if len(ctx) == 1:
                raise ValueError('root inport')
            pctx = ctx[:-1]
            psys = self._system_of(pctx)
            k = int(b.p.get('Port', '1'))
            return self.inp(pctx, psys, ctx[-1], k)
        if typ == 'Outport':
            return self.inp(ctx, sysname, b.sid, 1)
        if typ in ('SubSystem', 'Reference') and b.p.get('SFBlockType') != 'MATLAB Function':
            cctx = ctx + (b.sid,)
            csys = self._system_of(cctx)
            for cb in self.lib.systems[csys].blocks.values():
                if cb.type == 'Outport' and int(cb.p.get('Port', '1')) == port:
                    return self.out(cctx, cb.sid, 1)
            raise KeyError('outport %d of %s' % (port, b.name))
        if typ == 'SubSystem':   # MATLAB Function
            key = (sysname, b.sid)
            if key not in self.mlf:
                inner = self.lib.systems[b.system]
                sf = [x for x in inner.blocks.values() if x.type == 'S-Function'][0]
                num = sf.p['Tag'].split()[-1]
                script, ins, outs, pars = self.lib.charts[num]
                self.mlf[key] = MatlabFunction(script, ins, outs, pars)
            f = self.mlf[key]
            vals = {}
            for i, name in enumerate(f.ins):
                vals[name] = self.inp(ctx, sysname, b.sid, i + 1)
            for name in f.pars:
                vals[name] = self.ws[name]
            outs = f(vals)
            return outs[port - 1]
        if typ == 'VariantSource':
            key = (id(b), 'VariantControls')
            if key not in self.pcache:
                self.pcache[key] = [i for i, c in enumerate(b.variant_controls)
                                    if bool(meval(c, self.ws))]
            active = self.pcache[key]
            if len(active) != 1:
                raise ValueError('Variant Source %s: %d active choices' % (b.name, len(active)))
            return self.inp(ctx, sysname, b.sid, active[0] + 1)
        if typ == 'BusCreator':
            raise ValueError('bus creator evaluated directly')
        raise NotImplementedError(typ)

    # ------------------------------------------------------------------ helpers
    def outputs(self):
        """Elements of the bus that leaves the masked block: dict name -> value."""
        sysname = self.root.system
        s = self.lib.systems[sysname]
        bc = [b for b in s.blocks.values() if b.type == 'BusCreator'][0]
        res = {}
        for i in range(bc.n_in):
            src_sid, src_port, name = s.src_of[(bc.sid, i + 1)]
            res[name] = self.out(('root',), src_sid, src_port)
        return res

    def derivatives(self):
        d = {}
        for ctx, sysname, sid in self.integrators:
            d[(ctx, sid)] = np.atleast_1d(np.asarray(self.inp(ctx, sysname, sid, 1), dtype=float))
        return d

    def run(self, t_end, h, sample_every=1):
        """Fixed-step RK4 with major steps every h. Returns (t, dict of arrays)."""
        for ctx, sysname, sid in self.integrators:
            b = self.lib.systems[sysname].blocks[sid]
            ic = meval(b.p.get('InitialCondition', '0'), self.ws)
            self.int_state[(ctx, sid)] = np.atleast_1d(np.asarray(ic, dtype=float))
        for ctx, sysname, sid in self.ratelimiters:
            self.rl_state[(ctx, sid)] = None
        # size the vector states (Gain Matrix(K*u) on a scalar zero state)
        self._size_by_matrices()
        n = int(round(t_end / h))
        t_log, log = [], {}
        for k in range(n + 1):
            tk = k * h
            # major step: Step modes and outputs at tk
            self.t = tk
            for ctx, sysname, sid in self.steps:
                b = self.lib.systems[sysname].blocks[sid]
                self.step_mode[(ctx, sid)] = tk >= self.param(b, 'Time')
            self.cache = {}
            outs = self.outputs()
            d1 = self.derivatives()
            rl_now = {}
            for ctx, sysname, sid in self.ratelimiters:
                rl_now[(ctx, sid)] = self.out(ctx, sid, 1)
            if k % sample_every == 0:
                t_log.append(tk)
                for name, v in outs.items():
                    log.setdefault(name, []).append(v)
            if k == n:
                break
            # update the rate limiters (major step)
            for key, v in rl_now.items():
                self.rl_state[key] = (v, tk)
            # RK4 over [tk, tk + h], minor steps
            x0 = {key: v.copy() for key, v in self.int_state.items()}

            def f(tt, x):
                self.t = tt
                self.int_state.update(x)
                self.cache = {}
                return self.derivatives()

            k1 = d1
            k2 = f(tk + h / 2, {key: x0[key] + h / 2 * k1[key] for key in x0})
            k3 = f(tk + h / 2, {key: x0[key] + h / 2 * k2[key] for key in x0})
            k4 = f(tk + h, {key: x0[key] + h * k3[key] for key in x0})
            for key in x0:
                self.int_state[key] = x0[key] + h / 6 * (k1[key] + 2 * k2[key] + 2 * k3[key] + k4[key])
        return np.array(t_log), {k: np.array(v) for k, v in log.items()}

    def _size_by_matrices(self):
        """An Integrator inside a state-space loop (Gain Matrix(K*u)) gets the row count of
        the matrix gain fed by its output."""
        for ctx, sysname, sid in self.integrators:
            s = self.lib.systems[sysname]
            for (dsid, dport), (ssid, sport, _) in s.src_of.items():
                if ssid == sid:
                    gb = s.blocks[dsid]
                    if gb.type == 'Gain' and gb.p.get('Multiplication', '').startswith('Matrix'):
                        k = np.atleast_2d(np.asarray(self.param(gb, 'Gain'), dtype=float))
                        if k.shape[1] > 1:
                            self.int_state[(ctx, sid)] = np.zeros(k.shape[1])
