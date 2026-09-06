function mask = topology_active_parameter_mask(candidate, parameter_names)
%TOPOLOGY_ACTIVE_PARAMETER_MASK Mark parameters with physical meaning.
%   Main length and terminal impedances are active for every candidate.
%   Branch length and branch load scales are active only when a branch exists.

    if nargin < 2 || isempty(parameter_names)
        parameter_names = stage4a6_1_parameter_names();
    end
    mask = false(1, numel(parameter_names));
    has_branch = isfield(candidate,'network') && ...
        isfield(candidate.network,'branches') && ~isempty(candidate.network.branches);
    for k = 1:numel(parameter_names)
        switch parameter_names{k}
            case {'main_length_scale','source_impedance_ohm','receiver_impedance_ohm'}
                mask(k) = true;
            case {'branch_length_scale','branch_load_scale'}
                mask(k) = has_branch;
        end
    end
end
