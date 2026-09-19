"""Short-circuit (ideal crowbar) current of the DIV3 circuit driven by the digitised
open-circuit e.m.f. (ENEA Fig. 6) for several load models; compare with ENEA Fig. 7.
Model: (L0) i' + R0 i + sum_k L_mk x_k' + e = 0 ;  tau_k x_k' + x_k + tau_k i' = 0
"""
import numpy as np, json
from scipy.signal import lsim, StateSpace
d = np.load('/home/claude/dtt_crowbar/data/fig67_clean.npz'); t = d['t']*1e-3; dt = t[1]-t[0]
e = d['div3']*1e3; iref = d['iind']*1e3; itot_ref = d['itot']*1e3
fits = json.load(open('../data/fig3_fits.json'))
def sim(L0, R0, Lm, tau, e, i0=0.0):
    """coil loop + N eddy loops; returns coil current (positive = ENEA Fig. 7 direction)."""
    Lm = np.atleast_1d(Lm); tau = np.atleast_1d(tau); N = len(Lm)
    # states [i, x_1..x_N];  M(state') = -R state + B e
    M = np.zeros((N+1, N+1)); Rm = np.zeros((N+1, N+1)); B = np.zeros(N+1)
    M[0, 0] = L0; M[0, 1:] = Lm; Rm[0, 0] = R0; B[0] = -1.0     # v = 0:  L0 i' + sum Lm x' + R0 i + e = 0
    for k in range(N):
        M[k+1, 0] = tau[k]; M[k+1, k+1] = tau[k]; Rm[k+1, k+1] = 1.0
    A = -np.linalg.solve(M, Rm); Bm = np.linalg.solve(M, B).reshape(-1, 1)
    C = np.zeros((1, N+1)); C[0, 0] = 1.0
    x0 = np.zeros(N+1); x0[0] = i0
    _, y, _ = lsim(StateSpace(A, Bm, C, np.zeros((1, 1))), e, t, X0=x0)
    return y
def report(label, y):
    k = y.argmax()
    print(f"{label:58s} peak {y.max()/1e3:5.2f} kA @ {t[k]*1e3:5.1f} ms | i(150) {np.interp(0.15,t,y)/1e3:5.2f} | i(300) {y[-1]/1e3:5.2f} kA | rms vs Fig.7 {np.sqrt(np.mean((y-iref)**2)):6.0f} A")
print(f"{'ENEA Fig. 7 (digitised)':58s} peak {iref.max()/1e3:5.2f} kA @ {t[iref.argmax()]*1e3:5.1f} ms | i(150) {np.interp(0.15,t,iref)/1e3:5.2f} | i(300) {iref[-1]/1e3:5.2f} kA")
fit = np.load('/home/claude/dtt_crowbar/data/fit_fig7.npz')
res = {}
cases = {
 'A  calibrated single RL (L=1.92 mH, R=13.1 mOhm)': (float(fit['L']), float(fit['R']), [], []),
 'B  stand-alone Table 2: coil 1.7 + Lp 1.6 mH, R 24.9': (3.3e-3, 24.9e-3, [], []),
 'C  Fig.3 DC only: 3.12 mH, 24.9 mOhm (no eddy)': (3.12e-3, 24.9e-3, [], []),
 'D  Fig.3 fit N=2 (eddy loops 11.8/102 ms)': (3.12e-3, 24.9e-3, fits['div3_N2']['Lm'], fits['div3_N2']['tau']),
 'E  Fig.3 fit N=3 (0.7/13.6/111 ms)': (3.12e-3, 24.9e-3, fits['div3_N3']['Lm'], fits['div3_N3']['tau']),
}
for lab, (L0, R0, Lm, tau) in cases.items():
    y = sim(L0, R0, Lm, tau, e); report(lab, y); res[lab] = y
# F: N=2 Fig.3 loops + one fast loop tuned to the Fig. 7 peak (Lm_f, tau_f) with tau_f small enough to be invisible at 10 Hz
from scipy.optimize import minimize
Lm2, tau2 = fits['div3_N2']['Lm'], fits['div3_N2']['tau']
def cost(p):
    Lmf, tauf = p
    if Lmf <= 0 or Lmf >= 3.12e-3 - sum(Lm2) or tauf <= 1e-5 or tauf > 5e-3: return 1e12
    y = sim(3.12e-3, 24.9e-3, Lm2+[Lmf], tau2+[tauf], e)
    return (y.max()-iref.max())**2 + 0.2*np.mean((y-iref)**2)
best = None
for p0 in ([0.5e-3, 0.3e-3], [0.8e-3, 1e-3], [0.3e-3, 2e-3]):
    r = minimize(cost, p0, method='Nelder-Mead', options={'xatol': 1e-7, 'fatol': 1, 'maxiter': 400})
    if best is None or r.fun < best.fun: best = r
Lmf, tauf = best.x
y = sim(3.12e-3, 24.9e-3, Lm2+[Lmf], tau2+[tauf], e)
lab = f'F  N=2 + fast loop Lm={Lmf*1e3:.2f} mH tau={tauf*1e3:.2f} ms'
report(lab, y); res[lab] = y
w10 = 2*np.pi*10; print(f"   fast loop contribution at 10 Hz: dR = {Lmf*w10**2*tauf/(1+(w10*tauf)**2)*1e3:.2f} mOhm, dL = {Lmf*(w10*tauf)**2/(1+(w10*tauf)**2)*1e6:.1f} uH")
# G: as F but R free (what R would be needed for the tail)
def cost2(p):
    Lmf, tauf, R0 = p
    if Lmf <= 0 or Lmf >= 3.12e-3 - sum(Lm2) or tauf <= 1e-5 or tauf > 5e-3 or R0 <= 0: return 1e12
    y = sim(3.12e-3, R0, Lm2+[Lmf], tau2+[tauf], e)
    return np.mean((y-iref)**2)
r = minimize(cost2, [Lmf, tauf, 24.9e-3], method='Nelder-Mead', options={'xatol': 1e-7, 'fatol': 1, 'maxiter': 600})
y = sim(3.12e-3, r.x[2], Lm2+[r.x[0]], tau2+[r.x[1]], e)
lab = f'G  as F, R free: Lm={r.x[0]*1e3:.2f} mH tau={r.x[1]*1e3:.2f} ms R={r.x[2]*1e3:.1f} mOhm'
report(lab, y); res[lab] = y
# H: physical loops + e_oc scaled? (no) ; H: model D with total current i0 = 5 kA
y = sim(3.12e-3, 24.9e-3, Lm2, tau2, e, i0=5e3); report('H  case D with 5 kA initial current (cf. Fig.7 total)', y)
print(f"{'ENEA Fig. 7 total (digitised)':58s} peak {itot_ref.max()/1e3:5.2f} kA @ {t[itot_ref.argmax()]*1e3:5.1f} ms | i(300) {itot_ref[-1]/1e3:5.2f} kA")
np.savez('../data/compare_models.npz', t=t, e=e, iref=iref, itot_ref=itot_ref, labels=np.array(list(res.keys())), curves=np.array(list(res.values())))
json.dump(dict(Lmf=Lmf, tauf=tauf, G=r.x.tolist()), open('../data/fast_loop.json', 'w'), indent=1)
