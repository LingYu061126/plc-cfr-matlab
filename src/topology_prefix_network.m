function prefix = topology_prefix_network(network, number_of_segments)
%TOPOLOGY_PREFIX_NETWORK Return a network ending at an internal main node.
%   This is the minimal extra-measurement model used in stage 2.1: a second
%   receiver terminates the line at an existing main-line node. Branches
%   strictly before that node remain; downstream line and branches are not
%   included. It is a measurement-configuration assumption, not a claim
%   that an existing passive tap has no electrical loading.

    if ~isstruct(network) || ~isfield(network, 'main_lengths')
        error('topology_prefix_network:InvalidNetwork', ...
            'network.main_lengths is required.');
    end
    lengths = network.main_lengths(:).';
    if ~(isscalar(number_of_segments) && isfinite(number_of_segments) && ...
            number_of_segments == fix(number_of_segments) && ...
            number_of_segments >= 1 && number_of_segments <= numel(lengths))
        error('topology_prefix_network:InvalidSegmentCount', ...
            'number_of_segments must select an existing main-line prefix.');
    end
    prefix = network;
    prefix.main_lengths = lengths(1:number_of_segments);
    if isfield(network, 'main_cable_type')
        types = network.main_cable_type;
        if isscalar(types), types = types*ones(size(lengths)); end
        prefix.main_cable_type = types(1:number_of_segments);
    end
    if ~isfield(network, 'branches') || isempty(network.branches)
        prefix.branches = struct('node', {}, 'length', {}, ...
            'cable_type', {}, 'load', {});
        return;
    end
    branches = network.branches;
    keep = arrayfun(@(b) b.node < number_of_segments, branches);
    prefix.branches = branches(keep);
end
