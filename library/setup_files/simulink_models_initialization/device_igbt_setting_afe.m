function afe = device_igbt_setting_afe(fpwm)
    afe.Vth = evalin('base', 'Vth');                                 % [V]
    afe.Vce_sat = evalin('base', 'Vce_sat');                          % [V]
    afe.Rce_on = evalin('base', 'Rce_on');                            % [Ohm]
    afe.Vdon_diode = evalin('base', 'Vdon_diode');                    % [V]
    afe.Rdon_diode = evalin('base', 'Rdon_diode');                    % [Ohm]
    afe.Eon = evalin('base', 'Eon');                                  % [J] @ Tj = 125°C
    afe.Eoff = evalin('base', 'Eoff');                                % [J] @ Tj = 125°C
    afe.Erec = evalin('base', 'Erec');                                % [J] @ Tj = 125°C
    afe.Voff_sw_losses = evalin('base', 'Voff_sw_losses');            % [V]
    afe.Ion_sw_losses = evalin('base', 'Ion_sw_losses');              % [A]
    afe.JunctionTermalMass = evalin('base', 'JunctionTermalMass');    % [J/K]
    afe.Rtim = evalin('base', 'Rtim');                                % [K/W]
    afe.Rth_switch_JC = evalin('base', 'Rth_switch_JC');              % [K/W]
    afe.Rth_switch_CH = evalin('base', 'Rth_switch_CH');              % [K/W]
    afe.Rth_switch_JH = evalin('base', 'Rth_switch_JH');              % [K/W]
    afe.Rth_diode_JC = evalin('base', 'Rth_switch_JC');               % [K/W]
    afe.Rth_diode_CH = evalin('base', 'Rth_switch_CH');               % [K/W]
    afe.Rth_diode_JH = evalin('base', 'Rth_switch_JH');               % [K/W]
    afe.Lstray_module = evalin('base', 'Lstray_module');              % [H]
    afe.Irr = evalin('base', 'Irr');                                  % [A]
    afe.Csnubber = evalin('base', 'Csnubber');                        % [F]
    afe.Rsnubber = evalin('base', 'Rsnubber');                        % [Ohm]
    afe.Cies = evalin('base', 'Cies');                                % [F]
    
    afe.Csnubber_zvs = (afe.Irr)^2*afe.Lstray_module/(evalin('base', 'Vdc_bez'))^2;
    afe.Rsnubber_zvs = 1/(afe.Csnubber_zvs*fpwm)/5;
end