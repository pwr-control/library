classdef onoff < int32
% ONOFF  Enumeration for the on/off parameters of the afe_ttype_ssc package (cap_dc).
%   Referenced in the .ssc files as afe_ttype_ssc.onoff.on and afe_ttype_ssc.onoff.off. Must
%   stay inside the +afe_ttype_ssc folder (namespace folder on the MATLAB path) so that
%   Simscape can resolve it. Same pattern as afe_ssc.onoff and ideal_bridges.onoff of
%   pwr-control/library.
    enumeration
        off (0)
        on  (1)
    end
end
