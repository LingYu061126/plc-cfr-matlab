function test_stage4a3_1_statistical_open_set_audit()
%TEST_STAGE4A3_1_STATISTICAL_OPEN_SET_AUDIT Fast invariant tests for 4A.3.1.
    fprintf('Running Stage 4A.3.1 statistical open-set tests...\n');
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root,'src')); addpath(fullfile(root,'config')); addpath(fullfile(root,'experiments'));
    cfg = default_config(root);
    sc = stage4a3_1_statistical_config(cfg, 'smoke');
    formal = stage4a3_1_statistical_config(cfg, 'formal');
    assert(formal.per_graph_calibration >= 8 && formal.per_graph_test >= 12, ...
        'Formal repeated-sample counts are below the required minimum.');
    assert(numel(topology_parameter_grid(formal.parameter_search)) == 243, ...
        'The full Stage-2.3 Cartesian parameter grid changed.');

    p0 = generate_prior_constrained_candidates(sc.generator, sc.scenarios(1).asset_prior);
    p1 = generate_prior_constrained_candidates(sc.generator, sc.scenarios(2).asset_prior);
    p2 = generate_prior_constrained_candidates(sc.generator, sc.scenarios(3).asset_prior);
    base = generate_radial_topology_candidates(sc.generator);
    assert(numel(p0) == 7 && isequal({p0.canonical_key},{base.canonical_key}), ...
        'P0 no-prior candidate set is not the Stage-4A.1 set.');
    assert(numel(p1) < numel(p0) && numel(p2) < numel(p0), ...
        'P1/P2 did not apply hard prior filtering.');

    bank = generate_stage4a3_1_trial_bank(formal);
    cal = bank(strcmp({bank.split},'calibration'));
    test = bank(strcmp({bank.split},'test'));
    assert(isempty(intersect({cal.sample_id},{test.sample_id})), ...
        'Calibration and test sample IDs overlap.');
    assert(numel(unique({cal.truth_topology_id})) == 7, ...
        'Every P0 graph must enter the calibration bank.');
    structure_keys = unique({bank(strcmp({bank.category},'structure_out')).canonical_key});
    assert(numel(structure_keys) >= 3, 'Structure-out diversity is below three keys.');
    assert(sum(strcmp({bank.category},'structure_out')) == formal.structure_out_sample_count && ...
        sum(strcmp({bank.category},'parameter_out')) == formal.parameter_out_sample_count, ...
        'Out-of-library sample counts are not frozen as configured.');

    matcher_text = fileread(which('match_cached_composite_library_open_set'));
    assert(isempty(regexp(matcher_text,'coverage_status|truth_topology_id|scenario_id','once')), ...
        'Cached matcher source exposes a forbidden truth/scenario interface.');
    [h1,~] = stage4a3_1_config_hash(struct('frequency_hz',[1 2 3], ...
        'prior',sc.scenarios(1).asset_prior));
    [h2,~] = stage4a3_1_config_hash(struct('frequency_hz',[1 2 3.0001], ...
        'prior',sc.scenarios(1).asset_prior));
    assert(numel(h1) == 64 && ~strcmp(h1,h2), 'SHA-256 is not sensitive to exact frequency arrays.');

    grid = topology_parameter_grid(sc.parameter_search);
    nominal_index = find([grid.regularization] == 0, 1);
    small_grid = grid([nominal_index, 1, 2]);
    f = sc.grids(1).frequency_hz(1:5);
    frequency_grid = sc.grids(1); frequency_grid.frequency_hz = f;
    metadata = struct('measurement_kind',sc.measurement_kind, ...
        'tie_tolerance',sc.tie_tolerance,'distance_feature',sc.feature, ...
        'distance_weights',sc.weights,'distance_options',sc.distance_options, ...
        'scenario_id','P0_no_prior','configuration_hash',h1, ...
        'max_composite_templates',Inf,'baseline_P0_audit',[]);
    nominal_lib = build_composite_topology_library(f,p0,grid(nominal_index),sc.measurement_kind,cfg,numel(p0));
    p0_audit = audit_candidate_observability(p0,nominal_lib,cfg,sc.tie_tolerance);
    metadata.baseline_P0_audit = p0_audit;
    cache = build_stage4a3_1_template_cache(frequency_grid,p0,small_grid,cfg,metadata);
    [net, local_cfg] = topology_apply_parameters(p0(3).network,cfg,grid(nominal_index));
    [measurement,~] = plc_measurement_bundle(sc.measurement_kind,net,grid(nominal_index),local_cfg);
    [obs,~] = plc_multiview_response(f,net,measurement,local_cfg);
    options = struct('feature',sc.feature,'weights',sc.weights, ...
        'distance_options',sc.distance_options,'thresholds', ...
        struct('residual_threshold',Inf,'margin_threshold',-Inf), ...
        'candidate_count_before_prior',numel(p0));
    cached = match_cached_composite_library_open_set(obs,cache,options);
    assert(cached.distance_evaluations == cache.composite_template_count*numel(obs), ...
        'Nonempty cached library did not evaluate every template/view.');
    old_options = struct('measurement_kind',sc.measurement_kind, ...
        'tie_tolerance',sc.tie_tolerance,'feature',sc.feature,'weights',sc.weights, ...
        'batch_size',8,'thresholds',struct('residual',Inf,'margin',-Inf));
    streamed = match_composite_topology_library_open_set(obs,f,p0,small_grid,cfg,old_options);
    assert(abs(cached.best_distance-streamed.best_distance) < 1e-12 && ...
        strcmp(cached.best_topology_id,streamed.best_topology_id), ...
        'Cached and Stage-4A.3 streaming matches disagree.');
    cached_again = match_cached_composite_library_open_set(obs,cache,options);
    assert(strcmp(cached.decision,cached_again.decision) && ...
        strcmp(cached.best_template_id,cached_again.best_template_id) && ...
        abs(cached.best_distance-cached_again.best_distance) < 1e-14, ...
        'Changing no labels did not preserve the observation-only decision.');

    low_options = options; low_options.thresholds.margin_threshold = Inf;
    low = match_cached_composite_library_open_set(obs,cache,low_options);
    assert(strcmp(low.decision,'reject_low_margin'), ...
        'A singleton best class with insufficient margin was not rejected as low-margin.');
    empty_cache = cache; empty_cache.templates = repmat(cache.templates(1),0,1);
    empty = match_cached_composite_library_open_set(obs,empty_cache,options);
    assert(strcmp(empty.decision,'reject_no_feasible_candidate'), ...
        'Empty candidate cache did not produce reject_no_feasible_candidate.');

    prior_ids = {p1.topology_id};
    chosen = '';
    for k = 1:numel(p0)
        [~, size0] = class_for_id_local(p0_audit,p0(k).topology_id);
        if size0 > 1 && any(strcmp(prior_ids,p0(k).topology_id)), chosen = p0(k).topology_id; break; end
    end
    assert(~isempty(chosen), 'P1 did not retain a member of a P0 nonunique class.');
    p1_nominal = build_composite_topology_library(f,p1,grid(nominal_index), ...
        sc.measurement_kind,cfg,numel(p1));
    p1_audit = audit_candidate_observability(p1,p1_nominal,cfg,sc.tie_tolerance);
    metadata1 = metadata; metadata1.scenario_id = 'P1_partial_consistent_prior';
    metadata1.configuration_hash = h2; metadata1.baseline_P0_audit = p0_audit;
    cache1 = build_stage4a3_1_template_cache(frequency_grid,p1,small_grid,cfg,metadata1);
    chosen_index = find(strcmp({p0.topology_id},chosen),1);
    [net,local_cfg] = topology_apply_parameters(p0(chosen_index).network,cfg,grid(nominal_index));
    [measurement,~] = plc_measurement_bundle(sc.measurement_kind,net,grid(nominal_index),local_cfg);
    [prior_obs,~] = plc_multiview_response(f,net,measurement,local_cfg);
    prior_result = match_cached_composite_library_open_set(prior_obs,cache1,options);
    assert(strcmp(prior_result.decision,'unique_given_prior') && ...
        prior_result.baseline_P0_equivalence_class_size > 1 && ...
        prior_result.prior_conditioned_equivalence_class_size == 1, ...
        'Prior-conditioned uniqueness was not separated from physical uniqueness.');
    assert(any(strcmp({p2.topology_id},'G003')) == false || numel(p2) < numel(p0), ...
        'P2 stale prior did not demonstrate a coverage change.');

    out = bank(find(strcmp({bank.category},'structure_out'),1));
    [net,local_cfg] = topology_apply_parameters(out.truth_network,cfg,out.truth_theta);
    [measurement,~] = plc_measurement_bundle(sc.measurement_kind,net,out.truth_theta,local_cfg);
    [out_obs,~] = plc_multiview_response(f,net,measurement,local_cfg);
    out_result = match_cached_composite_library_open_set(out_obs,cache,options);
    assert(out_result.distance_evaluations > 0, 'Structure-out sample bypassed nonempty-library scoring.');
    reject_options = options; reject_options.thresholds.residual_threshold = 0;
    reject_out = match_cached_composite_library_open_set(out_obs,cache,reject_options);
    assert(~strcmp(out_result.decision,reject_out.decision) || ...
        strcmp(reject_out.decision,'reject_model_mismatch'), ...
        'Out-of-library decision did not respond to residual threshold changes.');

    % Offline metric checks: rejected nearest hits are diagnostics only, and
    % false-unique uses an independently supplied P0 truth class label.
    lab_bank = bank(find(strcmp({bank.category},'in_library_continuous') & ...
        strcmp({bank.truth_topology_id},'G003'),1));
    lab = build_stage4a3_1_truth_equivalence_labels(lab_bank,p0_audit,p0_audit,p0, ...
        'A_stage4a1_quick61','P0_no_prior',h1);
    reject_decision = cached;
    reject_decision.decision = 'reject_model_mismatch';
    reject_decision.accepted_topology_set = '';
    reject_decision.sample_id = lab.sample_id;
    reject_decision.grid_id = lab.grid_id;
    m = evaluate_stage4a3_1_metrics(reject_decision,lab,lab);
    assert(m.unique_accuracy_num == 0 && m.set_accuracy_num == 0 && ...
        m.nearest_topology_hit_num == 1, ...
        'Rejected nearest hit was counted as accepted accuracy.');
    nonunique_bank = bank(find(strcmp({bank.category},'in_library_continuous') & ...
        strcmp({bank.truth_topology_id},'G002'),1));
    nonunique_lab = build_stage4a3_1_truth_equivalence_labels(nonunique_bank,p0_audit,p0_audit,p0, ...
        'A_stage4a1_quick61','P0_no_prior',h1);
    false_unique_decision = reject_decision;
    false_unique_decision.decision = 'unique_topology';
    false_unique_decision.best_topology_id = nonunique_lab.truth_topology_id;
    false_unique_decision.accepted_topology_set = false_unique_decision.best_topology_id;
    false_unique_decision.sample_id = nonunique_lab.sample_id;
    m2 = evaluate_stage4a3_1_metrics(false_unique_decision,nonunique_lab,nonunique_lab);
    assert(m2.false_unique_num == 1 && m2.false_unique_den == 1, ...
        'false-unique did not use the independent P0 truth equivalence label.');
    fprintf('ALL STAGE-4A.3.1 TESTS PASSED\n');
end

function [label, size_value] = class_for_id_local(audit, topology_id)
    label = ''; size_value = 0;
    for k = 1:numel(audit.equivalence_classes)
        x = audit.equivalence_classes{k};
        if any(strcmp(x.member_topology_ids,topology_id)), label=x.label; size_value=numel(x.member_indices); return; end
    end
end
