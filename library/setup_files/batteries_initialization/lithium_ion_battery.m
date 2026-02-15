function data = lithium_ion_battery(nominal_voltage, nominal_power, soc_init, ts)

    data.ubattery = nominal_voltage;
    data.pnom = nominal_power;
    
    data.typical_cell_voltage = 3.6;
    data.number_of_cells = floor(nominal_voltage/data.typical_cell_voltage)-1; % nominal is 100
    
    % stato of charge init
    data.soc_init = soc_init; 
    
    data.R = 8.3143;
    data.F = 96487;
    data.T = 273.15+40;
    data.Q = 50; %Hr*A
    
    data.Vbattery_nom = data.ubattery;
    data.Pbattery_nom = data.pnom;
    data.Ibattery_nom = data.Pbattery_nom/data.Vbattery_nom;
    data.Rmax = data.Vbattery_nom^2/(data.Pbattery_nom*0.1);
    data.Rmin = data.Vbattery_nom^2/(data.Pbattery_nom);
    
    data.E_1 = -1.031;
    data.E0 = 3.485;
    data.E1 = 0.2156;
    data.E2 = 0;
    data.E3 = 0;
    data.Elog = -0.05;
    data.alpha = 35;
    
    data.R0 = 0.035;
    data.R1 = 0.035;
    data.C1 = 0.5;
    data.M = 125;
    
    data.q1Kalman = ts^2;
    data.q2Kalman = ts^1;
    data.q3Kalman = 0;
    data.rKalman = 1;
    
    Zmodel = (0:1e-3:1);
    data.ocv_model = data.E_1*exp(-Zmodel*data.alpha) + data.E0 + data.E1*Zmodel + data.E2*Zmodel.^2 +...
        data.E3*Zmodel.^3 + data.Elog*log(1-Zmodel+ts);
    figure; 
    plot(Zmodel,data.ocv_model,'LineWidth',2);
    xlabel('state of charge [p.u.]');
    ylabel('open circuit voltage [V]');
    title('open circuit voltage(state of charge)');
    grid on

end