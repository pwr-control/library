function psm = psm_calculus_with_variants(application_voltage)
    
if application_voltage == 690
    psm_sys = 6;
    psm_pwr = 1600e3;
    psm_i = 2062;
    psm_rpm = 17.8;
    psm_np = 104;
    psm_eta = 96;
    psm_Lq = 1.26e-3;
    psm_Ld = 1.04e-3;
    psm_Jm = 900e3/6;
    
    % psm = pmsm_setup(name, pwr_nom, i_nom, rpm_nom, number_poles, eta, Ld, Lq, Jm, h5_percent, h7_percent)
    psm = pmsm_setup('WindGen', psm_sys, psm_pwr, psm_i, psm_rpm, psm_np, psm_eta, psm_Ld, psm_Lq, psm_Jm, 0, 0);
    displayInfo(psm);
else
    psm_sys = 4;
    psm_pwr = 1000e3;
    psm_i = 1880;
    psm_rpm = 24.6;
    psm_np = 80;
    psm_eta = 96;
    psm_Lq = 0.8e-3;
    psm_Ld = 0.5e-3;
    psm_Jm = 900e3/4;

    % psm = pmsm_setup(name, pwr_nom, i_nom, rpm_nom, number_poles, eta, Ld, Lq, Jm, h5_percent, h7_percent)
    psm = pmsm_setup('MotorDrive', psm_sys, psm_pwr, psm_i, psm_rpm, psm_np, psm_eta, psm_Ld, psm_Lq, psm_Jm, 0, 0);
    displayInfo(psm);
end