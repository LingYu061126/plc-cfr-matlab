function result = match_cached_composite_library_open_set(observed_views, cache, options)
%MATCH_CACHED_COMPOSITE_LIBRARY_OPEN_SET Observation-only cached matcher.
%   Inputs are observed CFR views, a truth-free template cache and frozen
%   thresholds/options. No truth topology, coverage status, scenario label or
%   scoring result is accepted or read. All nonempty caches are fully scored.

    required = {'feature','weights','thresholds'};
    for k = 1:numel(required)
        if ~isfield(options, required{k})
            error('match_cached_composite_library_open_set:MissingOption', ...
                'options.%s is required.', required{k});
        end
    end
    if isempty(cache) || ~isfield(cache, 'templates') || isempty(cache.templates)
        result = empty_result(cache, options, 'reject_no_feasible_candidate');
        return;
    end
    if ~iscell(observed_views) || isempty(observed_views)
        error('match_cached_composite_library_open_set:InvalidObservation', ...
            'observed_views must be a nonempty cell array.');
    end
    for k = 1:numel(observed_views)
        if any(~isfinite(observed_views{k}(:)))
            error('match_cached_composite_library_open_set:NonfiniteObservation', ...
                'Observed CFR views must be finite.');
        end
    end

    templates = cache.templates;
    if isfield(cache, 'cfr_views') && ~isempty(cache.cfr_views)
        view_count = numel(cache.cfr_views);
        for v = 1:view_count
            if size(cache.cfr_views{v},2) ~= numel(cache.frequency_hz)
                error('match_cached_composite_library_open_set:FrequencyMismatch', ...
                    'Observed and cached frequency dimensions are inconsistent.');
            end
        end
    else
        view_count = numel(templates(1).views);
        if any(cellfun(@(x)numel(x) ~= numel(cache.frequency_hz), templates(1).views))
            error('match_cached_composite_library_open_set:FrequencyMismatch', ...
                'Observed and cached frequency dimensions are inconsistent.');
        end
    end
    if numel(observed_views) ~= view_count
        error('match_cached_composite_library_open_set:ViewCountMismatch', ...
            'Observed and cached view counts are inconsistent.');
    end

    tic;
    distances = Inf(1, numel(templates));
    for k = 1:numel(templates)
        per_view = zeros(1, numel(observed_views));
        for v = 1:numel(observed_views)
            if is_raw_complex_feature(options.feature)
                % topology_feature_distance(...,'complex_raw',...) returns
                % exactly this RMS quantity. Avoid computing unused phase,
                % CIR and normalized features for every cached template.
                delta = observed_views{v}(:).' - cached_view(cache, templates, k, v);
                per_view(v) = sqrt(mean(abs(delta).^2));
            else
                per_view(v) = topology_feature_distance(observed_views{v}, ...
                    cached_view(cache, templates, k, v), options.feature, cache.ofdm_config, ...
                    options.weights, get_option(options, 'distance_options', cache.distance_options));
            end
        end
        distances(k) = sqrt(mean(per_view.^2));
    end
    matching_time = toc;

    topology_ids = {templates.topology_id};
    unique_ids = unique(topology_ids, 'stable');
    topology_scores = Inf(1, numel(unique_ids));
    topology_best_template = zeros(1, numel(unique_ids));
    for k = 1:numel(unique_ids)
        ix = find(strcmp(topology_ids, unique_ids{k}));
        [topology_scores(k), local] = min(distances(ix));
        topology_best_template(k) = ix(local);
    end
    class_labels = unique({templates.equivalence_class}, 'stable');
    class_scores = Inf(1, numel(class_labels));
    class_best_template = zeros(1, numel(class_labels));
    for k = 1:numel(class_labels)
        ix = find(strcmp({templates.equivalence_class}, class_labels{k}));
        [class_scores(k), local] = min(distances(ix));
        class_best_template(k) = ix(local);
    end
    [d1, best_class_index] = min(class_scores);
    other = class_scores;
    other(best_class_index) = Inf;
    [d2, second_class_index] = min(other);
    if isinf(d2)
        second_class = '';
    else
        second_class = class_labels{second_class_index};
    end
    best_template_index = class_best_template(best_class_index);
    best_topology_id = templates(best_template_index).topology_id;
    best_class = class_labels{best_class_index};
    margin = d2 - d1;
    baseline_class = templates(best_template_index).baseline_P0_equivalence_class;
    baseline_size = templates(best_template_index).baseline_P0_equivalence_class_size;
    current_size = templates(best_template_index).equivalence_class_size;
    thresholds = options.thresholds;
    residual_threshold = get_threshold(thresholds, 'residual_threshold', 'residual', Inf);
    margin_threshold = get_threshold(thresholds, 'margin_threshold', 'margin', -Inf);

    if d1 > residual_threshold
        decision = 'reject_model_mismatch';
    elseif margin < margin_threshold
        decision = 'reject_low_margin';
    elseif current_size > 1
        decision = 'equivalence_class';
    elseif baseline_size > 1
        decision = 'unique_given_prior';
    else
        decision = 'unique_topology';
    end

    if is_accepted(decision)
        if current_size > 1
            accepted_set = best_class;
        else
            accepted_set = best_topology_id;
        end
    else
        accepted_set = '';
    end
    result = struct( ...
        'best_template_id',templates(best_template_index).template_id, ...
        'best_topology_id',best_topology_id, ...
        'best_topology_index',templates(best_template_index).topology_index, ...
        'best_equivalence_class',best_class, ...
        'accepted_topology_set',accepted_set, ...
        'baseline_P0_equivalence_class',baseline_class, ...
        'baseline_P0_equivalence_class_size',baseline_size, ...
        'prior_conditioned_equivalence_class',best_class, ...
        'prior_conditioned_equivalence_class_size',current_size, ...
        'best_parameter_values',templates(best_template_index).theta, ...
        'best_distance',d1,'second_competing_class',second_class, ...
        'second_distance',d2,'margin',margin, ...
        'topology_scores',topology_scores,'class_scores',class_scores, ...
        'candidate_count_before_prior',get_option(options,'candidate_count_before_prior',cache.candidate_count), ...
        'candidate_count_after_prior',cache.candidate_count, ...
        'parameter_template_count',cache.parameter_template_count, ...
        'composite_template_count',cache.composite_template_count, ...
        'distance_evaluations',numel(templates)*numel(observed_views), ...
        'matching_time_s',matching_time,'cache_hit',true, ...
        'configuration_hash',cache.configuration_hash, ...
        'decision',decision,'thresholds',thresholds);
end

function result = empty_result(cache, options, decision)
    if isempty(cache), hash = ''; n = 0; p = 0; else
        hash = get_option(cache,'configuration_hash','');
        n = get_option(cache,'candidate_count',0);
        p = get_option(cache,'parameter_template_count',0);
    end
    result = struct('best_template_id','','best_topology_id','', ...
        'best_topology_index',NaN,'best_equivalence_class','', ...
        'accepted_topology_set','','baseline_P0_equivalence_class','', ...
        'baseline_P0_equivalence_class_size',0, ...
        'prior_conditioned_equivalence_class','', ...
        'prior_conditioned_equivalence_class_size',0, ...
        'best_parameter_values',struct(),'best_distance',Inf, ...
        'second_competing_class','','second_distance',Inf,'margin',NaN, ...
        'topology_scores',[],'class_scores',[], ...
        'candidate_count_before_prior',get_option(options,'candidate_count_before_prior',n), ...
        'candidate_count_after_prior',0,'parameter_template_count',p, ...
        'composite_template_count',0,'distance_evaluations',0, ...
        'matching_time_s',0,'cache_hit',false,'configuration_hash',hash, ...
        'decision',decision,'thresholds',options.thresholds);
end

function value = get_option(s, name, default_value)
    if isfield(s, name) && ~isempty(s.(name)), value = s.(name); else, value = default_value; end
end

function value = get_threshold(t, primary, alias, default_value)
    if isfield(t, primary) && ~isempty(t.(primary)), value = t.(primary);
    elseif isfield(t, alias) && ~isempty(t.(alias)), value = t.(alias);
    else, value = default_value; end
end

function tf = is_accepted(decision)
    tf = ismember(decision, {'unique_topology','unique_given_prior','equivalence_class'});
end

function tf = is_raw_complex_feature(feature)
    tf = ismember(lower(char(feature)), {'complex_raw','cfr_complex_raw','raw_complex'});
end

function view = cached_view(cache, templates, template_index, view_index)
    if isfield(cache, 'cfr_views') && ~isempty(cache.cfr_views)
        view = cache.cfr_views{view_index}(template_index,:);
    else
        view = templates(template_index).views{view_index};
    end
end
