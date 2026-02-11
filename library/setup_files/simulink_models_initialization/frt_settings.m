
%% FRT Settings
enable_frt_1 = 0;
enable_frt_2 = 0;

%% FRT data for frt type 2
deepPOSxi = 0.5;
deepNEGxi = 0;
deepNEGeta = 0.5;

%% FRT, and other fault timing settings
test_index    = 25;
test_subindex = 4;

%% FRT Variants
% 0 -> Variant C, two phase, 
% 1 -> Variant D, single phase
asymmetric_error_type = 0;  


start_time_grid_switch_open = 1e3;
start_time_LVRT = 2.0;
time_start_motor_control = 0.035;

time_aux_power_supply_fault = 1e3;
time_phase_fault = 1e3;
start_load = 0.25;

%% FRT gain factor for grid support
settle_time = 0.175;
k_frt_ref = 2;