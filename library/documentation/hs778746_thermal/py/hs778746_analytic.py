"""
Heatsink 778746 (SECOM, PADA profile "G", L = 250 mm) -- analytical steady-state model.
Forced convection through the internal channels, fin analysis, Lee spreading resistance,
pressure drop. Reproduces Table 3 of the accompanying note.
"""
import numpy as np

# ---- geometry [m] (from drawing 778746-01-01) ----
W, Hs, L = 0.225, 0.091, 0.250      # width across fins, height, length (flow direction)
tb   = 0.014                        # base plate thickness, each side (surface to fin root)
tf   = 0.0016                       # fin (web) thickness
b    = 0.00415                      # channel width
Nf, Nch = 36, 37                    # fins, channels
tw   = (W - Nf*tf - Nch*b)/2        # side wall thickness (~6.9 mm)
Lf   = Hs - 2*tb                    # fin length plate to plate (63 mm)
Ds   = 0.100                        # SCR contact diameter
a    = Ds/2; As = np.pi*a**2; Ap = W*L; rp = np.sqrt(Ap/np.pi)

# ---- materials ----
k = 200.0                           # Al 6060/6063 extrusion [W/(m K)]
rho_a, cp_a, k_a, nu_a, Pr = 1.127, 1007.0, 0.0271, 1.70e-5, 0.71   # air, 40 degC

Aff  = Nch*b*Lf                     # free flow area
Afr  = W*Hs
sigma = Aff/Afr
Dh   = 2*b*Lf/(b+Lf)
Atop = Nch*b*L                      # channel top walls (at base temperature)

def h_channel(Vch):
    """Teertstra, Yovanovich, Culham (1999), h referred to inlet air temperature."""
    Reb = Vch*b/nu_a
    Res = Reb*b/L
    nu_fd  = Res*Pr/2
    nu_dev = 0.664*np.sqrt(Res)*Pr**(1/3)*np.sqrt(1 + 3.65/np.sqrt(Res))
    Nu = (nu_fd**-3 + nu_dev**-3)**(-1/3)
    return Nu*k_a/b, Nu, Reb, Res

def fin_conductance(h, t, two_sided, tip_ratio):
    """Conductance [W/K] of one fin (thickness t, length Lf, depth L) whose tip is
    attached to the bottom plate; the plate is modelled as a convective tip with
    h_t = h*tip_ratio (tip_ratio = collector area / fin cross-section)."""
    P  = 2*L if two_sided else L
    Ac = t*L
    m  = np.sqrt(h*P/(k*Ac));  M = np.sqrt(h*P*k*Ac)
    z  = h*tip_ratio/(m*k);   mL = m*Lf
    G  = M*(np.sinh(mL) + z*np.cosh(mL))/(np.cosh(mL) + z*np.sinh(mL))
    return G, mL

def G_total(h):
    Gf, mL = fin_conductance(h, tf, True,  b/tf)        # internal fins
    Gw, _  = fin_conductance(h, tw, False, (b/2)/tw)    # side walls, inner face only
    G = Nf*Gf + 2*Gw + h*Atop
    eta_eff = Gf/(h*2*Lf*L)
    return G, mL, eta_eff

def lee_spreading(heff, kk=k):
    """Lee, Song, Au, Moran (1995): circular source (radius a) on a circular plate
    (radius rp, thickness tb) with uniform h_eff on the back. Returns R_max, R_avg, R_1D."""
    eps, tau, Bi = a/rp, tb/rp, heff*rp/kk
    lam = np.pi + 1/(eps*np.sqrt(np.pi))
    Phi = (np.tanh(lam*tau) + lam/Bi)/(1 + lam/Bi*np.tanh(lam*tau))
    psi_max = eps*tau/np.sqrt(np.pi) + (1-eps)*Phi/np.sqrt(np.pi)
    psi_avg = eps*tau/np.sqrt(np.pi) + 0.5*(1-eps)**1.5*Phi
    return psi_max/(kk*np.sqrt(As)), psi_avg/(kk*np.sqrt(As)), tb/(kk*Ap)

def pressure_drop(Vch):
    """Laminar developing flow in a rectangular duct (Shah & London) + contraction/expansion."""
    Re = Vch*Dh/nu_a
    al = b/Lf
    fRe = 24*(1 - 1.3553*al + 1.9467*al**2 - 1.7012*al**3 + 0.9564*al**4 - 0.2537*al**5)  # Fanning
    xp = L/(Dh*Re)
    fapp = (3.44/np.sqrt(xp) + (fRe + 0.674/(4*xp) - 3.44/np.sqrt(xp))/(1 + 2.9e-5/xp**2))/Re
    Kc, Ke = 0.42*(1 - sigma**2), (1 - sigma**2)**2
    return 0.5*rho_a*Vch**2*(4*fapp*L/Dh + Kc + Ke)

if __name__ == "__main__":
    print(f"Lf={Lf*1e3:.0f} mm  tw={tw*1e3:.1f} mm  Aff={Aff*1e4:.1f} cm2  sigma={sigma:.3f}  Dh={Dh*1e3:.2f} mm  rp={rp*1e3:.1f} mm")
    print(" Q[m3/h] Vch[m/s]  Re_b  Nu_b  h[W/m2K] eta_f  G[W/K]  R_conv  R_sp,avg R_sp,max R_th,avg R_th,max dp[Pa]")
    for Vch in [1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 10]:
        h, Nu, Reb, Res = h_channel(Vch)
        G, mL, eta = G_total(h)
        Rmax, Ravg, R1d = lee_spreading(G/Ap)
        Q = Vch*Aff*3600
        print(f"{Q:7.0f} {Vch:7.1f} {Reb:6.0f} {Nu:5.2f} {h:8.1f} {eta:6.3f} {G:7.2f} {1/G:8.4f} {Ravg:8.4f} {Rmax:8.4f} {1/G+Ravg:8.4f} {1/G+Rmax:8.4f} {pressure_drop(Vch):6.1f}")
