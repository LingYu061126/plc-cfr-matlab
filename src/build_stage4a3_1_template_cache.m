function cache = build_stage4a3_1_template_cache(frequency_grid, candidates, theta_grid, cfg, metadata)
%BUILD_STAGE4A3_1_TEMPLATE_CACHE Build one reusable CFR template cache.
%   The cache contains only candidate graph/parameter templates and forward
%   model outputs. It contains no trial observations or truth labels.
%   frequency_grid is a scalar struct with frequency_hz and id fields.
%   metadata must contain measurement_kind, tie_tolerance, distance_feature,
%   distance_weights, distance_options, scenario_id, configuration_hash and
%   an optional baseline_P0_audit.

    required = {'measurement_kind','tie_tolerance','distance_feature', ...
        'distance_weights','distance_options','scenario_id','configuration_hash'};
    for k = 1:numel(required)
        if ~isfield(metadata, required{k})
            error('build_stage4a3_1_template_cache:MissingMetadata', ...
                'metadata.%s is required.', required{k});
        end
    end
    f = frequency_grid.frequency_hz(:).';
    if isempty(f) || any(~isfinite(f)) || any(f <= 0)
        error('build_stage4a3_1_template_cache:InvalidFrequencyGrid', ...
            'frequency_grid.frequency_hz must be a nonempty positive finite array.');
    end
    if isempty(candidates) || isempty(theta_grid)
        error('build_stage4a3_1_template_cache:EmptyInput', ...
            'Candidates and theta_grid are required.');
    end
    n_template = numel(candidates) * numel(theta_grid);
    if isfield(metadata, 'max_composite_templates') && n_template > metadata.max_composite_templates
        error('build_stage4a3_1_template_cache:MaxTemplatesExceeded', ...
            'Requested %d templates, above configured maximum %d.', ...
            n_template, metadata.max_composite_templates);
    end

    tic;
    nominal_index = find([theta_grid.regularization] == 0, 1);
    nominal = build_composite_topology_library(f, candidates, ...
        theta_grid(nominal_index), metadata.measurement_kind, cfg, numel(candidates));
    if numel(nominal) ~= numel(candidates)
        error('build_stage4a3_1_template_cache:NominalTemplateCount', ...
            'Exactly one nominal template per candidate is required.');
    end
    current_audit = audit_candidate_observability(candidates, nominal, cfg, metadata.tie_tolerance);

    current_labels = cell(1, numel(candidates));
    current_sizes = zeros(1, numel(candidates));
    for k = 1:numel(candidates)
        class_index = current_audit.core.class_index(k);
        current_labels{k} = current_audit.core.class_labels{k};
        current_sizes(k) = current_audit.core.class_sizes(class_index);
    end
    baseline_labels = repmat({''}, 1, numel(candidates));
    baseline_sizes = zeros(1, numel(candidates));
    if isfield(metadata, 'baseline_P0_audit') && ~isempty(metadata.baseline_P0_audit)
        baseline_audit = metadata.baseline_P0_audit;
        for k = 1:numel(candidates)
            [baseline_labels{k}, baseline_sizes(k)] = ...
                baseline_for_id(baseline_audit, candidates(k).topology_id);
        end
    end

    empty_template = struct('template_id','','topology_id','','topology_index',0, ...
        'canonical_key','','parameter_grid_index',0,'theta',struct(), ...
        'equivalence_class','','equivalence_class_size',0, ...
        'baseline_P0_equivalence_class','','baseline_P0_equivalence_class_size',0, ...
        'views',{{}},'frequency_grid_id','','scenario_id','','configuration_hash','');
    templates = repmat(empty_template, 1, n_template);
    cfr_views = {};
    view_count = 0;
    cursor = 0;
    % Generate directly into the compact cache. The older library builder
    % retains network/solver detail for every item and is unsuitable for the
    % 1793-point grid at this repeated-sample stage.
    for g = 1:numel(candidates)
        for q = 1:numel(theta_grid)
            cursor = cursor + 1;
            theta = theta_grid(q);
            [network, local_cfg] = topology_apply_parameters(candidates(g).network, cfg, theta);
            [measurement, ~] = plc_measurement_bundle(metadata.measurement_kind, network, theta, local_cfg);
            [views, ~] = plc_multiview_response(f, network, measurement, local_cfg);
            if any(cellfun(@(x)any(~isfinite(x(:))), views))
                error('build_stage4a3_1_template_cache:NonfiniteCFR', ...
                    'Template %s_P%03d has nonfinite CFR.', candidates(g).topology_id, q);
            end
            if cursor == 1
                view_count = numel(views);
                cfr_views = cell(1, view_count);
                for v = 1:view_count
                    cfr_views{v} = complex(zeros(n_template, numel(f)));
                end
            elseif numel(views) ~= view_count
                error('build_stage4a3_1_template_cache:ViewCountMismatch', ...
                    'Forward model returned inconsistent view counts.');
            end
            for v = 1:view_count
                cfr_views{v}(cursor,:) = views{v}(:).';
            end
            item = empty_template;
            item.template_id = sprintf('%s_P%03d', candidates(g).topology_id, q);
            item.topology_id = candidates(g).topology_id;
            item.topology_index = g;
            item.canonical_key = candidates(g).canonical_key;
            item.parameter_grid_index = q;
            item.theta = theta;
            item.equivalence_class = current_labels{g};
            item.equivalence_class_size = current_sizes(g);
            item.baseline_P0_equivalence_class = baseline_labels{g};
            item.baseline_P0_equivalence_class_size = baseline_sizes(g);
            % CFR data are kept in contiguous numeric matrices below. The
            % per-template field remains an empty placeholder for a stable
            % metadata schema and to avoid nested-cell allocation overhead.
            item.views = {};
            item.frequency_grid_id = frequency_grid.id;
            item.scenario_id = metadata.scenario_id;
            item.configuration_hash = metadata.configuration_hash;
            templates(cursor) = item;
        end
    end
    elapsed = toc;
    estimated_bytes = double(n_template) * double(view_count) * double(numel(f)) * 16;
    cache = struct();
    cache.stage_name = 'Stage 4A.3.1';
    cache.version = 'template_cache_v1';
    cache.frequency_grid_id = frequency_grid.id;
    cache.frequency_hz = f;
    cache.frequency_grid = frequency_grid;
    cache.scenario_id = metadata.scenario_id;
    cache.configuration_hash = metadata.configuration_hash;
    cache.measurement_kind = metadata.measurement_kind;
    cache.distance_feature = metadata.distance_feature;
    cache.distance_weights = metadata.distance_weights;
    cache.distance_options = metadata.distance_options;
    cache.ofdm_config = cfg.ofdm;
    cache.candidates = candidate_manifest(candidates);
    cache.current_equivalence_audit = current_audit;
    cache.templates = templates;
    cache.cfr_views = cfr_views;
    cache.candidate_count = numel(candidates);
    cache.parameter_template_count = numel(theta_grid);
    cache.composite_template_count = n_template;
    cache.view_count = view_count;
    cache.estimated_memory_bytes = estimated_bytes;
    cache.build_time_s = elapsed;
    cache.cache_contains_truth = false;
end

function rows = candidate_manifest(candidates)
    rows = repmat(struct('topology_id','','canonical_key',''), numel(candidates), 1);
    for k = 1:numel(candidates)
        rows(k) = struct('topology_id',candidates(k).topology_id, ...
            'canonical_key',candidates(k).canonical_key);
    end
end

function [label, size_value] = baseline_for_id(audit, topology_id)
    label = '';
    size_value = 0;
    for k = 1:numel(audit.equivalence_classes)
        ids = audit.equivalence_classes{k}.member_topology_ids;
        if any(strcmp(ids, topology_id))
            label = audit.equivalence_classes{k}.label;
            size_value = numel(audit.equivalence_classes{k}.member_indices);
            return;
        end
    end
end
