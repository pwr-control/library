function n = swap_grid_emulators_mfcn(mdl, direction)
%SWAP_GRID_EMULATORS_MFCN  Replace the grid emulators of a model with their MATLAB Function
%copies, or back, keeping block names, positions, connections and mask values.
%
%   n = swap_grid_emulators_mfcn('afe_inv_psm')              % originals -> *_mfcn copies
%   n = swap_grid_emulators_mfcn('afe_inv_psm', 'original')  % *_mfcn copies -> originals
%
%   Blocks handled (library links):
%     three_phase_voltage_emulator/three_phase_voltage_source_emulator
%       <-> three_phase_voltage_emulator_mfcn/three_phase_voltage_source_emulator
%     three_phase_voltage_with_frt_emulator/three_phase_voltage_source_with_frt_emulator
%       <-> three_phase_voltage_with_frt_emulator_mfcn/three_phase_voltage_source_with_frt_emulator
%
%   The model is loaded if needed and left open, modified and not saved: check it, then
%   save it. Links inside other library blocks are not touched (FollowLinks off).
%   n is the number of blocks replaced.

if nargin < 2
    direction = 'mfcn';
end
pairs = { ...
    'three_phase_voltage_emulator/three_phase_voltage_source_emulator', ...
    'three_phase_voltage_emulator_mfcn/three_phase_voltage_source_emulator'; ...
    'three_phase_voltage_with_frt_emulator/three_phase_voltage_source_with_frt_emulator', ...
    'three_phase_voltage_with_frt_emulator_mfcn/three_phase_voltage_source_with_frt_emulator'};
switch direction
    case 'mfcn'
        from = 1;
        to = 2;
    case 'original'
        from = 2;
        to = 1;
    otherwise
        error('swap_grid_emulators_mfcn: direction must be ''mfcn'' or ''original''.');
end

[~, mdl] = fileparts(mdl);
load_system(mdl);
n = 0;
for k = 1:size(pairs, 1)
    src = pairs{k, from};
    dst = pairs{k, to};
    blks = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'off', ...
        'ReferenceBlock', src);
    if isempty(blks)
        continue;
    end
    load_system(strtok(dst, '/'));
    % mask values of each block, by parameter name
    saved = cell(size(blks));
    for i = 1:numel(blks)
        names = get_param(blks{i}, 'MaskNames');
        values = get_param(blks{i}, 'MaskValues');
        saved{i} = [names(:), values(:)];
    end
    % same name, position, orientation and lines; then the mask values are set again
    replace_block(mdl, 'ReferenceBlock', src, dst, 'noprompt');
    for i = 1:numel(blks)
        if ~strcmp(get_param(blks{i}, 'ReferenceBlock'), dst)
            warning('swap_grid_emulators_mfcn:notReplaced', '%s was not replaced.', blks{i});
            continue;
        end
        names = get_param(blks{i}, 'MaskNames');
        for j = 1:size(saved{i}, 1)
            if any(strcmp(names, saved{i}{j, 1}))
                set_param(blks{i}, saved{i}{j, 1}, saved{i}{j, 2});
            end
        end
        n = n + 1;
        fprintf('%s: %s -> %s\n', blks{i}, strtok(src, '/'), strtok(dst, '/'));
    end
end
fprintf('%d block(s) replaced in %s (not saved).\n', n, mdl);
end
