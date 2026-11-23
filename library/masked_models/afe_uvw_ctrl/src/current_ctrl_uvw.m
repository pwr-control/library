function [u_abg, i_abc_ref, is_xe] = current_ctrl_uvw(i_xi_ref, i_stack_ref, is_abc, theta, p)
%CURRENT_CTRL_UVW  Per-phase resonant current control of the AFE stack current (uvw frame).
%
%   [u_abg, i_abc_ref, is_xe] = current_ctrl_uvw(i_xi_ref, i_stack_ref, is_abc, theta, p)
%
%   MATLAB Function version of the subsystem current_ctrl of the model afe_uvw_three_phase
%   (afe_uvw_ctrl.slx, pwr-control/modelization-and-control). Four steps:
%     1. the current references of the sequence frames become three phase references: the positive
%        sequence (xi_ref, pos_eta_ref) turned by +theta, the negative one (neg_xi, neg_eta) by
%        -theta, summed in alpha/beta and transformed to abc;
%     2. one resonant PI per phase on e = i_ref - i_meas:
%            d = kp*e + ki * s/(s^2 + 2*delta*w*s + w^2) * e
%        with w = p.ictrl.omega_res (the grid pulsation) and the damping delta = p.ictrl.delta_res
%        (0 gives the ideal resonator kp + ki*s/(s^2 + w^2)). The resonator is in state-space form
%        x = [x1; x2], x1' = x2, x2' = -w^2*x1 - 2*delta*w*x2 + ki*e, output x2, and is discretized
%        with the step ts as forward Euler on x1 and backward Euler on x2 (the NEW x1 is used in the
%        update of x2):
%            x1+ = x1 + ts*x2,   x2+ = x2 + ts*(-w^2*x1+ - 2*delta*w*x2 + ki*e).
%        The discrete poles then have |z|^2 = 1 - 2*delta*w*ts: on the unit circle for delta = 0 and
%        inside it for delta > 0, with the resonance at w. The plain forward Euler of the model
%        (Aresd = I + A*ts, Bresd = B*ts, used by this block up to library rev. 02) has instead
%        |z|^2 = 1 - 2*delta*w*ts + (w*ts)^2, i.e. poles OUTSIDE the unit circle when delta < w*ts/2
%        (0.0196 at 125 us): with the model's delta = 0.015 that resonator alone is a growing
%        oscillator and its gain at w is 10.8 instead of ki/(2*delta*w) = 3.7. The loop with the plant
%        was still stable (the plant pulls the poles inside), but the damping now means what it says:
%        delta = 0.005 gives about the same gain at w (11.1 against 10.8) as the model's resonator with
%        0.015, and is the default of afe_uvw_ctrl_param_example.m;
%     3. vector limiter: the three outputs are divided by scale = |u_alpha_beta| of the previous
%        step, limited to [p.ictrl.mag_lim, p.ictrl.mag_scale_max] (the model's "antiwind_up"), so
%        that the voltage vector stays inside the unit circle; then abc -> alpha, beta (the zero
%        sequence of the three outputs is dropped). The model delivers alpha/beta through one Unit
%        Delay (p.ictrl.out_delay = 1 keeps that one-step delay, 0 removes it);
%     4. zero-sequence current control: PI with clamped integrator on p.ictrl.iz_ref - mean(is_abc),
%        output limited to +-p.ictrl.u_z_lim, gives u_gamma.
%
%   Inputs
%     i_xi_ref     positive-sequence xi (active) stack current reference [pu] (from the DC-link control)
%     i_stack_ref  [3x1] [pos_eta; neg_xi; neg_eta] stack current references [pu]
%                        (output of grid_current_sequences_q_ctrl)
%     is_abc       [3x1] stack (converter) phase currents [pu]
%     theta        grid angle of the PLL [rad]
%     p            parameter struct, see afe_uvw_ctrl_param_example.m: p.ts, p.ictrl.*
%
%   Outputs
%     u_abg        [3x1] [u_alpha; u_beta; u_gamma] voltage references for the modulator [pu]
%                        (ualpha_afe, ubeta_afe, ugamma_afe of the model)
%     i_abc_ref    [3x1] phase current references [pu] (isa_ref, isb_ref, isc_ref)
%     is_xe        [2x1] stack current in the positive frame [xi; eta] (id_xi_pu, id_eta_pu), for logging
%
%   States (persistent)
%     x_res   [2x3] resonator states of the three phases (columns a, b, c)
%     u_ab_d  [2x1] alpha/beta output of the previous step (vector limiter and output delay)
%     ui_z    integral state of the zero-sequence PI
%
%   See also grid_current_sequences_q_ctrl, afe_uvw_ctrl_param_example.

    persistent x_res u_ab_d ui_z
    if isempty(x_res)
        x_res = zeros(2, 3);
        u_ab_d = zeros(2, 1);
        ui_z = 0;
    end
    ts = p.ts;
    c = cos(theta);
    s = sin(theta);

    % ---- 1. references: sequence frames -> alpha/beta -> abc
    pos_xi = i_xi_ref;        pos_eta = i_stack_ref(1);
    neg_xi = i_stack_ref(2);  neg_eta = i_stack_ref(3);
    alpha_ref = (pos_xi*c - pos_eta*s) + (neg_xi*c + neg_eta*s);      % positive turned by +theta,
    beta_ref  = (pos_xi*s + pos_eta*c) + (-neg_xi*s + neg_eta*c);     % negative turned by -theta
    i_abc_ref = [alpha_ref;
                 -0.5*alpha_ref + sqrt(3)/2*beta_ref;
                 -0.5*alpha_ref - sqrt(3)/2*beta_ref];

    % ---- 2. resonant PI per phase (forward Euler on x1, backward Euler on x2)
    w = p.ictrl.omega_res;
    kp = p.ictrl.kp;
    ki = p.ictrl.ki;
    delta = p.ictrl.delta_res;
    e = i_abc_ref - is_abc;                                 % [3x1]
    d_abc = kp*e + x_res(2, :)';                            % output: P + resonator state x2
    x1 = x_res(1, :) + ts*x_res(2, :);                      % new x1 ...
    x2 = x_res(2, :) + ts*(-w^2*x1 - 2*delta*w*x_res(2, :) + ki*e');   % ... used in the update of x2
    x_res(1, :) = x1;
    x_res(2, :) = x2;

    % ---- 3. vector limiter on the previous output, abc -> alpha/beta, output delay
    scale = min(max(sqrt(u_ab_d(1)^2 + u_ab_d(2)^2), p.ictrl.mag_lim), p.ictrl.mag_scale_max);
    d_abc = d_abc/scale;
    u_ab = [2/3*(d_abc(1) - 0.5*d_abc(2) - 0.5*d_abc(3));
            1/sqrt(3)*(d_abc(2) - d_abc(3))];
    if p.ictrl.out_delay > 0.5
        u_ab_out = u_ab_d;                                  % as the model: one step late
    else
        u_ab_out = u_ab;
    end
    u_ab_d = u_ab;

    % ---- 4. zero-sequence current control
    iz = (is_abc(1) + is_abc(2) + is_abc(3))/3;
    e_z = p.ictrl.iz_ref - iz;
    up_z = p.ictrl.kp_z*e_z;
    ui_z = ui_z + p.ictrl.ki_z*ts*e_z;
    u_gamma = min(max(up_z + ui_z, -p.ictrl.u_z_lim), p.ictrl.u_z_lim);
    ui_z = u_gamma - up_z;                                  % integrator clamped to the limit

    u_abg = [u_ab_out; u_gamma];

    % ---- stack current in the positive frame, for logging
    is_alpha = 2/3*(is_abc(1) - 0.5*is_abc(2) - 0.5*is_abc(3));
    is_beta  = 1/sqrt(3)*(is_abc(2) - is_abc(3));
    is_xe = [ is_alpha*c + is_beta*s;
             -is_alpha*s + is_beta*c];
end
