function single_phase_psfbc = single_phase_psfbc_hwdata(application_voltage, pwr_nom, fpwm_psfbc)

    %% psfbc : phase shift full bridge converter

    %% dclink for three level is splitted into two parts CFi1, CFi2
    % for psfbc is used CFi1_dc1, CFi2_dc1, CFi1_dc2, and CFi2_dc2
    
    %% Example 
    % hwdata.psfbc = single_phase_psfbc_hwdata(application_voltage, psfbc_pwr_nom, glb_time.fPWM_PSFBC);


    
    %% PSFBC 800V - 325kW
    udc1 = 750;
    udc2 = 45;
    uac1 = 750;
    uac2 = 45;
    idc1 = pwr_nom/udc1;
    idc2 = 12e3;
    Lm = 1e-3;
    n1 = 34;
    n2 = 2;

    Rfe = 1e3;
    Rs1 = 1e-3;

    core_length = 1;
    core_mur = 70;

    Cdc_dc1 = 1.2e-3; 
    Cdc1_dc1 = 2*Cdc_dc1; Cdc2_dc1 = 2*Cdc_dc1;
    Cdc_dc2 = 45e-3; 
    Cdc1_dc2 = 2*Cdc_dc2; Cdc2_dc2 = 2*Cdc_dc2;
    
    RCdc_dc1 = 1e-3; 
    RCdc1_dc1 = RCdc_dc1/2; RCdc2_dc1 = RCdc_dc1/2;
    RCdc_dc2 = 1e-4; 
    RCdc1_dc2 = RCdc_dc2/2; RCdc2_dc2 = RCdc_dc2/2;   
    
    Ldc_dc1 = 250e-6; 
    RLdc_dc1 = 157*0.02*Ldc_dc1; 
    Ldc_dc2 = 0.4e-6; 
    RLdc_dc2 = 157*0.01*Ldc_dc2; 


    psfbc800V_250kW = hw_psfbc_single_phase_setup('PSFBC_800V', pwr_nom, udc1, udc2, uac1, uac2, idc1, idc2, fpwm_psfbc, ...
            n1, n2, Lm, Rfe, Rs1, core_length, core_mur, Cdc_dc1, Cdc1_dc1, Cdc2_dc1, Cdc_dc2, ...
            Cdc1_dc2, Cdc2_dc2, RCdc_dc1, RCdc1_dc1, RCdc2_dc1, RCdc_dc2, RCdc1_dc2, RCdc2_dc2, ...
            Ldc_dc1, Ldc_dc2, RLdc_dc1, RLdc_dc2);

    %% PSFBC 1200V - 250kW
    udc1 = 1200;
    udc2 = 1200;
    uac1 = 1200;
    uac2 = 1200;
    idc1 = 250;
    idc2 = 250;

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

    psfbc1200V_250kW = hw_psfbc_single_phase_setup('PSFBC_1200V', pwr_nom, udc1, udc2, uac1, uac2, idc1, idc2, fpwm_psfbc, ...
            n1, n2, Lm, Rfe, Rs1, core_length, core_mur, Cdc_dc1, Cdc1_dc1, Cdc2_dc1, Cdc_dc2, ...
            Cdc1_dc2, Cdc2_dc2, RCdc_dc1, RCdc1_dc1, RCdc2_dc1, RCdc_dc2, RCdc1_dc2, RCdc2_dc2, ...
            Ldc_dc1, Ldc_dc2, RLdc_dc1, RLdc_dc2);   

    %% setup outputs
    if application_voltage == 690
        single_phase_psfbc = psfbc1200V_250kW;
        psfbc1200V_250kW.displayInfo();
    elseif application_voltage == 480
        single_phase_psfbc = psfbc800V_250kW;
        psfbc800V_250kW.displayInfo();
    else
        single_phase_psfbc = psfbc800V_250kW;
        psfbc800V_250kW.displayInfo();
    end

end
