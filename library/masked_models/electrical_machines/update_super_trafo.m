function update_super_trafo()
%UPDATE_SUPER_TRAFO  Build or refresh the library super_trafo.slx: block super_trafo, the configurable transformer.
%
%   update_super_trafo
%
%   The block is the Simscape language component super_transformer.super_transformer of
%   ../../foundation/electrical_machines/+super_transformer, placed as a Simscape Component block on its source
%   file: the block follows the .ssc after every change (no ssc_build needed) and its dialog is the mask of the
%   block, with the configuration in dropdowns:
%     Primaries                One / Two, on the same core
%     Primary 1 connection     Star, neutral brought out / Delta
%     Primary 2 connection     Star, neutral brought out / Delta                 (two primaries)
%     Primary 2 clock number   0 ... 11, lag of primary 2 on primary 1 in 30 deg  (two primaries)
%     Secondary                Three-phase, star, neutral brought out / Three-phase, delta /
%                              Single-phase, limb coils in series (ws)
%     Secondary clock number   0 ... 11, lag of the secondary on primary 1        (three-phase secondary)
%     ws                       turns of the single-phase secondary on limbs a, b, c (single-phase secondary)
%   then the ratings (Sr, V1, V2, V3, fr) and the impedances in per unit. The block shows only the ports of the
%   configuration: A1 B1 C1 (N1 if star), A2 B2 C2 (N2) with two primaries, a b c (n if star) or s1 s2, and the
%   flux linkages psi_a, psi_b, psi_c of the primary-1 coils. Equations, vector-group rule and per-unit bases:
%   header of super_transformer.ssc; checks: check_super_transformer.py (phasors, closed forms and the library
%   transformers) and test_super_transformer.m (Simscape, against the library transformers).
%   The library is named super_trafo, not super_transformer, so that the model file does not shadow the
%   package super_transformer, whose enumerations the dialog evaluates (super_transformer.connection.star, ...).
%
%   Run this function (library on the path, any folder): it creates super_trafo.slx next to this file, or
%   refreshes the block of the existing one (component path, size). Commit super_trafo.slx.

    lib  = 'super_trafo';
    blk  = [lib '/super_trafo'];
    comp = 'super_transformer.super_transformer';
    here = fileparts(mfilename('fullpath'));
    file = fullfile(here, [lib '.slx']);
    assert(~isempty(meta.class.fromName('super_transformer.connection')), ['update_super_trafo: package ' ...
        '+super_transformer not on the path (library/foundation/electrical_machines)']);

    if bdIsLoaded(lib)
        close_system(lib, 0);
    end
    if isfile(file)
        load_system(file);
        set_param(lib, 'Lock', 'off');
    else
        new_system(lib, 'Library');
    end
    if getSimulinkBlockHandle(blk) == -1
        add_block(library_block('nesl_utility', '^Simscape\s+Component$'), blk, 'Position', [100 60 280 420]);
    end
    try
        set_param(blk, 'ComponentPath', comp);
    catch
        set_param(blk, 'SourceFile', comp);
    end
    set_param(blk, 'Description', ['Super transformer: one or two three-phase primaries (star or delta), ' ...
        'secondary three-phase (star or delta, any clock number) or single-phase (turns distribution ws) on a ' ...
        'three-limb core. Component super_transformer.super_transformer (pwr-control/library, ' ...
        'foundation/electrical_machines/+super_transformer).']);

    % default configuration of the component: two star primaries, single-phase secondary ws [1 -1 0]
    ph = get_param(blk, 'PortHandles');
    assert(numel(ph.LConn) == 8 && numel(ph.RConn) == 5, ['update_super_trafo: %s has %d left and %d right ' ...
        'ports, 8 (A1 B1 C1 N1 A2 B2 C2 N2) and 5 (s1 s2 psi_a psi_b psi_c) expected with the default ' ...
        'configuration'], blk, numel(ph.LConn), numel(ph.RConn));

    save_system(lib, file);
    close_system(lib);
    fprintf('update_super_trafo: %s saved, block %s on %s\n', file, blk, comp);
end

function src = library_block(lib, name_regexp)
%LIBRARY_BLOCK  Path of the block of lib whose name matches name_regexp (names of nesl_utility have line breaks).
    load_system(lib);
    b = find_system(lib, 'Regexp', 'on', 'Name', name_regexp);
    b = b(~strcmp(b, lib));
    assert(~isempty(b), 'update_super_trafo: no block matching %s in %s', name_regexp, lib);
    src = b{1};
end
