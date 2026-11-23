classdef hw_afe_three_phase_setup
    properties
        name            string
        pwr_nom         double {mustBePositive} % Nominal power [W]
        us_nom          double {mustBePositive} % Nominal AC-grid voltage [V]
        is_nom          double {mustBePositive} % Nominal AC-grid current [A]
        f_nom           double {mustBePositive} % Nominal AC-grid frequency [Hz]
        udc_nom         double {mustBePositive} % Nominal DC-link voltage [V]
        fpwm_base       double {mustBePositive} % Base switching frequency [Hz]
        CFi             double {mustBePositive} % DClink capacitor [F]
        RCFi            double {mustBePositive} % DClink internal resistance [Ohm]
        CFi1            double {mustBePositive} % DClink capacitor bank 1 [F]
        RCFi1           double {mustBePositive} % DClink internal resistance [Ohm]
        CFi2            double {mustBePositive} % DClink capacitor bank 2 [F]
        RCFi2           double {mustBePositive} % DClink internal resistance [Ohm]
        LFu             double {mustBePositive} % Output filter inductace [H]
        RLFu            double {mustBePositive} % Output filter inductace resistance [Ohm]
        LFu_cm          double {mustBePositive} % Output filter inductace [H]
        RLFu_cm         double {mustBePositive} % Output filter inductace resistance [Ohm]
        CFu             double {mustBePositive} % Output filter capacitor [F]
        RCFu            double {mustBePositive} % Output filter damping resistor [Ohm]
        Rbrake          double {mustBePositive} % DClink braking resistor [Ohm]
        ibez            double {mustBePositive} % Normalization Current Factor [A]
        ubez            double {mustBePositive} % Normalization Voltage Factor [V]
    end
    
    methods
        function obj = hw_afe_three_phase_setup(name, pwr, us, is, freq, udc, fpwm, CFi, RCFi, CFi1, RCFi1, CFi2, RCFi2, LFu, RLFu, LFu_cm, RLFu_cm, CFu, RCFu, Rbrake)
            if nargin > 0
                obj.name = name;
                obj.pwr_nom = pwr;
                obj.us_nom = us;
                obj.is_nom = is;
                obj.f_nom = freq;
                obj.udc_nom = udc;
                obj.fpwm_base = fpwm;
                obj.CFi = CFi;
                obj.CFi1 = CFi1;
                obj.CFi2 = CFi2;
                obj.RCFi = RCFi;
                obj.RCFi1 = RCFi1;
                obj.RCFi2 = RCFi2;
                obj.LFu = LFu;
                obj.LFu_cm = LFu_cm;
                obj.RLFu = RLFu;
                obj.RLFu_cm = RLFu_cm;
                obj.CFu = CFu;
                obj.RCFu = RCFu;
                obj.Rbrake = Rbrake;
                obj.ubez =  obj.us_nom * sqrt(2/3);
                obj.ibez =  obj.is_nom * sqrt(2);
            end
        end
        
        function displayInfo(obj)
            fprintf('Device AFE_THREE_PHASE: %s\n', obj.name);
            fprintf('Nominal Voltage: %d V | Nominal Current: %d A\n', obj.us_nom, obj.is_nom);
            fprintf('Current Normalization Data: %.2f A\n', obj.ibez);
            fprintf('Voltage Normalization Data: %.2f V\n', obj.ubez);
            fprintf('---------------------------\n');
        end
    end
end