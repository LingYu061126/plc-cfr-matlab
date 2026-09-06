function test_stage4a6_2_member_aggregation()
%TEST_STAGE4A6_2_MEMBER_AGGREGATION Member disagreement remains indeterminate.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    p1=parameter_evidence('main_length_scale',true,'in_domain',true);p1.extended_optimum_outside=false;
    p2=p1;p2.profile_status='out_suspected';p2.extended_optimum_outside=true;
    m1=member_evidence(true,true,true,true,p1);m2=member_evidence(true,true,true,true,p2);
    td=struct('decision','equivalence_class','accepted_topology_set','G002,G005','best_topology_id','G002');
    t=struct('parameter_name','main_length_scale','reliable_sample_count',1,'absolute_improvement_threshold',0,'relative_improvement_threshold',0,'sensitivity_floor',0,'status','calibrated');
    out=apply_stage4a6_2_parameter_decision(td,[m1 m2],struct('parameter_thresholds',t),'A6_2_M3_joint_diagnostic');
    assert(strcmp(out.parameter_domain_status,'parameter_domain_indeterminate'),'Member disagreement must remain indeterminate.');
    assert(out.any_member_optimizer_converged && out.all_members_optimizer_converged);
    assert(out.member_optimizer_converged_count==2);
    fprintf('ALL STAGE-4A.6.2 MEMBER AGGREGATION TESTS PASSED\n');
end
function e=member_evidence(opt,finite,consistent,computed,p),e=struct('profile_reliable',opt,'profile_computed',computed,'residual_finite',finite,'multistart_consistent',consistent,'active_parameters_identifiable',true,'optimizer_converged',opt,'parameter_evidence',p);end
function p=parameter_evidence(name,active,status,reliable),p=struct('parameter_name',name,'active',active,'profile_status',status,'in_domain_min_distance',1,'extended_min_distance',0.1,'absolute_improvement',0.99,'relative_improvement',0.9,'extended_optimum',1.1,'extended_optimum_outside',true,'boundary_behavior','upper_boundary','flatness_metric',1,'valid_point_fraction',1,'local_sensitivity',1,'profile_reliable',reliable,'reliability_reason','test');end
