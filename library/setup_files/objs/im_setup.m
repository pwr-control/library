
%% example of application

% pwr_nom = 250e3;
% u_nom = 400;
% i_nom = 432;
% freq_nom = 50;
% rpm_load = 992;
% number_poles = 6;
% eta = 0.95;
% cosphi = 0.88;
% Rs = 2e-3;
% u_no_load = u_nom;
% i_no_load = 135;
% f_no_load = freq_nom;
% u_cc = u_nom;
% i_cc = 3084;
% f_cc = freq_nom;
% Jm = 40;
% load_friction_factor = 0.3;
% im = im_setup('GM355L6-250kW', pwr_nom, u_nom, i_nom, freq_nom, rpm_load, number_poles, eta, cosphi, ...
%                         Rs, u_no_load, i_no_load, f_no_load, u_cc, i_cc, f_cc, Jm, load_friction_factor);
% displayInfo(im);

%% class definition
classdef im_setup
    properties
        name                    string % Name of the machine
        pwr_nom                 double {mustBePositive} % Nominal power [W]
        torque_nom              double {mustBePositive} % % Nominal torque [Nm]
        psi_nom                 double {mustBePositive} % Nominal flux [Vs]
        u_nom                   double {mustBePositive} % Nominal voltage [V]
        i_nom                   double {mustBePositive} % Nominal current [A]
        freq_nom                double {mustBePositive} % Nominal frequency [Hz]
        rpm_load                double {mustBePositive} % Load rpm [rpm]
        slip_nom                double {mustBePositive} % Nominal slip [pu]
        number_poles            double {mustBePositive} % Number of poles
        eta                     double {mustBePositive} % Efficiency [pu]
        cosphi                  double {mustBePositive} % cosphi [pu]
        Rs                      double {mustBePositive} % Machine phase resistance [Ohm]
        u_no_load               double {mustBePositive} % Voltage used for the no load test [V]
        i_no_load               double {mustBePositive} % No load test current [A]
        f_no_load               double {mustBePositive} % No load test frequency [Hz]
        rpm_no_load             double {mustBePositive} % Machine rpm at no load at nominal frequency [A]
        u_cc                    double {mustBePositive} % Voltage used for the rotor locked test [V]
        i_cc                    double {mustBePositive} % Rotor locked test current [A]
        f_cc                    double {mustBePositive} % Rotor locked test frequency [Hz]
        Jm                      double {mustBePositive} % Machine load intertia [kgm^2]
        load_friction_factor    double {mustBePositive} % Machine load friction factor [pu]
        load_friction           double {mustBePositive} % Machine load friction [Nms/rad]

        Ls          double {mustBePositive} % Stator inductace Ls = Lm + Lds [H]
        Lds         double {mustBePositive} % Stator leakage inductace [H]
        Lm          double {mustBePositive} % Machine magnetization inductance [H]
        Lr          double {mustBePositive} % Rotor inductace Lr = Lm + Ldr [H]
        Ldr         double {mustBePositive} % Rotor leakage inductace [H]
        Rr          double {mustBePositive} % Rotor resistance [Ohm]
        alpha       double {mustBePositive} % Alpha Rr/Lr [rad/s]
        pp          double {mustBePositive} % Number of pole pairs
        radpersecond2rpm
        tau_bez         double {mustBePositive} % Normalization torque factor [Nm]
        psi_bez         double {mustBePositive} % Normalization flux factor [Vs]
        ibez            double {mustBePositive} % Normalization current factor [A]
        im_bez          double {mustBePositive} % Normalization magnetization current factor [A]
        ubez            double {mustBePositive} % Normalization voltage factor [V]
        omega_bez       double {mustBePositive} % Normalization electrical pulsation factor [rad/s]
        omega_m_bez     double {mustBePositive} % Normalization mechanical pulsation factor [rad/s]
        omega_m_load    double {mustBePositive} % Nominal load pulsation [rad/s]
        
        Xbez            double {mustBePositive} % Normalization impedance factor (per system) [Ohm]
        Lbez            double {mustBePositive} % Normalization inductance factor (per system) [H]
        Rs_norm         double {mustBePositive} % Normalized stator resistance [pu]
        Ls_norm         double {mustBePositive} % Normalized stator inductance [pu]
        Lm_norm         double {mustBePositive} % Normalized magnetization inductance [pu]
        Lr_norm         double {mustBePositive} % Normalized rotor inductance [pu]
        Rr_norm         double {mustBePositive} % Normalized rotor resistace [pu]
        alpha_norm      double {mustBePositive} % Normalized alpha Rr_nom/Lr_norm [pu]
        psi_norm        double {mustBePositive} % Normalized flux [pu]
        Jm_norm         double {mustBePositive} % Normalized load inertia [pu]

        mu              % parameter for im dynamic model
        mu_norm         % parameter for im dynamic model
        beta            % parameter for im dynamic model
        beta_norm       % parameter for im dynamic model
        sigma           % parameter for im dynamic model
        sigma_norm      % parameter for im dynamic model
        gamma           % parameter for im dynamic model
        gamma_norm      % parameter for im dynamic model
        
    end
    
    methods
        function obj = im_setup(name, pwr_nom, u_nom, i_nom, freq_nom, rpm_load, number_poles, eta, cosphi, ...
                        Rs, u_no_load, i_no_load, f_no_load, u_cc, i_cc, f_cc, Jm, load_friction_factor)
            if nargin > 0
                obj.name = name;
                obj.pwr_nom = pwr_nom;
                obj.u_nom = u_nom;
                obj.i_nom = i_nom;
                obj.freq_nom = freq_nom;
                obj.rpm_load = rpm_load;
                obj.number_poles = number_poles;
                obj.eta = eta;
                obj.cosphi = cosphi;
                obj.Rs = Rs;
                obj.u_no_load = u_no_load;
                obj.i_no_load = i_no_load;
                obj.f_no_load = f_no_load;
                obj.u_cc = u_cc;
                obj.i_cc = i_cc;
                obj.f_cc = f_cc;
                obj.Jm = Jm;
                obj.load_friction_factor = load_friction_factor;
                obj.pp = obj.number_poles / 2;
                obj.radpersecond2rpm = 60/2/pi;
                obj.omega_bez = obj.freq_nom * 2*pi;
                obj.omega_m_bez = obj.omega_bez / obj.pp;
                obj.omega_m_load = obj.rpm_load / 60 * 2*pi;
                obj.rpm_no_load = obj.freq_nom * 60 / obj.pp;
                obj.slip_nom = (obj.rpm_no_load - obj.rpm_load) / obj.rpm_no_load;
                obj.torque_nom = obj.pwr_nom/obj.eta/obj.omega_m_bez;

                obj.Rr = Rs;
                obj = im_parameter_calculation(obj);  
                obj = optimizeRotorResistor(obj, obj.Rs/5, obj.Rs/100, obj.Rs*5, 0.05);
                
                obj.alpha = obj.Rr / obj.Lr;
                obj.mu = 3/2*obj.Lm/obj.Jm/obj.Lr;
                obj.sigma = obj.Ls * (1-(obj.Lm)^2/obj.Ls/obj.Lr);
                obj.beta = obj.Lm/obj.sigma/obj.Lr;
                obj.gamma = obj.Rs/obj.sigma + obj.beta * obj.alpha * obj.Lm;

                obj = im_normalization(obj);  
                
                obj.load_friction =  obj.torque_nom * load_friction_factor / obj.omega_m_bez;

            end
        end
        
        function obj = optimizeRotorResistor(obj, Rr_start, deltaRr, Rr_max, toll)
            Rr_temp = Rr_start;
            Tn = obj.torque_nom / 2; 
            T_min = obj.torque_nom * (1 - toll);
            T_max = obj.torque_nom * (1 + toll);
            while (Rr_temp < Rr_max)
                
                a = obj.omega_bez * obj.Lm * Rr_temp / obj.slip_nom;
                b = obj.omega_bez * obj.Lm * a;
                c = (Rr_temp / obj.slip_nom)^2 + (obj.omega_bez * obj.Lr)^2;
                d = (Rr_temp / obj.slip_nom)^2 + obj.omega_bez^2 * obj.Ldr * obj.Lr;
                e = obj.omega_bez^2 * obj.Lm * obj.Lr;
             
                ZssRe = obj.Rs + b/c;
                ZssIm = obj.omega_bez * obj.Lds + obj.omega_bez * obj.Lm * d/c;
                Zss_abs2 = ZssRe^2 + ZssIm^2;
                
                Is_ssRe = obj.u_nom/sqrt(3) * ZssRe / Zss_abs2;
                Is_ssIm = -obj.u_nom/sqrt(3) * ZssIm / Zss_abs2;
                
                Ir_ssRe = (a * Is_ssIm - e * Is_ssRe) / c;
                Ir_ssIm = -(a * Is_ssRe + e * Is_ssIm) / c;

                Ir_ss_abs2 = Ir_ssRe^2 + Ir_ssIm^2;
                Pmech = 3 * Ir_ss_abs2 * Rr_temp * (1 - obj.slip_nom) / obj.slip_nom;
                Tn = Pmech / obj.omega_m_load;
                
                if (Tn >= T_min && Tn <= T_max)
                    break; 
                end
                
                Rr_temp = Rr_temp + deltaRr;
            end
            obj.Rr = Rr_temp;
            obj.tau_bez = Tn;
        end

        function obj = im_parameter_calculation(obj)
            obj.Ls = obj.u_no_load/sqrt(3)/obj.i_no_load/(2*pi*obj.f_no_load);

            Zsigma = (obj.u_cc/sqrt(3))/obj.i_cc;
            Lsigma = sqrt(Zsigma^2-(obj.Rs + obj.Rr)^2)/(2*pi*obj.f_cc);
            obj.Lds = Lsigma/2;
            obj.Ldr = Lsigma - obj.Lds;
            obj.Lm = obj.Ls - obj.Lds;
            obj.Lr = obj.Lm + obj.Ldr;
            obj.psi_nom = obj.i_no_load * sqrt(2) * obj.Lm;            
            obj.psi_bez = obj.u_nom / sqrt(3/2) / obj.omega_bez; 
        end

        function obj = im_normalization(obj)

            obj.ubez = obj.u_nom / sqrt(3/2);      
            obj.ibez = obj.i_nom * sqrt(2);      
            obj.im_bez = obj.i_no_load * sqrt(2);      
            obj.Xbez = obj.ubez / obj.ibez;      
            obj.Lbez =  obj.Xbez / obj.omega_bez;    
            obj.Rs_norm = obj.Rs / obj.Xbez;
            obj.Rr_norm = obj.Rr / obj.Xbez;
            obj.Ls_norm = obj.Ls / obj.Lbez;
            obj.Lr_norm = obj.Lr / obj.Lbez;
            obj.Lm_norm = obj.Lm / obj.Lbez;
            obj.alpha_norm = obj.Rr_norm / obj.Lr_norm;
            obj.psi_norm = obj.psi_nom / obj.psi_bez;
            obj.Jm_norm = 1/2*obj.Jm*obj.omega_m_bez/obj.torque_nom; 

            % obj.mu_norm = 3/2*obj.Lm_norm/obj.Jm_norm/obj.Lr_norm;
            obj.mu_norm = obj.Lm_norm/obj.Jm_norm/obj.Lr_norm;
            obj.sigma_norm = obj.Ls_norm * (1 - (obj.Lm_norm)^2/obj.Ls_norm/obj.Lr_norm); 
            obj.beta_norm = obj.Lm_norm/obj.sigma_norm/obj.Lr_norm;
            obj.gamma_norm = obj.Rs_norm/obj.sigma_norm + obj.beta_norm*obj.alpha_norm*obj.Lm_norm;

        end

        function displayInfo(obj)
            fprintf('Induction Machine: %s\n', obj.name);
            fprintf('IM Normalization Voltage Factor: %.1f V | IM Normalization Current Factor: %.1f A\n', obj.ubez, obj.ibez);
            fprintf('Rotor Resistance: %.5f Ohm\n', obj.Rr);
            fprintf('Magnetization Inductance: %.5f H\n', obj.Lm);
            fprintf('---------------------------\n');
        end
    end
end


