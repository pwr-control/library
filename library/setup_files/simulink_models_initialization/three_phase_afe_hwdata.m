function three_phase_afe = three_phase_afe_hwdata(application_voltage, pwr_nom, fpwm_afe)

    %% dclink for three level is splitted into two parts CFi1, CFi2
    % for DC/DC is used CFi1_dc1, CFi2_dc1, CFi1_dc2, and CFi2_dc2
    
  
    %% AFE 690V
    uafe_nom = 690;
    iafe_nom = pwr_nom/sqrt(3)/uafe_nom/0.9;
    iafe_freq = 50;
    udc = 1070;
    CFi = 7.2e-3; CFi1 = 2*CFi; CFi2 = 2*CFi;
    RCFi = 1e-3; RCFi1 = RCFi/2; RCFi2 = RCFi/2;
    LFu = 500e-6; LFu_cm = 500e-6;
    RLFu = 157*0.05*LFu; RLFu_cm = 157*0.05*LFu_cm;
    CFu = 200e-6;
    RCFu = 50e-3;
    Rbrake = 4;

    afe690V = hw_afe_three_phase_setup('afe690V', pwr_nom, uafe_nom, iafe_nom, iafe_freq, udc, fpwm_afe, CFi, ...
        RCFi, CFi1, RCFi1, CFi2, RCFi2, LFu, RLFu, LFu_cm, RLFu_cm, CFu, RCFu, Rbrake);

    %% AFE 400V
    uafe_nom = 400;
    iafe_nom = pwr_nom/sqrt(3)/uafe_nom/0.9;
    iafe_freq = 50;
    udc = 660;
    CFi = 7.2e-3; CFi1 = 2*CFi; CFi2 = 2*CFi;
    RCFi = 1e-3; RCFi1 = RCFi/2; RCFi2 = RCFi/2;
    LFu = 330e-6; LFu_cm = 330e-6;
    RLFu = 157*0.05*LFu; RLFu_cm = 157*0.05*LFu_cm;
    CFu = 360e-6;
    RCFu = 50e-3;
    Rbrake = 2.5;

    afe400V = hw_afe_three_phase_setup('afe400V', pwr_nom, uafe_nom, iafe_nom, iafe_freq, udc, fpwm_afe, CFi, ...
        RCFi, CFi1, RCFi1, CFi2, RCFi2, LFu, RLFu, LFu_cm, RLFu_cm, CFu, RCFu, Rbrake);

    %% AFE 480V
    uafe_nom = 480;
    iafe_nom = pwr_nom/sqrt(3)/uafe_nom/0.9;
    iafe_freq = 60;
    udc = 750;
    CFi = 7.2e-3; CFi1 = 2*CFi; CFi2 = 2*CFi;
    RCFi = 1e-3; RCFi1 = RCFi/2; RCFi2 = RCFi/2;
    LFu = 330e-6; LFu_cm = 330e-6;
    RLFu = 157*0.05*LFu; RLFu_cm = 157*0.05*LFu_cm;
    RCFu = 50e-3;
    CFu = 360e-6;
    Rbrake = 2.5;

    afe480V = hw_afe_three_phase_setup('afe480V', pwr_nom, uafe_nom, iafe_nom, iafe_freq, udc, fpwm_afe, CFi, ...
        RCFi, CFi1, RCFi1, CFi2, RCFi2, LFu, RLFu, LFu_cm, RLFu_cm, CFu, RCFu, Rbrake);

    %% setup outputs
    if application_voltage == 690
        three_phase_afe = afe690V;
        afe690V.displayInfo();
    elseif application_voltage == 480
        three_phase_afe = afe480V;
        afe480V.displayInfo();
    else
        three_phase_afe = afe400V;
        afe400V.displayInfo();
    end

end
