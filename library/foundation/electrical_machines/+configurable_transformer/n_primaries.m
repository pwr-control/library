classdef n_primaries < int32
% N_PRIMARIES  Enumeration for the number of three-phase primaries of configurable_transformer (parameter
%   primaries). Referenced in the .ssc file as configurable_transformer.n_primaries.one and
%   configurable_transformer.n_primaries.two. Must stay inside the +configurable_transformer folder (namespace
%   folder on the MATLAB path) so that Simscape can resolve it. Same pattern as afe_ssc.onoff and cllc_ssc.onoff
%   of pwr-control/library.
    enumeration
        one (1)
        two (2)
    end
    methods (Static)
        function map = displayText()
            map = containers.Map;
            map('one') = 'One';
            map('two') = 'Two, on the same core';
        end
    end
end
