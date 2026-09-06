function out = apply_joint_topology_parameter_decision(topology_decision,member_evidence,model,method_id)
%APPLY_JOINT_TOPOLOGY_PARAMETER_DECISION Truth-free orthogonal decision.
    out=struct('topology_status',map_topology(topology_decision.decision),'topology_set',topology_decision.accepted_topology_set,'best_topology_id',topology_decision.best_topology_id,'parameter_domain_status','parameter_not_evaluated','parameter_evidence','topology not accepted','method_id',method_id);
    if isempty(member_evidence)||startsWith(out.topology_status,'reject_'),return;end
    statuses=cell(1,numel(member_evidence));for k=1:numel(member_evidence),e=member_evidence(k);low=e.minimum_sensitivity<model.sensitivity_floor||~e.optimization_converged;switch method_id
        case 'A6_M0_topology_only',statuses{k}='parameter_not_evaluated';
        case 'A6_M1_boundary',if low,statuses{k}='parameter_domain_indeterminate';elseif e.boundary_hit&&e.outward_decrease,statuses{k}='parameter_out_suspected';else,statuses{k}='parameter_in_domain';end
        case 'A6_M2_extended_profile',if low,statuses{k}='parameter_domain_indeterminate';elseif e.extended_outside&&(e.lambda>model.lambda_threshold||e.relative_improvement>model.relative_improvement_threshold),statuses{k}='parameter_out_suspected';else,statuses{k}='parameter_in_domain';end
        otherwise,if low,statuses{k}='parameter_domain_indeterminate';elseif e.extended_outside&&e.boundary_hit&&e.outward_decrease&&e.lambda>model.lambda_threshold&&e.relative_improvement>model.relative_improvement_threshold,statuses{k}='parameter_out_suspected';elseif e.extended_outside&&(e.lambda>model.lambda_threshold||e.relative_improvement>model.relative_improvement_threshold),statuses{k}='parameter_domain_indeterminate';else,statuses{k}='parameter_in_domain';end
    end,end
    u=unique(statuses);if numel(u)>1,out.parameter_domain_status='parameter_domain_indeterminate';out.parameter_evidence='equivalence-class members disagree';else,out.parameter_domain_status=u{1};out.parameter_evidence=sprintf('%s; members=%d',u{1},numel(member_evidence));end
end
function s=map_topology(d),if ismember(d,{'unique_topology','unique_given_prior','equivalence_class'}),s=d;elseif strcmp(d,'reject_no_feasible_candidate'),s='reject_structure_mismatch';else,s='reject_low_confidence';end,end
