
%% example
% single_phase_inverter_ctrl = ctrl_single_phase_inverter_setup(ts, omega_base, ...
% kp_inv, ki_inv, kp_rpi, ki_rpi, delta_rpi);


%% class definition
classdef ctrl_single_phase_inverter_setup
    properties
        ts                      double {mustBePositive} % Samping time [s]
        omega_base              double {mustBePositive} % Base pulsation [s]
        omega_diobs             double {mustBePositive} % Double Integrator Observer - base pulsation [s]
        di_obs                  % Double Integrator Observer Object 
        vr_obs                  % Double Integrator Observer Object 
        fht_load                % First harmonic Tracker Object for Load application 
        res_pi                  % Resonant PI Object for grid current control 
        rms
        kp_inv
        ki_inv
        u_lim
        kp_rpi
        ki_rpi
        delta_rpi
    end
    
    methods

        function obj = ctrl_single_phase_inverter_setup(ts, omega_base, kp_inv, ki_inv, kp_rpi, ki_rpi, delta_rpi)
            if nargin > 0
                obj.ts = ts;
                obj.omega_base = omega_base;
                obj.omega_diobs = obj.omega_base;
                obj.kp_inv = kp_inv;
                obj.ki_inv = ki_inv;
                obj.u_lim = 1.0;
                obj.kp_rpi = kp_rpi;
                obj.ki_rpi = ki_rpi;
                obj.delta_rpi = delta_rpi;
                obj.di_obs = double_integrator_observer(obj);
                obj.vr_obs = voltage_rate_observer(obj);
                obj.fht_load = first_harmonic_tracker(obj);
                obj.res_pi = resonant_pi(obj);
                obj.rms = rms_setup(obj);


            end
        end
        
        function out = double_integrator_observer(obj)
                out.Aso = [0 1; 0 0];
                out.Adso = eye(2) + out.Aso*obj.ts;
                out.Cso = [1 0];
                p2place = [-1 -4]*obj.omega_diobs;
                p2placed = exp(p2place*obj.ts);
                out.Ldso = (acker(out.Adso',out.Cso',p2placed))';
            out.komega = out.Ldso(2) / obj.ts;
            out.ktheta = out.Ldso(1) / obj.ts;
        end

        function out = voltage_rate_observer(obj)
                out.Aso = [0 1; 0 0];
                out.Adso = eye(2) + out.Aso*obj.ts;
                out.Cso = [1 0];
                p2place = [-0.1 -0.4]*obj.omega_diobs;
                p2placed = exp(p2place*obj.ts);
                out.Ldso = (acker(out.Adso',out.Cso',p2placed))';
            out.kv = out.Ldso(2) / obj.ts;
            out.kx = out.Ldso(1) / obj.ts;
        end

        function out = first_harmonic_tracker(obj)
                out.omega_fht = obj.omega_base;
                out.delta_fht = 0.05;
                out.Afht = [0 1; -out.omega_fht^2 -out.delta_fht*out.omega_fht];
                out.Cfht = [1 0];
                poles_fht = [-1 -4] * out.omega_fht;
                out.Ad_fht = eye(2) + out.Afht * obj.ts;
                polesd_fht = exp(obj.ts * poles_fht);
            out.L_fht = (acker(out.Afht',out.Cfht', poles_fht))';
            out.Ld_fht = acker(out.Ad_fht',out.Cfht', polesd_fht)';
        end

        function out = resonant_pi(obj)
            out.kp_rpi = obj.kp_rpi;
            out.ki_rpi = obj.ki_rpi;
            out.delta_res = obj.delta_rpi;            
            out.Ares = [0 1; -(obj.omega_base)^2 -2*obj.delta_rpi*obj.omega_base];
            out.Bres = [0; 1];
            out.Cres = [0 1];
            out.Aresd = eye(2) + out.Ares*obj.ts;
            out.Bresd = out.Bres*obj.ts;
            out.Cresd = out.Cres;
        end

        function out = rms_setup(obj)
            rms_perios = 1;
            out.n1 = 2*pi * rms_perios / obj.omega_base / obj.ts;
            rms_perios = 10;
            out.n10 = 2*pi * rms_perios / obj.omega_base / obj.ts;
        end

    end
end


