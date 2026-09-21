function [out, options] = init_environment(model_name)

    close all; clc; beep off;
    pm_addunit('percent', 0.01, '1');
    options = bodeoptions;
    options.FreqUnits = 'Hz';
    out = model_name;
end