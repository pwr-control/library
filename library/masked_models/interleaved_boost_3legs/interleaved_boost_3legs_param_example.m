function p = interleaved_boost_3legs_param_example(tc)
%INTERLEAVED_BOOST_3LEGS_PARAM_EXAMPLE  Parameter struct p of interleaved_boost_3legs/interleaved_boost_3legs_mod1.
%
%   p = interleaved_boost_3legs_param_example()        tc = 833 ns
%   p = interleaved_boost_3legs_param_example(tc)      other sample time of the block (= step of the Simscape local solver)
%
%   The three-leg interleaved boost of interleaved_boost.slx of pwr-control/modelization-and-control
%   (foundations_of_power_electronics/interleaved_boost_converter, numbers in its init_model.m, whose param.boost is
%   this struct): 200 V battery to a 660 V DC link, 750 A of input current (150 kW, 250 A per leg, duty of the lower
%   switch 0.697; Infineon FF450R17ME4 half bridges), fpwm = 3 kHz per leg with double update (control at 6 kHz,
%   ts = 166.7 us; the capacitors see 9 kHz), dead time 3 us. Same hardware as the interleaved buck with the power
%   flow reversed: 0.8 mH per leg (58 A peak-peak of ripple per leg, 23 % of the leg current, 8 A peak-peak on the
%   sum at the nominal duty, 22.9 A worst case over the duty), 7.5 mF across the battery (the battery sits across it,
%   no control role; 0.8 mF would do for the ripple), DC link 7.2 mF (0.34 V of ripple at 9 kHz, 75 A rms; 1.7 mF for
%   0.2 %). Control: DC-link voltage PI -> total input current reference -> one PI per leg on the leg current sampled
%   at the extremes of its own carrier (average value) -> duty of the lower switch, m = 1 - d to the modulator of the
%   buck. Gains from the crossover targets, 225 Hz for the current loops (the plant duty -> leg current is the same
%   integrator udc/L as the buck: same gains, phase margin about 58 deg on leg 1 with 1.5 ts of delay, 45 deg on legs
%   2 and 3 with 2.5 ts) and 40 Hz for the voltage loop at nominal load, a quarter of the right-half-plane zero of the
%   boost (157 Hz at nominal load: 8 dB of gain margin on the zero, 83 deg of phase margin; about 43 Hz without load,
%   where the zero disappears). Mode 0 (default): DC-link voltage reference 1 pu reached in 70 ms from the precharged
%   link (0.303 pu = u_in) without reaching i_lim.
%
%   p.hw    parameters of the Simscape block boost_ssc.interleaved_boost_3legs, same names and units
%   p.pwm   carriers and gates, p.ctrl control: see the header of private/interleaved_boost_3legs_ctrl_pwm.m

    if nargin < 1
        tc = 1/(2*3e3)/200;                     % 0.833 us: ts/200 at 3 kHz with double update
    end

    % ------------------------------------------------------------------ operating point
    uin_nom  = 200;                             % [V]  battery (input)
    udc_nom  = 660;                             % [V]  DC link (output)
    i_in_nom = 750;                             % [A]  input current (total of the three legs)
    pwr_nom  = uin_nom*i_in_nom;                % [W]  150 kW
    n_legs   = 3;
    ibez     = i_in_nom;                        % [A]  750 A, base of the currents (total: a leg carries 1/3 pu)
    fpwm     = 3e3;                             % [Hz] carrier of each leg
    ts       = 1/(2*fpwm);                      % [s]  control period, double update

    % ------------------------------------------------------------------ p.hw: power stage (boost_ssc.interleaved_boost_3legs)
    % switches: numerical switch + antiparallel diode, Ron = Vce/I of the FF450R17ME4 at 250 A, 125 degC (conduction drop only)
    p.hw.Vth     = 2.5;                         % [V]   gate threshold
    p.hw.Ron     = 7e-3;                        % [Ohm]
    p.hw.Goff    = 1e-6;                        % [1/Ohm]
    % input capacitor (battery side)
    p.hw.Cin     = 7.5e-3;                      % [F]   the output capacitor of the buck; 15 mV of ripple at 9 kHz, 42 mV worst duty
    p.hw.RCin    = 3e-3/3;                      % [Ohm] ESR
    p.hw.Vin0    = uin_nom;                     % [V]   initial voltage: the battery is connected
    % legs: one separate inductor per leg (a coupled three-limb reactor is wrong for the in-phase DC currents of the legs)
    p.hw.L       = 0.8e-3;                      % [H]   58 A peak-peak of ripple per leg at D = 0.697 (25 % criterion: L_min 0.743 mH)
    p.hw.RL      = 6e-3;                        % [Ohm] 375 W per leg at 250 A, 0.75 % of Pnom
    p.hw.kL      = [1 1 1];                     %       per-leg factors of L (mismatch studies)
    p.hw.kRL     = [1 1 1];                     %       per-leg factors of RL
    % DC link (the regulated output)
    p.hw.Cdc     = 7.2e-3;                      % [F]   0.34 V of ripple at 9 kHz, 75 A rms
    p.hw.Rdc     = 1e-3;                        % [Ohm] ESR
    p.hw.Vdc0    = uin_nom;                     % [V]   initial DC-link voltage: precharged through the upper diodes to the battery voltage
    % normalization of the measurements
    p.hw.uin_nom = uin_nom;                     % [V]
    p.hw.ibez    = ibez;                        % [A]
    p.hw.udc_nom = udc_nom;                     % [V]

    % ------------------------------------------------------------------ p.pwm: carriers and gates
    p.pwm.tc            = tc;                   % [s]   sample time of the block = local solver step: the switching instants
                                                %       are quantized to tc (ts/200 at 6 kHz)
    p.pwm.fpwm          = fpwm;                 % [Hz]
    p.pwm.carrier_phase = [0 2*pi/3 4*pi/3];    % [rad] interleaving: 2*pi/n_legs between the carriers
    p.pwm.double_update = 1;                    %       control at the bottom and at the top of carrier 1 (6 kHz)
    p.pwm.dead_time     = 3e-6;                 % [s]   between Q1 and Q2 of each leg
    p.pwm.gate_on       = 15;                   % [V]
    p.pwm.gate_off      = -10;                  % [V]
    p.pwm.m_up          = 0.98;                 %       limits of the duty of the lower switch (m = 1 - d stays in the same interval)
    p.pwm.m_low         = 0.02;
    p.pwm.t_enable      = 0;                    % [s]   gates off and loops at rest before this time

    % ------------------------------------------------------------------ p.ctrl: control
    p.ctrl.ts             = ts;                 % [s]   control period, 1/(2*fpwm) with double update
    p.ctrl.k_time         = 1;                  %       local clock = master time
    p.ctrl.kp_align       = 0;                  %       alignment PI of the local clock, off
    p.ctrl.ki_align       = 0;
    p.ctrl.lim_up_align   = 0;
    p.ctrl.lim_down_align = 0;
    p.ctrl.adc_q          = 1/2^11;             % [pu]  11-bit quantization of the acquisitions
    % operating mode and references
    p.ctrl.mode           = 0;                  %       0 DC-link voltage loop, 1 total input current reference
    p.ctrl.udc_ref        = 1;                  % [pu]  660 V
    p.ctrl.udc_ref_init   = uin_nom/udc_nom;    % [pu]  start of the reference ramp, the precharged DC link (0.303 pu)
    p.ctrl.u_ref_slew     = 10;                 % [pu/s] ramp of the reference: 0.303 -> 1 pu in 70 ms (faster ramps saturate i_lim
                                                %       with the nominal load connected: the DC link stores 1.6 kJ at 660 V)
    p.ctrl.i_ref          = 1;                  % [pu]  mode 1: total input current reference (750 A; negative = buck direction)
    p.ctrl.t_ref          = 0;                  % [s]   step time of i_ref
    p.ctrl.i_ref_slew     = 20;                 % [pu/s]
    p.ctrl.i_lim          = 1.2;                % [pu]  limit of the total current reference (900 A, 300 A per leg)
    % loops (same closed-form design as private/boost_ctrl_param.m of the model). Per leg, with i_k positive from the
    % battery into the leg and d_k the duty of the lower switch, L di_k/dt = u_in - RL*i_k - (1 - d_k)*udc: the plant
    % duty -> i_Lk (pu of ibez) is the integrator of gain k_i = udc_nom/(L*ibez) = 1100 1/s, the same as the buck;
    % kp_i = 2*pi*f_c_i/k_i, ki_i = kp_i*2*pi*f_c_i/5 (PI zero at f_c_i/5). With the same duty on the three legs the
    % DC link reacts (common mode): G_cm = [k_i*(s + a1) + n*b*e]/[(s + RL/L)*(s + a1) + n*b*c], a1 = 1/(R_load*Cdc),
    % b = M*udc_nom/(L*ibez), c = M*ibez/(Cdc*udc_nom), e = i_leg/(Cdc*udc_nom), M = 1 - D = u_in/udc, with the
    % resonance M*sqrt(n/(L*Cdc))/(2*pi) = 35 Hz inside the current loops, which damp it at any load. Voltage loop:
    % the DC-link current of a leg is (1 - d_k)*i_k and a current increase is obtained by first increasing d_k, so the
    % plant from the total input current to udc (pu) is k_u*(1 - s/w_z)/(s + 2*a1), k_u = ibez*M/(Cdc*udc_nom) = 47 1/s,
    % w_z = (u_in - 2*RL*i_leg)/(L*i_leg) the right-half-plane zero (157 Hz at nominal load, as 1/i_leg at lighter
    % load, gone at no load), 2*a1 = 15 Hz the load corner (at constant input current the DC-link current falls as
    % 1/udc). The crossover must stay below f_z/4 (the gain does not roll off above the zero: the gain margin is set
    % by kp_u*k_u/w_z). Plant seen by the voltage PI at s = j*w_u: T_i*(c - e/G_cm)/(s + a1), T_i the closed common-
    % mode current loop of leg 1 (1.5 ts of delay); kp_u from |PI*plant| = 1 at w_u, ki_u = kp_u*w_u/5. Linear check
    % (discrete model at ts, 2026-10-26): current loops crossover 234 Hz on the inductor alone (240 Hz in common mode)
    % with 59 deg of phase margin on leg 1, 45 deg and 7.7 dB of gain margin on legs 2-3 (the same at no load);
    % voltage loop 40 Hz / 83 deg with 8.1 dB of gain margin at nominal load, 43 Hz / 78 deg at no load; 2.4 % dip
    % on a +0.2 pu load step recovered within 1 % in 31 ms
    f_c_i = 225;                                % [Hz] crossover target of the current loops (fs/26.7 at fs = 6 kHz)
    f_c_u = 40;                                 % [Hz] crossover target of the voltage loop at nominal load (f_z/4)
    i_leg = pwr_nom/(n_legs*uin_nom);           % [A]  250 A per leg (then with the drop on RL)
    for it = 1:20
        i_leg = pwr_nom/(n_legs*(uin_nom - p.hw.RL*i_leg));
    end
    M      = (uin_nom - p.hw.RL*i_leg)/udc_nom; %      duty of the upper switch at nominal load, 1 - D
    R_load = udc_nom^2/pwr_nom;                 % [Ohm] 2.9 Ohm
    k_i = udc_nom/(p.hw.L*ibez);                % [1/s]
    a1  = 1/(R_load*p.hw.Cdc);                  % [1/s]
    b   = M*udc_nom/(p.hw.L*ibez);              % [1/s]
    c   = M*ibez/(p.hw.Cdc*udc_nom);            % [1/s]
    e   = i_leg/(p.hw.Cdc*udc_nom);             % [1/s]
    p.ctrl.kp_i = 2*pi*f_c_i/k_i;               % [pu/pu] 1.285: duty per pu of leg current error
    p.ctrl.ki_i = p.ctrl.kp_i*2*pi*f_c_i/5;     % [1/s]   363
    s_u  = 1i*2*pi*f_c_u;
    G_cm = (k_i*(s_u + a1) + n_legs*b*e)/((s_u + p.hw.RL/p.hw.L)*(s_u + a1) + n_legs*b*c);
    L_cm = (p.ctrl.kp_i + p.ctrl.ki_i/s_u)*G_cm*exp(-1.5*ts*s_u);
    T_i  = L_cm/(1 + L_cm);
    G_ui = T_i*(c - e/G_cm)/(s_u + a1);         %         total current reference (pu) -> udc (pu) at j*w_u
    p.ctrl.kp_u = 1/(abs(G_ui)*sqrt(1 + 1/25)); % [pu/pu] 5.32: pu of total current per pu of voltage error
    p.ctrl.ki_u = p.ctrl.kp_u*2*pi*f_c_u/5;     % [1/s]   268
end
