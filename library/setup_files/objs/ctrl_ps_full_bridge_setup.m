
%% example
% kp_u = 0.5;
% ki_u = 18.0;
% kp_i = 0.5;
% ki_i = 18.0;
% ps_full_bridge_ctrl = ctrl_ps_full_bridge_setup(ts, kp_u, ki_u, kp_i, ki_i);

%% class definition
classdef ctrl_ps_full_bridge_setup
    properties
        ts
        kp_u
        ki_u
        kp_i
        ki_i
    end
    
    methods

        function obj = ctrl_ps_full_bridge_setup(ts, kp_u, ki_u, kp_i, ki_i)
            if nargin > 0
                obj.ts = ts;
                obj.kp_u = kp_u;
                obj.ki_u = ki_u;
                obj.kp_i = kp_i;
                obj.ki_i = ki_i;
            end
        end
        
    end
end


