function three_phase_inverter = three_phase_inverter_hwdata(application_voltage, pwr_nom, fpwm_inv)

    %% dclink for three level is splitted into two parts CFi1, CFi2
    % for DC/DC is used CFi1_dc1, CFi2_dc1, CFi1_dc2, and CFi2_dc2
    
  
    %% INVERTER 690V - 250kW
    u_inv_nom = 550;
    i_inv_nom = 370;
    i_inv_freq = 15.6;
    udc = 1070;
    LFi = 230e-6; LFi_cm = 230e-6;
    RLFi = 157*0.05*LFi; RLFi_cm = 157*0.05*LFi_cm;
    inv690V_250kW = hw_inverter_three_phase_setup('inv690V_250kW', pwr_nom, u_inv_nom, i_inv_nom, i_inv_freq, udc, fpwm_inv, LFi, RLFi, LFi_cm, RLFi_cm);

    %% INVERTER 400V - 250kW
    u_inv_nom = 400;
    i_inv_nom = 470;
    i_inv_freq = 15.6;
    udc = 660;
    LFi = 160e-6; LFi_cm = 160e-6;
    RLFi = 157*0.05*LFi; RLFi_cm = 157*0.05*LFi_cm;
    inv400V_250kW = hw_inverter_three_phase_setup('inv400V_250kW', pwr_nom, u_inv_nom, i_inv_nom, i_inv_freq, udc, fpwm_inv, LFi, RLFi, LFi_cm, RLFi_cm);

    %% INVERTER 480V - 250kW
    u_inv_nom = 400;
    i_inv_nom = 470;
    i_inv_freq = 15.6;
    udc = 750;
    LFi = 160e-6; LFi_cm = 160e-6;
    RLFi = 157*0.05*LFi; RLFi_cm = 157*0.05*LFi_cm;
    inv480V_250kW = hw_inverter_three_phase_setup('inv480V_250kW', pwr_nom, u_inv_nom, i_inv_nom, i_inv_freq, udc, fpwm_inv, LFi, RLFi, LFi_cm, RLFi_cm);

    %% setup outputs
    if application_voltage == 690
        three_phase_inverter = inv690V_250kW;
        inv690V_250kW.displayInfo();
    elseif application_voltage == 480
        three_phase_inverter = inv480V_250kW;
        inv480V_250kW.displayInfo();
    else
        three_phase_inverter = inv400V_250kW;
        inv400V_250kW.displayInfo();
    end

end
