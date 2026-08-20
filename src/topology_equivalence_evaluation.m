function metrics = topology_equivalence_evaluation(true_indices, match_results, candidates, class_audit)
%TOPOLOGY_EQUIVALENCE_EVALUATION Evaluate strict and equivalence-class output.
%   This function intentionally treats a non-singleton full-complex CFR
%   class as physically non-unique even when noise removes an exact score
%   tie. false_unique_rate therefore exposes an algorithm that emits a
%   concrete label where the configured observation cannot justify one.

    true_indices = true_indices(:).';
    if ~iscell(match_results) || numel(match_results) ~= numel(true_indices)
        error('topology_equivalence_evaluation:SizeMismatch', ...
            'match_results must have one entry per true index.');
    end
    n = numel(candidates);
    if any(true_indices < 1 | true_indices > n | true_indices ~= fix(true_indices))
        error('topology_equivalence_evaluation:InvalidTruth', ...
            'true_indices must index candidates.');
    end
    predicted = zeros(size(true_indices)); numerical_tie = false(size(true_indices));
    best = NaN(size(true_indices)); second = NaN(size(true_indices)); margin = NaN(size(true_indices));
    for k = 1:numel(true_indices)
        item = match_results{k};
        if ~isstruct(item) || ~isfield(item,'predicted_index') || ...
                ~isfield(item,'ambiguous') || ~isfield(item,'scores')
            error('topology_equivalence_evaluation:InvalidMatch', ...
                'Each match result must contain predicted_index, ambiguous and scores.');
        end
        predicted(k) = item.predicted_index;
        numerical_tie(k) = logical(item.ambiguous);
        best(k) = item.best_distance;
        second(k) = item.second_best_distance;
        margin(k) = item.distance_gap;
    end
    truth_class = class_audit.class_index(true_indices);
    predicted_class = class_audit.class_index(predicted);
    truth_nonunique = class_audit.class_sizes(truth_class) > 1;
    predicted_nonunique = class_audit.class_sizes(predicted_class) > 1;
    base = topology_evaluation_metrics(true_indices, predicted, candidates, numerical_tie, match_results);
    metrics = base;
    metrics.strict_topology_accuracy = mean(predicted == true_indices);
    metrics.equivalence_class_accuracy = mean(predicted_class == truth_class);
    metrics.unique_strict_accuracy = mean((predicted == true_indices) & ...
        ~numerical_tie & ~predicted_nonunique);
    metrics.ambiguity_rate = mean(numerical_tie);
    metrics.false_unique_rate = mean(truth_nonunique & ~numerical_tie);
    metrics.false_unique_rate_conditioned = conditional_mean(~numerical_tie, truth_nonunique);
    metrics.unique_identification_rate = mean(~numerical_tie & ~predicted_nonunique);
    metrics.best_distance = best;
    metrics.second_best_distance = second;
    metrics.distance_margin = margin;
    metrics.mean_best_distance = finite_mean_local(best);
    metrics.mean_second_best_distance = finite_mean_local(second);
    metrics.mean_distance_margin = finite_mean_local(margin);
    metrics.std_distance_margin = finite_std_local(margin);
    metrics.truth_equivalence_class = truth_class;
    metrics.predicted_equivalence_class = predicted_class;
    metrics.class_labels = class_audit.class_labels;
    metrics.class_sizes = class_audit.class_sizes;
    metrics.structural_indistinguishable_group_count = ...
        class_audit.structural_indistinguishable_group_count;
    metrics.numeric_tie_rate = mean(numerical_tie);
    metrics.numeric_tie_count = sum(numerical_tie);
    metrics.confusion_matrix = confusion_matrix_local(true_indices, predicted, n);
    metrics.equivalence_confusion_matrix = confusion_matrix_local(truth_class, predicted_class, ...
        numel(class_audit.class_sizes));
    [intra, inter] = class_distances(match_results, true_indices, class_audit);
    metrics.class_intra_distance = intra;
    metrics.nearest_class_inter_distance = inter;
    metrics.mean_class_intra_distance = finite_mean_local(intra);
    metrics.mean_nearest_class_inter_distance = finite_mean_local(inter);
    metrics.class_intra_inter_ratio = safe_ratio_local(metrics.mean_class_intra_distance, ...
        metrics.mean_nearest_class_inter_distance);
end

function value = conditional_mean(x, condition)
    if ~any(condition), value = NaN; else, value = mean(x(condition)); end
end
function matrix = confusion_matrix_local(a,b,n)
    matrix=zeros(n); for k=1:numel(a),matrix(a(k),b(k))=matrix(a(k),b(k))+1;end
end
function [intra,inter] = class_distances(results, truth, audit)
    intra=NaN(size(truth));inter=NaN(size(truth));
    for k=1:numel(truth)
        score=results{k}.scores; cls=audit.class_index; own=cls==cls(truth(k));
        intra(k)=min(score(own)); other=score;other(own)=Inf;inter(k)=min(other);
    end
end
function value=finite_mean_local(x),x=x(isfinite(x));if isempty(x),value=NaN;else,value=mean(x);end,end
function value=finite_std_local(x),x=x(isfinite(x));if numel(x)<2,value=0;else,value=std(x,0);end,end
function value=safe_ratio_local(a,b),if ~isfinite(a)||~isfinite(b)||b==0,value=NaN;else,value=a/b;end,end
