function ideal_switch = device_ideal_switch_setting(device, fpwm, udc)
%DEVICE_IDEAL_SWITCH_SETTING  Plain struct for the ideal-switch dataset.
%
%   ideal_switch = device_ideal_switch_setting(device, fpwm, udc)
%
%   device : dataset name, e.g. 'silicon_high_power_ideal_switch'
%   fpwm   : [Hz] switching frequency, used for the ZVS snubber
%   udc    : [V]  DC-link voltage, used for the ZVS snubber
%
%   See also DEVICE_DATA_LOAD.

p = device_data_load(device);
ideal_switch.device_name = p.device_name;
ideal_switch.Vth = p.Vth;                                  % [V]
ideal_switch.Rds_on = p.Rds_on;                            % [Ohm]
ideal_switch.Vdon_diode = p.Vdon_diode;                    % [V]
ideal_switch.Vgamma = p.Vgamma;                            % [V]
ideal_switch.Rdon_diode = p.Rdon_diode;                    % [Ohm]
ideal_switch.Csnubber = p.Csnubber;                        % [F]
ideal_switch.Rsnubber = p.Rsnubber;                        % [Ohm]
ideal_switch.Irr = p.Irr;                                  % [A]
ideal_switch.Lstray_module = p.Lstray_module;              % [H]
ideal_switch.Csnubber_zvs = (ideal_switch.Irr)^2*ideal_switch.Lstray_module/(udc)^2;
ideal_switch.Rsnubber_zvs = 1/(ideal_switch.Csnubber_zvs*fpwm)/5;
end
