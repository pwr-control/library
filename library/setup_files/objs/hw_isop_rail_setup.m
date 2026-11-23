%% hw_isop_rail_setup:
% phase shift full bridge converter

classdef hw_isop_rail_setup
    properties
        name            string
        pwr_nom         double {mustBePositive} % Nominal power [W]
        udc1_nom        double {mustBePositive} % Nominal DC1 voltage [V]
        udc2_nom        double {mustBePositive} % Nominal DC2 voltage [V]
        uac1_nom        double {mustBePositive} % Nominal AC1 voltage [V]
        uac2_nom        double {mustBePositive} % Nominal AC2 voltage [V]
        idc1_nom        double {mustBePositive} % Nominal DC1 current [A]
        idc2_nom        double {mustBePositive} % Nominal DC2 current [A]
        fpwm_base       double {mustBePositive} % Base switching frequency [Hz]
        Ls1             double {mustBePositive} % Primary side resonance inductance [H]
        n1              double {mustBePositive} % Transformer primary side number of turns
        n2              double {mustBePositive} % Transformer secondary side number of turns
        Lm              double {mustBePositive} % Transformer primary side magnetization inductance [H]
        Rfe             double {mustBePositive} % Transformer equivalent resistance for iron losses [Ohm]
        core_length     double {mustBePositive} % Transformer core length [m]
        core_mur        double {mustBePositive} % Transformer core relative permeability [pu]
        Ld1             double {mustBePositive} % Transformer primary side leakage inductance [H]
        Rs1             double {mustBePositive} % Transformer primary side winding resistance [Ohm]
        Ld2             double {mustBePositive} % Transformer secondary side leakage inductance [H]
        Rs2             double {mustBePositive} % Transformer seconsary side winding resistance [Ohm]
        Ls2             double {mustBePositive} % Secondary side resonance inductance [H]
        Cdc_dc1         double {mustBePositive} % DClink capacitor primary side [F]
        Cdc1_dc1        double {mustBePositive} % DClink capacitor primary side bank 1 [F]
        Cdc2_dc1        double {mustBePositive} % DClink capacitor primary side bank 2 [F]
        Cdc_dc2         double {mustBePositive} % DClink capacitor secondary side [F] 
        Cdc1_dc2        double {mustBePositive} % DClink capacitor secondary side bank 1 [F] 
        Cdc2_dc2        double {mustBePositive} % DClink capacitor secondary side bank 2 [F]

        RCdc_dc1        double {mustBePositive} % DClink capacitor primary side internal resistance [Ohm]
        RCdc1_dc1       double {mustBePositive} % DClink capacitor primary side bank 1 internal resistance [Ohm]
        RCdc2_dc1       double {mustBePositive} % DClink capacitor primary side bank 2 internal resistance [Ohm]
        RCdc_dc2        double {mustBePositive} % DClink capacitor secondary side internal resistance [Ohm]
        RCdc1_dc2       double {mustBePositive} % DClink capacitor secondary side bank 1 internal resistance [Ohm]
        RCdc2_dc2       double {mustBePositive} % DClink capacitor secondary side bank 2 internal resistance [Ohm]

        Ldc_dc1         double {mustBePositive} % Input/Output Inductance primary side [H]
        Ldc_dc2         double {mustBePositive} % Input/Output Inductance secondary side [H]

        RLdc_dc1        double {mustBePositive} % Input/Output Inductance primary side internal resistance [Ohm]
        RLdc_dc2        double {mustBePositive} % Input/Output Inductance secondary side internal resistance [Ohm]
        Idc_FS          double {mustBePositive} % Current End Scale [A]
        Vdc_FS          double {mustBePositive} % Voltage End Scale [V]

        idc1_bez        double {mustBePositive} % Normalization primary side current [A]
        idc2_bez        double {mustBePositive} % Normalization secondary side current [A]
        udc1_bez        double {mustBePositive} % Normalization primary side voltage [V]
        udc2_bez        double {mustBePositive} % Normalization secondary side voltage [V]

        Ls              double {mustBePositive} % Internal Ls tank [H]
    end
    
    methods
        function obj = hw_isop_rail_setup(name, pwr, udc1, udc2, uac1, uac2, idc1, idc2, fpwm, ...
            n1, n2, Lm, Rfe, Rs1, core_length, core_mur, Cdc_dc1, Cdc1_dc1, Cdc2_dc1, Cdc_dc2, ...
            Cdc1_dc2, Cdc2_dc2, RCdc_dc1, RCdc1_dc1, RCdc2_dc1, RCdc_dc2, RCdc1_dc2, RCdc2_dc2, ...
            Ldc_dc1, Ldc_dc2, RLdc_dc1, RLdc_dc2)
            if nargin > 0
                obj.name = name;
                obj.pwr_nom = pwr;
                obj.udc1_nom = udc1;
                obj.udc2_nom = udc2;
                obj.uac1_nom = uac1;
                obj.uac2_nom = uac2;
                obj.idc1_nom = idc1;
                obj.idc2_nom = idc2;
                obj.fpwm_base = fpwm;
                obj.n1 = n1;
                obj.n2 = n2;
                obj.Lm = Lm;
                obj.Rfe = Rfe;

                n12 = obj.n1/obj.n2;
                obj.Ls = (obj.udc1_nom^2/obj.fpwm_base/obj.pwr_nom/8/2.7); 

                obj.Rs1 = Rs1;
                obj.Rs2 = obj.Rs1 / (n12)^2;

                obj.Ld1 = obj.Ls/2;
                obj.Ld2 = obj.Ld1 / (n12)^2;
                
                obj.Ls1 = obj.Ld1;
                obj.Ls2 = obj.Ld2;

                obj.core_length = core_length;
                obj.core_mur = core_mur;

                obj.Cdc_dc1 = Cdc_dc1;
                obj.Cdc1_dc1 = Cdc1_dc1;
                obj.Cdc2_dc1 = Cdc2_dc1;

                obj.Cdc_dc2 = Cdc_dc2;
                obj.Cdc1_dc2 = Cdc1_dc2;
                obj.Cdc2_dc2 = Cdc2_dc2;

                obj.RCdc_dc1 = RCdc_dc1;
                obj.RCdc1_dc1 = RCdc1_dc1;
                obj.RCdc2_dc1 = RCdc2_dc1;

                obj.RCdc_dc2 = RCdc_dc2;
                obj.RCdc1_dc2 = RCdc1_dc2;
                obj.RCdc2_dc2 = RCdc2_dc2;

                obj.Ldc_dc1 = Ldc_dc1;
                obj.Ldc_dc2 = Ldc_dc2;
                obj.RLdc_dc1 = RLdc_dc1;
                obj.RLdc_dc2 = RLdc_dc2;

                obj.idc1_bez = obj.idc1_nom;
                obj.idc2_bez = obj.idc2_nom;
                obj.udc1_bez = obj.udc1_nom;
                obj.udc2_bez = obj.udc2_nom;

                obj.Idc_FS = max(obj.idc1_bez, obj.idc2_bez);
                obj.Vdc_FS = max(obj.udc1_bez, obj.udc2_bez);
               
            end
        end
        
        function displayInfo(obj)
            fprintf('ISOP: %s\n', obj.name);
            fprintf('Nominal Power: %d [W]\n', obj.pwr_nom);
            fprintf('Normalization Voltage DC1: %d [V] | Normalization Current DC1: %d [A]\n', ...
                obj.udc1_bez, obj.idc1_bez);
            fprintf('Normalization Voltage DC2: %d [V] | Normalization Current DC2: %d [A]\n', ...
                obj.udc2_bez, obj.idc2_bez);
            fprintf('Internal Tank Ls1: %d [H] | Internal Tank Ls2: %d [H]\n', ...
                obj.Ls1, obj.Ls2);
            fprintf('---------------------------\n');
        end
    end
end