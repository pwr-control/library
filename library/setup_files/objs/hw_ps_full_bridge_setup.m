%% ps_full_bridge_setup

    % ps_full_bridge = hw_ps_full_bridge_setup(CFi, RCFi, ...
    % LFu, LFu_leakage, RLFu, CFu1, RCFu1, CFu2, RCFu2, ...
    % LFc, LFc_leakage, RLFc, CFc1, RCFc1, CFc2, RCFc2, LFu_Isat, LFc_Isat, ...
    % udc_nom, udc_bez, u_nom, i_nom, u_bez, i_bez, Lload, Rload, fpwm);

classdef hw_ps_full_bridge_setup 
    properties
        Lload           double {mustBePositive} % [H]
        Rload           double {mustBePositive} % [Ohm]
        CFi             double {mustBePositive} % [F]
        RCFi            double {mustBePositive} % [Ohm]
        LFu             double {mustBePositive} % [H]
        LFu_leakage     double {mustBePositive} % [H]
        RLFu            double {mustBePositive} % [Ohm]
        CFu1            double {mustBePositive} % [F]
        RCFu1           double {mustBePositive} % [Ohm]
        CFu2            double {mustBePositive} % [F]
        RCFu2           double {mustBePositive} % [Ohm]
        LFc             double {mustBePositive} % [H]
        LFc_leakage     double {mustBePositive} % [H]
        RLFc            double {mustBePositive} % [Ohm]
        CFc1            double {mustBePositive} % [F]
        RCFc1           double {mustBePositive} % [Ohm]
        CFc2            double {mustBePositive} % [F]
        RCFc2           double {mustBePositive} % [Ohm]
        LFu_Isat        double {mustBePositive} % [A]
        LFc_Isat        double {mustBePositive} % [A]
        u_nom           double {mustBePositive} % [V]
        i_nom           double {mustBePositive} % [A]
        u_bez           double {mustBePositive} % [V]
        i_bez           double {mustBePositive} % [A]
        fpwm            double {mustBePositive} % [Hz]
        udc_nom         double {mustBePositive} % [V]
        udc_bez         double {mustBePositive} % [V]
    end
    
    methods
        function obj = hw_ps_full_bridge_setup(CFi, RCFi, ...
                        LFu, LFu_leakage, RLFu, CFu1, RCFu1, CFu2, RCFu2, ...
                        LFc, LFc_leakage, RLFc, CFc1, RCFc1, CFc2, RCFc2, LFu_Isat, LFc_Isat, ...
                        udc_nom, udc_bez, u_nom, i_nom, u_bez, i_bez, Lload, Rload, fpwm)
            if nargin > 0
                obj.CFi = CFi;
                obj.RCFi = RCFi;
                obj.LFu = LFu;
                obj.LFu_leakage = LFu_leakage;
                obj.RLFu = RLFu;
                obj.CFu1 = CFu1;
                obj.CFu2 = CFu2;
                obj.RCFu1 = RCFu1;
                obj.RCFu2 = RCFu2;
                obj.LFc = LFc;
                obj.LFc_leakage = LFc_leakage;
                obj.RLFc = RLFc;
                obj.CFc1 = CFc1;
                obj.CFc2 = CFc2;
                obj.RCFc1 = RCFc1;
                obj.RCFc2 = RCFc2;
                obj.u_nom = u_nom;
                obj.i_nom = i_nom;
                obj.u_bez = u_bez;
                obj.i_bez = i_bez;
                obj.fpwm =  fpwm;
                obj.udc_nom =  udc_nom;
                obj.udc_bez =  udc_bez;
                obj.Lload =  Lload;
                obj.Rload =  Rload;
                obj.LFu_Isat = LFu_Isat;
                obj.LFc_Isat = LFc_Isat;
            end
        end
        
    end
end