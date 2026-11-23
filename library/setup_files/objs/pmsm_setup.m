
%% example of application
% psm = pmsm_setup(name, pwr_nom, i_nom, rpm_nom, number_poles, eta, Ld, Lq, Jm, h5_percent, h7_percent)
% psm = pmsm_setup('WindGen', 250e3, 2062, 17.8, 104, 96, 1.26e-3, 1.04e-3, 900e3, 0, 0);
% displayInfo(psm);

%% notation
% in three phase system nominal voltage means phase to phase rms;
% in three phase system nominal current means phase rms;
% terms with bez suffix mean quantity used for normalization;
% quantities with suffix bez mean peak per phase;
% quantities with alpha/beta means quantities seen respect a stationary
% reference frame;
% quantities with dq means quantities seen respect the synchonous rotating
% reference frame;

%% class definition
classdef pmsm_setup
    properties
        name                string % Name of the machine
        number_of_systems   double {mustBePositive} % Number of galvanically insulated three phase systems
        pwr_nom             double {mustBePositive} % Nominal power [W]
        torque_nom          double {mustBePositive} % Nominal torque [Nm]
        i_nom               double {mustBePositive} % Nominal current [A]
        rpm_nom             double {mustBePositive} % Nominal rpm [min^-1]
        number_poles        double {mustBePositive} % Number of poles
        eta                 double {mustBePositive} % Efficiency in percent [%]
        Ld                  double {mustBePositive} % Direct axis machine inductance [H]
        Lq                  double {mustBePositive} % Quadrature axis machine inductance [H]
        Lmu                 double {} % Leakage inductance used in the machine inductance matrix to be invertible, in general set to 5uH [H]
        Jm                  double {mustBePositive} % Load inertia: both machine rotor plus load inertia [kgm^2]
        h5_percent_psm      double {} % Firth flux harmonic in percent [%]
        h7_percent_psm      double {} % seventh flux harmonic in percent [%]
            
        Ld_m                double {mustBePositive} % Equivalent per system of the direct axis inductance [H]
        Lq_m                double {mustBePositive} % Equivalent per system of the quadrature axis machine inductance [H]
        Ls_m                double {mustBePositive} % Equivalent per system of the synchonous inductance [H]
        Lalpha_m            double {mustBePositive} % Equivalent per system of the alpha inductance [H]
        Lbeta_m             double {mustBePositive} % Equivalent per system of the beta inductance [H]
        La_m                double {mustBePositive} % Equivalent per system of the self inductance term [H]
        Lb_m                double {} % Equivalent per system of the mutual inductance term [H]
        Rs_m                double {mustBePositive} % Equivalent per system of the phase resistance [Ohm]
        Jm_m                double {mustBePositive} % Equivalent per system of the load intertia [kgm^2]
        radpersecond2rpm
        pp                  double {mustBePositive} % Number of pole pairs
        u_nom               double {mustBePositive} % Nominal voltage [V]
        ibez                double {mustBePositive} % Normalization current factor (per system) [A]
        ubez                double {mustBePositive} % Normalization voltage factor [V]
        freq_bez            double {mustBePositive} % Normalization electrical frequency factor [Hz]
        omega_bez           double {mustBePositive} % Normalization electrical pulsation factor [rad/s]
        omega_m_bez         double {mustBePositive} % Normalization mechanical pulsation factor [rad/s]
        tau_bez             double {mustBePositive} % Normalization torque factor (per system) [Nm]
        psi_m               double {mustBePositive} % Magnet flux [Vs]
        psi_bez             double {mustBePositive} % Normalization flux factor [Vs]
        Rs                  double {mustBePositive} % Machine phase resistance [Ohm]
        La                  double {mustBePositive} % Machine self inductance term [H]
        Lb                  double {} % Machine mutual inductance term [H]
        Lalpha              double {mustBePositive} % Machine alpha inductance [H]
        Lbeta               double {mustBePositive} % Machine beta inductance [H]
        Ls                  double {mustBePositive} % Machine synchronous inductance [H]

        Xbez                double {mustBePositive} % Normalization impedance factor (per system) [Ohm]
        Lbez                double {mustBePositive} % Normalization inductance factor (per system) [H]
        Rs_norm             double {mustBePositive} % Equivalent per system normalized phase resistance [pu]
        Ld_norm             double {mustBePositive} % Equivalent per system normalized direct inductance [pu]
        Lq_norm             double {mustBePositive} % Equivalent per system normalized quadrature inductance [pu]
        Ls_norm             double {mustBePositive} % Equivalent per system normalized synchronous inductance [pu]
        Lalpha_norm         double {mustBePositive} % Equivalent per system normalized alpha inductance [pu]
        Lbeta_norm          double {mustBePositive} % Equivalent per system normalized beta inductance [pu]
        La_norm             double {mustBePositive} % Equivalent per system normalized self inductance term [pu]
        Lb_norm             double {} % Equivalent per system normalized mutual inductance term [pu]
        psi_m_norm          double {mustBePositive} % Normalized flux [pu]
        Jm_norm             double {mustBePositive} % Normalized load inertia [pu]

        load_friction      double {mustBePositive} % Load friction [Hz]
        load_friction_m    double {mustBePositive} % Equivalent per system load friction [Hz]
    end
    
    methods
        function obj = pmsm_setup(name, number_of_systems, pwr_nom, i_nom, rpm_nom, number_poles, eta, Ld, Lq, Jm, h5_percent, h7_percent)
            if nargin > 0
                obj.name = name;
                obj.number_of_systems = number_of_systems;
                obj.pwr_nom = pwr_nom;
                obj.rpm_nom = rpm_nom;
                obj.omega_m_bez = obj.rpm_nom / 60 *2*pi;
                obj.torque_nom = obj.pwr_nom/obj.omega_m_bez;
                obj.i_nom = i_nom;
                obj.number_poles = number_poles;
                obj.eta = eta;
                obj.Ld = Ld;
                obj.Lq = Lq;
                obj.Jm = Jm;
                obj.h5_percent_psm = h5_percent;
                obj.h7_percent_psm = h7_percent;

                obj.Lmu = 5e-6;
                obj.Rs = (obj.pwr_nom / 3) * (1 - obj.eta/100) / (obj.i_nom)^2;       
                obj.Rs_m = obj.Rs * obj.number_of_systems;       
                obj.La = 1/3*(obj.Lq + obj.Ld);   
                obj.Lb = 1/3*(obj.Lq - obj.Ld);  
                obj.Lalpha = (obj.Ld + obj.Lq)/2;   
                obj.Lbeta = obj.Lalpha;
                obj.Ls = obj.Lalpha;    
                
                obj.Ld_m = obj.Ld * obj.number_of_systems;     
                obj.Lq_m = obj.Lq * obj.number_of_systems;     
                obj.Ls_m = obj.Ls * obj.number_of_systems;     
                obj.Lalpha_m = obj.Lalpha * obj.number_of_systems;     
                obj.Lbeta_m = obj.Lbeta * obj.number_of_systems;     
                obj.La_m = obj.La * obj.number_of_systems;     
                obj.Lb_m = obj.Lb * obj.number_of_systems;     
                obj.Jm_m = obj.Jm / obj.number_of_systems;    
                obj.radpersecond2rpm = 60/2/pi;
                obj.pp = obj.number_poles/2;
                obj.ibez = obj.i_nom / obj.number_of_systems * sqrt(2);
                obj.tau_bez = obj.torque_nom / obj.number_of_systems;
                obj.psi_m = obj.torque_nom /obj.number_of_systems / (3/2*obj.pp*obj.ibez);
                obj.psi_bez = obj.psi_m;
                obj.omega_bez = obj.omega_m_bez * obj.pp;         
                obj.freq_bez = obj.omega_bez / (2*pi);             
                obj.ubez = obj.psi_bez * obj.omega_bez;
                obj.u_nom = obj.ubez / sqrt(2/3);

                obj.Xbez = obj.ubez / obj.ibez;      
                obj.Lbez =  obj.Xbez / obj.omega_bez;    
                obj.Rs_norm = obj.Rs_m / obj.Xbez;
                obj.Ld_norm = obj.Ld_m / obj.Lbez;
                obj.Lq_norm = obj.Lq_m / obj.Lbez;
                obj.Ls_norm = obj.Ls_m / obj.Lbez;
                obj.Lalpha_norm = obj.Lalpha_m / obj.Lbez;
                obj.Lbeta_norm = obj.Lbeta_m / obj.Lbez;
                obj.La_norm = obj.La_m / obj.Lbez;
                obj.Lb_norm = obj.Lb_m / obj.Lbez;
                obj.psi_m_norm = obj.psi_m / obj.psi_bez;
                obj.Jm_norm = 1/2*obj.Jm*obj.omega_m_bez/obj.torque_nom; 

                obj.load_friction = obj.torque_nom / obj.omega_m_bez;
                obj.load_friction_m = obj.load_friction / obj.number_of_systems;
            end
        end
        
        function displayInfo(obj)
            fprintf('Permanent Magnet Synchronous Machine: %s\n', obj.name);
            fprintf('PSM Normalization Voltage Factor: %.1f V | PSM Normalization Current Factor: %.1f A\n', obj.ubez, obj.ibez);
            fprintf('Per-System Direct Axis Inductance: %.5f H\n', obj.Ld_m);
            fprintf('Per-System Quadrature Axis Inductance: %.5f H\n', obj.Lq_m);
            fprintf('---------------------------\n');
        end
    end
end


