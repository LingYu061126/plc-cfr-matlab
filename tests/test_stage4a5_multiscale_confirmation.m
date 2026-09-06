function test_stage4a5_multiscale_confirmation()
%TEST_STAGE4A5_MULTISCALE_CONFIRMATION Invariants for Stage 4A.5.
%   This test exercises shared residual evidence, the observation-only
%   decision boundary, stable trial design and path-independent hashing.
    fprintf('Running Stage 4A.5 multiscale-confirmation tests...\n');
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root,'src')); addpath(fullfile(root,'config'));
    addpath(fullfile(root,'experiments'));
    cfg = default_config(root);
    smoke = stage4a5_multiscale_confirmation_config(cfg,'smoke');
    formal = stage4a5_multiscale_confirmation_config(cfg,'formal');

    p0 = generate_prior_constrained_candidates(smoke.generator,smoke.scenarios(1).asset_prior);
    p1 = generate_prior_constrained_candidates(smoke.generator,smoke.scenarios(2).asset_prior);
    p2 = generate_prior_constrained_candidates(smoke.generator,smoke.scenarios(3).asset_prior);
    assert(numel(p0)==7 && numel(p1)==4 && numel(p2)==4, ...
        'Stage 4A.5 prior candidate counts changed.');
    specs = stage4a5_method_specs(formal);
    assert(numel(specs)==53 && sum(strcmp({specs.family},'M0'))==1 && ...
        sum(strcmp({specs.family},'M1'))==4 && sum(strcmp({specs.family},'M2'))==12 && ...
        sum(strcmp({specs.family},'M3'))==36,'M0--M3 method grid changed.');

    bank = generate_stage4a5_trial_bank(smoke,'all');
    ids = {bank.sample_id};
    assert(numel(ids)==numel(unique(ids)),'Stage 4A.5 trial IDs are not unique.');
    dev_ids = ids(~ismember({bank.split},{'final_replication_calibration','final_replication_test'}));
    final_ids = ids(ismember({bank.split},{'final_replication_calibration','final_replication_test'}));
    assert(isempty(intersect(dev_ids,final_ids)),'Development and final IDs overlap.');
    assert(numel(unique({bank(strcmp({bank.split},'development_calibration')).truth_topology_id}))==7, ...
        'Development calibration does not cover every P0 graph.');
    assert(numel(unique({bank(strcmp({bank.split},'final_replication_calibration')).truth_topology_id}))==7, ...
        'Final calibration does not cover every P0 graph.');
    assert(numel(unique({bank(strcmp({bank.split},'final_replication_test')).truth_topology_id}))==7, ...
        'Final test does not cover every P0 graph.');
    fprintf('  PASS candidate counts, method enumeration and split isolation\n');

    % Construct a small real cache using the stable forward model.
    tg = topology_parameter_grid(smoke.parameter_search);
    nominal = find([tg.regularization]==0,1);
    small = tg(unique([nominal,1,min(2,numel(tg))]));
    f = smoke.grids(1).frequency_hz(1:16);
    fg = smoke.grids(1); fg.frequency_hz = f; fg.id = 'stage4a5_test16';
    nominal_library = build_composite_topology_library(f,p0,tg(nominal),smoke.measurement_kind,cfg,numel(p0));
    audit = audit_candidate_observability(p0,nominal_library,cfg,smoke.distance.tie_tolerance);
    metadata = struct('measurement_kind',smoke.measurement_kind, ...
        'tie_tolerance',smoke.distance.tie_tolerance,'distance_feature',smoke.distance.feature, ...
        'distance_weights',smoke.distance.weights,'distance_options',smoke.distance.options, ...
        'scenario_id','P0_no_prior','configuration_hash','test_hash', ...
        'max_composite_templates',Inf,'baseline_P0_audit',audit);
    cache = build_stage4a3_1_template_cache(fg,p0,small,cfg,metadata);
    [sets8,~] = stage4a5_make_subbands(f,8,fg.id,'test_hash');
    b = bank(find(strcmp({bank.split},'final_replication_test') & ...
        strcmp({bank.category},'in_library_grid'),1));
    [net,local_cfg] = topology_apply_parameters(b.truth_network,cfg,b.truth_theta);
    [measurement,~] = plc_measurement_bundle(smoke.measurement_kind,net,b.truth_theta,local_cfg);
    [observed,~] = plc_multiview_response(f,net,measurement,local_cfg);
    residual = compute_subband_residuals(observed,cache,sets8);
    assert(size(residual.template_subband_distance,1)==cache.composite_template_count && ...
        size(residual.template_subband_distance,2)==8 && all(isfinite(residual.template_full_distance)), ...
        'Subband residual dimensions or finiteness failed.');
    topk = compute_topk_template_evidence(residual.template_full_distance, ...
        residual.template_subband_distance,cache,[3,5,10]);
    assert(all([topk.k_values]==[3,5,10]) && numel(topk.topK_template_indices)==7 && ...
        numel(topk.topK_template_indices{1})==3, ...
        'Top-K evidence shape failed.');
    stability = compute_frequency_block_stability(observed,cache,topk, ...
        struct('repetitions',4,'block_count',2,'block_fraction',.5),77);
    stability2 = compute_frequency_block_stability(observed,cache,topk, ...
        struct('repetitions',4,'block_count',2,'block_fraction',.5),77);
    assert(stability.repetitions==4 && stability.uses_topK_cache && ...
        isequal(stability.selected_topology_ids,stability2.selected_topology_ids), ...
        'Frequency-block stability is not deterministic or cache-based.');
    raw = score_stage4a5_observation(observed,cache,sets8, ...
        struct('repetitions',4,'block_count',2,'block_fraction',.5,'stability_seed',77));
    assert(raw.distance_evaluations==cache.composite_template_count && ...
        strcmp(raw.cache_frequency_grid_id,fg.id) && ~isfield(raw,'truth_topology_id'), ...
        'Shared raw evidence violates the observation-only interface.');
    fprintf('  PASS subband, top-K and block-stability evidence\n');

    permissive = struct('thresholds',struct('residual_threshold',Inf,'margin_threshold',0), ...
        'subband',struct(),'neighborhood',struct(),'configuration_hash','test_hash');
    high = raw; high.best_distance = Inf; high_model = permissive;
    high_model.thresholds.residual_threshold = 1;
    d = apply_stage4a5_confirmation(high,high_model,specs(strcmp({specs.family},'M0')));
    assert(strcmp(d.decision,'reject_model_mismatch'),'Large residual did not reject.');
    low = raw; low.best_distance = 0; low.margin = -Inf;
    d = apply_stage4a5_confirmation(low,permissive,specs(strcmp({specs.family},'M0')));
    assert(strcmp(d.decision,'reject_low_margin'),'Small class margin did not reject.');
    empty = raw; empty.candidate_count_after_prior = 0;
    d = apply_stage4a5_confirmation(empty,permissive,specs(strcmp({specs.family},'M0')));
    assert(strcmp(d.decision,'reject_no_feasible_candidate'),'Empty candidate cache did not reject.');

    % Use a controlled raw record to test output semantics independently of
    % the physical sample selected above.
    fake = raw; fake.best_distance=0; fake.margin=1; fake.current_class_size=2;
    fake.baseline_P0_equivalence_class_size=2; fake.best_equivalence_members='G002,G005';
    d = apply_stage4a5_confirmation(fake,permissive,specs(strcmp({specs.family},'M0')));
    assert(strcmp(d.decision,'equivalence_class'),'Equivalent members were forced to unique.');
    fake.current_class_size=1; fake.best_equivalence_members='G002';
    d = apply_stage4a5_confirmation(fake,permissive,specs(strcmp({specs.family},'M0')));
    assert(strcmp(d.decision,'unique_given_prior'),'Prior-conditioned uniqueness was not distinguished.');

    m3 = specs(find(strcmp({specs.family},'M3'),1));
    m3.stability_threshold=.9;
    stability_model = permissive;
    for M=[4,8]
        for q=[.75,.90]
            stability_model.subband.(sprintf('M%d_q%03d',M,round(1000*q)))= ...
                struct('center',0,'scale',1,'max_threshold',Inf,'q_threshold',Inf);
        end
    end
    for K=[3,5,10]
        stability_model.neighborhood.(sprintf('K%d',K))= ...
            struct('score_threshold',Inf,'margin_threshold',-Inf);
    end
    fake.stability.best_topology_stability=0; fake.stability.best_class_stability=0;
    fake.current_class_size=1; fake.baseline_P0_equivalence_class_size=1;
    d = apply_stage4a5_confirmation(fake,stability_model,m3);
    assert(strcmp(d.decision,'reject_low_stability'),'Low stability did not reject.');
    fprintf('  PASS residual, margin, empty-set, equivalence and stability semantics\n');

    matcher_text = fileread(fullfile(root,'src','apply_stage4a5_confirmation.m'));
    scorer_text = fileread(fullfile(root,'src','score_stage4a5_observation.m'));
    assert(isempty(regexp(matcher_text,'truth_topology_id|coverage_status|outlier_dimension|scenario_id','once')) && ...
        isempty(regexp(scorer_text,'truth_topology_id|coverage_status|outlier_dimension','once')), ...
        'Stage 4A.5 observation-only functions expose offline labels.');
    [h1,t1] = stage4a4_scientific_config_hash(struct('root_dir','/one','results_data','/x', ...
        'frequency',[1 2 3],'prior',smoke.scenarios(1).asset_prior));
    [h2,t2] = stage4a4_scientific_config_hash(struct('root_dir','/two','results_data','/y', ...
        'frequency',[1 2 3],'prior',smoke.scenarios(1).asset_prior));
    assert(strcmp(h1,h2) && strcmp(t1,t2),'Scientific hash depends on absolute paths.');
    [h3,~] = stage4a4_scientific_config_hash(struct('frequency',[1 2 3.1], ...
        'prior',smoke.scenarios(1).asset_prior));
    assert(~strcmp(h1,h3),'Scientific hash ignores scientific frequency values.');
    fprintf('  PASS protocol isolation and path-independent scientific hash\n');
    fprintf('ALL STAGE-4A.5 TESTS PASSED\n');
end
