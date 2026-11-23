% Aluminum plate liquid cooled with a size fit for Primepack2
% heat exchange made by an aluminum plate with a liquid flow > 28 l/min
% "A" as "ambient" here means water: so HA means delta temperature between water and
% heatsink surface
% moreover the delta temperature between water in and water out is maximum
% 5K assuming a overall power losses of 2kW 

% weight = 0.150;                         % kg
% no_weight = 0.150/10;                   % kg - when /10 is applied thermal inertia is not accounted 
% cp_al = 880;                            % specific heat_capacity J/K/kg - aluminum
% heat_capacity = cp_al * weight;         % J/K
% thermal_conductivity = 204;             % W/(m K)
% Rth_switch_HA = 18/1000;                % K/W 
% Rth_mosfet_HA = Rth_switch_HA;          % K/W
% Rth_diode_HA = Rth_switch_HA;           % K/W
% Tambient = 40;                          % degC - water temperature
% DThs_init = 0;                          % degC

%% class definition
classdef liquid_cooled_plate_2kw_setup
    properties
        name                    string
        weight                  double {mustBePositive} % Mass of the cooling plate [kg]
        no_weight               double {mustBePositive} % Reduced mass for faster steady state analysis [kg]
        cp                      double {mustBePositive} % Specific heat_capacity [J/(kg K)]
        heat_capacity           double {mustBePositive} % Heat_capacity [J/K]
        thermal_conductivity    double {mustBePositive} % Thermal conductivity of the heatsink [W/(m K)] 
        Rth_switch_HA           double {mustBePositive} % Thermal impedance heatsink ambient below the igbt-switch area [K/W]
        Rth_mosfet_HA           double {mustBePositive} % Thermal impedance heatsink ambient below the mosfet area [K/W]
        Rth_diode_HA            double {mustBePositive} % Thermal impedance heatsink ambient below the igbt-diode area [K/W]
        Tambient                double {mustBePositive} % Ambient or water temperature [degC] 
        DThs_init               % Initial delta temperature between ambient and heatsink
    end
    
    methods
        function obj = liquid_cooled_plate_2kw_setup(weight, no_weight, cp, heat_capacity, thermal_conductivity, ...
                Rth_switch_HA, Rth_mosfet_HA, Rth_diode_HA, Tambient, DThs_init)
            if nargin > 0
                obj.name = "liquid_cooled_plate_2kw";
                obj.weight = weight;
                obj.no_weight = no_weight;
                obj.cp = cp;
                obj.heat_capacity = heat_capacity;
                obj.thermal_conductivity = thermal_conductivity;
                obj.Rth_switch_HA = Rth_switch_HA;
                obj.Rth_mosfet_HA = Rth_mosfet_HA;
                obj.Rth_diode_HA = Rth_diode_HA;
                obj.Tambient = Tambient;
                obj.DThs_init = DThs_init;
            end
        end
    end
end


