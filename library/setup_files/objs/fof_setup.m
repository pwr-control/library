
%% First order filter in state space representation, in continuous and in discrete time domain

        %% example of application
        
        % fcut = 10;
        % ts = 125e-6;
        % fof_10Hz = fof_setup(fcut, ts);
        % displayInfo(fof_10Hz);

classdef fof_setup
    properties
        fcut                double % Frequency cut [Hz]
        time_constant       double % Time constant [s]
        ts                  double {mustBePositive} % Sample time [s]
        ss_c                % Continuous State-space
        ss_d                % Discrete State-space
    end
    
    methods
        function obj = fof_setup(fcut, ts)
            if nargin > 0
                obj.fcut = fcut;
                obj.ts = ts;
                
                % Standard relation: tau = 1 / (2 * pi * fcut)
                obj.time_constant = 1 / (2 * pi * fcut);
                
                % Define the continuous transfer function
                % FOF: H(s) = 1 / (tau*s + 1)
                s = tf('s');
                fof_c = 1 / (obj.time_constant * s + 1);
                
                % Convert to State-Space (Continuous)
                obj.ss_c = ss(fof_c);
            
                % Convert to State-Space (Discrete) 
                fof_d = c2d(fof_c, ts, 'zoh'); 
                obj.ss_d = ss(fof_d);
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