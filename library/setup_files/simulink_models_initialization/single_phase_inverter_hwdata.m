function single_phase_inverter = single_phase_inverter_hwdata(application_voltage, pwr_nom, fpwm)

    %% dclink for three level is splitted into two parts CFi1, CFi2
  
  if (application_voltage == 400)
    %% Single Phase Inverter 400V application
    u_nom = application_voltage*1.35*0.9/sqrt(2);
    i_nom = pwr_nom/u_nom;
    udc_nom = 2/sqrt(3)*1.1*application_voltage*sqrt(2);
    f_nom = 50;
    CFi = 1500e-6 * 4; CFi1 = 2*CFi; CFi2 = 2*CFi;
    RCFi = 1e-3; RCFi1 = RCFi/2; RCFi2 = RCFi/2;
    LFu = 500e-6; LFu_cm = 500e-6;
    RLFu = 157*0.05*LFu; RLFu_cm = 157*0.05*LFu_cm;
    CFu = 200e-6;
    RCFu = 50e-3;
    Rbrake = 2.5;
  elseif (application_voltage == 480)
    %% Single Phase Inverter 480V application
    u_nom = application_voltage*1.35*0.9/sqrt(2);
    i_nom = pwr_nom/u_nom;
    udc_nom = 2/sqrt(3)*1.1*application_voltage*sqrt(2);
    f_nom = 60;
    CFi = 1500e-6 * 4; CFi1 = 2*CFi; CFi2 = 2*CFi;
    RCFi = 1e-3; RCFi1 = RCFi/2; RCFi2 = RCFi/2;
    LFu = 500e-6; LFu_cm = 500e-6;
    RLFu = 157*0.05*LFu; RLFu_cm = 157*0.05*LFu_cm;
    CFu = 200e-6;
    RCFu = 50e-3;
    Rbrake = 2.5;
  else
    %% Single Phase Inverter 690V application
    u_nom = application_voltage*1.35*0.9/sqrt(2);
    i_nom = pwr_nom/u_nom;
    udc_nom = 2/sqrt(3)*1.1*application_voltage*sqrt(2);
    f_nom = 50;
    CFi = 1500e-6 * 4; CFi1 = 2*CFi; CFi2 = 2*CFi;
    RCFi = 1e-3; RCFi1 = RCFi/2; RCFi2 = RCFi/2;
    LFu = 500e-6; LFu_cm = 500e-6;
    RLFu = 157*0.05*LFu; RLFu_cm = 157*0.05*LFu_cm;
    CFu = 200e-6;
    RCFu = 50e-3;
    Rbrake = 4;
  end


    single_phase_inverter = hw_single_phase_inverter_setup(application_voltage, pwr_nom, u_nom, i_nom, f_nom, udc_nom, fpwm, CFi, ...
        RCFi, CFi1, RCFi1, CFi2, RCFi2, LFu, RLFu, LFu_cm, RLFu_cm, CFu, RCFu, Rbrake);

end
