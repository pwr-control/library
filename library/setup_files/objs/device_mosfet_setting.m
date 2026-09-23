

%% class definition
classdef device_mosfet_setting
% DEVICE_MOSFET_SETTING  MOSFET / SiC MOSFET dataset: conduction, switching
% energies, single-die thermal chain, stray inductances, capacitances.
%
%   dev = device_mosfet_setting(p, fpwm, udc)
%
%   p    : struct with the dataset, normally built by device_data_load from a
%          script in semiconductor_devices_data. Field names are the names
%          of the variables in the script.
%   fpwm : [Hz] switching frequency, used for the ZVS snubber
%   udc  : [V]  DC-link voltage, used for the ZVS snubber
%
%   Fields of p
%     required      : device_name, device_type and the list returned by
%                     device_mosfet_setting.required_fields()
%     derived       : Rth_mosfet_JH = Rtim + JC + CH when not given
%     optional      : device_mosfet_setting.optional_fields(), NaN if absent
%     anything else : copied unchanged into the property extra
%
%   Normally called through device_mosfet_setup(device, fpwm, udc).

    properties
        name                 string
        type                 string
        Vth                  % [V]
        Rds_on               % [Ohm]
        g_fs                 % [A/V]
        Vdon_diode           % [V]
        Vgamma               % [V]
        Rdon_diode           % [Ohm]
        Eon                  % [J] at Voff_sw_losses, Ion_sw_losses, Tj of the dataset
        Eoff                 % [J] at Voff_sw_losses, Ion_sw_losses, Tj of the dataset
        Err                  % [J] at Voff_sw_losses, Ion_sw_losses, Tj of the dataset
        Voff_sw_losses       % [V]
        Ion_sw_losses        % [A]
        JunctionTermalMass   % [J/K]
        Rtim                 % [K/W]
        Rth_mosfet_JC        % [K/W]
        Rth_mosfet_CH        % [K/W]
        Rth_mosfet_JH        % [K/W]
        Lstray_module        % [H]
        Lstray_d             % [H]
        RLd                  % [Ohm]
        Lstray_s             % [H]
        RLs                  % [Ohm]
        Ciss                 % [F]
        Coss                 % [F]
        Crss                 % [F]
        Cgs                  % [F]
        Cgd                  % [F]
        Cds                  % [F]
        Rgate_internal       % [Ohm]
        Irr                  % [A]
        Csnubber             % [F]
        Rsnubber             % [Ohm]
        Csnubber_zvs         % [F]
        Rsnubber_zvs         % [Ohm]

        % dataset fields not listed above
        extra = struct();
    end

    methods
        function obj = device_mosfet_setting(p, fpwm, udc)
            if nargin == 0
                return;
            end
            if nargin ~= 3 || ~isstruct(p)
                error('device_mosfet_setting:input', ...
                      ['Usage: device_mosfet_setting(p, fpwm, udc), with p the struct ' ...
                       'returned by device_data_load.']);
            end

            if ~isfield(p, 'Rth_mosfet_JH') && all(isfield(p, {'Rtim', 'Rth_mosfet_JC', 'Rth_mosfet_CH'}))
                p.Rth_mosfet_JH = p.Rtim + p.Rth_mosfet_JC + p.Rth_mosfet_CH;
            end
            req = device_mosfet_setting.required_fields();
            opt = device_mosfet_setting.optional_fields();
            device_mosfet_setting.check_fields(p, [{'device_name', 'device_type'}, req]);

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

            known = [{'device_name', 'device_type'}, req, opt];
            rest = setdiff(fieldnames(p), known);
            for k = 1:numel(rest)
                obj.extra.(rest{k}) = p.(rest{k});
            end

            obj.Csnubber_zvs = (obj.Irr)^2*obj.Lstray_module/(udc)^2;
            obj.Rsnubber_zvs = 1/(obj.Csnubber_zvs*fpwm)/5;
        end
    end

    methods (Static)
        function f = required_fields()
            f = {'Vth', 'Rds_on', 'Vdon_diode', 'Rdon_diode', ...
                 'Eon', 'Eoff', 'Err', 'Voff_sw_losses', 'Ion_sw_losses', ...
                 'JunctionTermalMass', 'Rtim', ...
                 'Rth_mosfet_JC', 'Rth_mosfet_CH', 'Rth_mosfet_JH', ...
                 'Lstray_module', 'Irr', 'Csnubber', 'Rsnubber'};
        end

        function f = optional_fields()
            f = {'g_fs', 'Vgamma', 'Lstray_d', 'RLd', 'Lstray_s', 'RLs', ...
                 'Ciss', 'Coss', 'Crss', 'Cgs', 'Cgd', 'Cds', 'Rgate_internal'};
        end
    end

    methods (Static, Access = private)
        function check_fields(p, list)
            missing = list(~isfield(p, list));
            if ~isempty(missing)
                if isfield(p, 'device_name')
                    dev = p.device_name;
                else
                    dev = '(no device_name)';
                end
                error('device_mosfet_setting:missingField', ...
                      'Dataset %s: missing field(s) %s', dev, strjoin(missing, ', '));
            end
        end
    end
end
