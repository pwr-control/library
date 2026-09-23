function p = device_data_load(device)
%DEVICE_DATA_LOAD  Load a semiconductor dataset into a struct.
%
%   p = device_data_load('infineon_FF2000XTR17IE5')
%
%   DEVICE is the name of a dataset in semiconductor_devices_data (or one of
%   its one-line aliases). Two formats are accepted:
%     - a script that assigns loose variables (current format). The script
%       runs in the private workspace of this function and every variable
%       it defines becomes a field of P with the same name;
%     - a function with no inputs that returns a struct (possible future
%       format). Its output is returned as it is.
%   Both formats can coexist, so datasets can be migrated one at a time.
%
%   The scripts can still be run directly in the base workspace: this
%   function does not require any change to them.
%
%   See also DEVICE_IGBT_SETUP, DEVICE_MOSFET_SETUP, DEVICE_IDEAL_SWITCH_SETTING.

    if ~(ischar(device) || (isstring(device) && isscalar(device)))
        error('device_data_load:input', 'The device name must be a character vector or a string.');
    end
    device = char(device);

    if exist(device, 'file') ~= 2
        error('device_data_load:notFound', ...
              'Device dataset "%s" not found on the MATLAB path.', device);
    end

    if is_function_file(device)
        if nargout(device) < 1
            error('device_data_load:noOutput', ...
                  'Device dataset "%s" is a function but returns no output.', device);
        end
        p = feval(device);
        if ~isstruct(p)
            error('device_data_load:notStruct', ...
                  'Device dataset "%s" must return a struct.', device);
        end
    else
        p = run_dataset_script(device);
    end
end

function tf = is_function_file(name)
% nargout() errors on scripts, so it tells a script from a function file.
    try
        nargout(name);
        tf = true;
    catch
        tf = false;
    end
end

function p = run_dataset_script(dataset_script_name__)
% Runs the script here, so that its variables land in this workspace only,
% then copies every variable except the input name into the struct P.
    run(dataset_script_name__);
    names__ = setdiff(who, {'dataset_script_name__', 'ans'});
    p = struct();
    for k__ = 1:numel(names__)
        p.(names__{k__}) = eval(names__{k__});
    end
end
