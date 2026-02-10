function ideal_switch = device_ideal_switch_setting(fpwm)
    ideal_switch.Vth = evalin('base', 'Vth');                                  % [V]
    ideal_switch.Rds_on = evalin('base', 'Rds_on');                            % [Ohm]
    ideal_switch.Vdon_diode = evalin('base', 'Vdon_diode');                    % [V]
    ideal_switch.Vgamma = evalin('base', 'Vgamma');                            % [V]
    ideal_switch.Rdon_diode = evalin('base', 'Rdon_diode');                    % [Ohm]
    ideal_switch.Csnubber = evalin('base', 'Csnubber');                        % [F]
    ideal_switch.Rsnubber = evalin('base', 'Rsnubber');                        % [Ohm]
    ideal_switch.Irr = evalin('base', 'Irr');                                  % [A]
    Lstray_module = evalin('base', 'Lstray_module');
    ideal_switch.Csnubber_zvs = (ideal_switch.Irr)^2*Lstray_module/(evalin('base', 'Vdc_bez'))^2;
    ideal_switch.Rsnubber_zvs = 1/(ideal_switch.Csnubber_zvs*fpwm)/5;
end