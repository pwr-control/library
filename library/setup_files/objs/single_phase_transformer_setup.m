
%% example
% name = 'Load Single Phase Transformer';
% pwr_nom = 170e3;
% u1_nom = 690;
% n1 = 50;
% n2 = 1;
% u2_nom = u1_nom/n1*n2;
% f_nom = 50;
% eta = 98;
% ucc = 2;
% i1m = 10;
% p_iron = 5e3;
% trafo = single_phase_transformer_setup(name, pwr_nom, u1_nom, u2_nom, n1, n2, f_nom, eta, ucc, i1m, p_iron);

% SI fields: data of the two windings (foundation block single_phase_transformer: Rd1, Ld1, Lm1, Rfe1, Rd2,
% Ld2, n1, n2, psi). Per-unit fields (*_pu and the struct pu) on the bases Zbase1 = u1_nom^2/pwr_nom and
% Zbase2 = u2_nom^2/pwr_nom, as the Simscape components of the library (tri_monophase_transformer and the
% single-phase secondary of configurable_transformer use V^2/Sr of the winding). From the nameplate:
% Rd1_pu = (1 - eta/100)/2, Ld1_pu = ucc/200, Lm1_pu = i1_nom/i1m, Rfe1_pu = pwr_nom/p_iron; the secondary
% values differ from the primary ones only if the turns ratio n1/n2 differs from u1_nom/u2_nom.

%% class definition
classdef single_phase_transformer_setup
    properties
        name        string
        pwr_nom     double {mustBePositive} % Nominal power [W]
        u1_nom      double {mustBePositive} % Transformer nominal primary side voltage [V]
        i1_nom      double {mustBePositive} % Transformer nominal primary side current [A]
        u2_nom      double {mustBePositive} % Transformer nominal secondary side voltage [V]
        i2_nom      double {mustBePositive} % Transformer nominal secondary side current [A]
        n1          double {mustBePositive} % Turns of the primary winding []
        n2          double {mustBePositive} % Turns of the secondary winding []
        f_nom       double {mustBePositive} % Nominal frequency [Hz]
        eta         double {mustBePositive} % Transformer efficiency [%]
        ucc         double {mustBePositive} % Transformer short circuit voltage [%]
        i1m         double {mustBePositive} % Transformer primary side magnetization current [A]
        n12         double {mustBePositive} % Transformer turns ratio n1/n2 []
        Rd1         double {mustBePositive} % Transformer primary side winding resistance [Ohm]
        Ld1         double {mustBePositive} % Transformer primary side leakage inductance [H]
        Lm1         double {mustBePositive} % Transformer primary side magnetization inductance [H]
        Rd2         double {mustBePositive} % Transformer secondary side winding resistance [Ohm]
        Ld2         double {mustBePositive} % Transformer secondary side leakage inductance [H]
        Lm2         double {mustBePositive} % Transformer secondary side magnetization inductance [H]
        p_iron      double {mustBePositive} % Transformer iron losses [W]
        Rfe1        double {mustBePositive} % Transformer primary side equivalent iron losses resistance [Ohm]
        psi         double {mustBePositive} % Transformer core flux [Vs]
        % per unit
        Zbase1      double {mustBePositive} % Base impedance of the primary side: u1_nom^2/pwr_nom [Ohm]
        Zbase2      double {mustBePositive} % Base impedance of the secondary side: u2_nom^2/pwr_nom [Ohm]
        Rd1_pu      double {mustBePositive} % Primary winding resistance on Zbase1: (1 - eta/100)/2 [pu]
        Ld1_pu      double {mustBePositive} % Primary leakage inductance on Zbase1: ucc/200 [pu]
        Lm1_pu      double {mustBePositive} % Primary magnetization inductance on Zbase1: i1_nom/i1m [pu]
        Rfe1_pu     double {mustBePositive} % Primary iron losses resistance on Zbase1: pwr_nom/p_iron [pu]
        Rd2_pu      double {mustBePositive} % Secondary winding resistance on Zbase2 [pu]
        Ld2_pu      double {mustBePositive} % Secondary leakage inductance on Zbase2 [pu]
        i1m_pu      double {mustBePositive} % Magnetizing current over the rated current: 1/Lm1_pu [pu]
        pu          struct  % Per-unit parameter set: Sr, V1, V2, fr, r1, l1, r2, l2, lm, rfe
    end
    
    methods

        function obj = single_phase_transformer_setup(name, pwr_nom, u1_nom, u2_nom, n1, n2, f_nom, eta, ucc, i1m, p_iron)
            if nargin > 0
                obj.name = name;
                obj.pwr_nom = pwr_nom;
                obj.u1_nom = u1_nom;
                obj.i1_nom = obj.pwr_nom/obj.u1_nom;
                obj.u2_nom = u2_nom;
                obj.i2_nom = obj.pwr_nom/obj.u2_nom;
                obj.f_nom = f_nom;
                obj.ucc = ucc;
                obj.eta = eta;
                obj.i1m = i1m;
                obj.n12 = n1/n2;

                obj.n1 = n1;
                obj.n2 = n2;

                omega = 2*pi*obj.f_nom;
                
                obj.Ld1 = 0.5 * (obj.u1_nom*obj.ucc/100/obj.i1_nom/omega);
                obj.Rd1 = 0.5 * ((1 - obj.eta/100) * obj.pwr_nom / obj.i1_nom^2); 
                obj.Lm1 = obj.u1_nom/obj.i1m/omega;
                
                obj.Ld2 = obj.Ld1 / (obj.n12)^2;
                obj.Rd2 = obj.Rd1 / (obj.n12)^2;
                obj.Lm2 = obj.Lm1 / (obj.n12)^2;
                
                obj.p_iron = p_iron;
                obj.Rfe1 = (obj.u1_nom)^2/(obj.p_iron);
                obj.psi = obj.Lm1*obj.i1m*sqrt(2);

                % per unit on the winding bases V^2/Sr
                obj.Zbase1 = obj.u1_nom^2/obj.pwr_nom;
                obj.Zbase2 = obj.u2_nom^2/obj.pwr_nom;
                obj.Rd1_pu = obj.Rd1/obj.Zbase1;                               % = (1 - eta/100)/2
                obj.Ld1_pu = omega*obj.Ld1/obj.Zbase1;                         % = ucc/200
                obj.Lm1_pu = omega*obj.Lm1/obj.Zbase1;                         % = i1_nom/i1m
                obj.Rfe1_pu = obj.Rfe1/obj.Zbase1;                             % = pwr_nom/p_iron
                obj.Rd2_pu = obj.Rd2/obj.Zbase2;
                obj.Ld2_pu = omega*obj.Ld2/obj.Zbase2;
                obj.i1m_pu = obj.i1m/obj.i1_nom;                               % = 1/Lm1_pu
                obj.pu = struct('Sr', obj.pwr_nom, 'V1', obj.u1_nom, 'V2', obj.u2_nom, 'fr', obj.f_nom, ...
                    'r1', obj.Rd1_pu, 'l1', obj.Ld1_pu, 'r2', obj.Rd2_pu, 'l2', obj.Ld2_pu, ...
                    'lm', obj.Lm1_pu, 'rfe', obj.Rfe1_pu);
            end
        end
        
        function displayInfo(obj)
            fprintf('Single Phase Transformer Setup: %s\n', obj.name);
            fprintf('Primary Side Leakage Inductance: %.2f H | Secondary Side Leakage Inductance: %.2f H\n', obj.Ld1, obj.Ld2);
            fprintf('Primary Side Magnetization Inductance: %.2f H\n', obj.Lm1);
            fprintf('Per unit (bases %.4f / %.4f Ohm): r1 = %.4f, l1 = %.4f, r2 = %.4f, l2 = %.4f, lm = %.1f, rfe = %.0f\n', ...
                obj.Zbase1, obj.Zbase2, obj.pu.r1, obj.pu.l1, obj.pu.r2, obj.pu.l2, obj.pu.lm, obj.pu.rfe);
            fprintf('---------------------------\n');
        end
    end
end

