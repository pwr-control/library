"""Validation figures and numbers for the DIV load model note (Python replica of the .ssc equations)."""
import numpy as np, json, csv
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
from scipy.signal import medfilt, lfilter
from divmodel import load_ref, sim, i2t
plt.rcParams.update({'font.size': 8, 'axes.grid': True, 'grid.alpha': 0.4, 'lines.linewidth': 1.1, 'legend.fontsize': 7})
FIG = '../fig/'; DAT = '../data/'
ref = load_ref(); t = ref['t']; dt = t[1]-t[0]
fig3 = json.load(open(DAT+'fig3_fits.json')); an = json.load(open(DAT+'analytic_fits.json'))
R = {}
# ---------------------------------------------------------------- 1. clean + export digitised curves
def clean(x):
    y = medfilt(x, 9); keep = (t > 0.079) & (t < 0.090)          # keep the quench spike untouched
    y[keep] = x[keep]; return y
e3 = clean(ref['e_div3']); e12 = clean(ref['e_div12']); ii = medfilt(ref['i_ind'], 9); it = medfilt(ref['i_tot'], 9)
print(f"cleaning check: DIV3 peak {e3.min():.0f} V (raw {ref['e_div3'].min():.0f}), DIV1/2 peak {e12.min():.0f} (raw {ref['e_div12'].min():.0f}), flux {np.trapezoid(e3,dx=dt):.2f} vs raw {np.trapezoid(ref['e_div3'],dx=dt):.2f} Wb")
with open(DAT+'dtt_fig6_fig7_digitised.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['t_s', 'e_div12_V', 'e_div3_V', 'i_ind_fig7_A', 'i_tot_fig7_A'])
    for k in range(len(t)): w.writerow([f"{t[k]:.5f}", f"{e12[k]:.1f}", f"{e3[k]:.1f}", f"{ii[k]:.1f}", f"{it[k]:.1f}"])
R['emf'] = dict(div3_peak=float(e3.min()), div3_t_peak=float(t[e3.argmin()]), div12_peak=float(e12.min()), div3_prequench_max=float(e3[t < 0.0805].max()),
                div3_flux_pre=float(np.trapezoid(e3[t <= 0.08], dx=dt)), div3_flux_quench=float(np.trapezoid(e3[t >= 0.08], dx=dt)), div3_flux_total=float(np.trapezoid(e3, dx=dt)),
                div12_flux_total=float(np.trapezoid(e12, dx=dt)), fig7_peak=float(ii.max()), fig7_t_peak=float(t[ii.argmax()]), fig7_i300=float(ii[-1]), fig7_i80=float(np.interp(0.08, t, ii)),
                fig7_min=float(ii.min()), fig7_tot_peak=float(it.max()), fig7_tot_300=float(it[-1]), fig7_i2t=float(i2t(t, ii)), fig7_tot_i2t=float(i2t(t, it)))
# ---------------------------------------------------------------- 2. Fig. 3 fits figure
f = np.arange(0, 11); fd = np.linspace(0, 10, 200); w = 2*np.pi*fd
raw = {'div1': ([1.92,1.91,1.90,1.89,1.88,1.88,1.87,1.86,1.86,1.85,1.84], [10.6,10.8,11.1,11.4,11.9,12.4,12.9,13.5,14.2,14.8,15.5]),
       'div2': ([1.68,1.64,1.62,1.60,1.58,1.56,1.54,1.52,1.50,1.48,1.46], [18.7,19.1,19.9,21.0,22.3,23.8,25.6,27.4,29.2,31.1,33.0]),
       'div3': ([3.12,3.07,3.01,2.97,2.94,2.91,2.88,2.85,2.82,2.79,2.77], [24.9,25.6,26.9,28.4,30.3,32.4,34.6,37.0,39.4,41.8,44.1])}
fig, ax = plt.subplots(3, 2, figsize=(6.6, 6.0))
for r_, key in enumerate(['div1', 'div2', 'div3']):
    p = fig3[key+'_N2']; Lm = np.array(p['Lm']); tau = np.array(p['tau'])
    wt2 = (w[:, None]*tau[None, :])**2
    L = p['L0'] - (Lm*wt2/(1+wt2)).sum(1); Rr = p['R0'] + (Lm*w[:, None]**2*tau/(1+wt2)).sum(1)
    ax[r_, 0].plot(f, raw[key][0], 'ko', ms=3, label='spec Fig. 3'); ax[r_, 0].plot(fd, L*1e3, 'C0', label='2-loop model')
    ax[r_, 1].plot(f, raw[key][1], 'ko', ms=3); ax[r_, 1].plot(fd, Rr*1e3, 'C1')
    ax[r_, 0].set_ylabel(f'{key.upper()} $L_{{eq}}$ [mH]'); ax[r_, 1].set_ylabel(f'{key.upper()} $R_{{eq}}$ [m$\\Omega$]')
    ax[r_, 0].text(0.03, 0.05, f"$L_0$={p['L0']*1e3:.2f} mH\n$L_{{m}}$={Lm[0]*1e3:.3f}/{Lm[1]*1e3:.3f} mH\n$\\tau$={tau[0]*1e3:.1f}/{tau[1]*1e3:.0f} ms", transform=ax[r_, 0].transAxes, fontsize=6.5, va='bottom')
ax[0, 0].legend(loc='upper right'); ax[2, 0].set_xlabel('f [Hz]'); ax[2, 1].set_xlabel('f [Hz]')
fig.tight_layout(); fig.savefig(FIG+'fig_fig3_fit.pdf'); plt.close(fig)
# ---------------------------------------------------------------- 3. e.m.f. input figure
fig, ax = plt.subplots(1, 2, figsize=(6.6, 2.6))
ax[0].plot(t*1e3, e3/1e3, label='DIV3'); ax[0].plot(t*1e3, e12/1e3, label='DIV1/DIV2', alpha=0.8); ax[0].set_xlabel('t [ms]'); ax[0].set_ylabel('$e_{oc}$ [kV]'); ax[0].legend()
ax[1].plot(t*1e3, e3, label='DIV3'); ax[1].plot(t*1e3, e12, label='DIV1/DIV2', alpha=0.8); ax[1].set_ylim(-800, 500); ax[1].set_xlabel('t [ms]'); ax[1].set_ylabel('$e_{oc}$ [V] (zoom)')
fig.tight_layout(); fig.savefig(FIG+'fig_emf_input.pdf'); plt.close(fig)
# ---------------------------------------------------------------- 4. Fig. 7 reproduction
L_coil, R_coil, L_cab, R_cab, L_p = 1.7e-3, 24.9e-3, 160e-6, 5e-3, 1.6e-3
lm3, tau3 = fig3['div3_N2']['Lm'], fig3['div3_N2']['tau']
KE = 1.841
cases = {
 'S2: spec §8.2 circuit (3.46 mH, 24.9 mΩ), $k_e$=1.84': dict(L0=L_coil+L_cab+L_p, R0=R_coil, k_e=KE),
 'calibrated RL (1.92 mH, 13.1 mΩ), $k_e$=1': dict(L0=1.9193e-3, R0=13.14e-3, k_e=1.0),
 'spec §8.2 circuit, $k_e$=1 (Fig. 6 as is)': dict(L0=L_coil+L_cab+L_p, R0=R_coil, k_e=1.0),
}
fig, ax = plt.subplots(1, 2, figsize=(6.6, 2.8))
ax[0].plot(t*1e3, ii/1e3, 'k', lw=1.8, label='ENEA Fig. 7 (induced)')
res_cases = {}
for lab, c in cases.items():
    y = sim(t, e3, **c); ax[0].plot(t*1e3, y/1e3, label=lab)
    res_cases[lab] = dict(peak=float(y.max()), t_peak=float(t[y.argmax()]), i300=float(y[-1]), i80=float(np.interp(0.08, t, y)), rms=float(np.sqrt(np.mean((y-ii)**2))), i2t=float(i2t(t, y)), **{k: float(v) for k, v in c.items()})
ax[0].set_xlabel('t [ms]'); ax[0].set_ylabel('$i$ [kA]'); ax[0].legend(loc='lower right')
yS2 = sim(t, e3, L0=L_coil+L_cab+L_p, R0=R_coil, k_e=KE)
y5 = sim(t, e3, L0=L_coil+L_cab+L_p, R0=R_coil, k_e=KE, i0=5e3)
ax[1].plot(t*1e3, it/1e3, 'k', lw=1.8, label='ENEA Fig. 7 (total)')
ax[1].plot(t*1e3, (yS2+5e3)/1e3, label='S2 + 5 kA constant (as ENEA)')
ax[1].plot(t*1e3, y5/1e3, label='S2 with $i_0$ = 5 kA (decaying)')
ax[1].set_xlabel('t [ms]'); ax[1].set_ylabel('$i$ [kA]'); ax[1].legend(loc='lower right')
fig.tight_layout(); fig.savefig(FIG+'fig_fig7_repro.pdf'); plt.close(fig)
R['fig7_cases'] = res_cases
R['S2_total'] = dict(peak_const=float((yS2+5e3).max()), i2t_const=float(i2t(t, yS2+5e3)), peak_decay=float(y5.max()), i300_decay=float(y5[-1]), i2t_decay=float(i2t(t, y5)))
# ---------------------------------------------------------------- 5. physical variants (what ENEA left out)
R_p = 1.0e-3
var = {
 'S2 reference (R = $R_{coil}$ only)': dict(L0=L_coil+L_cab+L_p, R0=R_coil, k_e=KE),
 '+ $R_{cable}$ 5 mΩ + $R_p$ 1 mΩ': dict(L0=L_coil+L_cab+L_p, R0=R_coil+R_cab+R_p, k_e=KE),
 '+ eddy loops (spec Fig. 3)': dict(L0=L_coil+L_cab+L_p, R0=R_coil+R_cab+R_p, Lm=lm3, tau=tau3, k_e=KE),
 'eddy loops, $L_0$ from Fig. 3 DC (1.52 mH)': dict(L0=1.52e-3+L_cab+L_p, R0=R_coil+R_cab+R_p, Lm=lm3, tau=tau3, k_e=KE),
 'without $L_p$ (coil + cable only)': dict(L0=L_coil+L_cab, R0=R_coil+R_cab, k_e=KE),
}
fig, ax = plt.subplots(1, 2, figsize=(6.6, 2.8))
ax[0].plot(t*1e3, ii/1e3, 'k', lw=1.8, label='ENEA Fig. 7')
res_var = {}
for lab, c in var.items():
    y = sim(t, e3, **c); ax[0].plot(t*1e3, y/1e3, label=lab)
    res_var[lab] = dict(peak=float(y.max()), t_peak=float(t[y.argmax()]), i300=float(y[-1]), i2t=float(i2t(t, y)), i2t_tot=float(i2t(t, y+5e3)), peak_tot=float((y+5e3).max()))
ax[0].set_xlabel('t [ms]'); ax[0].set_ylabel('$i$ [kA] (ideal crowbar)'); ax[0].legend(loc='lower right', fontsize=6)
# open-circuit terminal voltage of the variants is e itself; show instead the voltage seen with the crowbar delayed: not here. Show the effect of the e.m.f. gain
for ke in (1.0, 1.4, 1.84, 2.2):
    y = sim(t, e3, L0=L_coil+L_cab+L_p, R0=R_coil+R_cab+R_p, Lm=lm3, tau=tau3, k_e=ke); ax[1].plot(t*1e3, y/1e3, label=f'$k_e$ = {ke}')
ax[1].plot(t*1e3, ii/1e3, 'k', lw=1.8, label='ENEA Fig. 7'); ax[1].set_xlabel('t [ms]'); ax[1].set_ylabel('$i$ [kA] (physical set)'); ax[1].legend(loc='lower right', fontsize=6)
fig.tight_layout(); fig.savefig(FIG+'fig_physical_variants.pdf'); plt.close(fig)
R['variants'] = res_var
# ---------------------------------------------------------------- 6. analytic e.m.f. model
def analytic(p, t, tt0=0.0):
    tt = t - tt0
    Psia, dPv, g, tq, tcq, tauv, gam = p['Psi_a'], p['dPsi_v'], p['g'], p['tq'], p['tcq'], p['tau_v'], p['gam']; Psi0 = Psia+dPv
    k = 1/(1-np.exp(-g*tq))
    Psi = np.where(tt <= 0, Psia, np.where(tt <= tq, Psia + dPv*(np.exp(g*(tt-tq))-np.exp(-g*tq))*k, np.where(tt < tq+tcq, Psi0*(1-(tt-tq)/tcq), 0.0)))
    dPsi = np.where(tt <= 0, 0.0, np.where(tt <= tq, dPv*g*np.exp(g*(tt-tq))*k, np.where(tt < tq+tcq, -Psi0/tcq, 0.0)))
    a = np.exp(-dt/tauv); x = lfilter([1-a], [1, -a], dPsi)
    return (1-gam)*dPsi + gam*x, Psi, dPsi
p3 = an['div3']; ea, Psi_a, dPsi_a = analytic(p3, t)
fig, ax = plt.subplots(2, 2, figsize=(6.6, 4.6))
ax[0, 0].plot(t*1e3, e3/1e3, 'k', lw=1.6, label='spec Fig. 6 DIV3 (digitised)'); ax[0, 0].plot(t*1e3, ea/1e3, 'C1', label='analytic model'); ax[0, 0].set_ylabel('$e_{oc}$ [kV]'); ax[0, 0].legend()
ax[0, 1].plot(t*1e3, e3, 'k', lw=1.6); ax[0, 1].plot(t*1e3, ea, 'C1'); ax[0, 1].set_ylim(-700, 450); ax[0, 1].set_ylabel('$e_{oc}$ [V] (zoom)')
ax[1, 0].plot(t*1e3, Psi_a, 'C2'); ax[1, 0].set_ylabel('$\\Psi = M_{cp} I_p$ [Wb]'); ax[1, 0].set_xlabel('t [ms]')
Ip0 = p3['Ip0']; tq, tcq = p3['tq'], p3['tcq']
Ip = np.where(t <= tq, Ip0, np.where(t < tq+tcq, Ip0*(1-(t-tq)/tcq), 0.0)); Mcp = np.where(t <= tq, Psi_a/Ip0, (p3['Psi0'])/Ip0)
ax[1, 1].plot(t*1e3, Ip/1e6, 'C3', label='$I_p$ [MA]'); ax[1, 1].set_ylabel('$I_p$ [MA]'); ax[1, 1].set_xlabel('t [ms]')
ax2 = ax[1, 1].twinx(); ax2.plot(t*1e3, Mcp*1e6, 'C4', label='$M_{cp}$ [µH]'); ax2.set_ylabel('$M_{cp}$ [µH]'); ax2.grid(False)
h1, l1 = ax[1, 1].get_legend_handles_labels(); h2, l2 = ax2.get_legend_handles_labels(); ax[1, 1].legend(h1+h2, l1+l2, loc='center left')
fig.tight_layout(); fig.savefig(FIG+'fig_analytic.pdf'); plt.close(fig)
R['analytic'] = dict(div3=dict(**p3, peak=float(ea.min()), pre_max=float(ea[t < tq].max())), div12=an['div12'])
ya = sim(t, ea, L0=L_coil+L_cab+L_p, R0=R_coil, k_e=KE); R['analytic']['div3_S2_peak'] = float(ya.max()); R['analytic']['div3_S2_i300'] = float(ya[-1])
# ---------------------------------------------------------------- 7. what-if with the analytic model: quench time and crowbar delay
fig, ax = plt.subplots(1, 2, figsize=(6.6, 2.8))
whatif = {}
for tcq_ in (1.5e-3, 3.19e-3, 6e-3, 12e-3):
    p = dict(p3); p['tcq'] = tcq_; e_, _, _ = analytic(p, t)
    y = sim(t, e_, L0=L_coil+L_cab+L_p, R0=R_coil+R_cab+R_p, Lm=lm3, tau=tau3, k_e=KE)
    ax[0].plot(t*1e3, y/1e3, label=f'$t_{{cq}}$ = {tcq_*1e3:.1f} ms, $\\hat e$ = {KE*e_.min()/1e3:.1f} kV')
    whatif[f'tcq_{tcq_*1e3:.1f}ms'] = dict(peak=float(y.max()), e_peak=float(KE*e_.min()), i2t=float(i2t(t, y)))
ax[0].set_xlabel('t [ms]'); ax[0].set_ylabel('$i$ [kA] (ideal crowbar, $k_e$=1.84)'); ax[0].legend(fontsize=6)
# crowbar closing delayed: terminal held at v = 0 only after t_fire; before, the coil is open (i = i0 = 0): emulate with v = e (open) -> i = 0, then short
for tf in (0.0, 0.085, 0.100, 0.130):
    e_ = KE*e3.copy(); v = np.where(t < tf, e_, 0.0)   # open circuit: v = e -> no current
    y = sim(t, e3, L0=L_coil+L_cab+L_p, R0=R_coil, k_e=KE, v=v)
    ax[1].plot(t*1e3, y/1e3, label=f'crowbar closed at {tf*1e3:.0f} ms' if tf > 0 else 'crowbar closed from $t$ = 0')
    whatif[f'fire_{tf*1e3:.0f}ms'] = dict(peak=float(y.max()), i2t=float(i2t(t, y)))
ax[1].set_xlabel('t [ms]'); ax[1].set_ylabel('$i$ [kA] (spec §8.2 circuit)'); ax[1].legend(fontsize=6)
fig.tight_layout(); fig.savefig(FIG+'fig_whatif.pdf'); plt.close(fig)
R['whatif'] = whatif
json.dump(R, open(DAT+'results.json', 'w'), indent=1)
for k, v in res_cases.items(): print(k, {a: (round(b, 4) if isinstance(b, float) else b) for a, b in v.items()})
for k, v in res_var.items(): print(k, {a: round(b, 4) for a, b in v.items()})
print('S2 total', R['S2_total']); print('whatif', whatif); print('emf', R['emf'])
