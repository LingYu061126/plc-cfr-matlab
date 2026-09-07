function result=test_stage4a6_3_1_r_equivalence_members(~)
%TEST_STAGE4A6_3_1_R_EQUIVALENCE_MEMBERS Enforce complete member coverage.
    c=struct('decision','equivalence_class','accepted_topology_set','G002,G005', ...
        'accepted_member_ids',{{'G002','G005'}},'best_topology_id','G002');
    e=struct('topology_id','G002','parameter_evidence',struct([]),'profile_reliable',false,'profile_computed',false,'optimizer_converged',false);
    z=aggregate_stage4a6_3_1_member_evidence(c,e,struct('calibration_status','insufficient_evidence'),'A6_3_M3_joint_diagnostic');
    assert(z.accepted_member_count==2);assert(z.evaluated_member_count==1);assert(strcmp(z.parameter_domain_status,'parameter_domain_indeterminate'));
    result=struct('name','test_stage4a6_3_1_r_equivalence_members','status','passed');
end
