function dev = device_mosfet_parallel(dev, n, fpwm, udc)
%DEVICE_MOSFET_PARALLEL  Equivalent switch of n identical MOSFETs in parallel.
%
%   dev = device_mosfet_parallel(dev, n, fpwm, udc)
%
%   dev  : device_mosfet_setting object of the single device (device_mosfet_setup)
%   n    : number of devices in parallel (perfect current sharing)
%   fpwm : [Hz] switching frequency, used for the ZVS snubber
%   udc  : [V]  DC-link voltage, used for the ZVS snubber
%
%   Resistances and the thermal chain are divided by n. Capacitances, charges, thermal mass,
%   recovery current and the reference current of the switching energies are multiplied by n,
%   so each device switches Ion_sw_losses/n with its own energy. The ZVS snubber is computed
%   again for the bank, with the same formula as device_mosfet_setting.
%
%   Example (SR of a 1000 A CLLC, 16 x IPT025N15NM6 per switch):
%       d = device_mosfet_setup('infineon_MOSFET_IPT025N15NM6', 35e3, 73.3);
%       mosfet_sr = device_mosfet_parallel(d, 16, 35e3, 73.3);
%
%   See also DEVICE_MOSFET_SETUP, DEVICE_MOSFET_SETTING.

if ~isa(dev, 'device_mosfet_setting') || ~isscalar(n) || n < 1 || n ~= round(n)
    error('device_mosfet_parallel:input', 'Usage: device_mosfet_parallel(dev, n, fpwm, udc), n integer >= 1.');
end

div = {'Rds_on', 'Rdon_diode', 'Rtim', 'Rth_mosfet_JC', 'Rth_mosfet_CH', 'Rth_mosfet_JH', ...
       'Lstray_module', 'Lstray_d', 'Lstray_s', 'RLd', 'RLs', 'Rgate_internal', 'Rsnubber'};
mul = {'g_fs', 'Eon', 'Eoff', 'Err', 'Ion_sw_losses', 'JunctionTermalMass', 'Irr', ...
       'Ciss', 'Coss', 'Crss', 'Cgs', 'Cgd', 'Cds', 'Csnubber'};
for k = 1:numel(div)
    dev.(div{k}) = dev.(div{k})/n;
end
for k = 1:numel(mul)
    dev.(mul{k}) = dev.(mul{k})*n;
end

dev.name = sprintf('%s x %d', dev.name, n);
dev.extra.n_parallel = n;
dev.Csnubber_zvs = (dev.Irr)^2*dev.Lstray_module/(udc)^2;
dev.Rsnubber_zvs = 1/(dev.Csnubber_zvs*fpwm)/5;
end
