function metrics = topology_evaluation_metrics(true_indices, predicted_indices, candidates, ambiguous, match_meta)
%TOPOLOGY_EVALUATION_METRICS Accuracy, confusion and edge-level metrics.
%   Confusion rows are true topology indices and columns are predictions.
%   Edge metrics compare the graph edge-label sets stored in each candidate;
%   the shared main-line segmentation prevents a representation artifact
%   from being confused with a branch-topology error.

    true_indices = true_indices(:).';
    predicted_indices = predicted_indices(:).';
    if numel(true_indices) ~= numel(predicted_indices)
        error('topology_evaluation_metrics:SizeMismatch', ...
            'True and predicted index arrays must have equal length.');
    end
    if nargin < 4 || isempty(ambiguous)
        ambiguous = false(size(true_indices));
    else
        ambiguous = logical(ambiguous(:).');
        if numel(ambiguous) ~= numel(true_indices)
            error('topology_evaluation_metrics:AmbiguitySizeMismatch', ...
                'Ambiguity flags must match the sample count.');
        end
    end
    if nargin < 5 || isempty(match_meta)
        match_meta = cell(1, numel(true_indices));
    elseif ~iscell(match_meta) || numel(match_meta) ~= numel(true_indices)
        error('topology_evaluation_metrics:MetadataSizeMismatch', ...
            'match_meta must be a cell array matching the sample count.');
    end
    n = numel(candidates);
    if any(true_indices < 1 | true_indices > n | true_indices ~= fix(true_indices)) || ...
            any(predicted_indices < 1 | predicted_indices > n | ...
            predicted_indices ~= fix(predicted_indices))
        error('topology_evaluation_metrics:InvalidIndex', ...
            'Topology indices must be integers in the candidate range.');
    end
    confusion = zeros(n, n);
    for k = 1:numel(true_indices)
        confusion(true_indices(k), predicted_indices(k)) = ...
            confusion(true_indices(k), predicted_indices(k)) + 1;
    end
    metrics = struct();
    metrics.sample_count = numel(true_indices);
    metrics.accuracy = mean(true_indices == predicted_indices);
    metrics.confusion_matrix = confusion;
    metrics.true_indices = true_indices;
    metrics.predicted_indices = predicted_indices;
    metrics.numeric_tie_count = sum(ambiguous);
    metrics.numeric_tie_rate = mean(ambiguous);
    metrics.ambiguous_count = metrics.numeric_tie_count;
    metrics.ambiguous_rate = metrics.numeric_tie_rate;
    group_labels = {candidates.observability_group};
    unique_groups = unique(group_labels, 'stable');
    true_groups = zeros(size(true_indices));
    predicted_groups = zeros(size(predicted_indices));
    for k = 1:numel(true_indices)
        true_groups(k) = find(strcmp(unique_groups, group_labels{true_indices(k)}), 1);
        predicted_groups(k) = find(strcmp(unique_groups, group_labels{predicted_indices(k)}), 1);
    end
    group_confusion = zeros(numel(unique_groups));
    for k = 1:numel(true_groups)
        group_confusion(true_groups(k), predicted_groups(k)) = ...
            group_confusion(true_groups(k), predicted_groups(k)) + 1;
    end
    metrics.observability_group_labels = unique_groups;
    metrics.group_accuracy = mean(true_groups == predicted_groups);
    metrics.group_confusion_matrix = group_confusion;
    group_sizes = zeros(1, numel(unique_groups));
    for g = 1:numel(unique_groups)
        group_sizes(g) = sum(strcmp(group_labels, unique_groups{g}));
    end
    metrics.structurally_indistinguishable_group_count = sum(group_sizes > 1);
    metrics.structurally_indistinguishable_groups = unique_groups(group_sizes > 1);
    metrics.structural_group_sizes = group_sizes;

    group_intra = NaN(size(true_indices));
    group_inter = NaN(size(true_indices));
    distance_gap = NaN(size(true_indices));
    for sample = 1:numel(true_indices)
        meta = match_meta{sample};
        if isstruct(meta) && isfield(meta, 'group_best_distances')
            truth_group = find(strcmp(unique_groups, group_labels{true_indices(sample)}), 1);
            group_intra(sample) = meta.group_best_distances(truth_group);
            if isfield(meta, 'group_best_distances')
                other = meta.group_best_distances;
                other(truth_group) = Inf;
                group_inter(sample) = min(other);
            end
            if isfield(meta, 'distance_gap')
                distance_gap(sample) = meta.distance_gap;
            end
        end
    end
    metrics.group_intra_distances = group_intra;
    metrics.group_inter_distances = group_inter;
    metrics.distance_gaps = distance_gap;
    metrics.mean_group_intra_distance = finite_mean(group_intra);
    metrics.mean_group_inter_distance = finite_mean(group_inter);
    metrics.group_intra_inter_ratio = safe_ratio(metrics.mean_group_intra_distance, ...
        metrics.mean_group_inter_distance);
    metrics.mean_distance_gap = finite_mean(distance_gap);
    metrics.std_distance_gap = finite_std(distance_gap);

    all_labels = {};
    for k = 1:n
        all_labels = [all_labels, candidates(k).edge_labels]; %#ok<AGROW>
    end
    all_labels = unique(all_labels);
    edge_template = struct('label', '', 'precision', 0, 'recall', 0, ...
        'f1', 0, 'support', 0, 'tp', 0, 'fp', 0, 'fn', 0);
    per_edge = repmat(edge_template, 1, numel(all_labels));
    tp_micro = 0; fp_micro = 0; fn_micro = 0;
    for sample = 1:numel(true_indices)
        truth = candidates(true_indices(sample)).edge_labels;
        pred = candidates(predicted_indices(sample)).edge_labels;
        tp = numel(intersect(truth, pred));
        fp = numel(setdiff(pred, truth));
        fn = numel(setdiff(truth, pred));
        tp_micro = tp_micro + tp;
        fp_micro = fp_micro + fp;
        fn_micro = fn_micro + fn;
        for k = 1:numel(all_labels)
            t = any(strcmp(truth, all_labels{k}));
            p = any(strcmp(pred, all_labels{k}));
            per_edge(k).label = all_labels{k};
            per_edge(k).tp = per_edge(k).tp + (t && p);
            per_edge(k).fp = per_edge(k).fp + (~t && p);
            per_edge(k).fn = per_edge(k).fn + (t && ~p);
            per_edge(k).support = per_edge(k).support + t;
        end
    end
    for k = 1:numel(per_edge)
        [per_edge(k).precision, per_edge(k).recall, per_edge(k).f1] = ...
            prf1(per_edge(k).tp, per_edge(k).fp, per_edge(k).fn);
    end
    [p, r, f1] = prf1(tp_micro, fp_micro, fn_micro);
    metrics.edge_micro = struct('precision', p, 'recall', r, 'f1', f1, ...
        'tp', tp_micro, 'fp', fp_micro, 'fn', fn_micro);
    metrics.edge_per_label = per_edge;
end

function value = finite_mean(x)
    x = x(isfinite(x));
    if isempty(x), value = NaN; else, value = mean(x); end
end

function value = finite_std(x)
    x = x(isfinite(x));
    if numel(x) < 2, value = 0; else, value = std(x, 0); end
end

function value = safe_ratio(a, b)
    if ~isfinite(a) || ~isfinite(b) || b == 0, value = NaN; else, value = a/b; end
end

function [precision, recall, f1] = prf1(tp, fp, fn)
    if tp + fp == 0, precision = 1; else, precision = tp/(tp+fp); end
    if tp + fn == 0, recall = 1; else, recall = tp/(tp+fn); end
    if precision + recall == 0, f1 = 0; else, f1 = 2*precision*recall/(precision+recall); end
end
