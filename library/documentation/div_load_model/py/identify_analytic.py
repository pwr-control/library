"""Analytic (parametrised) plasma-flux model of the open-circuit e.m.f. (spec Fig. 6), as implemented in
dtt.emf_analytic / dtt.plasma_emf:
   Psi(t) = Psi_a + dPsi_v (exp(g (t-tq)) - exp(-g tq)) / (1 - exp(-g tq))   0 <= t <= tq  (flat-top linkage Psi_a + VDE growth)
   Psi(t) = Psi0 (1 - (t-tq)/tcq),  Psi0 = Psi_a + dPsi_v                   tq < t < tq+tcq (current quench)
   Psi(t) = 0                                                        t >= tq+tcq
   e = (1-gam) dPsi/dt + gam x ,  tau_v dx/dt + x = dPsi/dt          (passive-structure delay)
ENEA sign: e positive during the flux growth, negative spike at the quench.
"""
import numpy as np, json
from scipy.optimize import minimize
from scipy.signal import lfilter
d = np.load('/home/claude/dtt_crowbar/data/fig67_clean.npz'); t = d['t']*1e-3; dt = t[1]-t[0]
def flux(p, t):
    Psia, dPv, g, tq, tcq = p[:5]; Psi0 = Psia + dPv
    k = 1.0/(1.0-np.exp(-g*tq))
    Psi = np.where(t <= tq, Psia + dPv*(np.exp(g*(t-tq))-np.exp(-g*tq))*k, np.where(t < tq+tcq, Psi0*(1-(t-tq)/tcq), 0.0))
    dPsi = np.where(t <= tq, dPv*g*np.exp(g*(t-tq))*k, np.where(t < tq+tcq, -Psi0/tcq, 0.0))
    return Psi, dPsi
def model(p, t):
    tauv, gam = p[5], p[6]
    Psi, dPsi = flux(p, t)
    a = np.exp(-dt/tauv)
    x = lfilter([1-a], [1, -a], dPsi)
    return (1-gam)*dPsi + gam*x, Psi
res = {}
for key in ['div3', 'div12']:
    eoc = d[key]*1e3
    def cost(p):
        if p[0] < 0 or p[1] <= 0 or p[2] <= 0 or p[2] > 200 or p[3] < 0.05 or p[3] > 0.09 or p[4] <= 0.0005 or p[4] > 0.03 or p[5] <= 0.005 or p[5] > 0.3 or p[6] < 0 or p[6] > 0.95: return 1e12
        e, _ = model(p, t); return np.mean((e-eoc)**2)
    best = None
    for g0 in [5.0, 30.0]:
        for tcq0 in [0.003, 0.006]:
            for tauv0 in [0.02, 0.05]:
                r = minimize(cost, [30.0, 8.0, g0, 0.081, tcq0, tauv0, 0.8], method='Nelder-Mead', options={'xatol': 1e-6, 'fatol': 5, 'maxiter': 4000})
                if best is None or r.fun < best.fun: best = r
    p = best.x; e, Psi = model(p, t)
    print(f"{key}: Psi_a={p[0]:.2f} Wb, dPsi_v={p[1]:.2f} Wb (Psi0={p[0]+p[1]:.2f}), g={p[2]:.1f} 1/s, tq={p[3]*1e3:.2f} ms, tcq={p[4]*1e3:.2f} ms, tau_v={p[5]*1e3:.1f} ms, gam={p[6]:.3f} -> rms {np.sqrt(best.fun):.0f} V | peak {e.min():.0f} V (ref {eoc.min():.0f}) | pre-quench max {e[t < p[3]].max():.0f} (ref {eoc[t < 0.08].max():.0f}) | e(150 ms) {np.interp(0.15,t,e):.0f} (ref {np.interp(0.15,t,eoc):.0f}) | flux 0..80 {np.trapezoid(e[t<=0.08],dx=dt):.1f} Wb (ref {np.trapezoid(eoc[t<=0.08],dx=dt):.1f}) | total flux {np.trapezoid(e,dx=dt):.1f} (ref {np.trapezoid(eoc,dx=dt):.1f})")
    res[key] = dict(Psi_a=p[0], dPsi_v=p[1], Psi0=p[0]+p[1], g=p[2], tq=p[3], tcq=p[4], tau_v=p[5], gam=p[6], rms=float(np.sqrt(best.fun)), Ip0=5.5e6, Mcp0=p[0]/5.5e6, Mcp_f=(p[0]+p[1])/5.5e6)
json.dump(res, open('../data/analytic_fits.json', 'w'), indent=1)
