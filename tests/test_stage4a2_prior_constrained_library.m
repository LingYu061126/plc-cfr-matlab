function test_stage4a2_prior_constrained_library()
%TEST_STAGE4A2_PRIOR_CONSTRAINED_LIBRARY Unit checks for prior/streaming API.
    fprintf('Running Stage 4A.2 prior-constrained library tests...\n');
    root=fileparts(fileparts(mfilename('fullpath'))); cfg=default_config(root); sc=stage4a2_prior_config(cfg);
    p0=generate_prior_constrained_candidates(sc.generator,sc.prior_scenarios(1).asset_prior);
    base=generate_radial_topology_candidates(sc.generator);
    assert(numel(p0)==7 && isequal({p0.canonical_key},{base.canonical_key}), ...
        'P0 must reproduce Stage-4A.1 candidates and canonical order.');
    p1=generate_prior_constrained_candidates(sc.generator,sc.prior_scenarios(2).asset_prior);
    assert(numel(p1)<numel(p0) && numel(p1)>=2 && any(strcmp({p1.topology_id},'G003')), ...
        'P1 did not reduce candidates while retaining the specified feasible truth.');
    p2=generate_prior_constrained_candidates(sc.generator,sc.prior_scenarios(3).asset_prior);
    assert(~any(strcmp({p2.topology_id},'G003')), ...
        'P2 stale prior should visibly exclude the designated covered topology.');
    reordered=sc.prior_scenarios(2).asset_prior; reordered.edge_prior=fliplr(reordered.edge_prior);
    p1_reordered=generate_prior_constrained_candidates(sc.generator,reordered);
    assert(isequal({p1.canonical_key},{p1_reordered.canonical_key}), ...
        'Prior input order changed the canonical candidate set.');
    conflict=sc.prior_scenarios(2).asset_prior; conflict.edge_prior(1).required=true; conflict.edge_prior(1).forbidden=true;
    assert_throws(@()validate_topology_prior_consistency(conflict,sc.generator), ...
        'validate_topology_prior_consistency:RequiredForbiddenConflict');
    disallowed=sc.prior_scenarios(2).asset_prior; disallowed.edge_prior(1).allowed=false;
    assert(isempty(generate_prior_constrained_candidates(sc.generator,disallowed)), ...
        'A hard disallowed edge was not applied.');
    short_edge=sc.prior_scenarios(2).asset_prior; short_edge.edge_prior(1).length_max_m=19;
    assert(isempty(generate_prior_constrained_candidates(sc.generator,short_edge)), ...
        'A hard length interval was not applied.');
    low_degree=sc.prior_scenarios(1).asset_prior; low_degree.network_rules.maximum_degree=2;
    degree_filtered=generate_prior_constrained_candidates(sc.generator,low_degree);
    assert(all(cellfun(@isempty,{degree_filtered.branch_edges})), ...
        'Maximum-degree rule did not remove side-branch candidates.');
    fprintf('  PASS P0/P1/P2 coverage, prior-order invariance and hard-conflict safety\n');

    grid=topology_parameter_grid(sc.parameter_search);
    assert(numel(grid)==243 && numel(grid)==sc.parameter_template_count_expected, ...
        'Stage-2.3 parameter grid Cartesian product count changed.');
    small_grid=grid([find([grid.regularization]==0,1),1,2]); f=sc.frequency_grids(1).frequency_hz(1:11);
    [net,local]=topology_apply_parameters(p0(3).network,cfg,small_grid(1)); [m,~]=plc_measurement_bundle(sc.measurement_kind,net,small_grid(1),local); obs=plc_multiview_response(f,net,m,local);
    opt=options(sc,7,struct('mismatch_distance_threshold',1e-8,'margin_threshold',1e-12),'covered');
    streamed=match_composite_topology_library(obs,f,p0,small_grid,cfg,opt);
    full=build_composite_topology_library(f,p0,small_grid,sc.measurement_kind,cfg,Inf);
    full_scores=Inf(1,numel(p0));
    for k=1:numel(full)
        d=topology_feature_distance(obs{1},full(k).views{1},sc.distance_feature,cfg.ofdm,sc.distance_weights,sc.distance_options);
        full_scores(full(k).topology_index)=min(full_scores(full(k).topology_index),d);
    end
    assert(abs(min(full_scores)-streamed.best_distance)<1e-12 && strcmp(streamed.best_topology_id,'G003'), ...
        'Streamed matching disagrees with bounded full-library matching.');
    assert(strcmp(streamed.decision,'unique_topology') || strcmp(streamed.decision,'equivalence_class'), ...
        'An exact library template was unexpectedly rejected.');
    fprintf('  PASS 243-template grid declaration, finite CFR and streamed/full agreement\n');

    nominal=grid(find([grid.regularization]==0,1)); legacy=legacy_candidates(cfg);
    lib=build_composite_topology_library(f,legacy,nominal,'siso_forward',cfg,16); a=audit_candidate_observability(legacy,lib,cfg,sc.tie_tolerance);
    i3=find(strcmp({legacy.topology_id},'T3')); i5=find(strcmp({legacy.topology_id},'T5'));
    assert(a.core.class_index(i3)==a.core.class_index(i5),'Symmetric T3/T5 must remain an equivalence class.');
    all_truth=generate_radial_topology_candidates(with_three(sc.generator)); truth_out=all_truth(end);
    [net,local]=topology_apply_parameters(truth_out.network,cfg,nominal); [m,~]=plc_measurement_bundle(sc.measurement_kind,net,nominal,local); out_obs=plc_multiview_response(f,net,m,local);
    rejected=match_composite_topology_library(out_obs,f,p0,small_grid,cfg,options(sc,7,opt.thresholds,'out_of_library'));
    assert(~strcmp(rejected.decision,'unique_topology'),'A legal library-out tree was unconditionally accepted as unique.');
    fprintf('  PASS symmetric equivalence output and library-out rejection\n');
    fprintf('ALL STAGE-4A.2 TESTS PASSED\n');
end

function o=options(sc,before,t,coverage)
    o=struct('measurement_kind',sc.measurement_kind,'tie_tolerance',sc.tie_tolerance, ...
        'distance_feature',sc.distance_feature,'distance_weights',sc.distance_weights, ...
        'distance_options',sc.distance_options,'batch_size',4,'thresholds',t, ...
        'candidate_count_before_prior',before,'coverage_status',coverage);
end
function g=with_three(g),g.max_branches=3;g.max_nodes=9;g.max_candidates=16;end
function c=legacy_candidates(cfg)
    old=topology_candidates(cfg); c=repmat(struct('topology_id','','canonical_key','','network',struct()),1,numel(old));
    for k=1:numel(old),c(k)=struct('topology_id',old(k).id,'canonical_key',['legacy_' old(k).id],'network',old(k).network);end
end
function assert_throws(fun,id)
    hit=false; try, fun(); catch ME,hit=true;assert(strcmp(ME.identifier,id),'Expected %s, got %s.',id,ME.identifier);end
    assert(hit,'Expected error %s.',id);
end
