
%% example
% name = 'Dyn11-690V-690V-1600kW'; % the clock number of the vector group is read from the name (Dyn11, Yyn0, ...)
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
% trafo = three_phase_transformer_setup(..., mur, lm0_pu); % optional: zero-sequence magnetizing inductance [pu]

% two simple calculation (the line no-load current i1m from the coil inductance Lm1 of the geometry):
% Lm1 = (n1^2 * mu0 * mur * core_area) / core_length;
% i1m = sqrt(3)*u1_nom/Lm1/(2*pi*f_nom);   % delta primary: the coil sees the line voltage
% i1m = u1_nom/sqrt(3)/Lm1/(2*pi*f_nom);   % star primary: the coil sees the phase voltage

% SI fields. The transformer is modelled with three single-phase transformers (foundation block
% single_phase_transformer, parameters Rd1, Ld1, Lm1, Rfe1, Rd2, Ld2, n1, n2, psi): the SI fields are the
% data of ONE COIL. A delta primary coil sees the line voltage and carries the line current divided by
% sqrt(3): its resistance and leakage inductance are 3 x the star-equivalent values and its magnetizing
% branch (Lm1, Rfe1, psi) is referred to the line voltage. A star coil sees the phase voltage and carries
% the line current: coil data = star-equivalent data. The secondary coil is always star.
%
% Per-unit fields (*_pu and the struct pu). Base of a coil as in the Simscape components of the library
% (configurable_transformer, +three_phase_transformer): V^2/Sr for a star coil, 3*V^2/Sr for a delta coil
% (Zcoil1, Zcoil2), so that the same pu value gives the same line-side behaviour for either connection;
% Lsigma_pu and i1m_pu are on the line quantities (Zbase1 = u1_nom^2/pwr_nom, i1_nom). From the nameplate:
% Rd1_pu = Rd2_pu = (1 - eta/100)/2, Ld1_pu = Ld2_pu = ucc/200, Lm1_pu = i1_nom/i1m, Rfe1_pu = pwr_nom/p_iron.
% The struct pu holds the parameters of the block configurable_trafo (masked_models/electrical_machines,
% one primary, three-phase secondary): Sr, V1, V3, fr, r1, l1, r3, l3, lm, lm0, rfe, clock3. For the blocks
% transformer_Dyn / transformer_Yyn of +three_phase_transformer use V2 = pu.V3, r2 = pu.r3, l2 = pu.l3,
% clock = pu.clock3. The zero-sequence magnetizing inductance lm0 is not on the nameplate: give it as the
% optional last argument lm0_pu (a fraction of a pu for a three-limb core, e.g. 0.5); default lm0 = lm
% (bank of three single-phase units or five-limb core, i.e. the three single-phase transformers).

%% class definition
classdef three_phase_transformer_setup
    properties
        name                string
        delta_star          % Dyn delta_star == 1, Yyn delta_star == 0
        vector_group        string  % Dyn11, Yyn0, ...: connection of the coils and clock number
        clock               double  % Clock number of the vector group: the secondary lags the primary by clock*30 deg []
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
        % per unit
        Zbase1              double {mustBePositive} % Base impedance of the primary side, line quantities: u1_nom^2/pwr_nom [Ohm]
        Zbase2              double {mustBePositive} % Base impedance of the secondary side, line quantities: u2_nom^2/pwr_nom [Ohm]
        Zcoil1              double {mustBePositive} % Base impedance of the primary coil: Zbase1 for star, 3*Zbase1 for delta [Ohm]
        Zcoil2              double {mustBePositive} % Base impedance of the secondary coil (star): Zbase2 [Ohm]
        Lsigma_pu           double {mustBePositive} % Total leakage inductance, star equivalent on Zbase1: ucc/100 [pu]
        Rd1_pu              double {mustBePositive} % Primary coil winding resistance on Zcoil1: (1 - eta/100)/2 [pu]
        Ld1_pu              double {mustBePositive} % Primary coil leakage inductance on Zcoil1: ucc/200 [pu]
        Lm1_pu              double {mustBePositive} % Primary coil magnetization inductance on Zcoil1: i1_nom/i1m [pu]
        Rfe1_pu             double {mustBePositive} % Primary coil iron losses resistance on Zcoil1: pwr_nom/p_iron [pu]
        Rd2_pu              double {mustBePositive} % Secondary coil winding resistance on Zcoil2: (1 - eta/100)/2 [pu]
        Ld2_pu              double {mustBePositive} % Secondary coil leakage inductance on Zcoil2: ucc/200 [pu]
        i1m_pu              double {mustBePositive} % Line no-load current over the rated current: 1/Lm1_pu [pu]
        lm0_pu              double {mustBePositive} % Zero-sequence magnetizing inductance on Zcoil1 (optional input, default Lm1_pu) [pu]
        pu                  struct  % Parameters of the block configurable_trafo: Sr, V1, V3, fr, r1, l1, r3, l3, lm, lm0, rfe, clock3
    end
    
    methods

        function obj = three_phase_transformer_setup(name, delta_star, pwr_nom, u1_nom, u2_nom, f_nom, eta, ...
                ucc, i1m, p_iron, n1, n2, core_area, core_length, mur, lm0_pu)
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

                % vector group: clock number from the name when it starts with it (Dyn11, Dyn5, Yyn0, Yyn6, ...),
                % otherwise 11 for a delta primary (Dyn11) and 0 for a star primary (Yyn0)
                [obj.clock, obj.vector_group] = three_phase_transformer_setup.vector_group_of(char(name), obj.delta_star);

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

                % per unit: coil bases of the Simscape components (star coil V^2/Sr, delta coil 3*V^2/Sr)
                obj.Zbase1 = obj.u1_nom^2/obj.pwr_nom;
                obj.Zbase2 = obj.u2_nom^2/obj.pwr_nom;
                obj.Zcoil1 = k1 * obj.Zbase1;
                obj.Zcoil2 = obj.Zbase2;
                obj.Lsigma_pu = omega*obj.Lsigma/obj.Zbase1;                   % = ucc/100
                obj.Rd1_pu = obj.Rd1/obj.Zcoil1;                               % = (1 - eta/100)/2
                obj.Ld1_pu = omega*obj.Ld1/obj.Zcoil1;                         % = ucc/200
                obj.Lm1_pu = omega*obj.Lm1/obj.Zcoil1;                         % = i1_nom/i1m
                obj.Rfe1_pu = obj.Rfe1/obj.Zcoil1;                             % = pwr_nom/p_iron
                obj.Rd2_pu = obj.Rd2/obj.Zcoil2;                               % = (1 - eta/100)/2
                obj.Ld2_pu = omega*obj.Ld2/obj.Zcoil2;                         % = ucc/200
                obj.i1m_pu = obj.i1m/obj.i1_nom;                               % = 1/Lm1_pu
                if nargin < 16 || isempty(lm0_pu)
                    obj.lm0_pu = obj.Lm1_pu;                                   % bank of single-phase units
                else
                    obj.lm0_pu = lm0_pu;                                       % three-limb core: a fraction of a pu
                end

                % parameters of the block configurable_trafo (one primary, three-phase secondary)
                obj.pu = struct('Sr', obj.pwr_nom, 'V1', obj.u1_nom, 'V3', obj.u2_nom, 'fr', obj.f_nom, ...
                    'r1', obj.Rd1_pu, 'l1', obj.Ld1_pu, 'r3', obj.Rd2_pu, 'l3', obj.Ld2_pu, ...
                    'lm', obj.Lm1_pu, 'lm0', obj.lm0_pu, 'rfe', obj.Rfe1_pu, 'clock3', obj.clock);
            end
        end
        
        function displayInfo(obj)
            fprintf('Three Phase Transformer Setup: %s (%s)\n', obj.name, obj.vector_group);
            fprintf('Primary Side Leakage Inductance: %.2f H | Secondary Side Leakage Inductance: %.2f H\n', obj.Ld1, obj.Ld2);
            fprintf('Primary Side Magnetization Inductance: %.2f H\n', obj.Lm1);
            fprintf('Primary Coil Resistance: %.2f mOhm | Secondary Coil Resistance: %.2f mOhm | Rfe1: %.1f Ohm\n', obj.Rd1*1e3, obj.Rd2*1e3, obj.Rfe1);
            fprintf('Per unit (coil bases %.4f / %.4f Ohm): r1 = %.4f, l1 = %.4f, r3 = %.4f, l3 = %.4f, lm = %.1f, lm0 = %.1f, rfe = %.0f, clock %d\n', ...
                obj.Zcoil1, obj.Zcoil2, obj.pu.r1, obj.pu.l1, obj.pu.r3, obj.pu.l3, obj.pu.lm, obj.pu.lm0, obj.pu.rfe, obj.pu.clock3);
            fprintf('---------------------------\n');
        end
    end

    methods (Static)
        function [clock, vector_group] = vector_group_of(name, delta_star)
            % clock number of the vector group from a name that starts with it (Dyn11, Dyn1, Yyn0, Yyn6, also
            % Dy11, Yy0); an odd clock number goes with a delta primary and a star secondary, an even one with
            % two star windings. A name without a vector group, or with a wrong parity, gives the default of the
            % connection (Dyn11 / Yyn0) and, for the wrong parity, a warning.
            if delta_star == 1
                clock = 11;
                prefix = 'Dyn';
            else
                clock = 0;
                prefix = 'Yyn';
            end
            tok = regexp(name, '^[DY][dy]n?(\d{1,2})', 'tokens', 'once');
            if ~isempty(tok)
                c = str2double(tok{1});
                if c >= 0 && c <= 11 && mod(c, 2) == mod(clock, 2)
                    clock = c;
                else
                    warning('three_phase_transformer_setup:clock', ...
                        'clock number %d of ''%s'' does not fit the connection (delta_star = %d): %s%d used', ...
                        c, name, delta_star, prefix, clock);
                end
            end
            vector_group = sprintf('%s%d', prefix, clock);
        end
    end
end

