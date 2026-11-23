function frt_data = frt_settings(test_index, test_subindex, asymmetric_error_type, ...
    enable_frt_1, enable_frt_2, start_time_LVRT, deepPOSxi, deepPOSeta, deepNEGxi, deepNEGeta)

%% FRT Settings
frt_data.enable_frt_1 = enable_frt_1;
frt_data.enable_frt_2 = enable_frt_2;

%% FRT data for frt type 2
frt_data.deepPOSxi = deepPOSxi;
frt_data.deepPOSeta = deepPOSeta;
frt_data.deepNEGxi = deepNEGxi;
frt_data.deepNEGeta = deepNEGeta;

%% FRT, and other fault timing settings
frt_data.test_index    = test_index;
frt_data.test_subindex = test_subindex;

%% FRT Variants
% 0 -> Variant C, two phase, 
% 1 -> Variant D, single phase
frt_data.asymmetric_error_type = asymmetric_error_type;  


frt_data.start_time_grid_switch_open = 1e3;
frt_data.start_time_LVRT = start_time_LVRT;
frt_data.time_start_motor_control = 0.035;

frt_data.time_aux_power_supply_fault = 1e3;
frt_data.time_phase_fault = 1e3;
frt_data.start_load = 0.25;

%% FRT gain factor for grid support
frt_data.settle_time = 0.175;
frt_data.k_frt_ref = 2;

end