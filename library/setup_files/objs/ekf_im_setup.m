%% ekf_im_setup - data of the extended Kalman filter of the induction machine
%
% Rev. 01 (2026-11): class rewritten and commented. The algorithm (one step of the filter) is in
% ekf_im_step.m (library/user_defined_functions/ekf_im).
%
% Errors of rev. 00 corrected here (derivation in the research note im_foc_ekf_sensorless,
% pwr-control/repositories-documentation, research/power_electronics):
%   1. mechanical row: 1/Jm_norm and mu = Lm/(Jm_norm Lr) were used in the time normalized with
%      omega_bez, with Jm_norm = 1/2 J omega_mb/T_nom: the gains of the torque and of the load
%      torque were tau_m omega_bez/Jm_norm = 632 times too high for the 261 kW machine of inv_im.
%      Now the mechanical equation is written in seconds with tau_m = J omega_mb/torque_bez and
%      the natural torque base torque_bez = 3/2 pp psi_bez ibez;
%   2. the prediction A_d(x)*x of rev. 00 multiplied the Jacobian by the state, so the bilinear
%      terms (omega*psi, psi*i) were counted twice: ekf_im_step uses x + ts*f(x, u);
%   3. forward Euler: at 8 kHz the rotor-flux mode of the discrete model is unstable above about
%      0.28 pu of speed and the estimate is biased (-18 deg of flux angle at rated speed):
%      ekf_im_step uses the second-order Taylor prediction;
%   4. sigma and Rs were those of the machine alone: the inverter output inductor (l_series,
%      r_series) is now added to the stator leakage and resistance;
%   5. Q and R were scaled with ts (R = ts = 1.25e-4 pu^2, i.e. 6.5 A rms on the 261 kW machine,
%      and a speed random walk of 1.25e-5 pu^2 per step), x0 was [0 0 1 1 0 0]*ts and P0 = 0:
%      Q and R are now derived from the measurement noise and from the model uncertainty, P0 is
%      diagonal and x0 starts with a small flux.
% The voltage scale of rev. 00 ((2/3)^2*udc_nom/ubez, 0.770 of the true value) was in the model
% init (u_im_scale_ekf): see the inv_im init, where the scale is udc/(sqrt(3) ubez).
%
%% Example (foundations_of_power_electronics/inv_im/init_model.m of modelization-and-control)
%   param.im.ctrl.ekf = ekf_im_setup(param.im.machine, param.glb_time.ts_inv, ...
%                                    param.inv.hw.LFi, param.inv.hw.RLFi);
%   param.im.ctrl.ekf.q_adc = param.meas.CurrentQuantization;
%   param.im.ctrl.ekf.n_hold = round(param.im.mode.time_start_motor_control/param.glb_time.ts_inv);
%   param.im.ctrl.ekf.displayInfo();
%
% Legacy call of rev. 00, still present in the inits copied from the common template:
%   im_ctrl.ekf = ekf_im_setup(im.alpha_norm, im.beta_norm, im.gamma_norm, im.sigma_norm, ...
%                              im.mu_norm, im.Lm_norm, im.Jm_norm, glb_time.ts_inv);
% It is accepted so that those inits keep running, but it does not give a usable filter: the
% base pulsation and the mechanical time constant cannot be recovered from the eight numbers
% (omega_b and tau_m are NaN, legacy = true). A model that uses the filter calls
% ekf_im_setup(im, ts, l_series, r_series).
%
%% State, units and model
% Six states in the stationary alpha-beta frame, all in per unit (pu) of the machine bases of
% im_setup (amplitude-invariant space vectors):
%
%     x = [i_alpha; i_beta; psi_alpha; psi_beta; omega; T_load]
%
%   i_alpha, i_beta       stator current, base ibez = sqrt(2) I_nom
%   psi_alpha, psi_beta   rotor flux, base psi_bez = ubez/omega_bez
%   omega                 electrical rotor speed, base omega_bez = 2 pi f_nom
%   T_load                load torque seen by the shaft (external torque plus friction),
%                         base torque_bez = 3/2 pp psi_bez ibez (natural torque base)
%
% Input: stator voltage u = [u_alpha; u_beta] in pu of ubez = sqrt(2/3) U_nom. Output: the stator
% current, y = C x with C = [1 0 0 0 0 0; 0 1 0 0 0 0].
%
% Continuous-time model, time in seconds, coefficients normalized with the machine bases:
%
%   di_alpha/dt   = wb*(-g*i_alpha + b*alpha*psi_alpha + b*omega*psi_beta + u_alpha/sigma)
%   di_beta/dt    = wb*(-g*i_beta  + b*alpha*psi_beta  - b*omega*psi_alpha + u_beta/sigma)
%   dpsi_alpha/dt = wb*(alpha*Lm*i_alpha - alpha*psi_alpha - omega*psi_beta)
%   dpsi_beta/dt  = wb*(alpha*Lm*i_beta  - alpha*psi_beta  + omega*psi_alpha)
%   domega/dt     = (kr*(psi_alpha*i_beta - psi_beta*i_alpha) - T_load)/tau_m
%   dT_load/dt    = 0 (random walk: the filter follows the load through Q)
%
%   wb = omega_b, sigma = sigma_n (leakage inductance of machine plus series inductor),
%   b = beta_n = Lm/(sigma Lr), g = gamma_n = Rs/sigma + b alpha Lm, kr = Lm/Lr,
%   alpha = alpha_n = Rr/Lr, tau_m = J omega_mb/torque_bez [s].
% The electromagnetic torque in pu of torque_bez is kr*(psi_alpha*i_beta - psi_beta*i_alpha).
%
%% Noise and initial values
% Q and R are per sample (discrete-time covariances of the step of ekf_im_step):
%   R = (sigma_i^2 + q_adc^2/12)/ibez^2 on each current component: sensor noise sigma_i [A rms]
%       plus the quantization of the ADC (step q_adc [A]);
%   Q(i)     = (ts*omega_b*u_err/sigma_n)^2: change of current produced in one sample by a voltage
%              error of u_err pu (dead time residue, voltage drops of the semiconductors,
%              quantization of the modulation);
%   Q(psi)   = q_psi, small: the flux equations are trusted;
%   Q(omega) = q_omega, small: the speed follows the mechanical equation;
%   Q(T_load) = q_tload: the main tuning knob. A larger value follows load steps faster and lets
%              more noise into the speed estimate. With 1e-6 per sample the load torque can change
%              by about sqrt(8000*1e-6) = 0.09 pu in one second (one standard deviation).
%   P0 = p0*I, x0 = [0 0 psi0 0 0 0]: no information on the initial state but a small flux, so
%   that the flux angle is defined from the first sample.
%
%% Model settings (written by the init of the model that uses the filter)
%   n_hold     samples after the start in which the machine is known to be at standstill
%              (magnetization before the speed control starts): speed and load torque are held at
%              zero and not updated, otherwise the filter would drift on the unobservable speed at
%              zero stator frequency. 0 when the shaft may turn from the start (speed source).
%   n_delay_u  samples between the voltage command fed to the filter (the one computed in the same
%              control step) and the interval [t_m - ts, t_m] that ends at the sampling instant t_m
%              of the measured current. 2 in inv_im (current sampled one step earlier, command
%              applied from the next PWM update) and in a drive with one step of computation delay.
%   cov_order  order of the transition matrix used for the covariance: 1 (default, half the
%              operations, same results in the note) or 2 (same order as the state prediction).
%
% See also ekf_im_step, im_setup.

classdef ekf_im_setup
    properties
        name = ''               % machine name (from im_setup)
        legacy = false          % true when built with the eight-coefficient call of rev. 00

        % ---- sampling and bases
        ts = NaN                % [s] sampling time of the filter (control period)
        omega_b = NaN           % [rad/s] base pulsation omega_bez = 2 pi f_nom
        ubez = NaN              % [V] voltage base, peak of the phase voltage
        ibez = NaN              % [A] current base, peak of the phase current
        psi_bez = NaN           % [Vs] flux base ubez/omega_bez
        torque_bez = NaN        % [Nm] natural torque base 3/2 pp psi_bez ibez

        % ---- inverter output inductor (in series with the stator)
        l_series = 0            % [H] per phase
        r_series = 0            % [Ohm] per phase

        % ---- normalized coefficients of the model (pu, time normalized with omega_b)
        sigma_n = NaN           % stator transient inductance sigma*Ls of the machine plus l_series
        rs_n = NaN              % stator resistance of the machine plus r_series
        lm_n = NaN              % magnetizing inductance
        lr_n = NaN              % rotor inductance
        alpha_n = NaN           % Rr/Lr (inverse of the rotor time constant times 1/omega_b)
        kr = NaN                % Lm/Lr: rotor coupling factor, also the torque factor in pu
        beta_n = NaN            % Lm/(sigma_n Lr)
        gamma_n = NaN           % rs_n/sigma_n + beta_n alpha_n lm_n
        tau_m = NaN             % [s] mechanical time constant J omega_mb/torque_bez

        % ---- noise and initial values (Q, R, P0, x0 follow from these, see the header)
        sigma_i = 1.0           % [A rms] noise of each current sensor
        q_adc = 0               % [A] quantization step of the current acquisition
        u_err = 0.02            % [pu of ubez] voltage uncertainty used for Q of the currents
        q_psi = 1e-10           % [pu^2 per sample] process noise of each rotor flux component
        q_omega = 1e-10         % [pu^2 per sample] process noise of the speed
        q_tload = 1e-6          % [pu^2 per sample] process noise of the load torque
        p0 = 1e-4               % [pu^2] initial variance of every state
        psi0 = 1e-3             % [pu] initial rotor flux (alpha component)

        % ---- model settings
        n_hold = 0              % samples with speed and load torque held at zero
        n_delay_u = 2           % samples of delay of the voltage command fed to the filter
        cov_order = 1           % order of the transition matrix of the covariance (1 or 2)

        % ---- measurement matrix (kept for the models that read it)
        C_ekf = [1 0 0 0 0 0; 0 1 0 0 0 0];
    end

    properties (Dependent)
        q_diag                  % 6x1, diagonal of Q per sample [pu^2]
        r_diag                  % 2x1, diagonal of R [pu^2]
        p0_diag                 % 6x1, diagonal of P0 [pu^2]
        x0                      % 6x1, initial state [pu]
    end

    methods
        function obj = ekf_im_setup(varargin)
            % obj = ekf_im_setup(im, ts)                      machine alone
            % obj = ekf_im_setup(im, ts, l_series, r_series)  machine behind an output inductor
            %   im        im_setup object of the machine
            %   ts        [s] sampling time of the filter
            %   l_series  [H] series inductance per phase (inverter output inductor), default 0
            %   r_series  [Ohm] its resistance, default 0
            if nargin == 0
                return
            end
            if nargin == 8 && isnumeric(varargin{1})
                obj = legacy_setup(obj, varargin{:});
                return
            end
            im = varargin{1};
            obj.ts = varargin{2};
            if nargin >= 3
                obj.l_series = varargin{3};
            end
            if nargin >= 4
                obj.r_series = varargin{4};
            end

            obj.name = char(im.name);
            obj.omega_b = im.omega_bez;
            obj.ubez = im.ubez;
            obj.ibez = im.ibez;
            obj.psi_bez = im.ubez/im.omega_bez;
            obj.torque_bez = 3/2*im.pp*obj.psi_bez*im.ibez;

            % electrical coefficients: the series inductor adds to the stator leakage, so it adds
            % to sigma*Ls and leaves Lm, Lr and the rotor time constant unchanged
            obj.sigma_n = im.sigma_norm + obj.l_series/im.Lbez;
            obj.rs_n = im.Rs_norm + obj.r_series/im.Xbez;
            obj.lm_n = im.Lm_norm;
            obj.lr_n = im.Lr_norm;
            obj.alpha_n = im.alpha_norm;
            obj.kr = im.Lm_norm/im.Lr_norm;
            obj.beta_n = obj.lm_n/(obj.sigma_n*obj.lr_n);
            obj.gamma_n = obj.rs_n/obj.sigma_n + obj.beta_n*obj.alpha_n*obj.lm_n;

            % mechanics: J d(omega_m)/dt = T - T_load with omega_m = omega*omega_mb and the torques
            % in pu of torque_bez gives domega/dt = (T - T_load)/tau_m
            obj.tau_m = im.Jm*im.omega_m_bez/obj.torque_bez;
        end

        function v = get.q_diag(obj)
            q_i = (obj.ts*obj.omega_b*obj.u_err/obj.sigma_n)^2;
            v = [q_i; q_i; obj.q_psi; obj.q_psi; obj.q_omega; obj.q_tload];
        end

        function v = get.r_diag(obj)
            r = (obj.sigma_i^2 + obj.q_adc^2/12)/obj.ibez^2;
            v = [r; r];
        end

        function v = get.p0_diag(obj)
            v = obj.p0*ones(6, 1);
        end

        function v = get.x0(obj)
            v = [0; 0; obj.psi0; 0; 0; 0];
        end

        function displayInfo(obj)
            fprintf('IM EKF (ekf_im_setup rev. 01): %s, ts = %.1f us\n', obj.name, obj.ts*1e6);
            if obj.legacy
                fprintf('  legacy call with eight coefficients: no usable filter (omega_b, tau_m unknown)\n');
                return
            end
            fprintf('  sigma = %.5f pu (series inductor %.1f uH), Rs = %.5f pu, Lm = %.4f pu, Lr = %.4f pu, alpha = %.6f pu\n', ...
                obj.sigma_n, obj.l_series*1e6, obj.rs_n, obj.lm_n, obj.lr_n, obj.alpha_n);
            fprintf('  torque base %.0f Nm, tau_m = %.4f s; R = %.3e pu^2 (%.2f A rms), Q = diag(%s)\n', ...
                obj.torque_bez, obj.tau_m, obj.r_diag(1), sqrt(obj.r_diag(1))*obj.ibez, ...
                sprintf('%.2e ', obj.q_diag));
            fprintf('  hold %d samples (%.3f s), voltage delay %d samples, covariance order %d\n', ...
                obj.n_hold, obj.n_hold*obj.ts, obj.n_delay_u, obj.cov_order);
        end
    end

    methods (Access = private)
        function obj = legacy_setup(obj, alpha, beta, gamma, sigma, ~, lm, ~, ts)
            % rev. 00 call: the electrical coefficients are recovered (kr = beta*sigma,
            % Rs = sigma*(gamma - beta*alpha*Lm)); omega_b and tau_m are not known.
            obj.legacy = true;
            obj.ts = ts;
            obj.alpha_n = alpha;
            obj.beta_n = beta;
            obj.gamma_n = gamma;
            obj.sigma_n = sigma;
            obj.lm_n = lm;
            obj.kr = beta*sigma;
            obj.lr_n = lm/obj.kr;
            obj.rs_n = sigma*(gamma - beta*alpha*lm);
        end
    end
end
