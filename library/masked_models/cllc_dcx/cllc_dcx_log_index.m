function idx = cllc_dcx_log_index()
%CLLC_DCX_LOG_INDEX  Indices of the ctrl_log output [24x1] of cllc_dcx/cllc_dcx_mod1 (cllc_dcx_ctrl_pwm).
%
%   idx = cllc_dcx_log_index()
%
%   Example, with ctrl_log logged as a timeseries "log_dcx":
%       idx = cllc_dcx_log_index();
%       plot(log_dcx.Time, log_dcx.Data(:, idx.phi))
%
%   Every step: t_loc, ramp1, trgo, f_c, ramp2, state_1, state_2, enable, i_r1, i_r2. The others are updated at
%   the control trigger and held in between. Currents and voltages are in pu of idc_nom and udc_nom of p.hw.

    idx.t_loc   = 1;    % [s]   local time of the block
    idx.ramp1   = 2;    %       carrier of bridge 1, triangle 0..1
    idx.trgo    = 3;    %       control trigger flag
    idx.corr    = 4;    %       correction of the local clock (alignment PI)
    idx.f_c     = 5;    % [Hz]  switching frequency of this step (sweeps during the soft start)
    idx.phi     = 6;    % [rad] phase of bridge 2 after bridge 1 (positive: bridge 2 lags)
    idx.ramp2   = 7;    %       carrier of bridge 2
    idx.state_1 = 8;    %       bridge 1: +1 pair (1a+, 1b-) on, -1 pair (1a-, 1b+) on, 0 both off
    idx.state_2 = 9;    %       bridge 2: +1 pair (2a+, 2b-) on, -1 pair (2a-, 2b+) on, 0 both off
    idx.u_dc1   = 10;   % [pu]  acquired (period average, quantized) terminal voltage of side 1
    idx.i_dc1   = 11;   % [pu]  acquired terminal current of side 1, positive into dc1+
    idx.u_dc2   = 12;   % [pu]  acquired terminal voltage of side 2
    idx.i_dc2   = 13;   % [pu]  acquired terminal current of side 2, positive out of dc2+
    idx.u_meas  = 14;   % [pu]  regulated voltage (u_dc2, or u_dc1 with p.ctrl.side = 1)
    idx.i_meas  = 15;   % [pu]  regulated current: the current rectified by the bridge into the DC link of the
                        %       regulated side (terminal current plus DC-link capacitor current)
    idx.u_ref   = 16;   % [pu]  voltage reference (mode 2, else 0)
    idx.i_ref   = 17;   % [pu]  current reference (mode 1: p.ctrl.i_ref, mode 2: output of the voltage PI)
    idx.clip_u  = 18;   %       clip flag of the voltage PI
    idx.phi_pi  = 19;   % [rad] output of the current PI (before the sign of the tank reactance and of the side)
    idx.clip_i  = 20;   %       clip flag of the current PI
    idx.mode    = 21;   %       p.ctrl.mode
    idx.enable  = 22;   %       gates enabled (t_master >= p.pwm.t_enable)
    idx.i_r1    = 23;   % [pu]  tank current of side 1 (M(5), one tc behind), out of midpoint 1a into the tank
    idx.i_r2    = 24;   % [pu]  tank current of side 2 (M(6), one tc behind), out of the secondary into midpoint 2a
end
