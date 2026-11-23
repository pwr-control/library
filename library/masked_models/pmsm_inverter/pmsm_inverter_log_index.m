function k = pmsm_inverter_log_index()
%PMSM_INVERTER_LOG_INDEX  Indices of the output ctrl_log (44x1) of the block pmsm_inverter_dqctrl_mod1.
%
%   k = pmsm_inverter_log_index;
%   theta = log(:, k.theta);                 % e.g. with log = squeeze(out.ctrl_log.Data)' (samples x 44)
%
%   Values held between two control triggers, apart from t_loc, ramp and trgo (every step tc).
%   Per unit: currents of p.hw.ibez, voltages of p.hw.ubez (u_mod: of vdc/sqrt(3)), flux of
%   p.hw.ubez/p.ctrl.omega_b, speed of p.ctrl.omega_b (electrical), torque of 3/2*pp*psi_base*ibez.
%   Same list as the header of private/pmsm_dq_ctrl_pwm.m.

    k.t_loc      = 1;         % local time [s]
    k.ramp       = 2;         % carrier, 0..1
    k.trgo       = 3;         % trigger flag of the control
    k.corr       = 4;         % correction of the local clock
    k.on         = 5;         % 1: bridge on (gates switching)
    k.src        = 6;         % angle source in use: 0 encoder, 1 back-EMF observer, 2 EKF
    k.theta      = 7;         % angle used by the control [rad]
    k.omega      = 8;         % speed used by the control [pu]
    k.w_flt      = 9;         % filtered speed (speed PI, torque curve) [pu]
    k.enc_theta  = 10;        % encoder tracking loop: angle [rad]
    k.enc_omega  = 11;        %                        speed [pu]
    k.bemf_theta = 12;        % back-EMF observer: angle [rad]
    k.bemf_omega = 13;        %                    speed [pu]
    k.ekf_theta  = 14;        % EKF: angle [rad]
    k.ekf_omega  = 15;        %      speed [pu]
    k.bemf_psi   = [16 17];   % active flux alpha/beta of the back-EMF observer [pu]
    k.ekf_psi    = [18 19];   % active flux alpha/beta of the EKF [pu]
    k.i_ab       = [20 21];   % feedback current alpha/beta (output current i2) [pu]
    k.id         = 22;        % i_d in the control frame [pu]
    k.iq         = 23;        % i_q in the control frame [pu]
    k.T_ref      = 24;        % torque reference after limit and slew [pu]
    k.id_ref     = 25;        % i_d reference [pu]
    k.iq_ref     = 26;        % i_q reference [pu]
    k.u_dq       = [27 28];   % u_d/u_q after the limiter [pu]
    k.clip       = 29;        % clip flag of the current PI
    k.u_mod      = [30 31];   % u_alpha/u_beta to the modulator [pu of vdc/sqrt(3)]
    k.duty       = 32:34;     % duties of the three legs
    k.vdc        = 35;        % DC-link voltage [pu of p.hw.udc_nom]
    k.u_obs      = [36 37];   % voltage used by the observers alpha/beta [pu]
    k.T_est      = 38;        % torque from the measured currents and the model [pu]
    k.w_ref      = 39;        % speed reference after its filter [pu]
    k.bemf_err   = 40;        % angle error of the back-EMF observer with respect to the encoder [rad]
    k.ekf_err    = 41;        % angle error of the EKF with respect to the encoder [rad]
    k.ekf_psi_abs  = 42;      % active flux magnitude of the EKF [pu]
    k.bemf_psi_abs = 43;      % active flux magnitude of the back-EMF observer [pu]
    k.ekf_innov  = 44;        % magnitude of the EKF innovation [pu]
    k.n          = 44;        % size of ctrl_log
end
