function inv = device_igbt_setting_inv(fpwm)
    inv.Vth = evalin('base', 'Vth');                                 % [V]
    inv.Vce_sat = evalin('base', 'Vce_sat');                          % [V]
    inv.Rce_on = evalin('base', 'Rce_on');                            % [Ohm]
    inv.Vdon_diode = evalin('base', 'Vdon_diode');                    % [V]
    inv.Rdon_diode = evalin('base', 'Rdon_diode');                    % [Ohm]
    inv.Eon = evalin('base', 'Eon');                                  % [J] @ Tj = 125°C
    inv.Eoff = evalin('base', 'Eoff');                                % [J] @ Tj = 125°C
    inv.Erec = evalin('base', 'Erec');                                % [J] @ Tj = 125°C
    inv.Voff_sw_losses = evalin('base', 'Voff_sw_losses');            % [V]
    inv.Ion_sw_losses = evalin('base', 'Ion_sw_losses');              % [A]
    inv.JunctionTermalMass = evalin('base', 'JunctionTermalMass');    % [J/K]
    inv.Rtim = evalin('base', 'Rtim');                                % [K/W]
    inv.Rth_switch_JC = evalin('base', 'Rth_switch_JC');              % [K/W]
    inv.Rth_switch_CH = evalin('base', 'Rth_switch_CH');              % [K/W]
    inv.Rth_switch_JH = evalin('base', 'Rth_switch_JH');              % [K/W]
    inv.Rth_diode_JC = evalin('base', 'Rth_switch_JC');               % [K/W]
    inv.Rth_diode_CH = evalin('base', 'Rth_switch_CH');               % [K/W]
    inv.Rth_diode_JH = evalin('base', 'Rth_switch_JH');               % [K/W]
    inv.Lstray_module = evalin('base', 'Lstray_module');              % [H]
    inv.Irr = evalin('base', 'Irr');                                  % [A]
    inv.Csnubber = evalin('base', 'Csnubber');                        % [F]
    inv.Rsnubber = evalin('base', 'Rsnubber');                        % [Ohm]
    inv.Cies = evalin('base', 'Cies');                                % [F]
    
    inv.Csnubber_zvs = (inv.Irr)^2*inv.Lstray_module/evalin('base', 'Vdc_bez')^2;
    inv.Rsnubber_zvs = 1/(inv.Csnubber_zvs*fpwm)/5;
end

