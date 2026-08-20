function result = topology_nearest_match(H_observed, references, feature, ofdm_cfg, weights, tie_tolerance)
%TOPOLOGY_NEAREST_MATCH Nearest-reference topology classifier.
%   references must contain id and reference_H fields. The classifier uses
%   only the selected feature distance and returns all candidate scores so
%   that confusion and failure cases remain auditable.

    if isempty(references)
        error('topology_nearest_match:EmptyReferences', ...
            'At least one topology reference is required.');
    end
    if nargin < 6 || isempty(tie_tolerance)
        tie_tolerance = 1e-10;
    end
    if ~(isscalar(tie_tolerance) && isfinite(tie_tolerance) && tie_tolerance >= 0)
        error('topology_nearest_match:InvalidTieTolerance', ...
            'tie_tolerance must be a finite nonnegative scalar.');
    end
    n = numel(references);
    scores = zeros(1, n);
    metric_details = cell(1, n);
    for k = 1:n
        if ~isfield(references(k), 'reference_H') || ...
                isempty(references(k).reference_H)
            error('topology_nearest_match:MissingReference', ...
                'Reference %d has no reference_H.', k);
        end
        [scores(k), metric_details{k}] = topology_feature_distance( ...
            H_observed, references(k).reference_H, feature, ofdm_cfg, weights);
    end
    [best_score, best_index] = min(scores);
    tied_indices = find(scores <= best_score + tie_tolerance * max(1, best_score));
    if n > 1
        ordered = sort(scores);
        second_best = ordered(2);
        distance_gap = second_best - best_score;
    else
        second_best = Inf;
        distance_gap = Inf;
    end
    group_labels = cell(1, n);
    for k = 1:n
        if isfield(references(k), 'observability_group') && ...
                ~isempty(references(k).observability_group)
            group_labels{k} = references(k).observability_group;
        else
            group_labels{k} = references(k).id;
        end
    end
    unique_groups = unique(group_labels, 'stable');
    group_best_distances = Inf(1, numel(unique_groups));
    group_best_indices = zeros(1, numel(unique_groups));
    for g = 1:numel(unique_groups)
        members = find(strcmp(group_labels, unique_groups{g}));
        [group_best_distances(g), local] = min(scores(members));
        group_best_indices(g) = members(local);
    end
    predicted_group_index = find(strcmp(unique_groups, group_labels{best_index}), 1);
    other_group_scores = group_best_distances;
    other_group_scores(predicted_group_index) = Inf;
    group_inter_best = min(other_group_scores);
    if isfinite(group_inter_best)
        group_distance_gap = group_inter_best - group_best_distances(predicted_group_index);
    else
        group_distance_gap = Inf;
    end
    result = struct('predicted_index', best_index, ...
        'predicted_id', references(best_index).id, ...
        'predicted_name', references(best_index).name, ...
        'selected_feature', char(feature), 'best_distance', best_score, ...
        'scores', scores, 'metric_details', {metric_details}, ...
        'second_best_distance', second_best, 'distance_gap', distance_gap, ...
        'observability_group_labels', {unique_groups}, ...
        'predicted_group', unique_groups{predicted_group_index}, ...
        'predicted_group_index', predicted_group_index, ...
        'group_best_distances', group_best_distances, ...
        'group_best_indices', group_best_indices, ...
        'group_inter_best_distance', group_inter_best, ...
        'group_distance_gap', group_distance_gap, ...
        'tied_indices', tied_indices, 'ambiguous', numel(tied_indices) > 1, ...
        'tie_tolerance', tie_tolerance);
end
