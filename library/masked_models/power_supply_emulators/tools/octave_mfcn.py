#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
octave_mfcn - runs the script of a MATLAB Function block in GNU Octave.

The function takes its port inputs first (t, and x for a block with states), then the
block parameters (scope Parameter) as further arguments, as a MATLAB Function block does.
A wrapper call_block(t, [x,] P) passes the fields of the struct P in the order of the
signature. The block is then evaluated on a fixed time grid:
- without state input (one port input t): at every grid point;
- with a state input x and a last output dx (Clock + Integrator around the function):
  integrated with the classic fourth-order Runge-Kutta method, x(0) = 0.
"""
import os
import re
import subprocess
import tempfile
import numpy as np
import scipy.io as sio


def signature(script):
    """Name and input arguments of the main function (continuation lines allowed)."""
    m = re.search(r'^\s*function\s*(?:\[[^\]]*\]|\w+)?\s*=?\s*([A-Za-z_]\w*)\s*\(([^)]*)\)',
                  script, re.M | re.S)
    args = [a.strip() for a in m.group(2).replace('...', ' ').split(',') if a.strip()]
    return m.group(1), args


def function_name(script):
    return signature(script)[0]


DRIVER = r"""
function run_driver(infile, outfile)
S = load(infile);
P = S.P;
h = S.h;
N = round(S.t_end/h);
nout = S.nout;
Y = zeros(N + 1, nout);
if S.nx == 0
    for k = 0:N
        out = cell(1, nout);
        [out{:}] = call_block(k*h, P);
        Y(k + 1, :) = cell2mat(out);
    end
else
    x = zeros(S.nx, 1);
    out = cell(1, nout + 1);
    for k = 0:N
        t = k*h;
        [out{:}] = call_block(t, x, P);
        Y(k + 1, :) = cell2mat(out(1:nout));
        if k == N
            break;
        end
        d1 = out{end};
        [out{:}] = call_block(t + h/2, x + h/2*d1, P);  d2 = out{end};
        [out{:}] = call_block(t + h/2, x + h/2*d2, P);  d3 = out{end};
        [out{:}] = call_block(t + h,   x + h*d3,   P);  d4 = out{end};
        x = x + h/6*(d1 + 2*d2 + 2*d3 + d4);
    end
end
save('-v6', outfile, 'Y');
end
"""


def wrapper(fname, args, nports):
    ports = args[:nports]
    params = args[nports:]
    call = ', '.join(ports + ['P.%s' % p for p in params])
    return ('function varargout = call_block(%s, P)\n'
            '[varargout{1:nargout}] = %s(%s);\nend\n' % (', '.join(ports), fname, call))


def run(script, params, outputs, t_end, h, nx=0, octave='octave-cli'):
    """Evaluate the MATLAB Function. params: dict name -> value of the parameters (scope
    Parameter, every argument after the port inputs). outputs: names of the outputs to log
    (without dx). nx: number of states (0 for a stateless block, port inputs t; otherwise
    port inputs t, x). Returns (t, dict name -> array)."""
    fname, args = signature(script)
    nports = 2 if nx else 1
    missing = [a for a in args[nports:] if a not in params]
    if missing:
        raise ValueError('no value for the parameters %s' % missing)
    with tempfile.TemporaryDirectory() as d:
        with open(os.path.join(d, fname + '.m'), 'w') as fh:
            fh.write(script)
        with open(os.path.join(d, 'call_block.m'), 'w') as fh:
            fh.write(wrapper(fname, args, nports))
        with open(os.path.join(d, 'run_driver.m'), 'w') as fh:
            fh.write(DRIVER)
        P = {k: np.atleast_2d(np.asarray(v, dtype=float)) for k, v in params.items()}
        sio.savemat(os.path.join(d, 'in.mat'), {'P': P, 'h': h, 't_end': t_end,
                                                'nout': len(outputs), 'nx': nx})
        r = subprocess.run([octave, '--no-gui', '--quiet', '--eval',
                            "cd('%s'); run_driver('in.mat', 'out.mat');" % d],
                           capture_output=True, text=True)
        if r.returncode != 0:
            raise RuntimeError(r.stdout + r.stderr)
        Y = sio.loadmat(os.path.join(d, 'out.mat'))['Y']
    n = Y.shape[0]
    t = np.arange(n) * h
    return t, {name: Y[:, i] for i, name in enumerate(outputs)}
