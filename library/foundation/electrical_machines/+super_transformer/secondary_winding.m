classdef secondary_winding < int32
% SECONDARY_WINDING  Enumeration for the secondary of super_transformer (parameter secondary).
%   Referenced in the .ssc file as super_transformer.secondary_winding.star, .delta and .single_phase.
%   Must stay inside the +super_transformer folder (namespace folder on the MATLAB path) so that Simscape can
%   resolve it. Same pattern as afe_ssc.onoff and cllc_ssc.onoff of pwr-control/library.
    enumeration
        star         (1)
        delta        (2)
        single_phase (3)
    end
    methods (Static)
        function map = displayText()
            map = containers.Map;
            map('star') = 'Three-phase, star, neutral brought out';
            map('delta') = 'Three-phase, delta';
            map('single_phase') = 'Single-phase, limb coils in series (ws)';
        end
    end
end
