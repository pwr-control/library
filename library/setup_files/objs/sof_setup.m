
%% Second order filter in state space representation, in continuous and in discrete time domain

        %% example of application
        
        % fcut = 10;
        % ts = 125e-6;
        % sof_10Hz = sof_setup(fcut, ts);
        % displayInfo(sof_10Hz);

classdef sof_setup
    properties
        fcut                double % Frequency cut [Hz]
        time_constant       double % Time constant [s]
        ts                  double {mustBePositive} % Sample time [s]
        ss_c                % Continuous State-space
        ss_d                % Discrete State-space
    end
    
    methods
        function obj = sof_setup(fcut, ts)
            if nargin > 0
                obj.fcut = fcut;
                obj.ts = ts;
                
                % Standard relation: tau = 1 / (2 * pi * fcut)
                obj.time_constant = 1 / (2 * pi * fcut);
                
                % Define the continuous transfer function
                % SOF: H(s) = 1 / (tau*s + 1)^2
                s = tf('s');
                sof_c = 1 / (obj.time_constant * s + 1)^2;
                
                % Convert to State-Space (Continuous)
                obj.ss_c = ss(sof_c);
            
                % Convert to State-Space (Discrete) 
                sof_d = c2d(sof_c, ts, 'zoh'); 
                obj.ss_d = ss(sof_d);
            end
        end

        function displayInfo(obj)
            fprintf('--- Second Order Filter Info ---\n');
            fprintf('Cutoff Frequency: %.2f Hz\n', obj.fcut);
            fprintf('Sample Time:      %.6f s\n', obj.ts);
            fprintf('\nContinuous State-Space:\n');
            disp(obj.ss_c);
            fprintf('\nDiscrete State-Space:\n');
            disp(obj.ss_d);
            fprintf('---------------------------\n');
        end
    end
end