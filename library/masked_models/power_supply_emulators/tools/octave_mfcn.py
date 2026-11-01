#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
octave_mfcn - runs the script of a MATLAB Function block in GNU Octave.

The script is written to a function file with one more input, P, a struct with the
block parameters (scope Parameter), unpacked at the top of the function. The block is
then evaluated on a fixed time grid:
- without state input (one input t): at every grid point;
- with a state input x and a last output dx (Clock + Integrator around the function):
  integrated with the classic fourth-order Runge-Kutta method, x(0) = 0.
"""
import os
import re
import subprocess
import tempfile
import numpy as np
import scipy.io as sio


def function_name(script):
    m = re.search(r'^\s*function\s*\[?[^=]*\]?\s*=\s*([A-Za-z_]\w*)\s*\(', script, re.M)
    return m.group(1)


def with_param_struct(script, params):
    """Add the input P after the existing inputs of the main function and unpack it."""
    lines = script.split('\n')
    # end of the (possibly continued) signature of the main function
    i = 0
    while not lines[i].lstrip().startswith('function'):
        i += 1
    j = i
    while lines[j].rstrip().endswith('...'):
        j += 1
    sig = ' '.join(l.rstrip().rstrip('.').strip() if k < j - i else l.strip()
                   for k, l in enumerate(lines[i:j + 1]))
    sig = re.sub(r'\)\s*$', ', P)', sig)
    unpack = ['%s = P.%s;' % (p, p) for p in params]
    return '\n'.join(lines[:i] + [sig] + unpack + lines[j + 1:])


DRIVER = r"""
function run_driver(infile, outfile)
S = load(infile);
P = S.P;
h = S.h;
N = round(S.t_end/h);
f = str2func(S.fname);
nout = S.nout;
Y = zeros(N + 1, nout);
if S.nx == 0
    for k = 0:N
        out = cell(1, nout);
        [out{:}] = f(k*h, P);
        Y(k + 1, :) = cell2mat(out);
    end
else
    x = zeros(S.nx, 1);
    out = cell(1, nout + 1);
    for k = 0:N
        t = k*h;
        [out{:}] = f(t, x, P);
        Y(k + 1, :) = cell2mat(out(1:nout));
        if k == N
            break;
        end
        d1 = out{end};
        [out{:}] = f(t + h/2, x + h/2*d1, P);  d2 = out{end};
        [out{:}] = f(t + h/2, x + h/2*d2, P);  d3 = out{end};
        [out{:}] = f(t + h,   x + h*d3,   P);  d4 = out{end};
        x = x + h/6*(d1 + 2*d2 + 2*d3 + d4);
    end
end
save('-v6', outfile, 'Y');
end
"""


def run(script, params, outputs, t_end, h, nx=0, octave='octave-cli'):
    """Evaluate the MATLAB Function. outputs: names of the outputs to log (without dx).
    nx: number of states (0 for a stateless block). Returns (t, dict name -> array)."""
    fname = function_name(script)
    with tempfile.TemporaryDirectory() as d:
        with open(os.path.join(d, fname + '.m'), 'w') as fh:
            fh.write(with_param_struct(script, list(params)))
        with open(os.path.join(d, 'run_driver.m'), 'w') as fh:
            fh.write(DRIVER)
        P = {k: np.atleast_2d(np.asarray(v, dtype=float)) for k, v in params.items()}
        sio.savemat(os.path.join(d, 'in.mat'), {'P': P, 'h': h, 't_end': t_end, 'fname': fname,
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
