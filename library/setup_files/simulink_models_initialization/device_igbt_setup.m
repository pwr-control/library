function dev = device_igbt_setup(device, fpwm, udc)
%DEVICE_IGBT_SETUP  Build the IGBT object of a dataset in semiconductor_devices_data.
%
%   dev = device_igbt_setup(device, fpwm, udc)
%
%   device : dataset name, e.g. 'infineon_FF2000XTR17IE5' (or its alias
%            'infineon_IGBT_FF2000XTR17IE5')
%   fpwm   : [Hz] switching frequency, used for the ZVS snubber
%   udc    : [V]  DC-link voltage, used for the ZVS snubber
%
%   Example:
%       used_device = 'infineon_FF900R12IE4';
%       igbt.inv = device_igbt_setup(used_device, glb_time.fPWM_INV, hwdata.inv.udc_nom);
%
%   See also DEVICE_DATA_LOAD, DEVICE_IGBT_SETTING.

p = device_data_load(device);
dev = device_igbt_setting(p, fpwm, udc);
end
