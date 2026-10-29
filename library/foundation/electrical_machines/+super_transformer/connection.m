classdef connection < int32
% CONNECTION  Enumeration for the connection of a three-phase primary of super_transformer (parameters conn1, conn2).
%   Referenced in the .ssc file as super_transformer.connection.star and super_transformer.connection.delta.
%   Must stay inside the +super_transformer folder (namespace folder on the MATLAB path) so that Simscape can
%   resolve it. Same pattern as afe_ssc.onoff and cllc_ssc.onoff of pwr-control/library.
    enumeration
        star  (1)
        delta (2)
    end
    methods (Static)
        function map = displayText()
            map = containers.Map;
            map('star') = 'Star, neutral brought out';
            map('delta') = 'Delta';
        end
    end
end
