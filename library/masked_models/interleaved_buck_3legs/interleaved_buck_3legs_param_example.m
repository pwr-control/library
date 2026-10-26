function p = interleaved_buck_3legs_param_example(tc)
%INTERLEAVED_BUCK_3LEGS_PARAM_EXAMPLE  Parameter struct p of interleaved_buck_3legs/interleaved_buck_3legs_mod1.
%
%   p = interleaved_buck_3legs_param_example()        tc = 625 ns
%   p = interleaved_buck_3legs_param_example(tc)      other sample time of the block (= step of the Simscape local solver)
%
%   The three-leg interleaved buck of interleaved_buck.slx of pwr-control/modelization-and-control
%   (foundations_of_power_electronics/interleaved_buck_converter, numbers in its init_model.m, whose param.buck is
%   this struct): 660 V battery to a 200 V DC bus, 750 A (150 kW, 250 A per leg, duty 0.303; Infineon FF450R17ME4
%   half bridges), fpwm = 3 kHz per leg with double update (control at 6 kHz, ts = 166.7 us; the output sees 9 kHz),
%   dead time 3 us, 0.8 mH per leg (58 A peak-peak of ripple per leg, 23 % of the leg current, 7.6 A peak-peak on
%   the sum at the nominal duty, 22.9 A worst case over the duty), output capacitor 7.5 mF (112 Hz with L/3, zeta
%   0.35 at full load: sized on the LC resonance, f0 <= f_c_i/2, the 0.2 % ripple specification alone would give
%   0.8 mF), DC link 7.2 mF. Control: output voltage PI -> total current reference -> one PI per leg on the leg
%   current sampled at the extremes of its own carrier (average value). Gains from the crossover targets, 225 Hz
%   for the current loops (fs/26.7: phase margin about 58 deg on leg 1 with 1.5 ts of delay, 45 deg on legs 2 and 3
%   with 2.5 ts: their samples are up to 2/3 ts older and their duties are loaded at their own carrier extreme) and
%   60 Hz for the voltage loop at nominal load (about 100 Hz without load). Mode 0 (default): output voltage
%   reference 1 pu reached in 50 ms. Previous version (PR #19): 750 V -> 400 V, 250 kW, 4 kHz, 1 mH, 3.6 mF, 300 Hz.
%
%   p.hw    parameters of the Simscape block buck_ssc.interleaved_buck_3legs, same names and units
%   p.pwm   carriers and gates, p.ctrl control: see the header of private/interleaved_buck_3legs_ctrl_pwm.m

    if nargin < 1
        tc = 1/(2*3e3)/200;                     % 0.833 us: ts/200 at 3 kHz with double update
    end

    % ------------------------------------------------------------------ operating point
    udc_nom   = 660;                            % [V]  DC link (battery)
    u_out_nom = 200;                            % [V]  output
    i_out_nom = 750;                            % [A]  output current (total of the three legs)
    pwr_nom   = u_out_nom*i_out_nom;            % [W]  150 kW
    n_legs    = 3;
    ubez      = u_out_nom;                      % [V]  base of the output voltage
    ibez      = i_out_nom;                      % [A]  750 A, base of the currents (total: a leg carries 1/3 pu)
    fpwm      = 3e3;                            % [Hz] carrier of each leg
    ts        = 1/(2*fpwm);                     % [s]  control period, double update

    % ------------------------------------------------------------------ p.hw: power stage (buck_ssc.interleaved_buck_3legs)
    % switches: numerical switch + antiparallel diode, Ron = Vce/I of the FF450R17ME4 at 250 A, 125 degC (conduction drop only)
    p.hw.Vth     = 2.5;                         % [V]   gate threshold
    p.hw.Ron     = 7e-3;                        % [Ohm]
    p.hw.Goff    = 1e-6;                        % [1/Ohm]
    % DC link
    p.hw.Cdc     = 7.2e-3;                      % [F]   0.3 V of ripple at 9 kHz, 72 A rms
    p.hw.Rdc     = 1e-3;                        % [Ohm] ESR
    p.hw.Vdc0    = udc_nom;                     % [V]   initial DC-link voltage: the run starts at the operating point
    % legs: one separate inductor per leg (a coupled three-limb reactor is wrong for the in-phase DC currents of the legs)
    p.hw.L       = 0.8e-3;                      % [H]   58 A peak-peak of ripple per leg at D = 0.303 (25 % criterion: L_min 0.743 mH)
    p.hw.RL      = 6e-3;                        % [Ohm] 375 W per leg at 250 A, 0.75 % of Pnom
    p.hw.kL      = [1 1 1];                     %       per-leg factors of L (mismatch studies)
    p.hw.kRL     = [1 1 1];                     %       per-leg factors of RL
    % output capacitor
    p.hw.Cout    = 7.5e-3;                      % [F]   112 Hz with L/3 (= f_c_i/2); 14 mV of ripple at 9 kHz, 42 mV worst duty
    p.hw.RCout   = 3e-3/3;                      % [Ohm] ESR
    % normalization of the measurements
    p.hw.ubez    = ubez;                        % [V]
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
    p.pwm.m_up          = 0.98;                 %       limits of the duty
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
    p.ctrl.mode           = 0;                  %       0 output voltage loop, 1 total current reference
    p.ctrl.u_out_ref      = 1;                  % [pu]  200 V
    p.ctrl.u_ref_slew     = 20;                 % [pu/s] ramp of the reference: 1 pu in 50 ms
    p.ctrl.i_ref          = 1;                  % [pu]  mode 1: total current reference (750 A)
    p.ctrl.t_ref          = 0;                  % [s]   step time of i_ref
    p.ctrl.i_ref_slew     = 20;                 % [pu/s]
    p.ctrl.i_lim          = 1.2;                % [pu]  limit of the total current reference (900 A, 300 A per leg)
    % loops (same closed-form design as private/buck_ctrl_param.m of the model): the plant of the per-leg current loop,
    % duty -> i_Lk (pu of ibez), is an integrator of gain k_i = udc_nom/(L*ibez) = 1100 1/s; kp_i = 2*pi*f_c_i/k_i,
    % ki_i = kp_i*2*pi*f_c_i/5 (PI zero at f_c_i/5). The plant of the voltage loop at nominal load is the output
    % capacitor with the load, Zc = k_u/(s + a) with k_u = ibez/(Cout*ubez) = 500 1/s and a = 1/(R_load*Cout) (80 Hz),
    % behind the closed common-mode current loop T_i (with the same duty on all legs the capacitor reacts: the leg
    % current per unit duty is k_i/(s + RL/L + 3*k_v*Zc), k_v = ubez/(L*ibez), and |T_i| is about 0.75 at the voltage
    % crossover): kp_u from |PI*T_i*Zc| = 1 at w_u, ki_u = kp_u*w_u/5. The LC resonance of the common mode, 112 Hz,
    % must stay below f_c_i/2 (the current loops damp it; above them they cross the undamped resonance a second time
    % at light load). Linear check (discrete model at ts, 2026-10-26): current loops crossover 234 Hz on the inductor
    % alone (276 Hz in common mode) with 59 deg of phase margin on leg 1, 43 deg and 7.4 dB of gain margin on legs 2-3
    % at nominal load (40 deg at no load); voltage loop 62 Hz / 123 deg at nominal load, 143 Hz / 73 deg at no load;
    % 6.9 % dip on a +0.2 pu load step recovered within 1 % in 44 ms
    f_c_i = 225;                                % [Hz] crossover target of the current loops (fs/26.7 at fs = 6 kHz)
    f_c_u = 60;                                 % [Hz] crossover target of the voltage loop at nominal load
    k_i = udc_nom/(p.hw.L*ibez);                % [1/s]
    k_u = ibez/(p.hw.Cout*ubez);                % [1/s]
    k_v = ubez/(p.hw.L*ibez);                   % [1/s]
    a   = 1/((u_out_nom^2/pwr_nom)*p.hw.Cout);  % [1/s] load corner at nominal power
    p.ctrl.kp_i = 2*pi*f_c_i/k_i;               % [pu/pu] 1.285: duty per pu of leg current error
    p.ctrl.ki_i = p.ctrl.kp_i*2*pi*f_c_i/5;     % [1/s]   363
    s_u  = 1i*2*pi*f_c_u;
    Zc   = k_u/(s_u + a);
    G_cm = k_i/(s_u + p.hw.RL/p.hw.L + n_legs*k_v*Zc);
    L_cm = (p.ctrl.kp_i + p.ctrl.ki_i/s_u)*G_cm*exp(-1.5*ts*s_u);
    T_i  = L_cm/(1 + L_cm);
    p.ctrl.kp_u = 1/(abs(T_i*Zc)*sqrt(1 + 1/25));   % [pu/pu] 1.627: pu of total current per pu of voltage error
    p.ctrl.ki_u = p.ctrl.kp_u*2*pi*f_c_u/5;     % [1/s]   123
end
