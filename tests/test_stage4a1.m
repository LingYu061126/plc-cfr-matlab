function test_stage4a1()
%TEST_STAGE4A1 Candidate grammar, composite library and equivalence audit.
    fprintf('Running Stage 4A.1 candidate-library tests...\n');
    root=fileparts(fileparts(mfilename('fullpath'))); cfg=default_config(root); sc=stage4a1_config(cfg);
    grammar=sc.generator; generated=generate_radial_topology_candidates(grammar);
    keys={generated.canonical_key};
    assert(~isempty(generated) && numel(keys)==numel(unique(keys)), ...
        'Generated candidates contain canonical structural duplicates.');
    for k=1:numel(generated)
        s=validate_radial_topology_candidate(generated(k),grammar);
        assert(s.connected && s.acyclic && s.edge_count==s.node_count-1, ...
            'Generated candidate is not a connected radial tree.');
    end
    repeated=generate_radial_topology_candidates(grammar);
    assert(isequal({generated.canonical_key},{repeated.canonical_key}), ...
        'Candidate order or canonical keys changed across identical runs.');
    fprintf('  PASS bounded radial grammar, tree constraints and deterministic canonical keys\n');

    too_small=grammar; too_small.max_candidates=1;
    assert_throws(@()generate_radial_topology_candidates(too_small), ...
        'generate_radial_topology_candidates:MaxCandidatesExceeded');
    fprintf('  PASS candidate-count protection\n');

    theta=topology_parameter_grid(sc.parameter_search);
    assert(numel(theta)==1 && theta(1).regularization==0, ...
        'Stage 4A.1 nominal grid must be the existing search nominal point.');
    inherited_grid=topology_parameter_grid(cfg.stage2_3.search);
    expected_grid_count=numel(cfg.stage2_3.search.main_length_scale)* ...
        numel(cfg.stage2_3.search.branch_length_scale)* ...
        numel(cfg.stage2_3.search.branch_load_scale)* ...
        numel(cfg.stage2_3.search.source_impedance_ohm)* ...
        numel(cfg.stage2_3.search.receiver_impedance_ohm);
    assert(numel(inherited_grid)==expected_grid_count, ...
        'Existing parameter-grid Cartesian-product count changed unexpectedly.');
    f=sc.frequency_hz; library=build_composite_topology_library(f,generated,theta, ...
        sc.measurement_kind,cfg,sc.max_composite_templates);
    finite_views=cellfun(@(bundle)all(cellfun(@(v)all(isfinite(v(:))),bundle)), ...
        {library.views});
    assert(numel(library)==numel(generated)*numel(theta) && all(finite_views), ...
        'Composite templates did not produce finite full-network CFR views.');
    fprintf('  PASS parameter Cartesian product and finite complete-network CFR templates\n');

    legacy=legacy_stage2_candidates(cfg); legacy_library=build_composite_topology_library(f,legacy,theta, ...
        'siso_forward',cfg,16);
    symmetric=audit_candidate_observability(legacy,legacy_library,cfg,sc.tie_tolerance);
    i3=find(strcmp({legacy.topology_id},'T3')); i5=find(strcmp({legacy.topology_id},'T5'));
    assert(symmetric.core.class_index(i3)==symmetric.core.class_index(i5), ...
        'Existing T3/T5 symmetric-SISO equivalence was not retained.');
    asym_theta=theta; asym_theta.receiver_impedance_ohm=75; asym_theta.regularization=0;
    asymmetric_library=build_composite_topology_library(f,legacy,asym_theta, ...
        'siso_forward_asymmetric',cfg,16);
    asymmetric=audit_candidate_observability(legacy,asymmetric_library,cfg,sc.tie_tolerance);
    assert(asymmetric.core.class_index(i3)~=asymmetric.core.class_index(i5), ...
        'Changed endpoint configuration reused the symmetric equivalence class.');
    old=topology_candidates(cfg);
    assert(isequal({old.id},{'T1','T2','T3','T4','T5','T6'}) && ...
        isequal([old.main_total_length_m],80*ones(1,6)) && ...
        isequal({old.branch_positions_m},{[],40,60,[20 60],20,[20 40 60]}), ...
        'Stage 4A.1 changed the historical T1--T6 definitions.');
    fprintf('  PASS T1--T6 preservation and configuration-specific T3/T5 audit\n');
    fprintf('ALL STAGE-4A.1 TESTS PASSED\n');
end

function c=legacy_stage2_candidates(cfg)
    old=topology_candidates(cfg); c=repmat(struct('topology_id','','canonical_key','','network',struct()),1,numel(old));
    for k=1:numel(old), c(k)=struct('topology_id',old(k).id,'canonical_key',['legacy_' old(k).id],'network',old(k).network); end
end

function assert_throws(fun,identifier)
    hit=false;try,fun();catch ME,hit=true;assert(strcmp(ME.identifier,identifier), ...
        'Expected %s but got %s.',identifier,ME.identifier);end
    assert(hit,'Expected %s.',identifier);
end
