function dab = device_igbt_setting_dab(fpwm)
    dab.Vth = evalin('base', 'Vth');                                 % [V]
    dab.Vce_sat = evalin('base', 'Vce_sat');                          % [V]
    dab.Rce_on = evalin('base', 'Rce_on');                            % [Ohm]
    dab.Vdon_diode = evalin('base', 'Vdon_diode');                    % [V]
    dab.Rdon_diode = evalin('base', 'Rdon_diode');                    % [Ohm]
    dab.Eon = evalin('base', 'Eon');                                  % [J] @ Tj = 125°C
    dab.Eoff = evalin('base', 'Eoff');                                % [J] @ Tj = 125°C
    dab.Erec = evalin('base', 'Erec');                                % [J] @ Tj = 125°C
    dab.Voff_sw_losses = evalin('base', 'Voff_sw_losses');            % [V]
    dab.Ion_sw_losses = evalin('base', 'Ion_sw_losses');              % [A]
    dab.JunctionTermalMass = evalin('base', 'JunctionTermalMass');    % [J/K]
    dab.Rtim = evalin('base', 'Rtim');                                % [K/W]
    dab.Rth_switch_JC = evalin('base', 'Rth_switch_JC');              % [K/W]
    dab.Rth_switch_CH = evalin('base', 'Rth_switch_CH');              % [K/W]
    dab.Rth_switch_JH = evalin('base', 'Rth_switch_JH');              % [K/W]
    dab.Rth_diode_JC = evalin('base', 'Rth_switch_JC');               % [K/W]
    dab.Rth_diode_CH = evalin('base', 'Rth_switch_CH');               % [K/W]
    dab.Rth_diode_JH = evalin('base', 'Rth_switch_JH');               % [K/W]
    dab.Lstray_module = evalin('base', 'Lstray_module');              % [H]
    dab.Irr = evalin('base', 'Irr');                                  % [A]
    dab.Csnubber = evalin('base', 'Csnubber');                        % [F]
    dab.Rsnubber = evalin('base', 'Rsnubber');                        % [Ohm]
    dab.Cies = evalin('base', 'Cies');                                % [F]
    
    dab.Csnubber_zvs = (dab.Irr)^2*dab.Lstray_module/(evalin('base', 'Vdc_bez'))^2;
    dab.Rsnubber_zvs = 1/(dab.Csnubber_zvs*fpwm)/5;
end