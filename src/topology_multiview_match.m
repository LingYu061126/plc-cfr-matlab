function result = topology_multiview_match(observed_views, reference_views, feature, ofdm_cfg, weights, tie_tolerance, group_labels, feature_options)
%TOPOLOGY_MULTIVIEW_MATCH Combine independent CFR observations.
%   observed_views is a cell array of CFR vectors. reference_views{k} is a
%   cell array containing the corresponding views for candidate k. Scores
%   are the root-mean-square of the per-view feature distances. This only
%   adds information when views are physically independent; repeating the
%   same CFR twice leaves the score ordering unchanged.

    if nargin < 6 || isempty(tie_tolerance), tie_tolerance = 1e-10; end
    if nargin < 7 || isempty(group_labels)
        group_labels = arrayfun(@(k) sprintf('candidate_%d', k), ...
            1:numel(reference_views), 'UniformOutput', false);
    end
    if nargin < 8 || isempty(feature_options), feature_options=struct(); end
    if ~iscell(observed_views) || isempty(observed_views)
        error('topology_multiview_match:InvalidObservedViews', ...
            'observed_views must be a nonempty cell array.');
    end
    if ~iscell(reference_views) || isempty(reference_views)
        error('topology_multiview_match:InvalidReferenceViews', ...
            'reference_views must be a nonempty cell array.');
    end
    nview = numel(observed_views);
    nref = numel(reference_views);
    scores = zeros(1, nref);
    metric_details = cell(1, nref);
    for k = 1:nref
        if ~iscell(reference_views{k}) || numel(reference_views{k}) ~= nview
            error('topology_multiview_match:ViewCountMismatch', ...
                'Each candidate must provide the same number of reference views.');
        end
        per_view = zeros(1, nview);
        per_details = cell(1, nview);
        for v = 1:nview
            [per_view(v), per_details{v}] = topology_feature_distance( ...
                observed_views{v}, reference_views{k}{v}, feature, ofdm_cfg, weights,feature_options);
        end
        scores(k) = sqrt(mean(per_view.^2));
        metric_details{k} = struct('per_view_distance', per_view, ...
            'per_view_details', {per_details});
    end
    [best_score, best_index] = min(scores);
    tied_indices = find(scores <= best_score + tie_tolerance*max(1, best_score));
    ordered = sort(scores);
    if nref > 1
        second_best = ordered(2);
        distance_gap = second_best - best_score;
    else
        second_best = Inf;
        distance_gap = Inf;
    end
    labels = group_labels(:).';
    if numel(labels) ~= nref
        error('topology_multiview_match:GroupLabelMismatch', ...
            'group_labels must match the number of candidates.');
    end
    unique_groups = unique(labels, 'stable');
    group_best = zeros(1, numel(unique_groups));
    group_best_indices = zeros(1, numel(unique_groups));
    for g = 1:numel(unique_groups)
        members = find(strcmp(labels, unique_groups{g}));
        [group_best(g), local] = min(scores(members));
        group_best_indices(g) = members(local);
    end
    predicted_group_index = find(strcmp(unique_groups, labels{best_index}), 1);
    other = group_best; other(predicted_group_index) = Inf;
    group_inter = min(other);
    result = struct('predicted_index', best_index, 'best_distance', best_score, ...
        'second_best_distance', second_best, 'distance_gap', distance_gap, ...
        'scores', scores, 'metric_details', {metric_details}, ...
        'tied_indices', tied_indices, 'ambiguous', numel(tied_indices) > 1, ...
        'tie_tolerance', tie_tolerance, 'group_best_distances', group_best, ...
        'group_best_indices', group_best_indices, ...
        'group_inter_best_distance', group_inter, ...
        'group_distance_gap', group_inter-group_best(predicted_group_index), ...
        'predicted_group_index', predicted_group_index, ...
        'predicted_group', unique_groups{predicted_group_index}, ...
        'observability_group_labels', {unique_groups}, ...
        'selected_feature', char(feature), 'view_count', nview);
end
