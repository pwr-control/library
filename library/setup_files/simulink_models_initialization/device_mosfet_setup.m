function dev = device_mosfet_setup(device, fpwm, udc)
%DEVICE_MOSFET_SETUP  Build the MOSFET object of a dataset in semiconductor_devices_data.
%
%   dev = device_mosfet_setup(device, fpwm, udc)
%
%   device : dataset name, e.g. 'danfoss_SKM1700MB20R4S2I4'
%   fpwm   : [Hz] switching frequency, used for the ZVS snubber
%   udc    : [V]  DC-link voltage, used for the ZVS snubber
%
%   Example:
%       used_device = 'danfoss_SKM1700MB20R4S2I4';
%       mosfet.dab = device_mosfet_setup(used_device, glb_time.fPWM_DAB, hwdata.dab.udc1_nom);
%
%   See also DEVICE_DATA_LOAD, DEVICE_MOSFET_SETTING.

p = device_data_load(device);
dev = device_mosfet_setting(p, fpwm, udc);
end
