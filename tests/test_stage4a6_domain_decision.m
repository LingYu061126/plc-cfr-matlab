function test_stage4a6_domain_decision()
%TEST_STAGE4A6_DOMAIN_DECISION Orthogonal truth-free output semantics.
    model=struct('lambda_threshold',0.1,'relative_improvement_threshold',0.1,'sensitivity_floor',0.01);topo=struct('decision','unique_topology','accepted_topology_set','G001','best_topology_id','G001');e=ev();
    z=apply_joint_topology_parameter_decision(topo,e,model,'A6_M3_joint_diagnostic');assert(strcmp(z.parameter_domain_status,'parameter_out_suspected'),'Strong outward profile was not detected.');
    e.minimum_sensitivity=0;z=apply_joint_topology_parameter_decision(topo,e,model,'A6_M3_joint_diagnostic');assert(strcmp(z.parameter_domain_status,'parameter_domain_indeterminate'),'Low sensitivity must be indeterminate.');
    e1=ev();e2=ev();e2.extended_outside=false;e2.lambda=0;e2.relative_improvement=0;e2.boundary_hit=false;e2.outward_decrease=false;topo.decision='equivalence_class';topo.accepted_topology_set='G002,G005';z=apply_joint_topology_parameter_decision(topo,[e1 e2],model,'A6_M3_joint_diagnostic');assert(strcmp(z.parameter_domain_status,'parameter_domain_indeterminate'),'Conflicting equivalent members must be indeterminate.');
    topo.decision='reject_low_stability';z=apply_joint_topology_parameter_decision(topo,e1,model,'A6_M3_joint_diagnostic');assert(strcmp(z.parameter_domain_status,'parameter_not_evaluated'),'Rejected topology must not expose a domain decision.');
    txt=fileread(which('apply_joint_topology_parameter_decision'));assert(isempty(regexp(txt,'truth_topology_id|coverage_status','once')),'Decision function references truth/oracle fields.');
    fprintf('ALL STAGE 4A.6 DOMAIN DECISION TESTS PASSED\n');
end
function e=ev(),e=struct('minimum_sensitivity',1,'optimization_converged',true,'boundary_hit',true,'outward_decrease',true,'extended_outside',true,'lambda',1,'relative_improvement',0.5);end
