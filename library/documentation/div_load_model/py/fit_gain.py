"""Hypothesis (ii): Fig. 7 = physical circuit (coil + cable + Lp, R_coil) driven by k_e x Fig. 6 e.m.f.
Fit k_e for several physical parameter sets; compare rms with the calibrated single-RL fit."""
import numpy as np, json
from scipy.optimize import minimize_scalar
from compare_models import sim, t, e, iref
fits = json.load(open('../data/fig3_fits.json'))
out = {}
sets = {
 'stand-alone Table 2, no cable: 3.30 mH / 24.9 mOhm': (3.30e-3, 24.9e-3, [], []),
 'stand-alone + cable 160 uH: 3.46 mH / 24.9 mOhm': (3.46e-3, 24.9e-3, [], []),
 'stand-alone + cable, R incl. cable 5 mOhm: 3.46 mH / 29.9': (3.46e-3, 29.9e-3, [], []),
 'Fig.3 DC 3.12 mH / 24.9 mOhm, no eddy': (3.12e-3, 24.9e-3, [], []),
 'Fig.3 N=2 eddy model, 3.12 mH / 24.9 mOhm': (3.12e-3, 24.9e-3, fits['div3_N2']['Lm'], fits['div3_N2']['tau']),
 'Fig.3 N=2 eddy + cable 160 uH: 3.28 mH / 24.9': (3.28e-3, 24.9e-3, fits['div3_N2']['Lm'], fits['div3_N2']['tau']),
}
for lab, (L0, R0, Lm, tau) in sets.items():
    y1 = sim(L0, R0, Lm, tau, e)
    r = minimize_scalar(lambda k: np.mean((k*y1-iref)**2), bounds=(0.5, 4), method='bounded')
    k = r.x; y = k*y1
    print(f"{lab:62s} k_e={k:.3f}  rms {np.sqrt(r.fun):5.0f} A | peak {y.max()/1e3:5.2f} kA @ {t[y.argmax()]*1e3:4.0f} ms | i(80) {np.interp(0.08,t,y)/1e3:5.2f} | i(300) {y[-1]/1e3:4.2f} kA | tau=L/R {L0/R0*1e3:.0f} ms")
    out[lab] = dict(L0=L0, R0=R0, Lm=Lm, tau=tau, k_e=float(k), rms=float(np.sqrt(r.fun)), peak=float(y.max()))
print(f"reference Fig. 7: peak {iref.max()/1e3:.2f} kA @ {t[iref.argmax()]*1e3:.0f} ms, i(80) {np.interp(0.08,t,iref)/1e3:.2f}, i(300) {iref[-1]/1e3:.2f} kA")
# joint fit of k_e and R with L fixed at physical values (what R would be implied)
from scipy.optimize import minimize
for L0 in (3.30e-3, 3.46e-3):
    r = minimize(lambda p: np.mean((p[0]*sim(L0, p[1], [], [], e)-iref)**2) if p[1] > 0 else 1e12, [1.8, 24.9e-3], method='Nelder-Mead', options={'xatol': 1e-6, 'fatol': 1})
    print(f"L={L0*1e3:.2f} mH, k_e and R free: k_e={r.x[0]:.3f}, R={r.x[1]*1e3:.1f} mOhm, rms {np.sqrt(r.fun):.0f} A")
json.dump(out, open('../data/gain_fits.json', 'w'), indent=1)
