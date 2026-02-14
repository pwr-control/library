
function grid_emu_data = grid_emulator(nominal_power, application_voltage, vp_xi_pu, vn_xi_pu, vn_eta_pu)

    grid_emu_data.vp_xi_pu = vp_xi_pu;
    grid_emu_data.vn_xi_pu = vn_xi_pu;
    grid_emu_data.vp_eta_pu = 0;
    grid_emu_data.vn_eta_pu = vn_eta_pu;
    
    application690 = 690;
    application480 = 480;
    grid_emu_data.application_voltage = application_voltage;
    %% grid emulator output transformer
    grid_emu_data.Ptrafo = nominal_power;
    grid_emu_data.I0 = 5; % no load current
    grid_emu_data.Vcc_perc = 6.6; %cc voltage percente
    
    
    if (application690 == application_voltage)
        Vline1 = 690; % primary voltage
        Vline2 = 690; % secondary voltage
        f_grid = 50;
        Vdclink_nom = 1070;
    elseif (application480 == application_voltage)
        Vline1 = 480; % primary voltage
        Vline2 = 480; % secondary voltage
        f_grid = 60;
        Vdclink_nom = 750;
    else
        Vline1 = 400; % primary voltage
        Vline2 = 400; % secondary voltage
        f_grid = 50;
        Vdclink_nom = 660;
    end
    
    grid_emu_data.nominal_frequency = f_grid;
    grid_emu_data.nominal_voltage = Vline2;

    grid_emu_data.Vphase1 = Vline1/sqrt(3);
    grid_emu_data.Vphase2 = Vline2/sqrt(3);
    
    grid_emu_data.w_grid = f_grid*2*pi;

    grid_emu_data.omega_grid_emulator_nom = grid_emu_data.w_grid;
    grid_emu_data.omega_grid_nom = grid_emu_data.w_grid;
    grid_emu_data.Inom_trafo = grid_emu_data.Ptrafo/Vline2/sqrt(3);
    grid_emu_data.Ld2_trafo= grid_emu_data.Vphase2/(100/grid_emu_data.Vcc_perc)/grid_emu_data.Inom_trafo/(grid_emu_data.w_grid); %leakage inductace
    grid_emu_data.Rd2_trafo = 0.05*grid_emu_data.Ptrafo/3/grid_emu_data.Inom_trafo^2; 
    grid_emu_data.Lmu2_trafo= grid_emu_data.Vphase2/grid_emu_data.I0/(grid_emu_data.w_grid); %magentization inductance
    grid_emu_data.Piron = 1.4e3;
    grid_emu_data.Rm2_trafo = grid_emu_data.Vphase2^2/(grid_emu_data.Piron/3);
    grid_emu_data.psi_trafo = grid_emu_data.Lmu2_trafo*grid_emu_data.I0*sqrt(2);
    
    %% grid emulator others data
    grid_emu_data.kp_vgrid = 10;
    grid_emu_data.ki_vgrid = 45;
    grid_emu_data.k_ff = 1;
    
    %% voltage reference grid emulator
    if (application690 == 1)
        Igrid_phase_normalization_factor = 270*sqrt(2);
    elseif (application480 == 1)
        Igrid_phase_normalization_factor = 360*sqrt(2);
    else
        Igrid_phase_normalization_factor = 360*sqrt(2);
    end
    grid_emu_data.Vgrid_phase_normalization_factor = grid_emu_data.Vphase2*sqrt(2);
    grid_emu_data.I_phase_normalization_factor = Igrid_phase_normalization_factor; % misura della corrente 
    grid_emu_data.V_phase_normalization_factor = grid_emu_data.Vgrid_phase_normalization_factor; % misura della tensione dopo il trafo
    grid_emu_data.ugrid_factor = 1;
    
    if (application690 == application_voltage)
        Vemu_ref = 690/sqrt(3); % tensione di fase rms di riferimento in uscita al trafo
        Vemu_ref_norm = Vemu_ref * sqrt(2) / grid_emu_data.V_phase_normalization_factor;
    elseif (application480 == application_voltage)
        Vemu_ref = 480/sqrt(3); % tensione di fase rms di riferimento in uscita al trafo
        Vemu_ref_norm = Vemu_ref * sqrt(2) / grid_emu_data.V_phase_normalization_factor;
    else
        Vemu_ref = 400/sqrt(3); % tensione di fase rms di riferimento in uscita al trafo
        Vemu_ref_norm = Vemu_ref * sqrt(2) / grid_emu_data.V_phase_normalization_factor;
    end
    
    grid_emu_data.Vemu_ref = Vemu_ref;
    grid_emu_data.Vemu_ref_norm = Vemu_ref_norm;
    grid_emu_data.Vdclink_nom = Vdclink_nom;

end
