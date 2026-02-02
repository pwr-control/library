
% HeatSink_1

% heat exchange made by an alluminium plate with a liquid flow of 28 l/min
% A here means water: so HA means delta temperature between water and
% heatsink sourface
% moreover the delta temperature between water in and water out is maximum
% 5K assuming a overall power losses of 10kW 

weigth = 0.150/10;                      % kg - when /10 is applied thermal inertia is not accounted 
cp_al = 880;                            % specific heat_capacity J/K/kg - alluminium
heat_capacity = cp_al*weigth;           % J/K
thermal_conducibility_al = 204;         % W/(m K) - alluminium
Rth_switch_HA = 2 * 18/1000;            % K/W 
Rth_mosfet_HA = Rth_switch_HA;          % K/W
Rth_diode_HA = Rth_switch_HA;           % K/W
Tambient = 40;                          % degC
DThs_init = 0;                          % degC