function out = rms_filter_setup(obj)
rms_periods = 1;
out.n1 = 2*pi * rms_periods / obj.omega_base / obj.ts;
rms_periods = 2;
out.n2 = 2*pi * rms_periods / obj.omega_base / obj.ts;
rms_periods = 10;
out.n10 = 2*pi * rms_periods / obj.omega_base / obj.ts;
end