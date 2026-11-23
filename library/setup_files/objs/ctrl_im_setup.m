
%% example
% im_ctrl = ctrl_im_setup(ts_inv, im.omega_bez, im.Jm_norm);

%% class definition
classdef ctrl_im_setup
    properties
        ts                    double {mustBePositive} % Samping time [s]
        omega_base            double {mustBePositive} % Base pulsation [rad/s]
        Jm_norm               double {mustBePositive} % Per unit representation of the load inertia [pu]
        di_obs                % Double Integrator Observer Object 
        edi_obs               % Extended Double Integrator Observer Object 
        u_im_scale
        kp_w                  % Speed control proportional gain  
        ki_w                  % Speed control integral gain  
        iq_lim                % IQ limit [pu] 
        id_lim                % ID limit [pu]
        kp_i                  % Current control proportional gain
        ki_i                  % Current control integral gain
        kp_id                 % Current control proportional gain
        ki_id                 % Current control integral gain
        kp_iq                 % Current control proportional gain
        ki_iq                 % Current control integral gain
        kp_inv_d              % Current control proportional gain
        ki_inv_d              % Current control integral gain
        kp_inv_q              % Current control proportional gain
        ki_inv_q              % Current control integral gain

        ekf                   % EKF state observer
                
    end
    
    methods

        function obj = ctrl_im_setup(ts, omega_base, u_im_scale, Jm_norm)
            if nargin > 0
                obj.ts = ts;
                obj.omega_base = omega_base;
                obj.Jm_norm = Jm_norm;
                obj.di_obs = double_integrator_observer(obj);
                obj.edi_obs = extended_double_integrator_observer(obj);
                obj.u_im_scale = u_im_scale;

                obj.kp_w = 2.5;
                obj.ki_w = 18;
                obj.iq_lim = 1.4;
                obj.id_lim = 0.35;
                obj.kp_i = 0.25;
                obj.ki_i = 18;
                obj.kp_id = obj.kp_i;
                obj.ki_id = obj.ki_i;
                obj.kp_iq = obj.kp_i;
                obj.ki_iq = obj.ki_i;
                obj.kp_inv_d = obj.kp_i;
                obj.ki_inv_d = obj.ki_i;
                obj.kp_inv_q = obj.kp_i;
                obj.ki_inv_q = obj.ki_i;
            end
        end
        
        function out = double_integrator_observer(obj)
                out.Aso = [0 1; 0 0];
                out.Adso = eye(2) + out.Aso*obj.ts;
                out.Cso = [1 0];
                p2place = [-1 -4]*obj.omega_base;
                p2placed = exp(p2place*obj.ts);
                out.Ldso = (acker(out.Adso',out.Cso',p2placed))';
            out.komega = out.Ldso(2) / obj.ts;
            out.ktheta = out.Ldso(1) / obj.ts;
        end

        function out = extended_double_integrator_observer(obj)
                out.A = [0 1 0; 0 0 -1/obj.Jm_norm; 0 0 0];
                out.Ad_edio = eye(3) + out.A * obj.ts;
                out.Bd_edio = [0; obj.ts/obj.Jm_norm; 0];
                out.Cedio = [1 0 0];
                p3place = exp([-1 -2 -4] * obj.omega_base * obj.ts);
                out.Ldeso = (acker(out.Ad_edio',out.Cedio',p3place))';
                out.l1 = out.Ldeso(1);
                out.l2 = out.Ldeso(2);
                out.l3 = out.Ldeso(3);
        end




    end
end


