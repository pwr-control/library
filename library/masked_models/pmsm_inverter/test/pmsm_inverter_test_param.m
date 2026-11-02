function [tb, p_inv, mach] = pmsm_inverter_test_param(name)
%PMSM_INVERTER_TEST_PARAM  Parameters of test_pmsm_inverter.slx for one test case.
%
%   [tb, p_inv, mach] = pmsm_inverter_test_param(name)
%
%   p_inv  parameter struct of the inverter block (mask parameter p of pmsm_inverter_dqctrl_mod1), from
%          pmsm_inverter_param_example (one 267 kW system of the wind generator of inv_psm)
%   mach   machine data, also from pmsm_inverter_param_example (mask of the library PMSM of the model)
%   tb     test bench: step, solver, DC source, initial state of the machine, profiles of the case
%
%   Cases (name):
%     'generator_bemf'   (default) L filter, torque curve of the speed (generator, p.ctrl.mode = 2), angle
%                        from the back-EMF observer; the shaft turns at 0.5 pu, the bridge starts at 50 ms
%                        on the turning machine (flying start), then the speed rises to 1 pu
%     'generator_ekf'    same with the extended Kalman filter
%     'torque_steps_lc'  LC filter, torque reference (mode 0), angle from the encoder, 0.8 pu, torque steps
%                        0, -0.5, +0.5, -1 pu
%
%   To run one case by hand: [tb, p_inv, mach] = pmsm_inverter_test_param('generator_ekf'); then open
%   test_pmsm_inverter.slx and run it (stop time tb.t_stop). pmsm_inverter_test_run.m runs all the cases
%   and checks them.

    if nargin < 1 || isempty(name)
        name = 'generator_bemf';
    end
    tb.name = name;

    % ---- step, solver, logging
    tb.tc          = 1e-6;          % [s] step of the Simscape local solver = p_inv.pwm.tc
    tb.nonlin_iter = 3;             % fixed-cost nonlinear iterations of the local solver (as inv_psm)
    tb.mode_iter   = 2;             % fixed-cost mode iterations
    tb.ts_log      = 20e-6;         % [s] sample time of the To Workspace blocks

    % ---- DC link: stiff source with a small series resistance (the block has its own capacitor)
    tb.Vdc = 1070;                  % [V]
    tb.Rdc = 0.05;                  % [Ohm]

    % ---- case
    switch name
        case {'generator_bemf', 'generator_ekf'}
            filter = 'L';
            tb.t_stop = 0.7;
            % speed [pu of the rated speed]: 0.5 pu, ramp to 1 pu between 0.15 s and 0.45 s
            t_w = [0 0.15 0.45];   w_pu = [0.5 0.5 1.0];
            % ref = [enable; scale of the torque curve]: enabled from the start, the block keeps the gates
            % off until p.ctrl.t_enable (the observers lock on the back-EMF meanwhile)
            t_e = 0;  en = 1;
            t_r = 0;  r = 1;
        case 'torque_steps_lc'
            filter = 'LC';
            tb.t_stop = 0.4;
            t_w = 0;  w_pu = 0.8;
            t_e = 0;  en = 1;
            t_r = [0 0.1 0.2 0.3];  r = [0 -0.5 0.5 -1];     % torque [pu], positive = motor
        otherwise
            error('pmsm_inverter_test_param: unknown case ''%s''', name);
    end

    % ---- inverter and machine
    [p_inv, mach] = pmsm_inverter_param_example(tb.tc, filter);
    p_inv.ctrl.t_enable = 0.05;                  % [s] gates off before (flying start)
    switch name
        case 'generator_bemf'
            p_inv.ctrl.mode = 2;  p_inv.ctrl.angle_src = 1;
            p_inv.ctrl.torque_slew = 10;         % [pu/s] faster than the 2 pu/s of inv_psm: short test
        case 'generator_ekf'
            p_inv.ctrl.mode = 2;  p_inv.ctrl.angle_src = 2;
            p_inv.ctrl.torque_slew = 10;
        case 'torque_steps_lc'
            p_inv.ctrl.mode = 0;  p_inv.ctrl.angle_src = 0;
            p_inv.ctrl.torque_slew = 100;        % steps (rise limited by the current loop)
    end

    % ---- machine initial state: angle 0 at t = 0, speed of the profile (the shaft is a velocity source)
    tb.theta0     = 0;                           % [rad] electrical angle (d axis on phase u)
    tb.omega_e0   = w_pu(1)*mach.omega_b;        % [rad/s] electrical speed at t = 0
    tb.w_tau      = 0.01;                        % [s] filter of the speed input of the velocity source

    % ---- profiles on one time vector (the three lookup tables share the breakpoints tb.prof.t)
    t_end = tb.t_stop + 1;
    [t1, y1] = local_profile(t_w, w_pu, t_end, false);       % ramps
    [t2, y2] = local_profile(t_e, en, t_end, true);          % steps
    [t3, y3] = local_profile(t_r, r, t_end, true);
    tb.prof.t       = unique([t1 t2 t3]);
    tb.prof.w_pu    = interp1(t1, y1, tb.prof.t);
    tb.prof.w_mech  = tb.prof.w_pu*mach.omega_m_bez;          % [rad/s] mechanical
    tb.prof.enable  = interp1(t2, y2, tb.prof.t);
    tb.prof.ref     = interp1(t3, y3, tb.prof.t);
    tb.steps.t      = t_r;                                    % for the checks
    tb.steps.ref    = r;
end

% ------------------------------------------------------------------------------------------------------
function [t, y] = local_profile(tk, yk, t_end, steps)
%LOCAL_PROFILE  Breakpoints of a profile: value yk(k) from tk(k) (tk(1) = 0), held after the last point.
%   steps = true: jumps (100 us ramps, the breakpoints of a lookup table must increase strictly);
%   steps = false: linear ramps between the points.
    dt = 1e-4;
    if steps
        t = 0;  y = yk(1);
        for k = 2:numel(tk)
            t = [t, tk(k), tk(k) + dt];          %#ok<AGROW>
            y = [y, yk(k-1), yk(k)];             %#ok<AGROW>
        end
    else
        t = tk;  y = yk;
    end
    t = [t, t_end];
    y = [y, yk(end)];
    if numel(t) == 2 && t(1) == t(2)
        t(2) = t(1) + 1;
    end
end
