function test_stage4a4_candidate_confirmation()
%TEST_STAGE4A4_CANDIDATE_CONFIRMATION Invariants for confirmation rules.
    fprintf('Running Stage 4A.4 candidate-confirmation tests...\n');
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));addpath(fullfile(root,'experiments'));
    cfg=default_config(root);sc=stage4a4_candidate_confirmation_config(cfg,'smoke');base=generate_radial_topology_candidates(sc.generator);
    assert(numel(base)==7,'P0 candidate count changed.');
    p1=generate_prior_constrained_candidates(sc.generator,sc.scenarios(2).asset_prior);p2=generate_prior_constrained_candidates(sc.generator,sc.scenarios(3).asset_prior);
    assert(numel(p1)==4&&numel(p2)==4,'P1/P2 candidate count changed.');
    bank=generate_stage4a4_trial_bank(sc);ids={bank.sample_id};assert(numel(ids)==numel(unique(ids)),'Trial IDs are not unique.');
    for a={'training','calibration','validation','test'},x=bank(strcmp({bank.split},a{1}));assert(~isempty(x),'Missing split.');end
    assert(isempty(intersect({bank(strcmp({bank.split},'training')).sample_id},{bank(strcmp({bank.split},'test')).sample_id}))); 
    assert(numel(unique({bank(strcmp({bank.split},'calibration')).truth_topology_id}))==7,'Calibration does not cover all P0 graphs.');
    matcher_text=fileread(which('match_candidate_library_calibrated'));assert(isempty(regexp(matcher_text,'coverage_status|truth_topology_id|scenario_id','once')),'Matcher exposes offline labels.');
    [h1,t1]=stage4a4_scientific_config_hash(struct('root_dir','/a','results_data','/b','frequency',[1 2 3],'prior',sc.scenarios(1).asset_prior));
    [h2,t2]=stage4a4_scientific_config_hash(struct('root_dir','/other','results_data','/c','frequency',[1 2 3],'prior',sc.scenarios(1).asset_prior));
    assert(strcmp(h1,h2)&&strcmp(t1,t2),'Scientific hash depends on runtime path.');
    [h3,~]=stage4a4_scientific_config_hash(struct('frequency',[1 2 3.1],'prior',sc.scenarios(1).asset_prior));assert(~strcmp(h1,h3),'Scientific hash ignores frequency values.');
    tg=topology_parameter_grid(sc.parameter_search);nom=tg(find([tg.regularization]==0,1));small=tg([find([tg.regularization]==0,1),1,2]);f=sc.grids(1).frequency_hz(1:5);p0=generate_prior_constrained_candidates(sc.generator,sc.scenarios(1).asset_prior);
    nl=build_composite_topology_library(f,p0,nom,sc.measurement_kind,cfg,numel(p0));audit=audit_candidate_observability(p0,nl,cfg,sc.tie_tolerance);
    md=struct('measurement_kind',sc.measurement_kind,'tie_tolerance',sc.tie_tolerance,'distance_feature',sc.feature,'distance_weights',sc.weights,'distance_options',sc.distance_options,'scenario_id','P0_no_prior','configuration_hash',h1,'max_composite_templates',Inf,'baseline_P0_audit',audit);
    fg=sc.grids(1);fg.frequency_hz=f;cache=build_stage4a3_1_template_cache(fg,p0,small,cfg,md);
    b=bank(find(strcmp({bank.split},'test')&strcmp({bank.category},'in_library_grid'),1));[net,lc]=topology_apply_parameters(b.truth_network,cfg,b.truth_theta);[me,~]=plc_measurement_bundle(sc.measurement_kind,net,b.truth_theta,lc);[ob,~]=plc_multiview_response(f,net,me,lc);
    raw=match_candidate_library_calibrated(ob,cache,struct(),struct('feature',sc.feature,'weights',sc.weights,'distance_options',sc.distance_options,'method','baseline_abs_margin','return_raw',true));
    assert(raw.distance_evaluations==cache.composite_template_count,'Nonempty cache did not score every template.');
    training_raw=repmat(raw,7,1);training_labels=repmat(build_stage4a4_truth_equivalence_labels(b,audit,audit,p0,fg.id,'P0_no_prior',h1),7,1);cal_raw=training_raw;cal_labels=training_labels;
    % Use a non-degenerate synthetic calibration vector to exercise robust stats.
    for k=1:numel(training_raw),training_raw(k).class_scores=training_raw(k).class_scores+0.001*k;cal_raw(k).class_scores=cal_raw(k).class_scores+0.001*k;end
    model=calibrate_candidate_confirmation(training_raw,training_labels,cal_raw,cal_labels,sc,fg.id,h1);
    pass=apply_candidate_confirmation(raw,model,struct('method','baseline_abs_margin'));assert(isfield(pass,'decision'),'Confirmation output missing decision.');
    low=apply_candidate_confirmation(raw,model,struct('method','baseline_abs_margin'));low.margin=-Inf;low.current_class_size=1; %#ok<NASGU>
    empty=cache;empty.templates=repmat(cache.templates(1),0,1);empty.candidate_count=0;empty.cfr_views={};er=match_candidate_library_calibrated(ob,empty,model,struct('feature',sc.feature,'weights',sc.weights,'method','baseline_abs_margin'));assert(strcmp(er.decision,'reject_no_feasible_candidate'),'Empty cache did not reject safely.');
    % A rejected nearest hit is a diagnostic, not an accuracy numerator.
    d=decision_row_for_test(pass);d.decision='reject_model_mismatch';d.accepted_topology_set='';l=build_stage4a4_truth_equivalence_labels(b,audit,audit,p0,fg.id,'P0_no_prior',h1);m=evaluate_stage4a4_metrics(d,l);assert(m.unique_accuracy_num==0&&m.set_accuracy_num==0,'Rejected sample counted as accepted accuracy.');
    fprintf('ALL STAGE-4A.4 TESTS PASSED\n');
end
function d=decision_row_for_test(x)
    d=struct('sample_id','test','grid_id',x.cache_frequency_grid_id,'scenario_id','P0_no_prior','method_id','baseline_abs_margin','decision',x.decision,'decision_reason','','best_template_id',x.best_template_id,'best_topology_id',x.best_topology_id,'best_equivalence_class',x.best_equivalence_class,'accepted_topology_set',x.best_topology_id,'baseline_P0_equivalence_class',x.baseline_P0_equivalence_class,'baseline_P0_equivalence_class_size',x.baseline_P0_equivalence_class_size,'prior_conditioned_equivalence_class_size',x.current_class_size,'best_distance',x.best_distance,'second_distance',x.second_distance,'margin',x.margin,'rho',x.rho,'robust_best_score',NaN,'robust_margin',NaN,'candidate_count_before_prior',7,'candidate_count_after_prior',7,'parameter_template_count',3,'composite_template_count',21,'distance_evaluations',21,'matching_time_s',0,'residual_threshold',NaN,'margin_threshold',NaN,'rho_threshold',NaN,'configuration_hash',x.configuration_hash,'calibration_hash',x.configuration_hash);
end
