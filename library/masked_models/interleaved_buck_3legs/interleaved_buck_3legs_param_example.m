function p = interleaved_buck_3legs_param_example(tc)
%INTERLEAVED_BUCK_3LEGS_PARAM_EXAMPLE  Parameter struct p of interleaved_buck_3legs/interleaved_buck_3legs_mod1.
%
%   p = interleaved_buck_3legs_param_example()        tc = 625 ns
%   p = interleaved_buck_3legs_param_example(tc)      other sample time of the block (= step of the Simscape local solver)
%
%   The three-leg interleaved buck of interleaved_buck.slx of pwr-control/modelization-and-control
%   (foundations_of_power_electronics/interleaved_buck_converter, numbers in its init_model.m, whose param.buck is
%   this struct): 750 V battery to a 400 V DC bus, 250 kW (625 A total, 208 A per leg, duty 0.533), fpwm = 4 kHz per
%   leg with double update (control at 8 kHz, ts = 125 us; the output sees 12 kHz), dead time 3 us, 1 mH per leg
%   (47 A peak-peak of ripple per leg, 22 % of the leg current, 15 A peak-peak on the sum), output capacitor 3.6 mF
%   (145 Hz with L/3, zeta 0.24 at full load), DC link 7.2 mF. Control: output voltage PI -> total current reference
%   -> one PI per leg on the leg current sampled at the extremes of its own carrier (average value). Gains from the
%   crossover targets, 300 Hz for the current loops (phase margin about 58 deg on leg 1 with 1.5 ts of delay, 45 deg on
%   legs 2 and 3 with 2.5 ts: their samples are up to 2/3 ts older and their duties are loaded at their own carrier
%   extreme) and 60 Hz for the voltage loop at nominal load (about 100 Hz without load). Mode 0 (default): output
%   voltage reference 1 pu reached in 50 ms.
%
%   p.hw    parameters of the Simscape block buck_ssc.interleaved_buck_3legs, same names and units
%   p.pwm   carriers and gates, p.ctrl control: see the header of private/interleaved_buck_3legs_ctrl_pwm.m

    if nargin < 1
        tc = 0.625e-6;
    end

    % ------------------------------------------------------------------ operating point
    pwr_nom   = 250e3;                          % [W]  nominal power
    udc_nom   = 750;                            % [V]  DC link (battery)
    u_out_nom = 400;                            % [V]  output
    n_legs    = 3;
    ubez      = u_out_nom;                      % [V]  base of the output voltage
    ibez      = pwr_nom/u_out_nom;              % [A]  625 A, base of the currents (total: a leg carries 1/3 pu)
    fpwm      = 4e3;                            % [Hz] carrier of each leg
    ts        = 1/(2*fpwm);                     % [s]  control period, double update

    % ------------------------------------------------------------------ p.hw: power stage (buck_ssc.interleaved_buck_3legs)
    % switches: numerical switch + antiparallel diode, Ron about Vce_sat/I of a 1200 V module at 200 A (conduction drop only)
    p.hw.Vth     = 2.5;                         % [V]   gate threshold
    p.hw.Ron     = 1.5e-3;                      % [Ohm]
    p.hw.Goff    = 1e-6;                        % [1/Ohm]
    % DC link
    p.hw.Cdc     = 7.2e-3;                      % [F]
    p.hw.Rdc     = 1e-3;                        % [Ohm] ESR
    p.hw.Vdc0    = udc_nom;                     % [V]   initial DC-link voltage: the run starts at the operating point
    % legs: one separate inductor per leg (a coupled three-limb reactor is wrong for the in-phase DC currents of the legs)
    p.hw.L       = 1e-3;                        % [H]   47 A peak-peak of ripple per leg at D = 0.533
    p.hw.RL      = 8e-3;                        % [Ohm] 350 W per leg at 208 A, 0.4 % of Pnom
    p.hw.kL      = [1 1 1];                     %       per-leg factors of L (mismatch studies)
    p.hw.kRL     = [1 1 1];                     %       per-leg factors of RL
    % output capacitor
    p.hw.Cout    = 3.6e-3;                      % [F]   145 Hz with L/3; 1 mV of ripple at 12 kHz
    p.hw.RCout   = 2e-3/3;                      % [Ohm] ESR
    % normalization of the measurements
    p.hw.ubez    = ubez;                        % [V]
    p.hw.ibez    = ibez;                        % [A]
    p.hw.udc_nom = udc_nom;                     % [V]

    % ------------------------------------------------------------------ p.pwm: carriers and gates
    p.pwm.tc            = tc;                   % [s]   sample time of the block = local solver step: the switching instants
                                                %       are quantized to tc (ts/200 at 8 kHz)
    p.pwm.fpwm          = fpwm;                 % [Hz]
    p.pwm.carrier_phase = [0 2*pi/3 4*pi/3];    % [rad] interleaving: 2*pi/n_legs between the carriers
    p.pwm.double_update = 1;                    %       control at the bottom and at the top of carrier 1 (8 kHz)
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
    p.ctrl.u_out_ref      = 1;                  % [pu]  400 V
    p.ctrl.u_ref_slew     = 20;                 % [pu/s] ramp of the reference: 1 pu in 50 ms
    p.ctrl.i_ref          = 1;                  % [pu]  mode 1: total current reference (625 A)
    p.ctrl.t_ref          = 0;                  % [s]   step time of i_ref
    p.ctrl.i_ref_slew     = 20;                 % [pu/s]
    p.ctrl.i_lim          = 1.2;                % [pu]  limit of the total current reference (750 A)
    % loops (same closed-form design as private/buck_ctrl_param.m of the model): the plant of the per-leg current loop,
    % duty -> i_Lk (pu of ibez), is an integrator of gain k_i = udc_nom/(L*ibez) = 1200 1/s; kp_i = 2*pi*f_c_i/k_i,
    % ki_i = kp_i*2*pi*f_c_i/5 (PI zero at f_c_i/5). The plant of the voltage loop at nominal load is the output
    % capacitor with the load, Zc = k_u/(s + a) with k_u = ibez/(Cout*ubez) = 434 1/s and a = 1/(R_load*Cout) (69 Hz),
    % behind the closed common-mode current loop T_i (with the same duty on all legs the capacitor reacts: the leg
    % current per unit duty is k_i/(s + RL/L + 3*k_v*Zc), k_v = ubez/(L*ibez), and |T_i| is about 0.7 at the voltage
    % crossover): kp_u from |PI*T_i*Zc| = 1 at w_u, ki_u = kp_u*w_u/5. Linear check (discrete model at ts, 2026-10-25):
    % current loops crossover 313 Hz, phase margin 59 deg on leg 1, 42-44 deg and 7.5 dB of gain margin on legs 2-3;
    % voltage loop 61 Hz / 121 deg at nominal load, 114 Hz / 94 deg at 5 % load; 5 % dip on a +0.2 pu load step
    % recovered within 1 % in 40 ms
    f_c_i = 300;                                % [Hz] crossover target of the current loops
    f_c_u = 60;                                 % [Hz] crossover target of the voltage loop at nominal load
    k_i = udc_nom/(p.hw.L*ibez);                % [1/s]
    k_u = ibez/(p.hw.Cout*ubez);                % [1/s]
    k_v = ubez/(p.hw.L*ibez);                   % [1/s]
    a   = 1/((u_out_nom^2/pwr_nom)*p.hw.Cout);  % [1/s] load corner at nominal power
    p.ctrl.kp_i = 2*pi*f_c_i/k_i;               % [pu/pu] 1.571: duty per pu of leg current error
    p.ctrl.ki_i = p.ctrl.kp_i*2*pi*f_c_i/5;     % [1/s]   592
    s_u  = 1i*2*pi*f_c_u;
    Zc   = k_u/(s_u + a);
    G_cm = k_i/(s_u + p.hw.RL/p.hw.L + n_legs*k_v*Zc);
    L_cm = (p.ctrl.kp_i + p.ctrl.ki_i/s_u)*G_cm*exp(-1.5*ts*s_u);
    T_i  = L_cm/(1 + L_cm);
    p.ctrl.kp_u = 1/(abs(T_i*Zc)*sqrt(1 + 1/25));   % [pu/pu] 1.875: pu of total current per pu of voltage error
    p.ctrl.ki_u = p.ctrl.kp_u*2*pi*f_c_u/5;     % [1/s]   141
end
