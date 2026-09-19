"""Fit the coil + eddy-current-loop model to the frequency-dependent equivalent
L(f), R(f) of spec PSS-SPT-59401 Fig. 3 (complete circuits: load coil + protection coil).

Model (N loops, k = 1..N):   Z(jw) = R0 + jw L0 + sum_k  (jw)^2 M_k^2 / (R_k + jw L_k)
 with L_mk = M_k^2/L_k, tau_k = L_k/R_k :
   L(w) = L0 - sum_k L_mk (w tau_k)^2 / (1 + (w tau_k)^2)
   R(w) = R0 + sum_k L_mk  w^2 tau_k  / (1 + (w tau_k)^2)
"""
import numpy as np, json
from scipy.optimize import least_squares
f = np.arange(0, 11)
fig3 = {
 'div1': dict(L=[1.92,1.91,1.90,1.89,1.88,1.88,1.87,1.86,1.86,1.85,1.84],
              R=[10.6,10.8,11.1,11.4,11.9,12.4,12.9,13.5,14.2,14.8,15.5], Lp=1.5, Lsa=0.5, Rsa=10.6),
 'div2': dict(L=[1.68,1.64,1.62,1.60,1.58,1.56,1.54,1.52,1.50,1.48,1.46],
              R=[18.7,19.1,19.9,21.0,22.3,23.8,25.6,27.4,29.2,31.1,33.0], Lp=0.6, Lsa=1.2, Rsa=18.7),
 'div3': dict(L=[3.12,3.07,3.01,2.97,2.94,2.91,2.88,2.85,2.82,2.79,2.77],
              R=[24.9,25.6,26.9,28.4,30.3,32.4,34.6,37.0,39.4,41.8,44.1], Lp=1.6, Lsa=1.7, Rsa=24.9),
}
def LR(w, L0, R0, Lm, tau):
    Lm = np.atleast_1d(Lm); tau = np.atleast_1d(tau)
    wt2 = (w[:, None]*tau[None, :])**2
    L = L0 - (Lm[None, :]*wt2/(1+wt2)).sum(1)
    R = R0 + (Lm[None, :]*w[:, None]**2*tau[None, :]/(1+wt2)).sum(1)
    return L, R
def fit(key, N):
    d = fig3[key]; w = 2*np.pi*f
    Lref = np.array(d['L'])*1e-3; Rref = np.array(d['R'])*1e-3
    L0, R0 = Lref[0], Rref[0]
    def resid(p):
        Lm = p[:N]; tau = p[N:]
        L, R = LR(w, L0, R0, Lm, tau)
        return np.concatenate([(L-Lref)/1e-3*20, (R-Rref)/1e-3])   # weight: 0.05 mH ~ 1 mOhm
    best = None
    for tau0 in ([0.03], [0.01, 0.1], [0.005, 0.03, 0.2]):
        if len(tau0) != N: continue
        p0 = np.concatenate([np.full(N, 0.2e-3), tau0])
        r = least_squares(resid, p0, bounds=(np.concatenate([np.zeros(N), np.full(N, 1e-4)]), np.concatenate([np.full(N, L0), np.full(N, 2.0)])))
        if best is None or r.cost < best.cost: best = r
    Lm, tau = best.x[:N], best.x[N:]
    L, R = LR(w, L0, R0, Lm, tau)
    return dict(L0=L0, R0=R0, Lm=Lm.tolist(), tau=tau.tolist(), rmsL=float(np.sqrt(np.mean((L-Lref)**2))), rmsR=float(np.sqrt(np.mean((R-Rref)**2))))
out = {}
for key in fig3:
    for N in (1, 2, 3):
        r = fit(key, N)
        print(f"{key} N={N}: L0={r['L0']*1e3:.2f} mH R0={r['R0']*1e3:.1f} mOhm | Lm={np.array(r['Lm'])*1e3} mH tau={np.array(r['tau'])*1e3} ms | rms L {r['rmsL']*1e6:.0f} uH, R {r['rmsR']*1e3:.2f} mOhm | L_inf={(r['L0']-sum(r['Lm']))*1e3:.2f} mH")
        out[f'{key}_N{N}'] = r
    out[key+'_Lp'] = fig3[key]['Lp']*1e-3
json.dump(out, open('../data/fig3_fits.json', 'w'), indent=1)
