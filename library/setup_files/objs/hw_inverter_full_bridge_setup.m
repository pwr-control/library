%% inverter single phase (full bridge)

classdef hw_inverter_full_bridge_setup 
    properties
        name          string
        pwr_nom       double {mustBePositive} % Nominal power [W]
        us_nom        double {mustBePositive} % Nominal AC-grid voltage [V]
        is_nom        double {mustBePositive} % Nominal AC-grid current [A]
        f_nom         double {mustBePositive} % Nominal AC-grid frequency [Hz]
        udc_nom       double {mustBePositive} % Nominal DC-link voltage [V]
        fpwm_base     double {mustBePositive} % Base switching frequency [Hz]
        LFi           double {mustBePositive} % Output filter inductace [H]
        RLFi          double {mustBePositive} % Output filter inductace resistance [Ohm]
        LFi_cm        double {mustBePositive} % Output filter inductace [H]
        RLFi_cm       double {mustBePositive} % Output filter inductace resistance [Ohm]
        ibez          double {mustBePositive} % Normalization Current Factor [A]
        ubez          double {mustBePositive} % Normalization Voltage Factor [V]
    end
    
    methods
        function obj = hw_inverter_full_bridge_setup(name, pwr, us, is, freq, udc, fpwm, LFi, RLFi, LFi_cm, RLFi_cm)
            if nargin > 0
                obj.name = name;
                obj.pwr_nom = pwr;
                obj.us_nom = us;
                obj.is_nom = is;
                obj.f_nom = freq;
                obj.udc_nom = udc;
                obj.fpwm_base = fpwm;
                obj.LFi = LFi;
                obj.RLFi = RLFi;
                obj.LFi_cm = LFi_cm;
                obj.RLFi_cm = RLFi_cm;
                obj.ubez =  obj.us_nom * sqrt(2/3);
                obj.ibez =  obj.is_nom * sqrt(2);
            end
        end
        
        function displayInfo(obj)
            fprintf('Device INVERTER: %s\n', obj.name);
            fprintf('Nominal Voltage: %d V | Nominal Current: %d A\n', obj.us_nom, obj.is_nom);
            fprintf('Current Normalization Data: %.2f A\n', obj.ibez);
            fprintf('Voltage Normalization Data: %.2f V\n', obj.ubez);
            fprintf('---------------------------\n');
        end
    end
end