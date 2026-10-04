

%% class definition
classdef device_igbt_setting
% DEVICE_IGBT_SETTING  IGBT dataset: conduction, switching energies, thermal
% chain, gate and parasitic data, plus the optional parameter set of the
% igbt_dyn switching-dynamics model.
%
%   dev = device_igbt_setting(p, fpwm, udc)
%
%   p    : struct with the dataset, normally built by device_data_load from a
%          script in semiconductor_devices_data. Field names are the names
%          of the variables in the script.
%   fpwm : [Hz] switching frequency, used for the ZVS snubber
%   udc  : [V]  DC-link voltage, used for the ZVS snubber
%
%   Fields of p
%     required       : device_name, device_type and the list returned by
%                      device_igbt_setting.required_fields()
%     derived        : Rth_switch_JH, Rth_diode_JH = Rtim + JC + CH when the
%                      dataset does not give them
%     optional       : device_igbt_setting.optional_fields(), NaN if absent
%     igbt_dyn_param : optional struct with the igbt_dyn parameters
%                      (Vth, Kp, lam, Cge, Cgc0, Vjc, mc, Cce0, Vjo, mo, Rg,
%                      ftail, tauT, dsm). Missing entries are NaN, except
%                      lam = 0, dsm = 0.1 V, Rg = Rgate_internal and
%                      Vth -> Vth_dyn = Vth. has_dyn_param tells whether the
%                      set is complete.
%     anything else  : copied unchanged into the property extra
%
%   Normally called through device_igbt_setup(device, fpwm, udc).

    properties
        name                    string
        type                    string

        Vth                     % [V]
        Rce_on                  % [Ohm]
        Vce_sat                 % [V]
        Vdon_diode              % [V]
        Rdon_diode              % [Ohm]
        Eon                     % [J] at Voff_sw_losses, Ion_sw_losses, Tj of the dataset
        Eoff                    % [J] at Voff_sw_losses, Ion_sw_losses, Tj of the dataset
        Erec                    % [J] at Voff_sw_losses, Ion_sw_losses, Tj of the dataset
        Voff_sw_losses          % [V]
        Ion_sw_losses           % [A]
        JunctionTermalMass      % [J/K]
        Rtim                    % [K/W]
        Rth_switch_JC           % [K/W]
        Rth_switch_CH           % [K/W]
        Rth_switch_JH           % [K/W]
        Rth_diode_JC            % [K/W]
        Rth_diode_CH            % [K/W]
        Rth_diode_JH            % [K/W]
        Lstray_module           % [H]
        Irr                     % [A]
        Cies                    % [F]
        Cres                    % [F]
        Rgate_internal          % [Ohm]
        td_on                   % [s]
        trise                   % [s]
        td_off                  % [s]
        tfall                   % [s]
        Csnubber                % [F]
        Rsnubber                % [Ohm]
        Csnubber_zvs            % [F]
        Rsnubber_zvs            % [Ohm]

        % igbt_dyn parameters, from p.igbt_dyn_param of the dataset.
        % NaN = not characterized for this device.
        has_dyn_param = false;  %         true when the set below is complete
        Vth_dyn = NaN;          % [V]     threshold of the square-law channel fit
        Kp    = NaN;            % [A/V^2] transconductance parameter
        lam   = 0;              % [1/V]   output conductance
        Cge   = NaN;            % [F]     gate-emitter capacitance
        Cgc0  = NaN;            % [F]     Miller capacitance at Vgc = 0
        Vjc   = NaN;            % [V]     Miller junction potential
        mc    = NaN;            % [-]     Miller grading coefficient
        Cce0  = NaN;            % [F]     output capacitance at Vce = 0
        Vjo   = NaN;            % [V]     output junction potential
        mo    = NaN;            % [-]     output grading coefficient
        Rg    = NaN;            % [Ohm]   internal gate resistance
        ftail = NaN;            % [-]     tail fraction of the on-state current
        tauT  = NaN;            % [s]     tail time constant
        dsm   = 0.1;            % [V]     smoothing width (numerics)

        % dataset fields not listed above (Coes, Foster network, tables, ...)
        extra = struct();
    end

    methods
        function obj = device_igbt_setting(p, fpwm, udc)
            if nargin == 0
                return;
            end
            if nargin ~= 3 || ~isstruct(p)
                error('device_igbt_setting:input', ...
                      ['Usage: device_igbt_setting(p, fpwm, udc), with p the struct ' ...
                       'returned by device_data_load.']);
            end

            p = device_igbt_setting.add_derived(p);
            req = device_igbt_setting.required_fields();
            opt = device_igbt_setting.optional_fields();
            device_igbt_setting.check_fields(p, [{'device_name', 'device_type'}, req]);

            obj.name = p.device_name;
            obj.type = p.device_type;
            for k = 1:numel(req)
                obj.(req{k}) = p.(req{k});
            end
            for k = 1:numel(opt)
                if isfield(p, opt{k})
                    obj.(opt{k}) = p.(opt{k});
                else
                    obj.(opt{k}) = NaN;
                end
            end

            obj = obj.set_dyn_param(p);

            known = [{'device_name', 'device_type', 'igbt_dyn_param'}, req, opt];
            rest = setdiff(fieldnames(p), known);
            for k = 1:numel(rest)
                obj.extra.(rest{k}) = p.(rest{k});
            end

            obj.Csnubber_zvs = (obj.Irr)^2*obj.Lstray_module/(udc)^2;
            obj.Rsnubber_zvs = 1/(obj.Csnubber_zvs*fpwm)/5;
        end
    end

    methods (Access = private)
        function obj = set_dyn_param(obj, p)
            obj.Vth_dyn = obj.Vth;
            obj.Rg = obj.Rgate_internal;
            if isfield(p, 'igbt_dyn_param')
                d = p.igbt_dyn_param;
                if ~isstruct(d)
                    error('device_igbt_setting:dyn', ...
                          '%s: igbt_dyn_param must be a struct.', p.device_name);
                end
                f = fieldnames(d);
                unknown = setdiff(f, device_igbt_setting.dyn_fields());
                if ~isempty(unknown)
                    error('device_igbt_setting:dyn', ...
                          '%s: unknown igbt_dyn_param field(s): %s', ...
                          p.device_name, strjoin(unknown', ', '));
                end
                for k = 1:numel(f)
                    if strcmp(f{k}, 'Vth')
                        obj.Vth_dyn = d.Vth;
                    else
                        obj.(f{k}) = d.(f{k});
                    end
                end
            end
            need = {'Vth_dyn', 'Kp', 'Cge', 'Cgc0', 'Vjc', 'mc', 'Cce0', 'Vjo', 'mo', ...
                    'Rg', 'ftail', 'tauT'};
            ok = true;
            for k = 1:numel(need)
                ok = ok && isscalar(obj.(need{k})) && isfinite(obj.(need{k}));
            end
            obj.has_dyn_param = ok;
        end
    end

    methods (Static)
        function f = required_fields()
            f = {'Vth', 'Rce_on', 'Vce_sat', 'Vdon_diode', 'Rdon_diode', ...
                 'Eon', 'Eoff', 'Erec', 'Voff_sw_losses', 'Ion_sw_losses', ...
                 'JunctionTermalMass', 'Rtim', ...
                 'Rth_switch_JC', 'Rth_switch_CH', 'Rth_switch_JH', ...
                 'Rth_diode_JC', 'Rth_diode_CH', 'Rth_diode_JH', ...
                 'Lstray_module', 'Irr', 'Csnubber', 'Rsnubber'};
        end

        function f = optional_fields()
            f = {'Cies', 'Cres', 'Rgate_internal', 'td_on', 'trise', 'td_off', 'tfall'};
        end

        function f = dyn_fields()
            f = {'Vth', 'Kp', 'lam', 'Cge', 'Cgc0', 'Vjc', 'mc', 'Cce0', 'Vjo', 'mo', ...
                 'Rg', 'ftail', 'tauT', 'dsm'};
        end
    end

    methods (Static, Access = private)
        function p = add_derived(p)
            if ~isfield(p, 'Rth_switch_JH') && all(isfield(p, {'Rtim', 'Rth_switch_JC', 'Rth_switch_CH'}))
                p.Rth_switch_JH = p.Rtim + p.Rth_switch_JC + p.Rth_switch_CH;
            end
            if ~isfield(p, 'Rth_diode_JH') && all(isfield(p, {'Rtim', 'Rth_diode_JC', 'Rth_diode_CH'}))
                p.Rth_diode_JH = p.Rtim + p.Rth_diode_JC + p.Rth_diode_CH;
            end
        end

        function check_fields(p, list)
            missing = list(~isfield(p, list));
            if ~isempty(missing)
                if isfield(p, 'device_name')
                    dev = p.device_name;
                else
                    dev = '(no device_name)';
                end
                error('device_igbt_setting:missingField', ...
                      'Dataset %s: missing field(s) %s', dev, strjoin(missing, ', '));
            end
        end
    end
end
