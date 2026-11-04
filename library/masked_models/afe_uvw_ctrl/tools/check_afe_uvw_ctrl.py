#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
check_afe_uvw_ctrl.py - compares the MATLAB Functions of afe_uvw_ctrl with the original block
diagrams of the model afe_uvw_three_phase (afe_uvw_ctrl.slx of pwr-control/modelization-and-control),
without MATLAB.

Two implementations run on the same recorded inputs (open loop, one sample every ts):

  original  a Python twin of the Simulink subsystems grid_voltage_sequences,
            grid_current_sequences_and_reactive_pwr_ctrl (Simulink variant of the moving average,
            dmavgflt_process), FRT-VDE4110 (LVRT_detector, linear_double_integrator_observer,
            avg_flt, u_161Hz_flt), current_ctrl (rpi_phase_x, antiwind_up, zero_sequence_current_ctrl)
            and islanding_mode_detector (7th harmonic only), written block by block from the .slx
            (netlist read with the XML tools of the thread) and from the library sources
            (ctrl_afe_setup.m, linear_double_integrator_observer.c, moving_average_filter.slx);
  new       the five functions of ../src run in GNU Octave by a generated driver script.

The differences are printed per signal, twice: "chain" runs the twin on its own signals (as the
model does), "per block" gives every block of the twin the signals of the new code at the block
borders (v_seq_avg, i_grid_ref, i_seq_avg, i_stack_ref), so that each block is compared with the
same inputs. Expected: per block, everything but the moving averages agrees to numerical precision
(1e-15); the moving averages agree in steady state and differ during transients, because the new
moving average includes the present sample and is unbiased during its fill-up, while
dmavgflt_process (the port of the C mavgflt) averages the samples up to the previous one and starts
from an implicit zero sample (see the README). In the chain the small differences of the averages
propagate (the PI integrators of the open-loop scenario keep the start-up difference).

Usage (python3 with numpy; octave-cli on the PATH; matplotlib optional for the figure):

    python3 check_afe_uvw_ctrl.py [--plot out.png] [--t-end 1.2]

Rev. 00, 2026-11-04.
"""
import argparse
import math
import os
import subprocess
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)                       # library/masked_models/afe_uvw_ctrl
SRC = os.path.join(PKG, 'src')

# ---------------------------------------------------------------------------- parameters of the model
TS = 125e-6
F_NOM = 50.0
W_NOM = 2*math.pi*F_NOM
# resonator of the twin: 'fb' = forward Euler on x1, backward on x2, as the block since rev. 03 (poles
# inside the unit circle); 'fe' = plain forward Euler Aresd = I + A*ts of the model (poles outside the
# circle for delta < w*ts/2). --model-resonator selects 'fe' with the model's delta 0.015 on both sides.
RESONATOR = 'fb'
PAR = dict(
    # ctrl_afe_setup / init_model.m
    kp_rpi=0.6, ki_rpi=35.0, delta_res=0.005,     # delta_res: 0.005 of the package (0.015 in the model's class)
    kp_rc_pos=0.25, ki_rc_pos=35.0, kp_rc_neg=0.25, ki_rc_neg=35.0,
    ieta_pos_ref_lim=1.0, ieta_neg_ref_lim=0.5,
    i_grid_pos_eta_lim=1.0, i_grid_neg_xi_lim=0.5, i_grid_neg_eta_lim=0.5,
    kp_is_z=0.5, ki_is_z=18.0,
    mavg_order=2, dmavg_enable_time=0.025,
    # frt_settings / setup_global_filters
    k_frt_ref=2.0, settle_time=0.175, g0_161=2*math.pi*161*TS,
    obs_poles=(-0.1*W_NOM, -0.4*W_NOM), time_release=0.025,
)


def observer_gains(poles, ts):
    """acker of ctrl_afe_setup in closed form: A = [1 ts; 0 1], C = [1 0]."""
    z1, z2 = math.exp(poles[0]*ts), math.exp(poles[1]*ts)
    l1 = 2 - (z1 + z2)
    l2 = (z1*z2 - 1 + l1)/ts
    return l1/ts, l2/ts


def sat(x, lo, hi):
    return min(max(x, lo), hi)


# ---------------------------------------------------------------------------- twin of the original blocks
class DmavgFlt:
    """moving_average_filter/dmavg_flt: Step(enable_time) -> enable, period = 2*pi/omega (enabled
    subsystem, omega > 0), MATLAB Function dmavgflt_process (circular buffer, fractional period)."""
    SIZE = 17500

    def __init__(self, ts, enable_time):
        self.ts = ts
        self.enable_time = enable_time
        self.buffer = np.zeros(self.SIZE)
        self.cb_index = 1
        self.sample_count = 1
        self.sum_short = 0.0
        self.sum_long = 0.0
        self.prev_input = 0.0
        self.period = 0.0

    def _idx(self, offset):
        return (self.cb_index - 1 - offset) % self.SIZE          # 0-based index of the sample "offset" back

    def step(self, t, x, omega):
        if omega > 0:
            self.period = 1.0/(omega/(2*math.pi))
        period = self.period
        enable = t >= self.enable_time - 1e-9
        if not enable:
            return 0.0
        if period <= 0:
            return 0.0
        desired = period/self.ts
        if desired > self.SIZE - 1:
            desired = self.SIZE - 1
        n_samples = math.floor(desired + 1)
        frac = desired + 1 - n_samples
        if n_samples < 1:
            n_samples = 1
        if n_samples > self.sample_count:
            self.sum_short += self.prev_input
            self.sum_long += x
            self.sample_count += 1
        elif n_samples < self.sample_count:
            s = self.buffer[self._idx(self.sample_count)] + self.buffer[self._idx(self.sample_count - 1)]
            self.sum_short += self.prev_input - s
            self.sum_long += x - s
            self.sample_count -= 1
        else:
            oldest = self.buffer[self._idx(self.sample_count)]
            self.sum_short += self.prev_input - oldest
            self.sum_long += x - oldest
        self.buffer[self.cb_index - 1] = x
        self.cb_index = (self.cb_index % self.SIZE) + 1
        self.prev_input = x
        avg_short = self.sum_short/(self.sample_count - 1) if self.sample_count > 1 else 0.0
        avg_long = self.sum_long/self.sample_count
        return avg_short*(1 - frac) + avg_long*frac


class PiSimulink:
    """The PI of the sequence controllers and of the zero-sequence controller: P = kp*e,
    y = sat(P + ki*ts*e + z, -lim, lim), z <- y - P (Unit Delay fed with saturation - P)."""

    def __init__(self, kp, ki_ts, lim):
        self.kp, self.ki_ts, self.lim = kp, ki_ts, lim
        self.z = 0.0

    def step(self, e):
        P = self.kp*e
        y = sat(P + self.ki_ts*e + self.z, -self.lim, self.lim)
        self.z = y - P
        return y


class DIObserver:
    """linear_double_integrator_observer.c with the reset step of the _ccaller block."""

    def __init__(self, ts, kx, kv, time_release):
        self.ts, self.kx, self.kv, self.time_release = ts, kx, kv, time_release
        self.x = 0.0
        self.v = 0.0

    def step(self, t, u):
        if t < self.time_release - 1e-9:          # Step Before=1 After=0 at time_release -> reset
            self.x = 0.0
            self.v = 0.0
        x_new = self.x + self.v*self.ts + self.ts*self.kx*(u - self.x)
        v_new = self.v + self.ts*self.kv*(u - self.x)
        self.x, self.v = x_new, v_new
        return self.x, self.v


class AvgFlt:
    """avg_flt_1 of the FRT references: running integral of x*ts*w, shift register of N = T/ts+1 values,
    y = (newest - oldest)/(2*pi); frozen (register not shifted) when enable ~= 1."""

    def __init__(self, ts, w):
        self.ts, self.w = ts, w
        self.N = int(round((1.0/(w/(2*math.pi)))/ts + 1))
        self.reg = np.zeros(self.N)               # reg[0] newest ... reg[N-1] oldest
        self.x_int_1 = 0.0

    def step(self, x, enable):
        if enable == 1:
            x_int = x*self.ts*self.w + self.x_int_1
            self.x_int_1 = x_int
            self.reg[0] = x_int
            y1 = (self.reg[0] - self.reg[self.N - 1])/(2*math.pi)
            self.reg[1:] = self.reg[:-1].copy()
        else:
            y1 = (self.reg[0] - self.reg[self.N - 1])/(2*math.pi)
        return y1


class Lpf1:
    """u_161Hz_flt: y = g0*u + g1*y_prev."""

    def __init__(self, g0):
        self.g0, self.g1 = g0, 1 - g0
        self.y = 0.0

    def step(self, u):
        self.y = self.g0*u + self.g1*self.y
        return self.y


class LvrtDetector:
    """LVRT_detector MATLAB Function of FRT-Detection, line by line."""
    IDLE, ACTIVE, EXCEEDED = 0, 1, 2

    def __init__(self):
        self.state = self.IDLE
        self.state_pwr_lim = 0
        self.count = 0
        self.count2 = 0

    def step(self, vxi_p, vxi_n, veta_n, vxi_p_dot, vxi_n_dot, enable, red_dyn_enabled, reset):
        TH_LOW, TH_HIGH, HYST, VNEG_TH = 0.85, 1.15, 0.1, 0.1
        VPOS_DOT_TH, VNEG_DOT_TH = 2.0, 2.0
        VPOS_PWRLIM_TH, VNEG_PWRLIM_TH, PWRLIM_HYST = 0.8, 0.1, 0.1
        VPOS_RED_DYN_TH, VNEG_RED_DYN_TH = 0.7, 0.2
        TIME_HOLD_MAX = 61000
        vn = math.sqrt(vxi_n**2 + veta_n**2)
        red_dyn_active = 0
        if enable == 1:
            if self.state == self.IDLE:
                if ((vxi_p > TH_HIGH or vxi_p < TH_LOW or vn > VNEG_TH)
                        and (vxi_p_dot > VPOS_DOT_TH or vxi_n_dot > VNEG_DOT_TH) and self.count2 > 1000):
                    self.state = self.ACTIVE
                frt_active, frt_exceeded = 0, 0
                self.count = 0
                frt_state = self.IDLE
                self.state_pwr_lim = 0
                self.count2 += 1
            elif self.state == self.ACTIVE:
                self.count2 = 0
                if TH_LOW + HYST <= vxi_p < TH_HIGH - HYST:
                    self.state = self.IDLE
                elif self.count >= TIME_HOLD_MAX:
                    self.state = self.EXCEEDED
                if vxi_p < VPOS_PWRLIM_TH or vn > VNEG_PWRLIM_TH:
                    self.state_pwr_lim = 1
                elif vxi_p > VPOS_PWRLIM_TH + PWRLIM_HYST and vn < VPOS_PWRLIM_TH - PWRLIM_HYST:
                    self.state_pwr_lim = 0
                if red_dyn_enabled and (vxi_p < VPOS_RED_DYN_TH or vn > VNEG_RED_DYN_TH):
                    red_dyn_active = 1
                frt_active, frt_exceeded = 1, 0
                frt_state = self.ACTIVE
                self.count += 1
            else:
                if reset == 1 or enable == 0:
                    self.state = self.IDLE
                frt_exceeded, frt_active = 1, 0
                frt_state = self.EXCEEDED
            pwr_lim_enable = 1 if self.state_pwr_lim == 1 else 0
        else:
            self.state = self.IDLE
            frt_active, pwr_lim_enable, frt_exceeded = 0, 0, 0
            frt_state = self.IDLE
        return pwr_lim_enable, frt_exceeded, frt_active, frt_state, red_dyn_active


def clarke(a, b, c):
    return 2/3*(a - 0.5*b - 0.5*c), 1/math.sqrt(3)*(b - c)


def to_pos(alpha, beta, g):
    return alpha*math.cos(g) + beta*math.sin(g), -alpha*math.sin(g) + beta*math.cos(g)


def to_neg(alpha, beta, g):
    return alpha*math.cos(g) - beta*math.sin(g), alpha*math.sin(g) + beta*math.cos(g)


class OriginalTwin:
    """All the original subsystems together, one step per control period."""

    def __init__(self, ts=TS, par=PAR):
        self.ts = ts
        self.par = par
        w_order = par['mavg_order']
        self.w_order = w_order
        self.v_avg = [DmavgFlt(ts, par['dmavg_enable_time']) for _ in range(4)]
        self.i_avg = [DmavgFlt(ts, par['dmavg_enable_time']) for _ in range(4)]
        self.h7_avg = [DmavgFlt(ts, par['dmavg_enable_time']) for _ in range(2)]
        self.pi_pos_eta = PiSimulink(par['kp_rc_pos'], par['ki_rc_pos']*ts, par['ieta_pos_ref_lim'])
        self.pi_neg_eta = PiSimulink(par['kp_rc_neg'], par['ki_rc_neg']*ts, par['ieta_neg_ref_lim'])
        self.pi_neg_xi = PiSimulink(par['kp_rc_neg'], par['ki_rc_neg']*ts, par['ieta_pos_ref_lim'])
        kx, kv = observer_gains(par['obs_poles'], ts)
        self.obs_pos = DIObserver(ts, kx, kv, par['time_release'])
        self.obs_neg = DIObserver(ts, kx, kv, par['time_release'])
        self.lvrt = LvrtDetector()
        self.avg500 = [AvgFlt(ts, 2*math.pi/0.5) for _ in range(4)]
        self.lpf = [Lpf1(par['g0_161']) for _ in range(3)]
        # resonant PI (resonant_pi of ctrl_afe_setup: forward Euler; 'fb': the new x1 in the update of x2)
        w0, d = W_NOM, par['delta_res']
        A = np.array([[0.0, 1.0], [-w0**2, -2*d*w0]])
        if RESONATOR == 'fe':
            self.Aresd = np.eye(2) + A*ts
        else:
            self.Aresd = np.array([[1.0, ts], [-w0**2*ts, 1.0 - (w0*ts)**2 - 2*d*w0*ts]])
        self.Bresd = np.array([0.0, 1.0])*ts
        self.Cresd = np.array([0.0, 1.0])
        self.x_res = [np.zeros(2) for _ in range(3)]
        self.ud_alpha = 0.0                       # Unit Delay4/5 of antiwind_up
        self.ud_beta = 0.0
        self.pi_z = PiSimulink(par['kp_is_z'], par['ki_is_z']*ts, 1.0)
        self.frt_active = 0                       # Goto frt_active of the previous computation (same step
        self.i_grid_seq_ref = (0.0, 0.0, 0.0)     # order: data flow below keeps them of the same step)

    def step(self, t, ug_abc, theta, omega_pu, ig_abc, is_abc, i_xi_ref, i_react_ref, enable, reset, ovr=None):
        # ovr: optional dict of signals of the new code (v_seq_avg, i_grid_ref, i_seq_avg, i_stack_ref) that
        # replace the twin's own ones at the block borders, so that every block is compared with the same
        # inputs as the new code (per-block comparison); the twin's own values are still returned in out.
        ts, par = self.ts, self.par
        ovr = ovr or {}
        out = {}
        # ---------------- grid_voltage_sequences
        ua, ub = clarke(*ug_abc)
        pxi, peta = to_pos(ua, ub, theta)
        nxi, neta = to_neg(ua, ub, theta)
        w_avg = W_NOM*self.w_order*sat(abs(omega_pu), 0.1, 2)
        v_avg = [f.step(t, x, w_avg) for f, x in zip(self.v_avg, (pxi, peta, nxi, neta))]
        out['ug_ab'] = (ua, ub)
        out['v_seq'] = (pxi, peta, nxi, neta)
        out['v_seq_avg'] = tuple(v_avg)
        if 'v_seq_avg' in ovr:
            v_avg = list(ovr['v_seq_avg'])
        # ---------------- FRT-VDE4110: detection
        vxi_p, vxi_n, veta_n = v_avg[0], v_avg[2], v_avg[3]
        _, vp_dot = self.obs_pos.step(t, vxi_p)
        _, vn_dot = self.obs_neg.step(t, vxi_n)
        en = 1 if enable > 0.5 else 0
        rs = 1 if reset > 0.5 else 0
        pwr_lim, frt_exc, frt_act, frt_state, red_dyn = self.lvrt.step(vxi_p, vxi_n, veta_n, abs(vp_dot),
                                                                       abs(vn_dot), en, 0, rs)
        # ---------------- FRT-VDE4110: references (red_dyn_active Goto of this subsystem is a constant 0)
        en_avg = 1 - frt_act
        v_pre = [f.step(x, en_avg) for f, x in zip(self.avg500, v_avg)]
        deltaU = v_avg[0] - v_pre[0]
        dib_pos_eta = par['k_frt_ref']*deltaU
        di_neg_eta = -par['k_frt_ref']*(v_avg[2] - v_pre[2])
        di_neg_xi = par['k_frt_ref']*(v_avg[3] - v_pre[3])
        no_frt = (1 - frt_act) > 0.5
        i_react_pos, i_react_neg = i_react_ref
        u_pos_eta = i_react_pos if no_frt else i_react_pos + dib_pos_eta
        u_neg_eta = i_react_neg if no_frt else i_react_neg + di_neg_eta
        u_neg_xi = 0.0 if no_frt else di_neg_xi
        lim_pe, lim_ne, lim_nx = par['i_grid_pos_eta_lim'], par['i_grid_neg_eta_lim'], par['i_grid_neg_xi_lim']
        r_pos_eta = self.lpf[0].step(sat(u_pos_eta, -lim_pe, lim_pe))
        r_neg_eta = self.lpf[1].step(sat(u_neg_eta, -lim_ne, lim_ne))
        r_neg_xi = self.lpf[2].step(sat(u_neg_xi, -lim_nx, lim_nx))
        out['i_grid_ref'] = (r_pos_eta, r_neg_xi, r_neg_eta)
        out['frt_active'] = frt_act
        out['pwr_lim_enable'] = pwr_lim
        out['frt_state'] = frt_state
        out['v_dot'] = (abs(vp_dot), abs(vn_dot))
        out['v_prefault'] = tuple(v_pre)
        if 'i_grid_ref' in ovr:
            r_pos_eta, r_neg_xi, r_neg_eta = ovr['i_grid_ref']
        # ---------------- grid_current_sequences_and_reactive_pwr_ctrl
        ia, ib = clarke(*ig_abc)
        ipxi, ipeta = to_pos(ia, ib, theta)
        inxi, ineta = to_neg(ia, ib, theta)
        i_avg = [f.step(t, x, w_avg) for f, x in zip(self.i_avg, (ipxi, ipeta, inxi, ineta))]
        out['i_seq_avg'] = tuple(i_avg)
        if 'i_seq_avg' in ovr:
            i_avg = list(ovr['i_seq_avg'])
        s_pos_eta = self.pi_pos_eta.step(-(r_pos_eta - i_avg[1]))
        s_neg_eta = self.pi_neg_eta.step(-(r_neg_eta - i_avg[3]))
        s_neg_xi = self.pi_neg_xi.step(-(r_neg_xi - i_avg[2]))
        out['i_seq'] = (ipxi, ipeta, inxi, ineta)
        out['i_stack_ref'] = (s_pos_eta, s_neg_xi, s_neg_eta)
        if 'i_stack_ref' in ovr:
            s_pos_eta, s_neg_xi, s_neg_eta = ovr['i_stack_ref']
        # ---------------- current_ctrl
        c, s = math.cos(theta), math.sin(theta)
        a_p = i_xi_ref*c - s_pos_eta*s
        b_p = i_xi_ref*s + s_pos_eta*c
        a_n = s_neg_xi*c + s_neg_eta*s
        b_n = -s_neg_xi*s + s_neg_eta*c
        alpha_r, beta_r = a_p + a_n, b_p + b_n
        i_ref = (alpha_r, -0.5*alpha_r + math.sqrt(3)/2*beta_r, -0.5*alpha_r - math.sqrt(3)/2*beta_r)
        d_abc = []
        for k in range(3):
            e = i_ref[k] - is_abc[k]
            d = par['kp_rpi']*e + float(self.Cresd @ self.x_res[k])
            self.x_res[k] = self.Aresd @ self.x_res[k] + self.Bresd*(par['ki_rpi']*e)
            d_abc.append(d)
        scaling = sat(math.sqrt(self.ud_alpha**2 + self.ud_beta**2), 1.0, 10.0)
        das, dbs, dcs = (d/scaling for d in d_abc)
        u_alpha_new, u_beta_new = clarke(das, dbs, dcs)
        u_alpha, u_beta = self.ud_alpha, self.ud_beta          # Unit Delay outputs
        self.ud_alpha, self.ud_beta = u_alpha_new, u_beta_new
        iz = (is_abc[0] + is_abc[1] + is_abc[2])/3
        u_gamma = self.pi_z.step(0.0 - iz)
        isa, isb = clarke(*is_abc)
        out['u_abg'] = (u_alpha, u_beta, u_gamma)
        out['i_abc_ref'] = i_ref
        out['is_xe'] = to_pos(isa, isb, theta)
        # ---------------- islanding_mode_detector (7th harmonic measurement)
        g7 = -math.pi + ((7*theta + 3*math.pi) % (2*math.pi))
        x7, e7 = to_pos(ua, ub, g7)
        w7 = W_NOM*2*sat(abs(omega_pu), 0.1, 2)
        u7 = [f.step(t, x, w7) for f, x in zip(self.h7_avg, (x7, e7))]
        out['u7'] = math.sqrt(u7[0]**2 + u7[1]**2)
        return out


# ---------------------------------------------------------------------------- scenario
def scenario(t_end=1.2, ts=TS):
    n = int(round(t_end/ts))
    t = np.arange(n)*ts
    omega_pu = 1.004                               # 50.2 Hz: the averaging window is not an integer
    w = W_NOM*omega_pu
    theta = w*t
    dip = (t >= 0.75) & (t < 0.90)
    vp = np.where(dip, 0.55, 1.0)
    vn = np.where(dip, 0.25, 0.0)
    phin = 0.9
    h7, h5 = 0.02, 0.015
    ua = vp*np.cos(theta) + vn*np.cos(-theta + phin) + h7*np.cos(7*theta + 0.3) + h5*np.cos(-5*theta + 1.1)
    ub = vp*np.sin(theta) + vn*np.sin(-theta + phin) + h7*np.sin(7*theta + 0.3) + h5*np.sin(-5*theta + 1.1)
    ug_abc = np.vstack([ua, -0.5*ua + math.sqrt(3)/2*ub, -0.5*ua - math.sqrt(3)/2*ub])
    # grid current: positive frame (xi, eta) with a step of eta at 0.3 s, negative sequence in the dip
    g_pxi = 0.8*np.ones(n)
    g_peta = 0.1 + 0.2*(t >= 0.3)
    g_nxi = np.where(dip, 0.10, 0.0)
    g_neta = np.where(dip, -0.05, 0.0)
    ia = (g_pxi*np.cos(theta) - g_peta*np.sin(theta)) + (g_nxi*np.cos(theta) + g_neta*np.sin(theta))
    ib = (g_pxi*np.sin(theta) + g_peta*np.cos(theta)) + (-g_nxi*np.sin(theta) + g_neta*np.cos(theta))
    ig_abc = np.vstack([ia, -0.5*ia + math.sqrt(3)/2*ib, -0.5*ia - math.sqrt(3)/2*ib])
    # stack current for the current controller (open loop): positive and negative sequence, zero sequence
    s_pxi, s_peta, s_nxi, s_neta, s_z = -0.80, 0.05, 0.02, 0.0, 0.01
    ia = (s_pxi*np.cos(theta) - s_peta*np.sin(theta)) + (s_nxi*np.cos(theta) + s_neta*np.sin(theta))
    ib = (s_pxi*np.sin(theta) + s_peta*np.cos(theta)) + (-s_nxi*np.sin(theta) + s_neta*np.cos(theta))
    is_abc = np.vstack([ia, -0.5*ia + math.sqrt(3)/2*ib, -0.5*ia - math.sqrt(3)/2*ib]) + s_z
    i_xi_ref = -0.85*np.ones(n)
    i_react_ref = np.vstack([0.1*(t >= 1.0), np.zeros(n)])
    enable = (t >= PAR['settle_time'] - 1e-9).astype(float)
    reset = (t < 0.025 - 1e-9).astype(float)
    return dict(t=t, ug_abc=ug_abc, theta=theta, omega_pu=omega_pu*np.ones(n), ig_abc=ig_abc, is_abc=is_abc,
                i_xi_ref=i_xi_ref, i_react_ref=i_react_ref, enable=enable, reset=reset)


OUT_KEYS = [('ug_ab', 2), ('v_seq', 4), ('v_seq_avg', 4), ('i_grid_ref', 3), ('frt_active', 1),
            ('pwr_lim_enable', 1), ('frt_state', 1), ('v_dot', 2), ('v_prefault', 4), ('i_seq', 4),
            ('i_seq_avg', 4), ('i_stack_ref', 3), ('u_abg', 3), ('i_abc_ref', 3), ('is_xe', 2), ('u7', 1)]


OVR_KEYS = ('v_seq_avg', 'i_grid_ref', 'i_seq_avg', 'i_stack_ref')


def run_original(sc, new=None):
    # new: outputs of the new code (run_new); when given, the twin's blocks read the new code's
    # signals at the block borders (per-block comparison), see OriginalTwin.step
    tw = OriginalTwin()
    n = len(sc['t'])
    res = {k: np.zeros((m, n)) for k, m in OUT_KEYS}
    for k in range(n):
        ovr = {key: tuple(new[key][:, k]) for key in OVR_KEYS} if new is not None else None
        o = tw.step(sc['t'][k], sc['ug_abc'][:, k], sc['theta'][k], sc['omega_pu'][k], sc['ig_abc'][:, k],
                    sc['is_abc'][:, k], sc['i_xi_ref'][k], sc['i_react_ref'][:, k], sc['enable'][k],
                    sc['reset'][k], ovr)
        for key, m in OUT_KEYS:
            res[key][:, k] = o[key]
    return res


OCTAVE_DRIVER = r"""
addpath('%(pkg)s'); addpath('%(src)s');
clear functions
p = afe_uvw_ctrl_param_example(%(ts)g, %(f_nom)g);
p.ictrl.delta_res = %(delta)g;
in = csvread('%(inputs)s');
n = size(in, 1);
out = zeros(n, %(ncol)d);
tic
for k = 1:n
    t = in(k, 1); ug_abc = in(k, 2:4)'; theta = in(k, 5); omega_pu = in(k, 6); ig_abc = in(k, 7:9)';
    is_abc = in(k, 10:12)'; i_xi_ref = in(k, 13); i_react_ref = in(k, 14:15)'; en = in(k, 16); rs = in(k, 17);
    [v_seq_avg, v_seq, ug_ab] = grid_voltage_sequences(ug_abc, theta, omega_pu, p);
    [i_grid_ref, frt_active, pwr_lim_enable, frt_log] = frt_vde4110(v_seq_avg, i_react_ref, en, rs, p);
    [i_stack_ref, i_seq_avg, i_seq] = grid_current_sequences_q_ctrl(ig_abc, theta, omega_pu, i_grid_ref, p);
    [u_abg, i_abc_ref, is_xe] = current_ctrl_uvw(i_xi_ref, i_stack_ref, is_abc, theta, p);
    [island, crit, idet_log] = islanding_detector(ug_ab, theta, omega_pu, 1, p);
    out(k, :) = [ug_ab' v_seq' v_seq_avg' i_grid_ref' frt_active pwr_lim_enable frt_log(1) frt_log(4:5)' ...
                 frt_log(6:9)' i_seq' i_seq_avg' i_stack_ref' u_abg' i_abc_ref' is_xe' idet_log(3) island crit idet_log'];
end
printf('octave: %%d steps in %%.1f s\n', n, toc);
csvwrite('%(outputs)s', out);
"""


def run_new(sc, keep=None):
    n = len(sc['t'])
    cols = [sc['t'], sc['ug_abc'][0], sc['ug_abc'][1], sc['ug_abc'][2], sc['theta'], sc['omega_pu'],
            sc['ig_abc'][0], sc['ig_abc'][1], sc['ig_abc'][2], sc['is_abc'][0], sc['is_abc'][1], sc['is_abc'][2],
            sc['i_xi_ref'], sc['i_react_ref'][0], sc['i_react_ref'][1], sc['enable'], sc['reset']]
    inputs = np.vstack(cols).T
    ncol = sum(m for _, m in OUT_KEYS) + 2 + 8
    d = keep or tempfile.mkdtemp(prefix='afe_uvw_check_')
    os.makedirs(d, exist_ok=True)
    f_in = os.path.join(d, 'inputs.csv')
    f_out = os.path.join(d, 'outputs_new.csv')
    f_drv = os.path.join(d, 'run_new.m')
    np.savetxt(f_in, inputs, delimiter=',', fmt='%.17g')
    open(f_drv, 'w').write(OCTAVE_DRIVER % dict(pkg=PKG, src=SRC, ts=TS, f_nom=F_NOM, inputs=f_in,
                                                outputs=f_out, ncol=ncol, delta=PAR['delta_res']))
    r = subprocess.run(['octave-cli', '--no-gui', '-q', f_drv], capture_output=True, text=True)
    sys.stdout.write(r.stdout)
    if r.returncode != 0:
        sys.stderr.write(r.stderr)
        raise SystemExit('octave failed')
    out = np.loadtxt(f_out, delimiter=',')
    res = {}
    c = 0
    for key, m in OUT_KEYS:
        res[key] = out[:, c:c + m].T
        c += m
    res['island'] = out[:, c:c + 1].T
    res['crit'] = out[:, c + 1:c + 2].T
    res['idet_log'] = out[:, c + 2:c + 10].T
    return res


def compare(sc, orig, new, blk, t_skip=0.05):
    # orig: twin in the chain (own signals), blk: twin block by block (new code's signals at the borders)
    t = sc['t']
    late = t >= t_skip
    print('\n%-16s %-22s %12s %12s %12s   %s' % ('signal', 'component', 'chain', 'chain', 'per block', 'note'))
    print('%-16s %-22s %12s %12s %12s' % ('', '', 'max|diff|', 'max|diff|', 'max|diff|'))
    print('%-16s %-22s %12s %12s %12s' % ('', '', 'all', 't>%.2fs' % t_skip, 't>%.2fs' % t_skip))
    names = {'ug_ab': ['alpha', 'beta'], 'v_seq': ['pos_xi', 'pos_eta', 'neg_xi', 'neg_eta'],
             'v_seq_avg': ['pos_xi', 'pos_eta', 'neg_xi', 'neg_eta'], 'i_grid_ref': ['pos_eta', 'neg_xi', 'neg_eta'],
             'frt_active': [''], 'pwr_lim_enable': [''], 'frt_state': [''], 'v_dot': ['pos', 'neg'],
             'v_prefault': ['pos_xi', 'pos_eta', 'neg_xi', 'neg_eta'], 'i_seq': ['pos_xi', 'pos_eta', 'neg_xi', 'neg_eta'],
             'i_seq_avg': ['pos_xi', 'pos_eta', 'neg_xi', 'neg_eta'], 'i_stack_ref': ['pos_eta', 'neg_xi', 'neg_eta'],
             'u_abg': ['alpha', 'beta', 'gamma'], 'i_abc_ref': ['a', 'b', 'c'], 'is_xe': ['xi', 'eta'], 'u7': ['']}
    summary = {}
    for key, m in OUT_KEYS:
        for j in range(m):
            d = np.abs(orig[key][j] - new[key][j])
            note = ''
            if key in ('frt_active', 'pwr_lim_enable', 'frt_state'):
                k_o = np.flatnonzero(np.diff(orig[key][j]) != 0)
                k_n = np.flatnonzero(np.diff(new[key][j]) != 0)
                note = 'edges orig %s / new %s [ms]' % (np.round(t[k_o]*1e3, 2).tolist()[:6],
                                                        np.round(t[k_n]*1e3, 2).tolist()[:6])
            db = np.abs(blk[key][j] - new[key][j])
            print('%-16s %-22s %12.3e %12.3e %12.3e   %s' % (key, names[key][j], d.max(), d[late].max(),
                                                           db[late].max(), note))
            summary[(key, j)] = (d.max(), d[late].max(), db[late].max())
    return summary


def plot(sc, orig, new, path):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    t = sc['t']
    fig, ax = plt.subplots(4, 1, figsize=(10, 11), sharex=True)
    for j, lab in enumerate(['pos_xi', 'pos_eta', 'neg_xi', 'neg_eta']):
        ax[0].plot(t, orig['v_seq_avg'][j], lw=2.2, alpha=0.5, label='original ' + lab if j == 0 else None, color='C%d' % j)
        ax[0].plot(t, new['v_seq_avg'][j], 'k--', lw=0.8, label='new (MATLAB Function)' if j == 0 else None)
    ax[0].set_ylabel('grid voltage sequences, averaged [pu]')
    ax[0].legend(loc='lower left', fontsize=8)
    ax[0].set_title('afe_uvw_ctrl: original block diagrams (Python twin) against the new MATLAB Functions (Octave)')
    for j, lab in enumerate(['pos_eta', 'neg_xi', 'neg_eta']):
        ax[1].plot(t, orig['i_grid_ref'][j], lw=2.2, alpha=0.5, color='C%d' % j, label='i_grid_ref ' + lab)
        ax[1].plot(t, new['i_grid_ref'][j], 'k--', lw=0.8)
    ax[1].plot(t, orig['frt_active'][0]*0.1 - 0.9, color='C4', lw=1, label='frt_active (0.1 scale)')
    ax[1].set_ylabel('FRT current references [pu]')
    ax[1].legend(loc='lower left', fontsize=8)
    for j, lab in enumerate(['pos_eta', 'neg_xi', 'neg_eta']):
        ax[2].plot(t, orig['i_stack_ref'][j], lw=2.2, alpha=0.5, color='C%d' % j, label='i_stack_ref ' + lab)
        ax[2].plot(t, new['i_stack_ref'][j], 'k--', lw=0.8)
    ax[2].set_ylabel('stack current references [pu]')
    ax[2].legend(loc='lower left', fontsize=8)
    for j, lab in enumerate(['alpha', 'beta', 'gamma']):
        ax[3].plot(t, orig['u_abg'][j], lw=2.2, alpha=0.5, color='C%d' % j, label='u_' + lab)
        ax[3].plot(t, new['u_abg'][j], 'k--', lw=0.8)
    ax[3].set_ylabel('current controller output [pu]')
    ax[3].set_xlabel('t [s]')
    ax[3].legend(loc='lower left', fontsize=8)
    for a in ax:
        a.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(path, dpi=110)
    print('figure written:', path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--plot', default=None, help='write a comparison figure (PNG)')
    ap.add_argument('--t-end', type=float, default=1.2)
    ap.add_argument('--keep', default=None, help='folder for the CSV files and the Octave driver')
    ap.add_argument('--model-resonator', action='store_true',
                    help="twin with the model's forward Euler resonator and delta 0.015 (both sides): shows the "
                         'difference of the current controller from the model')
    a = ap.parse_args()
    global RESONATOR
    if a.model_resonator:
        RESONATOR = 'fe'
        PAR['delta_res'] = 0.015
    print('twin resonator: %s, delta_res %g' % (RESONATOR, PAR['delta_res']))
    sc = scenario(a.t_end)
    print('scenario: %d steps of %g us, dip 0.75..0.90 s (pos 0.55, neg 0.25), 7th harmonic 2 %%, 5th 1.5 %%'
          % (len(sc['t']), TS*1e6))
    orig = run_original(sc)
    new = run_new(sc, a.keep)
    blk = run_original(sc, new)
    compare(sc, orig, new, blk)
    # islanding detector: what it measured
    k = -1
    print('\nislanding_detector at the end: island %d crit %d, u1 %.4f u5 %.4f u7 %.4f (set 1, 0.015, 0.02), '
          'f %.4f pu, rocof %.3f Hz/s' % (new['island'][0, k], new['crit'][0, k], new['idet_log'][0, k],
                                          new['idet_log'][1, k], new['idet_log'][2, k], new['idet_log'][4, k],
                                          new['idet_log'][5, k]))
    kd = np.flatnonzero(np.diff(new['island'][0]) != 0)
    print('islanding_detector edges [s]:', np.round(sc['t'][kd], 4).tolist())
    if a.plot:
        plot(sc, orig, new, a.plot)


if __name__ == '__main__':
    main()
