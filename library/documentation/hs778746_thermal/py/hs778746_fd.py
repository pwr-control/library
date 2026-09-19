"""
Heatsink 778746 -- 3-D finite-difference thermal model (steady state and step response).
Top plate: 3-D (x, y, z); fins and side walls: 2-D (x, s); bottom plate: 3-D (x, y, z).
Uniform channel h from hs778746_analytic.h_channel, referred to inlet air temperature.
Run:  python hs778746_fd.py   (about 3 min; writes results_fd.json and foster.json)
"""
import json, time
import numpy as np
import scipy.sparse as sp
import scipy.sparse.linalg as spla
from scipy.optimize import curve_fit
from hs778746_analytic import (W, Hs, L, tb, tf, b, Nf, tw, Lf, a, Ap, As, Aff, k,
                               h_channel, G_total, lee_spreading, pressure_drop)
rho, cp = 2700.0, 900.0

def build(h, hj=np.inf, Nx=50, Nz=7, Ns=10, Nzb=2, h_out=0.0):
    """Assemble conductance matrix K, capacitance vector C and unit-power vector P."""
    dx = L/Nx
    p  = tf + b
    we = tw + b/2                              # edge cell: side wall + half channel
    wy = np.array([we] + [p]*Nf + [we]); Ny = len(wy)
    dz, ds, dzb = tb/Nz, Lf/Ns, tb/Nzb
    n = 0
    itp = np.arange(Nx*Ny*Nz).reshape(Nx, Ny, Nz);      n += itp.size
    ifn = n + np.arange(Nx*Nf*Ns).reshape(Nx, Nf, Ns);  n += ifn.size
    iwl = n + np.arange(Nx*2*Ns).reshape(Nx, 2, Ns);    n += iwl.size
    ibp = n + np.arange(Nx*Ny*Nzb).reshape(Nx, Ny, Nzb); n += ibp.size
    N = n
    C = np.zeros(N); Gg = np.zeros(N); I = []; J = []; V = []
    link = lambda i, j, g: (I.append(i), J.append(j), V.append(g))
    # plates
    for idx, nz, dzz in ((itp, Nz, dz), (ibp, Nzb, dzb)):
        for ix in range(Nx):
            for iy in range(Ny):
                for iz in range(nz):
                    nd = idx[ix, iy, iz]
                    C[nd] = rho*cp*dx*wy[iy]*dzz
                    if ix+1 < Nx: link(nd, idx[ix+1, iy, iz], k*wy[iy]*dzz/dx)
                    if iy+1 < Ny:
                        g = k*dx*dzz/(0.5*(wy[iy]+wy[iy+1]))
                        if 1 <= iy <= Nf-1 and iy % 2 == 0 and np.isfinite(hj):   # module joint every 2 fins
                            g = 1/(1/g + 1/(hj*dx*dzz))
                        link(nd, idx[ix, iy+1, iz], g)
                    if iz+1 < nz: link(nd, idx[ix, iy, iz+1], k*dx*wy[iy]/dzz)
    # fins
    for ix in range(Nx):
        for jf in range(Nf):
            iy = jf + 1
            for s in range(Ns):
                nd = ifn[ix, jf, s]
                C[nd] = rho*cp*dx*tf*ds
                Gg[nd] += h*2*dx*ds
                if ix+1 < Nx: link(nd, ifn[ix+1, jf, s], k*tf*ds/dx)
                if s+1 < Ns:  link(nd, ifn[ix, jf, s+1], k*dx*tf/ds)
            link(ifn[ix, jf, 0],    itp[ix, iy, Nz-1], 1/((dz/2)/(k*dx*wy[iy]) + (ds/2)/(k*dx*tf)))
            link(ifn[ix, jf, Ns-1], ibp[ix, iy, 0],    1/((dzb/2)/(k*dx*wy[iy]) + (ds/2)/(k*dx*tf)))
            Gg[itp[ix, iy, Nz-1]] += h*dx*(wy[iy]-tf)      # channel top wall
            Gg[ibp[ix, iy, 0]]    += h*dx*(wy[iy]-tf)      # channel bottom wall
    # side walls (inner face convects)
    for ix in range(Nx):
        for jw, iy in enumerate((0, Ny-1)):
            for s in range(Ns):
                nd = iwl[ix, jw, s]
                C[nd] = rho*cp*dx*tw*ds
                Gg[nd] += h*dx*ds + h_out*dx*ds
                if ix+1 < Nx: link(nd, iwl[ix+1, jw, s], k*tw*ds/dx)
                if s+1 < Ns:  link(nd, iwl[ix, jw, s+1], k*dx*tw/ds)
            link(iwl[ix, jw, 0],    itp[ix, iy, Nz-1], 1/((dz/2)/(k*dx*wy[iy]) + (ds/2)/(k*dx*tw)))
            link(iwl[ix, jw, Ns-1], ibp[ix, iy, 0],    1/((dzb/2)/(k*dx*wy[iy]) + (ds/2)/(k*dx*tw)))
            Gg[itp[ix, iy, Nz-1]] += h*dx*(wy[iy]-tw)
            Gg[ibp[ix, iy, 0]]    += h*dx*(wy[iy]-tw)
    if h_out > 0:                                          # optional: outer face of bottom plate
        for ix in range(Nx):
            for iy in range(Ny):
                Gg[ibp[ix, iy, Nzb-1]] += h_out*dx*wy[iy]
    I, J, V = map(np.array, (I, J, V))
    K = sp.coo_matrix((np.r_[V, V, -V, -V], (np.r_[I, J, I, J], np.r_[I, J, J, I])), shape=(N, N)).tocsr()
    K = K + sp.diags(Gg)
    # source: fraction of each top cell inside the circle of radius a
    xc = (np.arange(Nx)+0.5)*dx - L/2
    ye = np.r_[0, np.cumsum(wy)] - W/2
    frac = np.zeros((Nx, Ny)); sub = 8
    for ix in range(Nx):
        xs = xc[ix] - dx/2 + (np.arange(sub)+0.5)*dx/sub
        for iy in range(Ny):
            ys = ye[iy] + (np.arange(sub)+0.5)*wy[iy]/sub
            X, Y = np.meshgrid(xs, ys)
            frac[ix, iy] = np.mean(X**2 + Y**2 <= a**2)
    Acell = dx*wy[None, :]*frac
    P = np.zeros(N); P[itp[:, :, 0].ravel()] = (Acell/Acell.sum()).ravel()
    q = P[itp[:, :, 0]]/(dx*wy[None, :])                    # flux per unit power
    geom = dict(itp=itp, ifn=ifn, iwl=iwl, ibp=ibp, Acell=Acell, q=q, dz=dz,
                xc=xc, yc=np.cumsum(wy)-wy/2-W/2, frac=frac, N=N, Gg=Gg)
    return K, C, P, geom

def surface(T, geom):
    """Contact-face temperature per unit power: node value + half-cell correction."""
    return T[geom['itp'][:, :, 0]] + geom['q']*(geom['dz']/2)/k

def steady(K, P, geom):
    T = spla.spsolve(K.tocsc(), P)
    Ts = surface(T, geom); A = geom['Acell']
    return T, Ts, (Ts*A).sum()/A.sum(), Ts[A > 0].max()

def transient(K, C, P, geom, decades=(-3, 5), spd=90):
    """Implicit Euler step response; constant dt inside each decade (spd steps per decade)."""
    N = len(C); T = np.zeros(N); t = 0.0; Cd = sp.diags(C); A = geom['Acell']
    ts, Za, Zm = [], [], []
    for dec in range(*decades):
        dt = 10.0**dec/(spd/9)
        lu = spla.splu((Cd/dt + K).tocsc())
        for _ in range(spd):
            T = lu.solve(C*T/dt + P); t += dt
            Ts = surface(T, geom)
            ts.append(t); Za.append((Ts*A).sum()/A.sum()); Zm.append(Ts[A > 0].max())
    return np.array(ts), np.array(Za), np.array(Zm)

def foster_fit(t, Z, n=4, tmin=0.05):
    f = lambda t, *p: sum(np.exp(p[i])*(1-np.exp(-t/np.exp(p[n+i]))) for i in range(n))
    m = t >= tmin
    p0 = np.r_[np.log(np.full(n, Z[-1]/n)), np.log(np.logspace(-0.5, 2.5, n))]
    popt, _ = curve_fit(f, t[m], Z[m], p0=p0, sigma=Z[m]*0.02 + 2e-5, maxfev=40000)
    R, tau = np.exp(popt[:n]), np.exp(popt[n:]); o = np.argsort(tau)
    return R[o], tau[o], np.max(np.abs(f(t[m], *popt) - Z[m])/Z[m])

if __name__ == "__main__":
    out = {'sweep': [], 'joint': [], 'zth': {}}
    for Vch in [1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 10]:
        h, Nu, Reb, Res = h_channel(Vch)
        K, C, P, geom = build(h)
        T, Ts, Ravg, Rmax = steady(K, P, geom)
        G, mL, eta = G_total(h); Rsm, Rsa, _ = lee_spreading(G/Ap)
        out['sweep'].append(dict(V=Vch, Q=Vch*Aff*3600, Reb=Reb, Nu=Nu, h=h, eta=eta, G=G,
                                 Ran_avg=1/G+Rsa, Ran_max=1/G+Rsm, Rsp_avg=Rsa, Rsp_max=Rsm,
                                 Rfd_avg=Ravg, Rfd_max=Rmax, dp=pressure_drop(Vch)))
        print(f"V={Vch:4.1f} m/s  Q={Vch*Aff*3600:4.0f} m3/h  analytic {1/G+Rsa:.4f}/{1/G+Rsm:.4f}  FD {Ravg:.4f}/{Rmax:.4f} K/W")
    h = h_channel(4.0)[0]
    for hj in [np.inf, 5e4, 2e4, 1e4, 5e3]:
        K, C, P, geom = build(h, hj=hj); _, _, Ravg, Rmax = steady(K, P, geom)
        out['joint'].append(dict(hj=hj, Ravg=Ravg, Rmax=Rmax)); print("joint hj =", hj, Ravg, Rmax)
    K, C, P, geom = build(h, h_out=5.0); _, _, Ravg, Rmax = steady(K, P, geom)
    out['hout5'] = dict(Ravg=Ravg, Rmax=Rmax); print("h_out = 5:", Ravg, Rmax)
    K, C, P, geom = build(h); T, Ts, Ravg, Rmax = steady(K, P, geom)
    itp = geom['itp']; iy0 = np.argmin(np.abs(geom['yc'])); ix0 = np.argmin(np.abs(geom['xc']))
    out['prof_x'] = dict(x=(geom['xc']*1e3).tolist(), Tsurf=Ts[:, iy0].tolist(),
                         Troot=T[itp[:, iy0, -1]].tolist(), Tbot=T[geom['ibp'][:, iy0, 0]].tolist())
    out['prof_y'] = dict(y=(geom['yc']*1e3).tolist(), Tsurf=Ts[ix0, :].tolist(),
                         Troot=T[itp[ix0, :, -1]].tolist(), Tbot=T[geom['ibp'][ix0, :, 0]].tolist())
    Pc = geom['Gg']*T; mask = np.zeros(len(T), bool)
    for ix in range(len(geom['xc'])):
        for jf in range(Nf):
            if geom['frac'][ix, jf+1] > 0.5: mask[geom['ifn'][ix, jf, :]] = True
    out['share_under_source'] = float(Pc[mask].sum()); out['mass'] = float(C.sum()/cp)
    print("mass", out['mass'], "kg; share under footprint", out['share_under_source'])
    fits = {}
    for Vch in [2.0, 4.0, 8.0]:
        h = h_channel(Vch)[0]; K, C, P, geom = build(h); t0 = time.time()
        ts, Za, Zm = transient(K, C, P, geom)
        out['zth'][str(Vch)] = dict(t=ts.tolist(), Zavg=Za.tolist(), Zmax=Zm.tolist())
        for key, Z in (('Zavg', Za), ('Zmax', Zm)):
            R, tau, err = foster_fit(ts, Z)
            fits[f"{Vch}_{key}"] = dict(R=R.tolist(), tau=tau.tolist(), err=float(err))
            print(f"V={Vch} {key}: R_i [mK/W] = {np.round(R*1e3,2)}  tau_i [s] = {np.round(tau,2)}  max rel err {err*100:.1f}%  ({time.time()-t0:.0f} s)")
    json.dump(out, open('results_fd.json', 'w')); json.dump(fits, open('foster.json', 'w'))
