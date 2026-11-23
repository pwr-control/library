function three_phase_dab = three_phase_dab_hwdata(application_voltage, pwr_nom, fpwm_dab, fres)

    %% dclink for three level is splitted into two parts CFi1, CFi2
    % for DAB is used CFi1_dc1, CFi2_dc1, CFi1_dc2, and CFi2_dc2
    
    %% Example
    % hwdata.three_phase_dab = three_phase_dab_hwdata(application_voltage, dab_pwr_nom, glb_time.fPWM_DAB, fres_dab);


    
    %% DAB 800V - 750kW
    udc1 = 800;
    udc2 = 800;
    uac1 = 800;
    uac2 = 800;
    idc1 = 350*3;
    idc2 = 350*3;
    Lm = 1e-3;
    n1 = 6;
    n2 = 6;

    Rfe = 1e3;
    Rs1 = 1e-3;

    core_length = 1;
    core_mur = 75;

    Cdc_dc1 = 3.6e-3; 
    Cdc1_dc1 = 2*Cdc_dc1; Cdc2_dc1 = 2*Cdc_dc1;
    Cdc_dc2 = 3.6e-3; 
    Cdc1_dc2 = 2*Cdc_dc2; Cdc2_dc2 = 2*Cdc_dc2;
    
    RCdc_dc1 = 1e-3; 
    RCdc1_dc1 = RCdc_dc1/2; RCdc2_dc1 = RCdc_dc1/2;
    RCdc_dc2 = 1e-3; 
    RCdc1_dc2 = RCdc_dc2/2; RCdc2_dc2 = RCdc_dc2/2;   
    
    Ldc_dc1 = 250e-6; 
    RLdc_dc1 = 157*0.05*Ldc_dc1; 
    Ldc_dc2 = 250e-6; 
    RLdc_dc2 = 157*0.05*Ldc_dc2; 


    three_phase_dab_800V_750kW = hw_dab_three_phase_setup('Three_phase_DAB_800V', pwr_nom, udc1, udc2, uac1, uac2, idc1, idc2, fpwm_dab, fres, ...
            n1, n2, Lm, Rfe, Rs1, core_length, core_mur, Cdc_dc1, Cdc1_dc1, Cdc2_dc1, Cdc_dc2, ...
            Cdc1_dc2, Cdc2_dc2, RCdc_dc1, RCdc1_dc1, RCdc2_dc1, RCdc_dc2, RCdc1_dc2, RCdc2_dc2, ...
            Ldc_dc1, Ldc_dc2, RLdc_dc1, RLdc_dc2);

    %% DAB 1200V - 750kW
    udc1 = 1200;
    udc2 = 1200;
    uac1 = 1000;
    uac2 = 1000;
    idc1 = 250*3;
    idc2 = 250*3;

    Lm = 1e-3;
    n1 = 6;
    n2 = 6;

    Rfe = 1e3;
    Rs1 = 1e-3;

    core_length = 1;
    core_mur = 75;
    Cdc_dc1 = 3.6e-3; 
    Cdc1_dc1 = 2*Cdc_dc1; Cdc2_dc1 = 2*Cdc_dc1;
    Cdc_dc2 = 3.6e-3; 
    Cdc1_dc2 = 2*Cdc_dc2; Cdc2_dc2 = 2*Cdc_dc2;
   
    RCdc_dc1 = 1e-3; 
    RCdc1_dc1 = RCdc_dc1/2; RCdc2_dc1 = RCdc_dc1/2;
    RCdc_dc2 = 1e-3; 
    RCdc1_dc2 = RCdc_dc2/2; RCdc2_dc2 = RCdc_dc2/2;   
    
    Ldc_dc1 = 250e-6; 
    RLdc_dc1 = 157*0.05*Ldc_dc1; 
    Ldc_dc2 = 250e-6; 
    RLdc_dc2 = 157*0.05*Ldc_dc2; 

    three_phase_dab_1200V_750kW = hw_dab_three_phase_setup('Three_phase_DAB_1200V', pwr_nom, udc1, udc2, uac1, uac2, idc1, idc2, fpwm_dab, fres, ...
            n1, n2, Lm, Rfe, Rs1, core_length, core_mur, Cdc_dc1, Cdc1_dc1, Cdc2_dc1, Cdc_dc2, ...
            Cdc1_dc2, Cdc2_dc2, RCdc_dc1, RCdc1_dc1, RCdc2_dc1, RCdc_dc2, RCdc1_dc2, RCdc2_dc2, ...
            Ldc_dc1, Ldc_dc2, RLdc_dc1, RLdc_dc2);   

    %% setup outputs
    if application_voltage == 690
        three_phase_dab = three_phase_dab_1200V_750kW;
        three_phase_dab_1200V_750kW.displayInfo();
    elseif application_voltage == 480
        three_phase_dab = three_phase_dab_800V_750kW;
        three_phase_dab_800V_750kW.displayInfo();
    else
        three_phase_dab = three_phase_dab_800V_750kW;
        three_phase_dab_800V_750kW.displayInfo();
    end

end
