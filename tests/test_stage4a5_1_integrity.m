function test_stage4a5_1_integrity()
%TEST_STAGE4A5_1_INTEGRITY Identity, labels, masks and cache validation.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    cfg=default_config(root);sc=stage4a5_1_integrity_config(cfg,'formal');base=generate_radial_topology_candidates(sc.generator);
    bank=generate_stage4a5_1_trial_bank(sc,'all');ix=strcmp({bank.category},'structure_out');oids=unique({bank(ix).truth_topology_id});okeys=unique({bank(ix).canonical_key});
    assert(numel(okeys)>=3,'At least three independent OOL keys are required.');
    assert(isempty(intersect({base.topology_id},oids)),'OOL IDs collide with P0.');
    assert(isempty(intersect({base.canonical_key},okeys)),'OOL keys collide with P0.');
    assert(all(startsWith(oids,'OOG')),'OOL IDs must use the OOG namespace.');
    theta=topology_parameter_grid(sc.parameter_search);nom=theta(find([theta.regularization]==0,1));grid=sc.grids(1);
    lib=build_composite_topology_library(grid.frequency_hz,base,nom,sc.measurement_kind,cfg,numel(base));audit=audit_candidate_observability(base,lib,cfg,sc.distance.tie_tolerance);
    labels=build_truth_labels_by_canonical_key(bank,base,audit,audit,base,sc.parameter_search,grid.id,'P0_no_prior',struct('experiment_scientific_hash','x','source_tree_hash','y'));
    assert(all(~[labels(ix).truth_graph_in_current_prior])&&all(~[labels(ix).truth_covered]),'Structure-out coverage is incorrect.');
    assert(all(strcmp({labels(ix).coverage_status},'structure_out_of_library')),'Structure-out status is incorrect.');
    ip=strcmp({bank.category},'parameter_out');assert(all([labels(ip).truth_graph_in_current_prior])&&all(~[labels(ip).truth_parameter_in_domain])&&all(~[labels(ip).truth_covered]),'Parameter-out semantics are incorrect.');
    assert(all(strcmp({labels(ip).coverage_status},'parameter_out_of_domain')),'Parameter-out status is incorrect.');
    [d1,m1]=build_frozen_resampling_masks(grid,{'final01','final02'},sc,'hash');[d2,m2]=build_frozen_resampling_masks(grid,{'final01','final02'},sc,'hash'); %#ok<ASGLU>
    assert(isequal(d1,d2),'Frozen masks are not reproducible.');
    assert(isequal(d1(1).masks,d2(1).masks),'Masks changed without grid/replicate change.');
    source=stage4a5_1_source_tree_hash(root);[expected,ch]=stage4a5_1_cache_expected(grid,base,theta,cfg,sc,source);
    fake=expected;fake.parameter_template_count=numel(theta);fake.cache_schema_version=sc.cache_schema_version;fake.cache_configuration_hash=ch;fake.forward_model_source_hash=source;fake.frequency_hz=grid.frequency_hz;fake.candidates=expected.candidates;fake.parameter_grid=theta;fake.measurement_kind=sc.measurement_kind;fake.source_impedance_ohm=cfg.Zs;fake.receiver_impedance_ohm=cfg.Zr;fake.distance_feature=sc.distance.feature;fake.distance_weights=sc.distance.weights;
    [valid,~]=validate_candidate_cache_identity(fake,expected);assert(valid,'Complete cache identity should validate.');fake.frequency_hz(1)=fake.frequency_hz(1)+1;[valid,~]=validate_candidate_cache_identity(fake,expected);assert(~valid,'Frequency mutation must invalidate cache.');
    fprintf('ALL STAGE 4A.5.1 INTEGRITY TESTS PASSED\n');
end
