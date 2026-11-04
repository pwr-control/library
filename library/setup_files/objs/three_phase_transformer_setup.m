
%% example
% name = 'Dyn11-690V-690V-1600kW';
% delta_star = 1; % 1: delta primary (Dyn), 0: star primary (Yyn); the secondary is always star
% pwr_nom = 1600e3;
% u1_nom = 690;
% u2_nom = 690;
% f_nom = 50;
% eta = 98;
% ucc = 4.6;
% i1m = 10; % line no-load current
% p_iron = 10e3;
% n2 = 14;
% n1 = floor(n2*sqrt(3));
% core_area = 0.05;
% core_length = 2.5;
% mur = 10e3;
% trafo = three_phase_transformer_setup(name, delta_star, pwr_nom, u1_nom, u2_nom, f_nom, eta, ucc, ...
% i1m, p_iron, n1, n2, core_area, core_length, mur);

% two simple calculation (the line no-load current i1m from the coil inductance Lm1 of the geometry):
% Lm1 = (n1^2 * mu0 * mur * core_area) / core_length;
% i1m = sqrt(3)*u1_nom/Lm1/(2*pi*f_nom);   % delta primary: the coil sees the line voltage
% i1m = u1_nom/sqrt(3)/Lm1/(2*pi*f_nom);   % star primary: the coil sees the phase voltage

% The transformer is modelled with three single-phase transformers (foundation block
% single_phase_transformer, parameters Rd1, Ld1, Lm1, Rfe1, Rd2, Ld2, n1, n2, psi): the fields are the
% data of ONE COIL. A delta primary coil sees the line voltage and carries the line current divided by
% sqrt(3): its resistance and leakage inductance are 3 x the star-equivalent values and its magnetizing
% branch (Lm1, Rfe1, psi) is referred to the line voltage. A star coil sees the phase voltage and carries
% the line current: coil data = star-equivalent data. The secondary coil is always star.

%% class definition
classdef three_phase_transformer_setup
    properties
        name                string
        delta_star          % Dyn delta_star == 1, Yyn delta_star == 0
        pwr_nom             double {mustBePositive} % Nominal power [W]
        u1_nom              double {mustBePositive} % Transformer nominal primary side line-to-line voltage [V]
        i1_nom              double {mustBePositive} % Transformer nominal primary side line current [A]
        u2_nom              double {mustBePositive} % Transformer nominal secondary side line-to-line voltage [V]
        i2_nom              double {mustBePositive} % Transformer nominal secondary side line current [A]
        n1                  double {mustBePositive} % Turns of the primary coil []
        n2                  double {mustBePositive} % Turns of the secondary coil []
        f_nom               double {mustBePositive} % Nominal frequency [Hz]
        eta                 double {mustBePositive} % Transformer efficiency [%]
        ucc                 double {mustBePositive} % Transformer short circuit voltage [%]
        i1m                 double {mustBePositive} % Transformer primary side no-load (magnetizing) LINE current [A]
        n12                 double {mustBePositive} % Transformer U1/U2 (line-to-line voltages) []
        u1_coil             double {mustBePositive} % Voltage of the primary coil: U1 for delta, U1/sqrt(3) for star [V]
        i1m_coil            double {mustBePositive} % Magnetizing current of the primary coil: i1m/sqrt(3) for delta, i1m for star [A]
        Rd1                 double {mustBePositive} % Primary coil winding resistance [Ohm]
        Lsigma              double {mustBePositive} % Transformer leakage inductance, star equivalent on the primary side [H]
        Ld1                 double {mustBePositive} % Primary coil leakage inductance [H]
        Lm1                 double {mustBePositive} % Primary coil magnetization inductance [H]
        Rd2                 double {mustBePositive} % Secondary coil winding resistance [Ohm]
        Ld2                 double {mustBePositive} % Secondary coil leakage inductance [H]
        Lm2                 double {mustBePositive} % Magnetization inductance seen from the secondary coil [H]
        p_iron              double {mustBePositive} % Transformer iron losses, total of the three limbs [W]
        Rfe1                double {mustBePositive} % Primary coil equivalent iron losses resistance [Ohm]
        psi                 double {mustBePositive} % Peak flux linkage of the primary coil at rated voltage [Vs]
        core_area           double {mustBePositive} % Core Area [m^2]
        core_length         double {mustBePositive} % Core Length [m]
        mu0                 double {mustBePositive} % Air permeability [N/m]
        mur                 double {mustBePositive} % Relative permeability [pu]
    end
    
    methods

        function obj = three_phase_transformer_setup(name, delta_star, pwr_nom, u1_nom, u2_nom, f_nom, eta, ...
                ucc, i1m, p_iron, n1, n2, core_area, core_length, mur)
            if nargin > 0
                obj.name = name;
                obj.delta_star = delta_star;
                obj.pwr_nom = pwr_nom;
                obj.u1_nom = u1_nom;
                obj.i1_nom = obj.pwr_nom/sqrt(3)/obj.u1_nom;
                obj.u2_nom = u2_nom;
                obj.i2_nom = obj.pwr_nom/sqrt(3)/obj.u2_nom;
                obj.f_nom = f_nom;
                obj.ucc = ucc;
                obj.eta = eta;
                obj.i1m = i1m;
                obj.n12 = obj.u1_nom/obj.u2_nom;

                obj.n1 = n1;
                obj.n2 = n2;

                omega = 2*pi*obj.f_nom;

                % primary coil: delta (Dy) sees the line voltage and carries the line current / sqrt(3),
                % so its resistance and leakage are k1 = 3 times the star-equivalent values; star (Yy): k1 = 1
                if obj.delta_star == 1
                    k1 = 3;
                    obj.u1_coil = obj.u1_nom;
                else
                    k1 = 1;
                    obj.u1_coil = obj.u1_nom/sqrt(3);
                end
                obj.i1m_coil = obj.i1m/sqrt(k1);

                % leakage from the short-circuit voltage and copper losses (1 - eta)*pwr_nom, half per winding,
                % both as star equivalents on the primary side
                obj.Lsigma = (obj.u1_nom*obj.ucc/100/sqrt(3)/obj.i1_nom/omega);
                Rd_star = 0.5 * ((1 - obj.eta/100) * obj.pwr_nom / 3 / obj.i1_nom^2);
                obj.Ld1 = k1 * obj.Lsigma / 2;
                obj.Rd1 = k1 * Rd_star;

                % secondary coil (star): star-equivalent values referred with the line-to-line ratio
                obj.Ld2 = obj.Lsigma / 2 / (obj.n12)^2;
                obj.Rd2 = Rd_star / (obj.n12)^2;

                % magnetizing branch of the primary coil at its own voltage; iron losses one third per limb
                obj.Lm1 = obj.u1_coil/obj.i1m_coil/omega;
                obj.Lm2 = obj.Lm1 / (obj.u1_coil/(obj.u2_nom/sqrt(3)))^2;   % coil turns ratio N1/N2
                obj.p_iron = p_iron;
                obj.Rfe1 = obj.u1_coil^2/(obj.p_iron/3);
                obj.psi = sqrt(2)*obj.u1_coil/omega;                           % = Lm1*i1m_coil*sqrt(2)

                obj.core_area = core_area;
                obj.core_length = core_length;
                obj.mu0 = 4*pi*1e-7;
                obj.mur = mur;
            end
        end
        
        function displayInfo(obj)
            fprintf('Three Phase Transformer Setup: %s\n', obj.name);
            fprintf('Primary Side Leakage Inductance: %.2f H | Secondary Side Leakage Inductance: %.2f H\n', obj.Ld1, obj.Ld2);
            fprintf('Primary Side Magnetization Inductance: %.2f H\n', obj.Lm1);
            fprintf('Primary Coil Resistance: %.2f mOhm | Secondary Coil Resistance: %.2f mOhm | Rfe1: %.1f Ohm\n', obj.Rd1*1e3, obj.Rd2*1e3, obj.Rfe1);
            fprintf('---------------------------\n');
        end
    end
end

