
%% high power ideal switch
device_name = 'ideal_power_switch';
Vth = 5.5;                                              % [V]
Ron = 1.5e-3;                                           % [Ohm]
Rds_on = Ron;                                           % [Ohm]
Vdon_diode = 2;                                         % [V]
Vgamma = Vdon_diode;                                    % [V]
Rdon_diode = 0.15e-3;                                   % [Ohm]
Irr = 900;                                              % [A]
Csnubber = 10e-9;                                       % [F]
Rsnubber = 2200;                                        % [Ohm]

% ------------------------------------------------------------