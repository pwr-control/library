classdef onoff < int32
% ONOFF  Enumeration for the on/off parameters of the cllc_ssc package (cap_dc1, ind_dc1, cap_dc2,
%   ind_dc2, coss_on). Referenced in the .ssc files as cllc_ssc.onoff.on and cllc_ssc.onoff.off. Must
%   stay inside the +cllc_ssc folder (namespace folder on the MATLAB path) so that Simscape can resolve
%   it. Same pattern as afe_ssc.onoff and ideal_bridges.onoff of pwr-control/library.
    enumeration
        off (0)
        on  (1)
    end
end
