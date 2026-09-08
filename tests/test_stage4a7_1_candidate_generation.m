function test_stage4a7_1_candidate_generation()
%TEST_STAGE4A7_1_CANDIDATE_GENERATION Route-A/B/C and layer semantics.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    cfg=default_config(root);sc=stage4a7_1_candidate_confirmation_config(cfg,'smoke');
    legacy=generate_radial_topology_candidates(sc.legacy_grammar);adapted=stage4a7_1_adapt_legacy_candidates(legacy);
    assert(numel(legacy)==7,'Legacy grammar count changed.');
    assert(isequal({legacy.topology_id},{adapted.graph_candidate_id})&&isequal({legacy.canonical_key},{adapted.canonical_graph_key}), ...
        'Legacy adapter changed IDs/order/canonical keys.');
    for k=1:numel(legacy)
        assert(isequal(legacy(k).network,adapted(k).network),'Legacy network changed through adapter.');
        if ~is_octave()
            [adapted(k),rep]=check_forward_model_compatibility(adapted(k),cfg);
            assert(rep.forward_model_compatible&&adapted(k).scored_library_included,'Legacy network was not recognized as compatible.');
        end
    end
    fprintf('  PASS legacy restricted grammar strict adapter preservation\n');

    s=small_spec();[a,aa]=generate_engineering_topology_candidates(s);
    assert(~isempty(a)&&aa.allowed_edge_count==6&&aa.feasible_radial_candidate_count==4, ...
        'Constrained spanning-tree enumeration count is incorrect.');
    assert(aa.cycle_pruned_branch_count>0,'Cycle pruning was not exercised.');
    reverse=s;s.allowed_edges=s.allowed_edges(end:-1:1,:);[b,~]=generate_engineering_topology_candidates(reverse);
    assert(isequal(sort({a.canonical_graph_key}),sort({b.canonical_graph_key})),'Edge input order changed candidate keys.');
    bad=s;bad.required_edges={'A','B'};bad.forbidden_edges={'A','B'};assert_throws(@()generate_engineering_topology_candidates(bad),'stage4a7_1:RequiredForbiddenConflict');
    cap=s;cap.maximum_candidate_count=1;assert_throws(@()generate_engineering_topology_candidates(cap),'stage4a7_1:MaxCandidatesExceeded');
    fprintf('  PASS required/forbidden, pruning, order invariance and candidate cap\n');

    [top,ta]=generate_topk_topology_candidates(s,numel(a));assert(isequal(sort({top.canonical_graph_key}),sort({a.canonical_graph_key}))&&ta.no_good_cut_count==0, ...
        'Top-K prototype does not reproduce exact key set at K=all.');
    [top2,~]=generate_topk_topology_candidates(s,2);assert(numel(top2)==2&&numel(unique({top2.canonical_graph_key}))==2,'Top-K returned duplicates.');
    fprintf('  PASS exact/Top-K prototype and no-good identity\n');

    if ~is_octave()
        [x,~]=check_forward_model_compatibility(a(1),cfg);assert(~x.forward_model_compatible&&~x.scored_library_included,'Bare engineering graph was silently scored.');
    end
    gate=stage4a7_1_multinode_tomography_capability(struct('pairwise_distance_matrix',[]));assert(strcmp(gate.status,'not_applicable') && ~gate.uses_single_port_cfr_as_distance,'Route-C gate incorrectly accepted single-port input.');
    fprintf('  PASS engineering/model compatibility layer and Route-C gate\n');
    [cal,pilot,reserved]=generate_stage4a7_1_scenarios(sc,legacy);
    assert(numel(cal)==140&&numel(pilot)==33,'Stage-4A.7.1 split sizes changed.');
    assert(isempty(intersect({cal.sample_id},{pilot.sample_id}))&&isempty(intersect({cal.parameter_vector_hash},{pilot.parameter_vector_hash})), ...
        'Calibration and Pilot identities overlap.');
    assert(strcmp(reserved.status,'manifest_only_not_materialized')&&reserved.scenario_count==0, ...
        'Final-reserved split was materialized.');
    assert(numel(unique({cal.parameter_vector_hash}))>20,'Calibration physical parameters were duplicated excessively.');
    fprintf('  PASS independent calibration/Pilot identities and unconsumed final reserve\n');

    ext=stage4a7_1_candidate_confirmation_config(cfg,'extended_pilot');
    [ec,ep,ef]=generate_stage4a7_1_scenarios(ext,legacy);
    assert(numel(ec)==700&&numel(ep)==500&&strcmp(ef.status,'manifest_only_not_materialized'), ...
        'Extended Pilot tier does not contain the frozen 700+500 split.');
    for k=find(strcmp({ep.category},'parameter_out'))
        j=find(strcmp({legacy.topology_id},ep(k).truth_topology_id),1);
        if ismember(ep(k).outlier_dimension,{'branch_length_scale','branch_load_scale'})
            assert(topology_active_parameter_mask(legacy(j),{ep(k).outlier_dimension}), ...
                'Extended Pilot contains an inactive branch-parameter outlier.');
        end
    end
    assert(isempty(intersect({ec.parameter_vector_hash},{ep.parameter_vector_hash})), ...
        'Extended calibration/Pilot parameter identities overlap.');
    po=ep(strcmp({ep.category},'parameter_out'));
    assert(numel(unique({po.parameter_vector_hash}))==numel(po), ...
        'Extended parameter-OOD replicates do not have unique physical parameters.');
    fprintf('  PASS frozen 700+500 extended Pilot design and active OOD dimensions\n');
    if ~is_octave()
        h=stage4a7_1_source_tree_hash(root);assert(numel(h)==64,'Stage-4A.7.1 source hash was not SHA-256.');
        fprintf('  PASS Stage-4A.7.1 scientific source-tree hash coverage\n');
    else
        fprintf('  SKIP Java SHA-256 source-tree hash check in Octave fallback\n');
    end
end

function s=small_spec()
    s=struct('node_ids',{{'A','B','C','D'}},'allowed_edges',{{'A','B';'A','C';'A','D';'B','C';'B','D';'C','D'}}, ...
        'required_edges',{{'A','B'}},'forbidden_edges',{{'C','D'}},'maximum_degree',3,'maximum_candidate_count',128, ...
        'radial_only',true,'require_connected',true,'prior_source','synthetic_demo_prior_not_field_data','prior_config_hash','octave-test-hash','edge_prior_cost',[0;3;1;2;4;5]);
end
function assert_throws(fun,id),hit=false;try,fun();catch ME,hit=true;assert(strcmp(ME.identifier,id),'Expected %s got %s.',id,ME.identifier);end;assert(hit,'Expected %s.',id);end
function tf=is_octave(),tf=exist('OCTAVE_VERSION','builtin')==5;end
