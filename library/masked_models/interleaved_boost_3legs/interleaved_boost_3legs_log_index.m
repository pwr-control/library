function idx = interleaved_boost_3legs_log_index()
%INTERLEAVED_BOOST_3LEGS_LOG_INDEX  Indices of the ctrl_log output [30x1] of interleaved_boost_3legs/interleaved_boost_3legs_mod1.
%
%   idx = interleaved_boost_3legs_log_index()
%
%   Example, with ctrl_log logged as a timeseries "log_boost":
%       idx = interleaved_boost_3legs_log_index();
%       plot(log_boost.Time, log_boost.Data(:, [idx.i_L1 idx.i_L2 idx.i_L3 idx.i_leg_ref]))
%
%   Every step: t_loc, ramp_1..3, trgo_1..3, m_1..3, enable, i_hold_1..3. The others are updated at the control step
%   (rising edge of trgo_1) and held in between. Currents in pu of ibez (total base: a leg carries 1/3 pu at nominal
%   load; positive from the battery into the legs, the boost direction), u_in in pu of uin_nom, udc in pu of udc_nom
%   (p.hw of the block). Same layout as interleaved_buck_3legs_log_index.m: 13 is the input voltage instead of the
%   output voltage, 15 the DC-link voltage reference, 20-22 the duties of the lower switches computed by the loops and
%   23-25 the duties applied to the modulator in the buck convention, m = 1 - d.

    idx.t_loc     = 1;    % [s]   local time of the block
    idx.ramp_1    = 2;    %       carrier of leg 1, triangle 0..1
    idx.ramp_2    = 3;    %       carrier of leg 2 (shifted by carrier_phase(2))
    idx.ramp_3    = 4;    %       carrier of leg 3
    idx.trgo_1    = 5;    %       TRGO flag of carrier 1 (the control trigger)
    idx.trgo_2    = 6;    %       TRGO flag of carrier 2 (sample of i_L2, shadow load of m_2)
    idx.trgo_3    = 7;    %       TRGO flag of carrier 3
    idx.corr      = 8;    %       correction of the local clock (alignment PI)
    idx.i_L1      = 9;    % [pu]  acquired current of leg 1 used by the control (sampled at its own carrier extreme, one control step behind)
    idx.i_L2      = 10;   % [pu]  leg 2
    idx.i_L3      = 11;   % [pu]  leg 3
    idx.i_sum     = 12;   % [pu]  sum of the three acquired currents
    idx.u_in      = 13;   % [pu]  acquired input (battery) voltage (one control step behind, quantized)
    idx.udc       = 14;   % [pu]  acquired DC-link voltage (the regulated voltage)
    idx.udc_ref   = 15;   % [pu]  ramped DC-link voltage reference (mode 0, else 0)
    idx.e_u       = 16;   % [pu]  error of the voltage loop (mode 0, else 0)
    idx.i_ref     = 17;   % [pu]  total input current reference (output of the voltage PI, or the ramped p.ctrl.i_ref in mode 1)
    idx.sat_u     = 18;   %       saturation flag of the voltage PI
    idx.i_leg_ref = 19;   % [pu]  current reference of each leg, i_ref/3
    idx.d_cmd_1   = 20;   %       duty of the lower (boost) switch of leg 1 computed at the control step
    idx.d_cmd_2   = 21;   %       leg 2
    idx.d_cmd_3   = 22;   %       leg 3
    idx.m_1       = 23;   %       duty applied to leg 1 in the convention of the modulator, m_1 = 1 - d_1 (loaded at the control step)
    idx.m_2       = 24;   %       leg 2 (loaded at the extremes of carrier 2)
    idx.m_3       = 25;   %       leg 3
    idx.enable    = 26;   %       gates enabled (from the first control step with t_master >= p.pwm.t_enable)
    idx.mode      = 27;   %       p.ctrl.mode
    idx.i_hold_1  = 28;   % [pu]  current of leg 1 held at the extremes of its carrier (every step)
    idx.i_hold_2  = 29;   % [pu]  leg 2
    idx.i_hold_3  = 30;   % [pu]  leg 3
end
