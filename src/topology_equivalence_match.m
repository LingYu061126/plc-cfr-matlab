function result = topology_equivalence_match(observed_views, reference_views, candidates, ...
        class_audit, feature, ofdm_cfg, weights, feature_options)
%TOPOLOGY_EQUIVALENCE_MATCH Match CFR views and expose physical ambiguity.
%   Numerical tie (result.ambiguous) is kept distinct from configuration-
%   specific physical equivalence (result.equivalence_class). A noisy
%   numerical winner inside a non-singleton class is deliberately not
%   labelled a unique topology identification.

    if nargin < 8 || isempty(feature_options), feature_options = struct(); end
    labels = class_audit.class_labels;
    result = topology_multiview_match(observed_views, reference_views, ...
        feature, ofdm_cfg, weights, class_audit.tie_tolerance, labels, feature_options);
    index = result.predicted_index;
    result.predicted_topology = candidates(index).id;
    result.equivalence_class = labels{index};
    result.equivalence_class_index = class_audit.class_index(index);
    result.physically_ambiguous_class = ...
        class_audit.class_sizes(result.equivalence_class_index) > 1;
    result.unique_identification = ~result.ambiguous && ...
        ~result.physically_ambiguous_class;
    result.second_best_distance = result.second_best_distance;
    result.distance_margin = result.distance_gap;
end
