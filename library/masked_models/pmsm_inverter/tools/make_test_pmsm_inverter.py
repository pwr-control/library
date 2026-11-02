#!/usr/bin/env python3
"""Write test/test_pmsm_inverter.slx, the test bench of the block pmsm_inverter_dqctrl_mod1, without MATLAB.

  DC source (tb.Vdc, series tb.Rdc) -> pmsm_inverter_dqctrl_mod1 -> u, v, w of the library PMSM
  (permanent_magnet_synchronous_machine) -> shaft driven by an ideal angular velocity source (speed
  profile of the case, filtered by its Simulink-PS converter, time constant tb.w_tau)

The inverter gets the time of a Clock (t_master), ref = [enable; reference] from two 1-D lookup tables of
the time (profiles tb.prof.*) and the encoder angle phase_elec of the machine. Logged with To Workspace
(sample time tb.ts_log): ctrl_log (44x1), m_log (17x1) and mach_log = [phase_elec (rad); omega_elec
(rad/s); torque (Nm); id (A); iq (A)] of the machine. Parameters: p_inv (mask of the inverter), mach (machine
data), tb (test bench), made by test/pmsm_inverter_test_param.m; test/pmsm_inverter_test_run.m runs the
cases and checks them.

The .slx is written with slxlib.py and sscblocks.py of ../../semiconductors_bridges/tools (the generator of
the bridges and of their test bench, R2026a format, loaded by R2026b).

Usage:  python3 make_test_pmsm_inverter.py [output_dir]          (default: ../test)

Rev. 00, 2026-11-02.
"""
import datetime
import hashlib
import itertools
import os
import sys
import types
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(os.path.dirname(FOLDER), 'semiconductors_bridges', 'tools'))
import slxlib  # noqa: E402
from slxlib import (System, SidPool, write_slx, pos, solver_model, DATAIO_MODEL, P, P_indent,   # noqa: E402
                    esc_attr, NESL_VERSION)
import sscblocks as sb  # noqa: E402

MODEL = 'test_pmsm_inverter'

# same bytes on every run, so that running the script again gives no git diff: slxlib draws random UUIDs and
# writes the time of the run; here the UUIDs come from a counter and the date is fixed
FIXED_DATE = datetime.datetime(2026, 11, 2, tzinfo=datetime.timezone.utc)
_uuid_count = itertools.count(1)


class _FixedDate(datetime.datetime):
    @classmethod
    def now(cls, tz=None):
        return FIXED_DATE


slxlib.new_uuid = lambda: str(uuid.UUID(bytes=hashlib.md5(('%s/%d' % (MODEL, next(_uuid_count))).encode())
                                        .digest(), version=4))
slxlib.datetime = types.SimpleNamespace(datetime=_FixedDate, timezone=datetime.timezone)
INV_SRC = 'pmsm_inverter_dqctrl/pmsm_inverter_dqctrl_mod1'
PMSM_SRC = 'permanent_magnet_synchronous_machine/permanent_magnet_synchronous_machine'
MACH_SIGNALS = ['phase_elec (rad)', 'omega_elec (rad/s)', 'torque (Nm)', 'id (A)', 'iq (A)']

# mask of the library PMSM: pp is passed to number_poles of the Simscape component (pmsm_uvw_with_harmonics),
# so it takes the NUMBER OF POLES (as in inv_psm); La, Lb from Ld, Lq: Ld = 3/2*(La - Lb), Lq = 3/2*(La + Lb)
# (+ Lmu, leakage, in both)
PMSM_MASK = [('pp', 'mach.poles'), ('psi_m', 'mach.psi_m'), ('Lmu', 'mach.Lmu'),
             ('La', '(mach.Ld + mach.Lq)/3'), ('Lb', '(mach.Lq - mach.Ld)/3'), ('Rs', 'mach.Rs'),
             ('Jm', 'mach.J'), ('b_linear', '0'), ('b_quadratic', '0'), ('h5_percent', '0'),
             ('h7_percent', '0'), ('psi_r_u_init', 'mach.psi_m*cos(tb.theta0)'),
             ('psi_r_v_init', 'mach.psi_m*cos(tb.theta0 - 2*pi/3)'),
             ('psi_r_w_init', 'mach.psi_m*cos(tb.theta0 + 2*pi/3)'), ('omega_init', 'tb.omega_e0'),
             ('phase_init', 'tb.theta0'), ('angle_error', '0')]


def lookup_1d(s, name, breakpoints, table, position):
    """1-D Lookup Table (Lookup_n-D), as saved by R2026b in inv_psm.slx (linear interpolation)."""
    sid = s.sids()
    xml = (f'  <Block BlockType="Lookup_n-D" Name="{esc_attr(name)}" SID="{sid}">\n'
           '    <PortCounts in="1" out="1"/>\n'
           + P('Position', position) + P('ZOrder', s.z())
           + P('InputPortMap', 'u0') + P('NumberOfTableDimensions', '1')
           + P('BreakpointsForDimension1', breakpoints) + P('Table', table)
           + P('InternalRulePriority', 'Speed') + P('RndMeth', 'Simplest')
           + '  </Block>\n')
    return s.add(xml, sid)


def sl2ps_filtered(s, name, position, unit, tau):
    """Simulink-PS Converter with a first-order input filter (derivative computed by Simscape): needed by
    the velocity source, whose input derivative drives the inertia of the machine."""
    sid = s.sids()
    idata = [('ContentPreviewEnabled', 'on'), ('PhysicalDomain', 'network_engine_domain'),
             ('SubClassName', 'ps_input'), ('LeftPortType', 'input'), ('RightPortType', 'output'),
             ('PseudoPeriodic', 'off'), ('Frequencies', '[]'), ('NoiseDistribution', 'none'),
             ('NoiseParameters', '[]'), ('Unit', unit), ('AffineConversion', 'off'),
             ('FilteringAndDerivatives', 'filter'), ('SimscapeFilterOrder', '1'),
             ('InputFilterTimeConstant', tau), ('UdotUserProvided', '0')]
    xml = (f'  <Block BlockType="Reference" Name="{esc_attr(name)}" SID="{sid}">\n'
           '    <PortCounts in="1" rconn="1"/>\n'
           + P('Position', position) + P('ZOrder', s.z())
           + P('BackgroundColor', 'automatic') + P('LibraryVersion', NESL_VERSION)
           + P('SourceBlock', 'nesl_utility/Simulink-PS\nConverter') + P('SourceType', 'Simulink-PS\nConverter')
           + '    <InstanceData>\n' + ''.join(P_indent(k, v, '      ') for k, v in idata)
           + '    </InstanceData>\n  </Block>\n')
    return s.add(xml, sid)


def open_circuit(s, name, position):
    return s.ssc(name, 'fl_lib/Electrical/Electrical Elements/Open Circuit',
                 'foundation.electrical.elements.open_circuit', 'open_circuit', [],
                 [('lconn', 1, 'V')], position, mirror=True, variables=[('v', 'off', 'None', '0', 'V')])


def velocity_source(s, name, position):
    """Ideal Angular Velocity Source: R (lconn1) - C (rconn2) at the speed of the input S (rconn1)."""
    return s.ssc(name, 'fl_lib/Mechanical/Mechanical Sources/Ideal Angular\nVelocity Source',
                 'foundation.mechanical.sources.angular_velocity', 'angular_velocity', [],
                 [('lconn', 1, 'R'), ('rconn', 1, 'S'), ('rconn', 2, 'C')], position)


def rotational_reference(s, name, position):
    return s.ssc(name, 'fl_lib/Mechanical/Rotational Elements/Mechanical\nRotational Reference',
                 'foundation.mechanical.rotational.reference', 'reference', [],
                 [('lconn', 1, 'W')], position, rotation='270', mirror=True, name_location='right')


def build(out_dir):
    sids = SidPool()
    s = System(sids, location='[40, 40, 1500, 860]', zoom='100')

    # ---- time, references
    clk = s.clock('t', pos(40, 60, 30, 30))
    lk_en = lookup_1d(s, 'enable', 'tb.prof.t', 'tb.prof.enable', pos(130, 125, 65, 40))
    lk_ref = lookup_1d(s, 'reference', 'tb.prof.t', 'tb.prof.ref', pos(130, 185, 65, 40))
    lk_w = lookup_1d(s, 'speed', 'tb.prof.t', 'tb.prof.w_mech', pos(130, 600, 65, 40))
    mux_ref = s.mux(2, pos(250, 130, 5, 90), name='ref')

    # ---- inverter
    inv = s.library_ref('pmsm_inverter', INV_SRC, {'in': 3, 'out': 2, 'lconn': 2, 'rconn': 3},
                        pos(420, 90, 220, 200), [('p', 'p_inv')])
    s.sig(f'{clk}#out:1', [f'{inv}#in:1', f'{lk_en}#in:1', f'{lk_ref}#in:1', f'{lk_w}#in:1'])
    s.sig(f'{lk_en}#out:1', f'{mux_ref}#in:1')
    s.sig(f'{lk_ref}#out:1', f'{mux_ref}#in:2')
    s.sig(f'{mux_ref}#out:1', f'{inv}#in:2', name='ref')

    # ---- DC link: source with series resistance, reference and solver at the negative pole
    vdc = sb.dc_voltage(s, 'Vdc', pos(230, 380, 30, 50), 'tb.Vdc', rotation='90')
    rdc = sb.resistor(s, 'Rdc', pos(300, 330, 40, 20), 'tb.Rdc')
    gnd = sb.electrical_reference(s, 'Electrical Reference', pos(230, 500, 30, 30))
    solver = s.solver_configuration('Solver Configuration', pos(320, 470, 50, 32), sample_time='tb.tc',
                                    nonlin_iter='tb.nonlin_iter', mode_iter='tb.mode_iter')
    s.conn(f'{vdc}#lconn:1', f'{rdc}#lconn:1')
    s.conn(f'{rdc}#rconn:1', f'{inv}#lconn:1')
    s.conn(f'{vdc}#rconn:1', f'{inv}#lconn:2', f'{gnd}#lconn:1', f'{solver}#rconn:1')

    # ---- machine: magnet flux input, star point open, shaft on the velocity source
    pmsm = s.library_ref('pmsm', PMSM_SRC, {'out': 1, 'lconn': 5, 'rconn': 1}, pos(800, 90, 170, 226),
                         PMSM_MASK, lib_version='3.0')
    for k in (1, 2, 3):
        s.conn(f'{inv}#rconn:{k}', f'{pmsm}#lconn:{k}')
    c_psi = s.constant('psi_m', 'mach.psi_m', pos(640, 360, 50, 30))
    ps_psi = s.sl2ps('psi_m_ps', pos(720, 365, 20, 20), unit='V*s')
    s.sig(f'{c_psi}#out:1', f'{ps_psi}#in:1')
    s.conn(f'{ps_psi}#rconn:1', f'{pmsm}#lconn:4')
    oc = open_circuit(s, 'star_point_open', pos(740, 420, 20, 10))
    s.conn(f'{oc}#lconn:1', f'{pmsm}#lconn:5')
    vs = velocity_source(s, 'speed_source', pos(1060, 180, 40, 40))
    rr = rotational_reference(s, 'shaft_reference', pos(1120, 260, 20, 20))
    ps_w = sl2ps_filtered(s, 'speed_ps', pos(1000, 605, 20, 20), 'rad/s', 'tb.w_tau')
    s.sig(f'{lk_w}#out:1', f'{ps_w}#in:1', name='w_mech')
    s.conn(f'{pmsm}#rconn:1', f'{vs}#lconn:1')
    s.conn(f'{ps_w}#rconn:1', f'{vs}#rconn:1')
    s.conn(f'{vs}#rconn:2', f'{rr}#lconn:1')

    # ---- encoder angle and logging
    bsel = s.bus_selector(MACH_SIGNALS, pos(1020, 340, 5, 160))
    s.sig(f'{pmsm}#out:1', f'{bsel}#in:1', name='motor_data')
    mux_m = s.mux(len(MACH_SIGNALS), pos(1120, 340, 5, 160), name='mach')
    s.sig(f'{bsel}#out:1', [f'{inv}#in:3', f'{mux_m}#in:1'], name='enc')
    for k in range(2, len(MACH_SIGNALS) + 1):
        s.sig(f'{bsel}#out:{k}', f'{mux_m}#in:{k}')
    tw_mach = s.to_workspace('mach_log', 'mach_log', pos(1180, 405, 100, 30), sample_time='tb.ts_log')
    s.sig(f'{mux_m}#out:1', f'{tw_mach}#in:1')
    tw_m = s.to_workspace('m_log', 'm_log', pos(700, 470, 100, 30), sample_time='tb.ts_log')
    tw_c = s.to_workspace('ctrl_log', 'ctrl_log', pos(700, 530, 100, 30), sample_time='tb.ts_log')
    s.sig(f'{inv}#out:1', f'{tw_m}#in:1', name='m')
    s.sig(f'{inv}#out:2', f'{tw_c}#in:1', name='ctrl_log')

    path = os.path.join(out_dir, MODEL + '.slx')
    write_slx(path, s, is_library=False, model_name=MODEL,
              solver_xml=solver_model('tb.t_stop', 'auto'), dataio_xml=DATAIO_MODEL,
              description=('Test bench of library/masked_models/pmsm_inverter: the block '
                           'pmsm_inverter_dqctrl_mod1 between a DC source and the library PMSM, whose shaft '
                           'runs at the speed of an ideal velocity source. Run pmsm_inverter_test_run.m '
                           '(cases and parameters in pmsm_inverter_test_param.m: p_inv, mach, tb). Generated '
                           'by tools/make_test_pmsm_inverter.py.'))
    return path


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(FOLDER, 'test')
    path = build(out_dir)
    print('%8d  %s' % (os.path.getsize(path), path))


if __name__ == '__main__':
    main()
