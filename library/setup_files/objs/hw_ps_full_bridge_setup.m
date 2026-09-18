%% ps_full_bridge_setup

% ps_full_bridge = hw_ps_full_bridge_setup(CFi, RCFi, LFu, RLFu, CFu1, RCFu1, CFu2, RCFu2, udc_nom, udc_bez, u_nom, i_nom, u_bez, i_bez, fpwm);

classdef hw_ps_full_bridge_setup 
    properties
        CFi             double {mustBePositive} % [F]
        RCFi            double {mustBePositive} % [Ohm]
        LFu             double {mustBePositive} % [H]
        RLFu             double {mustBePositive} % [Ohm]
        CFu1            double {mustBePositive} % [F]
        RCFu1           double {mustBePositive} % [Ohm]
        CFu2            double {mustBePositive} % [F]
        RCFu2           double {mustBePositive} % [Ohm]
        u_nom           double {mustBePositive} % [V]
        i_nom           double {mustBePositive} % [A]
        u_bez           double {mustBePositive} % [V]
        i_bez           double {mustBePositive} % [A]
        fpwm            double {mustBePositive} % [Hz]
        udc_nom         double {mustBePositive} % [V]
        udc_bez         double {mustBePositive} % [V]
    end
    
    methods
        function obj = hw_ps_full_bridge_setup(CFi, RCFi, LFu, RLFu, CFu1, RCFu1, CFu2, RCFu2, ...
                udc_nom, udc_bez, u_nom, i_nom, u_bez, i_bez, fpwm)
            if nargin > 0
                obj.LFu = LFu;
                obj.RLFu = RLFu;
                obj.CFi = CFi;
                obj.RCFi = RCFi;
                obj.CFu1 = CFu1;
                obj.CFu2 = CFu2;
                obj.RCFu1 = RCFu1;
                obj.RCFu2 = RCFu2;
                obj.u_nom = u_nom;
                obj.i_nom = i_nom;
                obj.u_bez = u_bez;
                obj.i_bez = i_bez;
                obj.fpwm =  fpwm;
                obj.udc_nom =  udc_nom;
                obj.udc_bez =  udc_bez;
            end
        end
        
    end
end