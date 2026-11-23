function isop_rail = isop_rail_aux_application(application_voltage, pwr_nom, fpwm_psfbc)
    
    %% PSFBC 750V - 250kW
    udc1 = application_voltage;
    udc2 = 750;
    uac1 = udc1*4/pi;
    uac2 = udc2*4/pi;
    idc1 = pwr_nom/udc1;
    idc2 = pwr_nom/udc2;
    Lm = 1e-3;
    n1 = 1;
    n2 = udc2/udc1;

    Rfe = 1e3;
    Rs1 = 1e-3;

    core_length = 1;
    core_mur = 70;

    Cdc_dc1 = 1.2e-3; 
    Cdc1_dc1 = 2*Cdc_dc1; Cdc2_dc1 = 2*Cdc_dc1;
    Cdc_dc2 = Cdc_dc1; 
    Cdc1_dc2 = 2*Cdc_dc2; Cdc2_dc2 = 2*Cdc_dc2;
    
    RCdc_dc1 = 1e-3; 
    RCdc1_dc1 = RCdc_dc1/2; RCdc2_dc1 = RCdc_dc1/2;
    RCdc_dc2 = 1e-4; 
    RCdc1_dc2 = RCdc_dc2/2; RCdc2_dc2 = RCdc_dc2/2;   
    
    Ldc_dc1 = 1e-3; 
    RLdc_dc1 = 157*0.02*Ldc_dc1; 
    Ldc_dc2 = Ldc_dc1/4; 
    RLdc_dc2 = 157*0.01*Ldc_dc2; 


    isop_rail = hw_isop_rail_setup('PS_FBC_750V', pwr_nom, udc1, udc2, uac1, uac2, idc1, idc2, fpwm_psfbc, ...
            n1, n2, Lm, Rfe, Rs1, core_length, core_mur, Cdc_dc1, Cdc1_dc1, Cdc2_dc1, Cdc_dc2, ...
            Cdc1_dc2, Cdc2_dc2, RCdc_dc1, RCdc1_dc1, RCdc2_dc1, RCdc_dc2, RCdc1_dc2, RCdc2_dc2, ...
            Ldc_dc1, Ldc_dc2, RLdc_dc1, RLdc_dc2);   

end
