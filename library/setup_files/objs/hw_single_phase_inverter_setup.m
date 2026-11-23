

classdef hw_single_phase_inverter_setup
    properties
        application_voltage         
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
        LFu1            double {mustBePositive} % Output filter inductace (half) [H]
        LFu2            double {mustBePositive} % Output filter inductace (half)[H]
        RLFu            double {mustBePositive} % Output filter inductace resistance [Ohm]
        RLFu1           double {mustBePositive} % Output filter inductace resistance (half) [Ohm]
        RLFu2           double {mustBePositive} % Output filter inductace resistance (half) [Ohm]
        LFu_cm          double {mustBePositive} % Output filter inductace [H]
        RLFu_cm         double {mustBePositive} % Output filter inductace resistance [Ohm]
        CFu             double {mustBePositive} % Output filter capacitor [F]
        RCFu            double {mustBePositive} % Output filter damping resistor [Ohm]
        Rbrake          double {mustBePositive} % DClink braking resistor [Ohm]
        ibez            double {mustBePositive} % Normalization Current Factor [A]
        ubez            double {mustBePositive} % Normalization Voltage Factor [V]
        udc_bez         double {mustBePositive} % Normalization DC Voltage Factor [V]
        omega_bez       double {mustBePositive} % Base Pulsation [rad/s]
        norm
    end
    
    methods
        function obj = hw_single_phase_inverter_setup(application_voltage, pwr, us, is, freq, udc, fpwm, CFi, RCFi, CFi1, RCFi1, CFi2, RCFi2, LFu, RLFu, LFu_cm, RLFu_cm, CFu, RCFu, Rbrake)
            if nargin > 0
                obj.application_voltage = application_voltage;
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
                obj.LFu1 = LFu/2;
                obj.LFu2 = LFu/2;
                obj.LFu_cm = LFu_cm;
                obj.RLFu = RLFu;
                obj.RLFu1 = RLFu/2;
                obj.RLFu2 = RLFu/2;
                obj.RLFu_cm = RLFu_cm;
                obj.CFu = CFu;
                obj.RCFu = RCFu;
                obj.Rbrake = Rbrake;
                obj.ubez =  obj.us_nom * sqrt(2);
                obj.ibez =  obj.is_nom * sqrt(2);
                obj.udc_bez =  obj.udc_nom;
                obj.omega_bez =  2 * pi * obj.f_nom;
                obj.norm = normalization(obj);
            end
        end

        function norm = normalization(obj)
                norm.Xbez = obj.ubez / obj.ibez;      
                norm.Lbez =  norm.Xbez / obj.omega_bez;    
        end

        function displayInfo(obj)
            fprintf('Device Single Phase Inverter: %d V\n', obj.application_voltage);
            fprintf('Nominal Voltage: %d V | Nominal Current: %d A\n', obj.us_nom, obj.is_nom);
            fprintf('Current Normalization Data: %.2f A\n', obj.ibez);
            fprintf('Voltage Normalization Data: %.2f V\n', obj.ubez);
            fprintf('---------------------------\n');
        end
    end
end