function test_stage4a6_2_flat_profile()
%TEST_STAGE4A6_2_FLAT_PROFILE Flat and partial scans cannot become in-domain.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    p=parameter_evidence('branch_load_scale',true,'unidentifiable_flat',false);m=member_evidence(true,true,true,true,p);
    td=struct('decision','unique_topology','accepted_topology_set','G001','best_topology_id','G001');
    out=apply_stage4a6_2_parameter_decision(td,m,struct('parameter_thresholds',struct([])),'A6_2_M3_joint_diagnostic');
    assert(strcmp(out.parameter_domain_status,'parameter_domain_indeterminate'),'Flat profile must be indeterminate.');
    assert(strcmp(out.parameter_statuses(1).profile_status,'indeterminate_unidentifiable'));
    p.profile_status='scan_unreliable';m.parameter_evidence=p;m.profile_reliable=false;
    out=apply_stage4a6_2_parameter_decision(td,m,struct('parameter_thresholds',struct([])),'A6_2_M3_joint_diagnostic');
    assert(strcmp(out.parameter_domain_status,'parameter_domain_indeterminate'),'Failed scan must be indeterminate.');
    fprintf('ALL STAGE-4A.6.2 FLAT PROFILE TESTS PASSED\n');
end
function e=member_evidence(opt,finite,consistent,computed,p),e=struct('profile_reliable',opt,'profile_computed',computed,'residual_finite',finite,'multistart_consistent',consistent,'active_parameters_identifiable',true,'optimizer_converged',opt,'parameter_evidence',p);end
function p=parameter_evidence(name,active,status,reliable),p=struct('parameter_name',name,'active',active,'profile_status',status,'in_domain_min_distance',1,'extended_min_distance',1,'absolute_improvement',0.01,'relative_improvement',0.01,'extended_optimum',1,'extended_optimum_outside',false,'boundary_behavior','interior','flatness_metric',1,'valid_point_fraction',1,'local_sensitivity',1,'profile_reliable',reliable,'reliability_reason','test');end
