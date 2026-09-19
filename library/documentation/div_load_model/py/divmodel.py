"""Python replica of the equations implemented in the Simscape components (ssc/+dtt):
   coil loop : v = R0 i + L0 di/dt + sum_k L_mk dx_k/dt + k_e e(t)
   eddy loop : tau_k dx_k/dt + x_k + tau_k di/dt = 0
Ideal crowbar (v = 0) response computed with scipy.signal.lsim (exact for piecewise-linear e)."""
import numpy as np
from scipy.signal import lsim, StateSpace
DATA = '/home/claude/dtt_crowbar/data/fig67_clean.npz'
def load_ref():
    d = np.load(DATA); t = d['t']*1e-3
    return dict(t=t, e_div3=d['div3']*1e3, e_div12=d['div12']*1e3, i_ind=d['iind']*1e3, i_tot=d['itot']*1e3)
def sim(t, e, L0, R0, Lm=(), tau=(), k_e=1.0, i0=0.0, v=None):
    """coil current for terminal voltage v(t) (default 0 = ideal crowbar) and e.m.f. e(t)."""
    Lm = np.atleast_1d(np.asarray(Lm, float)); tau = np.atleast_1d(np.asarray(tau, float)); N = len(Lm)
    M = np.zeros((N+1, N+1)); Rm = np.zeros((N+1, N+1)); B = np.zeros((N+1, 2))
    M[0, 0] = L0; M[0, 1:] = Lm; Rm[0, 0] = R0; B[0, 0] = -k_e; B[0, 1] = 1.0
    for k in range(N):
        M[k+1, 0] = tau[k]; M[k+1, k+1] = tau[k]; Rm[k+1, k+1] = 1.0
    A = -np.linalg.solve(M, Rm); Bm = np.linalg.solve(M, B)
    C = np.zeros((1, N+1)); C[0, 0] = 1.0
    x0 = np.zeros(N+1); x0[0] = i0
    u = np.stack([e, np.zeros_like(e) if v is None else v], 1)
    _, y, _ = lsim(StateSpace(A, Bm, C, np.zeros((1, 2))), u, t, X0=x0)
    return y
def i2t(t, i):
    return np.trapezoid(i**2, t)
