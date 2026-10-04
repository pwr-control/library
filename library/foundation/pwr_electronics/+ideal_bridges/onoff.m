classdef onoff < int32
% ONOFF  Enumeration for the on/off parameters of the ideal_bridges package
%   (cap_dc, ind_ac). Referenced in the .ssc files as ideal_bridges.onoff.on
%   and ideal_bridges.onoff.off. Must stay inside the +ideal_bridges folder
%   (namespace folder on the MATLAB path) so that Simscape can resolve it.
    enumeration
        off (0)
        on  (1)
    end
end
