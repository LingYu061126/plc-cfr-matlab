function out = exp_stage4a3_1_statistical_open_set_audit(cfg, sc)
%EXP_STAGE4A3_1_STATISTICAL_OPEN_SET_AUDIT Run the repeated-sample audit.
%   One trial bank is shared across grids and prior scenarios. A full CFR
%   template cache is built once per (frequency grid, prior scenario), then
%   every trial is matched against that cache. Truth is joined only offline.

    if nargin < 1 || isempty(cfg)
        root = fileparts(fileparts(mfilename('fullpath')));
        cfg = default_config(root);
    end
    if nargin < 2 || isempty(sc), sc = stage4a3_1_statistical_config(cfg); end
    ensure_result_dirs(cfg);
    if ~exist(sc.cache_dir, 'dir'), mkdir(sc.cache_dir); end

    bank = generate_stage4a3_1_trial_bank(sc);
    parameter_grid = topology_parameter_grid(sc.parameter_search);
    if numel(parameter_grid) ~= sc.parameter_template_count_expected
        error('exp_stage4a3_1:ParameterGridCount', ...
            'Expected %d parameter templates, got %d.', ...
            sc.parameter_template_count_expected, numel(parameter_grid));
    end
    base = generate_radial_topology_candidates(sc.generator);
    test_indices = find(strcmp({bank.split}, 'test'));
    calibration_indices = find(strcmp({bank.split}, 'calibration'));
    if isempty(test_indices) || isempty(calibration_indices)
        error('exp_stage4a3_1:EmptyTrialSplit', 'Calibration and test splits are required.');
    end
    observations = cell(numel(bank), 1);
    grid_rows = repmat(frequency_row_template(), numel(sc.grids), 1);
    for fg = 1:numel(sc.grids)
        grid_rows(fg) = frequency_row(sc.grids(fg), sc);
    end

    decisions = repmat(decision_template(), 0, 1);
    scoring_labels = struct([]);
    truth_labels = struct([]);
    threshold_rows = repmat(threshold_row_template(), 0, 1);
    runtime_rows = repmat(runtime_row_template(), 0, 1);
    equivalence_rows = repmat(equivalence_row_template(), 0, 1);
    cache_metadata = repmat(runtime_row_template(), 0, 1);
    threshold_by_grid = cell(1, numel(sc.grids));
    p0_audit_by_grid = cell(1, numel(sc.grids));
    total_tic = tic;

    fprintf('Stage 4A.3.1 mode=%s: %d calibration, %d test, %d parameter templates\n', ...
        sc.mode, numel(calibration_indices), numel(test_indices), numel(parameter_grid));
    for fg = 1:numel(sc.grids)
        grid = sc.grids(fg);
        fprintf('Stage 4A3.1 grid %s: building P0 baseline audit and cache\n', grid.id);
        f = grid.frequency_hz(:).';
        observations = make_observations(bank, f, cfg, sc.measurement_kind, observations);
        p0 = generate_prior_constrained_candidates(sc.generator, sc.scenarios(1).asset_prior);
        nominal_index = find([parameter_grid.regularization] == 0, 1);
        nominal_library = build_composite_topology_library(f, p0, ...
            parameter_grid(nominal_index), sc.measurement_kind, cfg, numel(p0));
        p0_audit = audit_candidate_observability(p0, nominal_library, cfg, sc.tie_tolerance);
        p0_audit_by_grid{fg} = p0_audit;

        cal_decisions = repmat(decision_template(), 0, 1);
        p0_pre_payload = hash_payload(cfg, sc, grid, sc.scenarios(1), ...
            parameter_grid, 'P0_no_prior', struct());
        [p0_pre_hash, p0_pre_text] = stage4a3_1_config_hash(p0_pre_payload); %#ok<ASGLU>
        p0_metadata = cache_metadata_struct(sc, 'P0_no_prior', p0_pre_hash, p0_audit);
        p0_cache_tic = tic;
        p0_cache = build_stage4a3_1_template_cache(grid, p0, parameter_grid, ...
            cfg, p0_metadata);
        p0_build_time = toc(p0_cache_tic);
        cal_decisions = match_index_set(calibration_indices, bank, observations, ...
            p0_cache, sc, struct('residual_threshold',Inf,'margin_threshold',-Inf));
        cal_labels = build_stage4a3_1_truth_equivalence_labels( ...
            bank(calibration_indices), p0_audit, p0_audit, p0, grid.id, ...
            'P0_no_prior', p0_pre_hash);
        thresholds = calibrate_stage4a3_1_thresholds(cal_decisions, cal_labels, ...
            sc, grid.id, p0_pre_hash);
        threshold_by_grid{fg} = thresholds;

        final_payload = hash_payload(cfg, sc, grid, sc.scenarios(1), ...
            parameter_grid, 'P0_no_prior', thresholds);
        [final_hash, final_text] = stage4a3_1_config_hash(final_payload);
        p0_cache.configuration_hash = final_hash;
        p0_cache.configuration_canonical_text = final_text;
        p0_cache = update_template_hash(p0_cache, final_hash);
        p0_cache_path = cache_path(sc, grid.id, 'P0_no_prior');
        save_cache(p0_cache, p0_cache_path);
        p0_cache_bytes = file_bytes(p0_cache_path);
        threshold_rows(end+1) = threshold_row(grid.id, thresholds, final_hash); %#ok<AGROW>
        equivalence_rows = append_equivalence_rows(equivalence_rows, p0_audit, ...
            grid.id, 'P0_no_prior', 'baseline_P0', final_hash);

        for ss = 1:numel(sc.scenarios)
            scenario = sc.scenarios(ss);
            scenario_id = scenario.id;
            fprintf('  scenario %s: cache and repeated test matching\n', scenario_id);
            candidates = generate_prior_constrained_candidates(sc.generator, scenario.asset_prior);
            if strcmp(scenario_id, 'P0_no_prior')
                cache = p0_cache;
                current_audit = p0_audit;
                build_time = p0_build_time;
                cache_file = p0_cache_path;
                cache_bytes = p0_cache_bytes;
                current_hash = final_hash;
            else
                payload = hash_payload(cfg, sc, grid, scenario, parameter_grid, ...
                    scenario_id, thresholds);
                [current_hash, current_text] = stage4a3_1_config_hash(payload); %#ok<ASGLU>
                metadata = cache_metadata_struct(sc, scenario_id, current_hash, p0_audit);
                cache_tic = tic;
                cache = build_stage4a3_1_template_cache(grid, candidates, ...
                    parameter_grid, cfg, metadata);
                build_time = toc(cache_tic);
                cache.configuration_canonical_text = current_text;
                cache_file = cache_path(sc, grid.id, scenario_id);
                save_cache(cache, cache_file);
                cache_bytes = file_bytes(cache_file);
                current_audit = cache.current_equivalence_audit;
            end
            if ~strcmp(current_hash, cache.configuration_hash)
                cache.configuration_hash = current_hash;
                cache = update_template_hash(cache, current_hash);
            end
            if isempty(cache_file) || ~exist(cache_file, 'file')
                cache_file = cache_path(sc, grid.id, scenario_id);
                save_cache(cache, cache_file);
                cache_bytes = file_bytes(cache_file);
            end

            match_tic = tic;
            test_decisions = match_index_set(test_indices, bank, observations, ...
                cache, sc, thresholds);
            match_time = toc(match_tic);
            test_labels = build_stage4a3_1_truth_equivalence_labels( ...
                bank(test_indices), p0_audit, current_audit, candidates, ...
                grid.id, scenario_id, current_hash);
            for k = 1:numel(test_decisions)
                test_decisions(k).grid_id = grid.id;
            end
            if isempty(decisions), decisions = test_decisions; else, decisions = [decisions; test_decisions]; end %#ok<AGROW>
            if isempty(scoring_labels), scoring_labels = test_labels; else, scoring_labels = [scoring_labels; test_labels]; end %#ok<AGROW>
            if isempty(truth_labels), truth_labels = test_labels; else, truth_labels = [truth_labels; test_labels]; end %#ok<AGROW>
            equivalence_rows = append_equivalence_rows(equivalence_rows, current_audit, ...
                grid.id, scenario_id, 'prior_conditioned', current_hash);
            row = runtime_row(grid, scenario_id, cache, cache_file, cache_bytes, ...
                build_time, numel(calibration_indices), numel(test_indices), ...
                match_time, current_hash);
            runtime_rows(end+1) = row; %#ok<AGROW>
            cache_metadata(end+1) = row; %#ok<AGROW>
            clear cache;
        end
    end

    metrics = evaluate_stage4a3_1_metrics(decisions, scoring_labels, truth_labels);
    prefix = sc.output_prefix;
    write_stage_outputs(cfg, prefix, bank, decisions, scoring_labels, truth_labels, ...
        threshold_rows, metrics, runtime_rows, grid_rows, equivalence_rows, ...
        parameter_grid, sc, threshold_by_grid, p0_audit_by_grid, cache_metadata, total_tic);
    out = struct('runtime_s',toc(total_tic),'bank',bank,'decisions',decisions, ...
        'scoring_labels',scoring_labels,'truth_labels',truth_labels, ...
        'thresholds',threshold_rows,'metrics',metrics,'runtime',runtime_rows, ...
        'frequency_manifest',grid_rows,'equivalence_audit',equivalence_rows, ...
        'parameter_grid',parameter_grid,'config',sc);
    fprintf('Stage 4A.3.1 completed in %.3f s\n', out.runtime_s);
end

function observations = make_observations(bank, f, cfg, measurement_kind, observations)
    for k = 1:numel(bank)
        [network, local_cfg] = topology_apply_parameters(bank(k).truth_network, ...
            cfg, bank(k).truth_theta);
        [measurement, ~] = plc_measurement_bundle(measurement_kind, network, ...
            bank(k).truth_theta, local_cfg);
        [observations{k}, ~] = plc_multiview_response(f, network, measurement, local_cfg);
    end
end

function decisions = match_index_set(indices, bank, observations, cache, sc, thresholds)
    decisions = repmat(decision_template(), numel(indices), 1);
    options = struct('feature',sc.feature,'weights',sc.weights, ...
        'distance_options',sc.distance_options,'thresholds',thresholds, ...
        'candidate_count_before_prior',numel(cache.candidates));
    for k = 1:numel(indices)
        result = match_cached_composite_library_open_set(observations{indices(k)}, cache, options);
        result.sample_id = bank(indices(k)).sample_id;
        result.grid_id = cache.frequency_grid_id;
        decisions(k) = result;
    end
    decisions = decisions(:);
end

function payload = hash_payload(cfg, sc, grid, scenario, parameter_grid, scenario_id, thresholds)
    observation = struct('measurement_kind',sc.measurement_kind, ...
        'source_impedance_ohm',cfg.Zs,'receiver_impedance_ohm',cfg.Zr, ...
        'port_reference_ohm',cfg.port_reference_ohm, ...
        'reference_plane_status','simulation_reference_plane');
    payload = struct('stage_name',sc.stage_name,'version',sc.version, ...
        'code_version',sc.code_version,'base_config',cfg,'stage_config',sc, ...
        'candidate_grammar',sc.generator,'asset_prior',scenario.asset_prior, ...
        'parameter_search',sc.parameter_search,'parameter_grid',parameter_grid, ...
        'frequency_grid',grid,'frequency_array_hz',grid.frequency_hz(:).', ...
        'nfft',grid.nfft,'sample_rate_hz',grid.sample_rate_hz, ...
        'active_bin_1based',grid.active_bin_1based, ...
        'observation_config',observation,'distance_feature',sc.feature, ...
        'distance_weights',sc.weights,'distance_options',sc.distance_options, ...
        'tie_tolerance',sc.tie_tolerance,'calibration',sc.calibration, ...
        'sample_design',sc.sample_design,'calibration_seed',sc.calibration_seed, ...
        'test_seed',sc.test_seed,'scenario_id',scenario_id, ...
        'frozen_thresholds',thresholds);
end

function metadata = cache_metadata_struct(sc, scenario_id, hash, p0_audit)
    metadata = struct('measurement_kind',sc.measurement_kind, ...
        'tie_tolerance',sc.tie_tolerance,'distance_feature',sc.feature, ...
        'distance_weights',sc.weights,'distance_options',sc.distance_options, ...
        'scenario_id',scenario_id,'configuration_hash',hash, ...
        'max_composite_templates',sc.max_composite_templates, ...
        'baseline_P0_audit',p0_audit);
end

function cache = update_template_hash(cache, hash)
    cache.configuration_hash = hash;
    for k = 1:numel(cache.templates), cache.templates(k).configuration_hash = hash; end
end

function path_out = cache_path(sc, grid_id, scenario_id)
    if ~exist(sc.cache_dir, 'dir'), mkdir(sc.cache_dir); end
    path_out = fullfile(sc.cache_dir, sprintf('stage4a3_1_cache_%s_%s.mat', ...
        grid_id, scenario_id));
end

function save_cache(cache, path_out)
    save(path_out, 'cache', '-v7.3');
end

function value = file_bytes(path_in)
    info = dir(path_in);
    if isempty(info), value = NaN; else, value = info.bytes; end
end

function row = runtime_row(grid, scenario_id, cache, cache_file, cache_bytes, ...
        build_time, ncal, ntest, match_time, hash)
    row = runtime_row_template();
    row.grid_id = grid.id;
    row.scenario_id = scenario_id;
    row.cache_file = cache_file;
    row.candidate_count = cache.candidate_count;
    row.parameter_template_count = cache.parameter_template_count;
    row.composite_template_count = cache.composite_template_count;
    row.frequency_count = numel(cache.frequency_hz);
    row.view_count = cache.view_count;
    row.estimated_memory_bytes = cache.estimated_memory_bytes;
    row.cache_file_bytes = cache_bytes;
    row.cache_build_time_s = build_time;
    row.calibration_sample_count = ncal;
    row.test_sample_count = ntest;
    row.match_time_s = match_time;
    row.total_runtime_s = build_time + match_time;
    row.configuration_hash = hash;
end

function append_rows = append_equivalence_rows(append_rows, audit, grid_id, scenario_id, scope, hash)
    for k = 1:numel(audit.equivalence_classes)
        x = audit.equivalence_classes{k};
        row = equivalence_row_template();
        row.grid_id = grid_id;
        row.scenario_id = scenario_id;
        row.scope = scope;
        row.equivalence_class = x.label;
        row.member_count = numel(x.member_indices);
        row.member_topology_ids = strjoin(x.member_topology_ids, ',');
        row.candidate_count = audit.candidate_count;
        row.tie_tolerance = audit.tie_tolerance;
        row.configuration_hash = hash;
        append_rows(end+1) = row; %#ok<AGROW>
    end
end

function write_stage_outputs(cfg, prefix, bank, decisions, scoring_labels, ...
        truth_labels, threshold_rows, metrics, runtime_rows, grid_rows, ...
        equivalence_rows, parameter_grid, sc, threshold_by_grid, p0_audits, ...
        cache_metadata, total_tic)
    data = cfg.results_data;
    writetable(struct2table(bank_rows(bank, sc)), fullfile(data, [prefix '_trial_bank.csv']));
    writetable(struct2table(decision_rows(decisions)), fullfile(data, [prefix '_match_decisions.csv']));
    writetable(struct2table(scoring_rows(scoring_labels)), fullfile(data, [prefix '_scoring_labels.csv']));
    writetable(struct2table(truth_rows(truth_labels)), fullfile(data, [prefix '_truth_equivalence_labels.csv']));
    writetable(struct2table(threshold_rows), fullfile(data, [prefix '_thresholds.csv']));
    writetable(struct2table(metrics), fullfile(data, [prefix '_metrics.csv']));
    writetable(struct2table(runtime_rows), fullfile(data, [prefix '_runtime_and_cache.csv']));
    writetable(struct2table(grid_rows), fullfile(data, [prefix '_frequency_grid_manifest.csv']));
    writetable(struct2table(equivalence_rows), fullfile(data, [prefix '_equivalence_audit.csv']));
    parameter_summary = make_parameter_summary(bank, sc);
    writetable(struct2table(parameter_summary), fullfile(data, [prefix '_parameter_summary.csv']));
    result_file = fullfile(data, [prefix '_results.mat']);
    save(result_file, 'sc','bank','decisions','scoring_labels','truth_labels', ...
        'threshold_rows','metrics','runtime_rows','grid_rows','equivalence_rows', ...
        'parameter_grid','threshold_by_grid','p0_audits','cache_metadata','-v7.3');
    fprintf('Generated or rewritten Stage 4A.3.1 files under %s\n', data);
    fprintf('  total elapsed at output write: %.3f s\n', toc(total_tic));
end

function row = decision_template()
    row = struct('sample_id','','grid_id','','decision','', ...
        'best_template_id','','best_topology_id','','best_topology_index',NaN, ...
        'best_equivalence_class','', ...
        'accepted_topology_set','','baseline_P0_equivalence_class','', ...
        'baseline_P0_equivalence_class_size',0, ...
        'prior_conditioned_equivalence_class','', ...
        'prior_conditioned_equivalence_class_size',0, ...
        'best_parameter_values',struct(),'best_distance',NaN, ...
        'second_competing_class','','second_distance',NaN,'margin',NaN, ...
        'topology_scores',[],'class_scores',[], ...
        'candidate_count_before_prior',0,'candidate_count_after_prior',0, ...
        'parameter_template_count',0,'composite_template_count',0, ...
        'distance_evaluations',0,'matching_time_s',NaN,'cache_hit',false, ...
        'configuration_hash','','thresholds',struct());
end

function rows = decision_rows(x)
    row = struct('sample_id','','grid_id','','decision','', ...
        'best_template_id','','best_topology_id','','best_equivalence_class','', ...
        'accepted_topology_set','','baseline_P0_equivalence_class','', ...
        'baseline_P0_equivalence_class_size',0,'prior_conditioned_equivalence_class','', ...
        'prior_conditioned_equivalence_class_size',0,'best_parameter_values','', ...
        'best_distance',NaN,'second_competing_class','','second_distance',NaN, ...
        'margin',NaN,'candidate_count_before_prior',0,'candidate_count_after_prior',0, ...
        'parameter_template_count',0,'composite_template_count',0, ...
        'distance_evaluations',0,'matching_time_s',NaN,'cache_hit',false, ...
        'residual_threshold',NaN,'margin_threshold',NaN,'configuration_hash','');
    rows = repmat(row, numel(x), 1);
    for k = 1:numel(x)
        rows(k) = struct('sample_id',x(k).sample_id,'grid_id',x(k).grid_id, ...
            'decision',x(k).decision,'best_template_id',x(k).best_template_id, ...
            'best_topology_id',x(k).best_topology_id, ...
            'best_equivalence_class',x(k).best_equivalence_class, ...
            'accepted_topology_set',x(k).accepted_topology_set, ...
            'baseline_P0_equivalence_class',x(k).baseline_P0_equivalence_class, ...
            'baseline_P0_equivalence_class_size',x(k).baseline_P0_equivalence_class_size, ...
            'prior_conditioned_equivalence_class',x(k).prior_conditioned_equivalence_class, ...
            'prior_conditioned_equivalence_class_size',x(k).prior_conditioned_equivalence_class_size, ...
            'best_parameter_values',theta_text(x(k).best_parameter_values), ...
            'best_distance',x(k).best_distance,'second_competing_class',x(k).second_competing_class, ...
            'second_distance',x(k).second_distance,'margin',x(k).margin, ...
            'candidate_count_before_prior',x(k).candidate_count_before_prior, ...
            'candidate_count_after_prior',x(k).candidate_count_after_prior, ...
            'parameter_template_count',x(k).parameter_template_count, ...
            'composite_template_count',x(k).composite_template_count, ...
            'distance_evaluations',x(k).distance_evaluations, ...
            'matching_time_s',x(k).matching_time_s,'cache_hit',x(k).cache_hit, ...
            'residual_threshold',threshold_value(x(k).thresholds,'residual_threshold','residual',Inf), ...
            'margin_threshold',threshold_value(x(k).thresholds,'margin_threshold','margin',-Inf), ...
            'configuration_hash',x(k).configuration_hash);
    end
end

function rows = bank_rows(bank, sc)
    row = struct('sample_id','','split','','category','','truth_topology_id','', ...
        'canonical_key','','truth_main_length_scale',NaN,'truth_branch_length_scale',NaN, ...
        'truth_branch_load_scale',NaN,'truth_source_impedance_ohm',NaN, ...
        'truth_receiver_impedance_ohm',NaN,'outlier_dimension','','outlier_direction','', ...
        'source_tag','','calibration_seed',sc.calibration_seed,'test_seed',sc.test_seed);
    rows = repmat(row, numel(bank), 1);
    for k = 1:numel(bank)
        t = bank(k).truth_theta;
        rows(k) = struct('sample_id',bank(k).sample_id,'split',bank(k).split, ...
            'category',bank(k).category,'truth_topology_id',bank(k).truth_topology_id, ...
            'canonical_key',bank(k).canonical_key,'truth_main_length_scale',t.main_length_scale, ...
            'truth_branch_length_scale',t.branch_length_scale,'truth_branch_load_scale',t.branch_load_scale, ...
            'truth_source_impedance_ohm',t.source_impedance_ohm, ...
            'truth_receiver_impedance_ohm',t.receiver_impedance_ohm, ...
            'outlier_dimension',bank(k).outlier_dimension,'outlier_direction',bank(k).outlier_direction, ...
            'source_tag',bank(k).source_tag,'calibration_seed',sc.calibration_seed, ...
            'test_seed',sc.test_seed);
    end
end

function rows = scoring_rows(labels)
    rows = labels;
end

function rows = truth_rows(labels)
    rows = labels;
end

function row = threshold_row_template()
    row = struct('grid_id','','residual_threshold',NaN,'margin_threshold',NaN, ...
        'sample_count',0,'residual_calibration_count',0,'margin_calibration_count',0, ...
        'residual_quantile',NaN,'margin_quantile',NaN,'residual_quantile_value',NaN, ...
        'margin_quantile_value',NaN,'residual_safety_factor',NaN, ...
        'calibration_seed',0,'test_seed',0,'source','','configuration_hash','');
end

function row = threshold_row(grid_id, threshold, hash)
    row = threshold_row_template();
    row.grid_id = grid_id;
    row.residual_threshold = threshold.residual_threshold;
    row.margin_threshold = threshold.margin_threshold;
    row.sample_count = threshold.sample_count;
    row.residual_calibration_count = threshold.residual_calibration_count;
    row.margin_calibration_count = threshold.margin_calibration_count;
    row.residual_quantile = threshold.residual_quantile;
    row.margin_quantile = threshold.margin_quantile;
    row.residual_quantile_value = threshold.residual_quantile_value;
    row.margin_quantile_value = threshold.margin_quantile_value;
    row.residual_safety_factor = threshold.residual_safety_factor;
    row.calibration_seed = threshold.calibration_seed;
    row.test_seed = threshold.test_seed;
    row.source = threshold.source;
    row.configuration_hash = hash;
end

function row = frequency_row_template()
    row = struct('grid_id','','source','','nfft',0,'sample_rate_hz',NaN, ...
        'active_bin_count',0,'frequency_count',0,'frequency_min_hz',NaN, ...
        'frequency_max_hz',NaN,'frequency_spacing_hz',NaN, ...
        'active_bin_1based','','frequency_array_hz','','configuration_hash','');
end

function row = frequency_row(grid, sc)
    row = frequency_row_template();
    f = grid.frequency_hz(:).'; d = diff(f);
    if isempty(d), spacing = NaN; else, spacing = median(d); end
    payload = struct('stage_config',sc,'frequency_grid',grid, ...
        'frequency_array_hz',f,'nfft',grid.nfft,'sample_rate_hz',grid.sample_rate_hz, ...
        'active_bin_1based',grid.active_bin_1based);
    [hash, ~] = stage4a3_1_config_hash(payload);
    row.grid_id = grid.id; row.source = grid.source; row.nfft = grid.nfft;
    row.sample_rate_hz = grid.sample_rate_hz; row.active_bin_count = numel(grid.active_bin_1based);
    row.frequency_count = numel(f); row.frequency_min_hz = min(f); row.frequency_max_hz = max(f);
    row.frequency_spacing_hz = spacing; row.active_bin_1based = array_text(grid.active_bin_1based);
    row.frequency_array_hz = array_text(f); row.configuration_hash = hash;
end

function row = runtime_row_template()
    row = struct('grid_id','','scenario_id','','cache_file','', ...
        'candidate_count',0,'parameter_template_count',0,'composite_template_count',0, ...
        'frequency_count',0,'view_count',0,'estimated_memory_bytes',NaN, ...
        'cache_file_bytes',NaN,'cache_build_time_s',NaN,'calibration_sample_count',0, ...
        'test_sample_count',0,'match_time_s',NaN,'total_runtime_s',NaN, ...
        'configuration_hash','');
end

function row = equivalence_row_template()
    row = struct('grid_id','','scenario_id','','scope','','equivalence_class','', ...
        'member_count',0,'member_topology_ids','','candidate_count',0, ...
        'tie_tolerance',NaN,'configuration_hash','');
end

function rows = make_parameter_summary(bank, sc)
    kinds = unique({bank.category}, 'stable');
    rows = repmat(struct('split','','category','','sample_count',0, ...
        'main_min',NaN,'main_max',NaN,'main_mean',NaN, ...
        'branch_min',NaN,'branch_max',NaN,'branch_mean',NaN, ...
        'load_min',NaN,'load_max',NaN,'load_mean',NaN, ...
        'Zs_min',NaN,'Zs_max',NaN,'Zs_mean',NaN, ...
        'Zr_min',NaN,'Zr_max',NaN,'Zr_mean',NaN, ...
        'calibration_seed',sc.calibration_seed,'test_seed',sc.test_seed), 0, 1);
    splits = {'calibration','test'};
    for a = 1:numel(splits)
        for b = 1:numel(kinds)
            ix = strcmp({bank.split},splits{a}) & strcmp({bank.category},kinds{b});
            if ~any(ix), continue; end
            theta = [bank(ix).truth_theta];
            row = rows_template_summary();
            row.split = splits{a}; row.category = kinds{b}; row.sample_count = sum(ix);
            row.main_min = min([theta.main_length_scale]); row.main_max = max([theta.main_length_scale]); row.main_mean = mean([theta.main_length_scale]);
            row.branch_min = min([theta.branch_length_scale]); row.branch_max = max([theta.branch_length_scale]); row.branch_mean = mean([theta.branch_length_scale]);
            row.load_min = min([theta.branch_load_scale]); row.load_max = max([theta.branch_load_scale]); row.load_mean = mean([theta.branch_load_scale]);
            row.Zs_min = min([theta.source_impedance_ohm]); row.Zs_max = max([theta.source_impedance_ohm]); row.Zs_mean = mean([theta.source_impedance_ohm]);
            row.Zr_min = min([theta.receiver_impedance_ohm]); row.Zr_max = max([theta.receiver_impedance_ohm]); row.Zr_mean = mean([theta.receiver_impedance_ohm]);
            rows(end+1) = row; %#ok<AGROW>
        end
    end
end

function row = rows_template_summary()
    row = struct('split','','category','','sample_count',0, ...
        'main_min',NaN,'main_max',NaN,'main_mean',NaN,'branch_min',NaN, ...
        'branch_max',NaN,'branch_mean',NaN,'load_min',NaN,'load_max',NaN, ...
        'load_mean',NaN,'Zs_min',NaN,'Zs_max',NaN,'Zs_mean',NaN, ...
        'Zr_min',NaN,'Zr_max',NaN,'Zr_mean',NaN,'calibration_seed',0,'test_seed',0);
end

function value = threshold_value(t, primary, alias, default_value)
    if isfield(t, primary) && ~isempty(t.(primary)), value = t.(primary);
    elseif isfield(t, alias) && ~isempty(t.(alias)), value = t.(alias);
    else, value = default_value; end
end

function text = theta_text(theta)
    if isempty(theta) || ~isstruct(theta), text = ''; return; end
    text = sprintf('main=%.12g;branch=%.12g;load=%.12g;Zs=%.12g;Zr=%.12g', ...
        theta.main_length_scale,theta.branch_length_scale,theta.branch_load_scale, ...
        theta.source_impedance_ohm,theta.receiver_impedance_ohm);
end

function text = array_text(x)
    if isempty(x), text = ''; else, text = mat2str(x(:).', 17); end
end
