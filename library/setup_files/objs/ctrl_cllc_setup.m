
%% example
% kp_udc = 0.5;
% ki_udc = 18.0;
% kp_idc = 0.5;
% ki_idc = 18.0;
% cllc_ctrl = ctrl_cllc_setup(kp_udc, ki_udc, kp_idc, ki_idc);

%% class definition
classdef ctrl_cllc_setup
    properties
        kp_udc
        ki_udc
        kp_idc
        ki_idc
    end
    
    methods

        function obj = ctrl_cllc_setup(kp_udc, ki_udc, kp_idc, ki_idc)
            if nargin > 0
                obj.kp_udc = kp_udc;
                obj.ki_udc = ki_udc;
                obj.kp_idc = kp_idc;
                obj.ki_idc = ki_idc;
            end
        end
        
    end
end


