function test_stage4a6_2_profile_semantics()
%TEST_STAGE4A6_2_PROFILE_SEMANTICS Empty profiles and point states are explicit.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    names=stage4a6_1_parameter_names();d=struct('names',{names},'in_lower',[.95 .95 .8 45 45], ...
        'in_upper',[1.05 1.05 1.2 55 55],'ext_lower',[.9 .9 .6 40 40],'ext_upper',[1.1 1.1 1.4 60 60]);
    cfg=default_config(root);sc=stage4a6_2_profile_config(cfg,'smoke');
    candidate=generate_radial_topology_candidates(sc.generator);
    fake=struct('theta',struct(),'distance',0,'residual_finite',true,'optimizer_converged',true,'multistart_consistent',true);
    options=struct('enabled',false);
    p=compute_stage4a6_2_parameter_profile({1},[1],candidate(1),cfg,d,fake,fake,struct([]),options);
    assert(all(~[p.profile_computed]),'Disabled profile must not be marked computed.');
    assert(all(~[p.profile_reliable]),'Disabled profile must not be marked reliable.');
    assert(any(strcmp({p.profile_status},'not_computed')),'Active disabled parameters need not_computed state.');
    td=struct('decision','unique_topology','accepted_topology_set','G001','best_topology_id','G001');
    e=struct('profile_reliable',false,'profile_computed',false,'residual_finite',true, ...
        'multistart_consistent',true,'optimizer_converged',true,'parameter_evidence',struct([]));
    out=apply_stage4a6_2_parameter_decision(td,e,struct('parameter_thresholds',struct([])),'A6_2_M3_joint_diagnostic');
    assert(~isfield(out,'optimization_converged'),'Conflicting optimizer field was reintroduced.');
    fprintf('ALL STAGE-4A.6.2 PROFILE SEMANTICS TESTS PASSED\n');
end
