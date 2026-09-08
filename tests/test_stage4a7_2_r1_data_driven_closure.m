function test_stage4a7_2_r1_data_driven_closure()
%TEST_STAGE4A7_2_R1_DATA_DRIVEN_CLOSURE Static and small deterministic checks.
%   Numerical Pilot execution remains an experiment-level operation; this
%   test covers shared-prior construction, profile API isolation, round-trip
%   metadata, and non-unique metric denominators.
    root=fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);
    sc=stage4a7_2_r1_data_driven_config(base,'smoke');
    [reference,read_audit]=read_stage4a7_2_r1_public_subnetwork(sc.derived_subnetwork);
    assert(read_audit.edge_count==7 && numel(reference.node_ids)==8, ...
        'The selected derived public subnetwork dimensions changed.');
    [ledger,spec,~,audit]=build_stage4a7_2_r1_uncertain_engineering_prior(reference,sc);
    assert(audit.shared_ledger && numel(ledger)>audit.reference_edge_count, ...
        'A shared uncertain ledger must contain ambiguity edges.');
    assert(~isfield(spec,'reference_truth') && ~isfield(spec,'truth_topology_id'), ...
        'Reference truth leaked into the candidate-generation specification.');
    [candidates,gen_audit]=generate_engineering_topology_candidates(spec);
    assert(gen_audit.candidate_count>1 && numel(unique({candidates.canonical_graph_key}))==numel(candidates), ...
        'A single shared prior did not generate multiple unique candidates.');
    [adapted,rep]=check_forward_model_compatibility(candidates(1),base);
    if rep.forward_model_compatible
        assert(rep.round_trip_ok && adapted.scored_library_included, ...
            'A compatible candidate failed the forward-network round-trip audit.');
    end

    theta=struct('main_length_scale',1,'branch_length_scale',1, ...
        'branch_load_scale',1,'source_impedance_ohm',50,'receiver_impedance_ohm',50);
    cache=struct('candidate_ids',{{'C1','C2'}},'candidates',repmat(struct('topology_id',''),1,2), ...
        'theta_grid',theta,'H',{{[1 2 3 4],[2 3 4 5]}},'template_count',2);
    cache.candidates(1).topology_id='C1';cache.candidates(2).topology_id='C2';
    observed={cache.H{1}};
    profile=stage4a7_2_r1_profile_distance(observed,cache,struct('feature','complex_raw'));
    assert(profile.profile_distances(1)<=profile.profile_distances(2), ...
        'Profile distance did not select the matching candidate template.');
    direct=topology_feature_distance(observed{1},cache.H{1},'complex_raw',struct(),[1 1],struct());
    assert(abs(profile.profile_distances(1)-direct)<1e-14, ...
        'Fast complex-raw profile path changed the declared distance.');
    assert(isfield(profile,'definition_version') && ...
        strcmp(profile.definition_version,'independent_discrete_profile_distance_v1'), ...
        'Profile distance API identity is missing.');

    decisions=repmat(struct('truth_member_count',1,'set_size',1,'hit',true),4,1);
    decisions(2).truth_member_count=2;decisions(2).set_size=1;decisions(2).hit=true;
    decisions(3).truth_member_count=2;decisions(3).set_size=2;decisions(3).hit=true;
    decisions(4).truth_member_count=0;decisions(4).set_size=1;decisions(4).hit=false;
    metrics=stage4a7_2_r1_nonunique_metrics(decisions,'test-hash');
    ix=find(strcmp({metrics.metric_id},'false_unique_conditional_rate'),1);
    assert(metrics(ix).denominator==2 && metrics(ix).numerator==1, ...
        'Conditional false-unique denominator is not restricted to true non-unique rows.');
    fprintf('  PASS Stage 4A.7.2-R.1 shared-prior, profile-isolation and nonunique metrics\n');
end
