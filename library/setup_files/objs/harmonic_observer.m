
%% example
% harmonic_obs = harmonic_observer(ts, omega_base, delta, pole1, pole2);


%% class definition
classdef harmonic_observer
    properties
        ts                  double {mustBePositive} % Sampling time [s]
        omega_base          double {mustBePositive} % Base pulsation [s]
        delta               double {mustBePositive} % damping []
        pole1               double {mustBePositive} % pole 1 to be placed [rad/s]
        pole2               double {mustBePositive} % pole 2 to be placed [rad/s]
        poles_hobs
        polesd_hobs
        A_hobs              % evolution matrix harmonic observer in continuous time domain
        C_hobs              % output matrix harmonic observer 
        Ad_hobs             % evolution matrix harmonic observer in discrete time domain
        L_hobs              % state observer feedback gains in continuous time domain
        Ld_hobs             % state observer feedback gains in discrete time domain
    end
    
    methods

        function obj = harmonic_observer(omega_base, delta, pole1, pole2, ts)
                obj.ts = ts;
                obj.omega_base = omega_base;
                obj.delta = delta;
                obj.A_hobs = [0 1; -obj.omega_base^2 -obj.delta*obj.omega_base];
                obj.C_hobs = [1 0];
                obj.Ad_hobs = eye(2) + obj.A_hobs * obj.ts;
                obj.pole1 = pole1;
                obj.pole2 = pole2;
                obj.poles_hobs = [-obj.pole1 -obj.pole2];
                obj.polesd_hobs = exp(obj.ts * obj.poles_hobs);
            obj.L_hobs = (acker(obj.A_hobs',obj.C_hobs', obj.poles_hobs))';
            obj.Ld_hobs = acker(obj.Ad_hobs',obj.C_hobs', obj.polesd_hobs)';
        end

    end
end


