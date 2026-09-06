function out = apply_stage4a6_1_parameter_decision(topology_decision,member_evidence,model,method_id)
%APPLY_STAGE4A6_1_PARAMETER_DECISION Truth-free joint output.
    out=struct('topology_status',map_topology(topology_decision.decision), ...
        'topology_set',topology_decision.accepted_topology_set, ...
        'best_topology_id',topology_decision.best_topology_id, ...
        'parameter_domain_status','parameter_not_evaluated', ...
        'parameter_evidence','topology not accepted','method_id',method_id, ...
        'profile_reliable',false,'optimizer_converged',false, ...
        'multistart_consistent',false,'active_parameters_identifiable',false);
    if isempty(member_evidence) || startsWith(out.topology_status,'reject_'), return; end
    if strcmp(method_id,'A6_1_M0_topology_only')
        out.parameter_domain_status='parameter_not_evaluated';
        out.parameter_evidence='parameter-domain detector not applicable'; return;
    end
    if ~isfield(model,'calibration_valid') || ~model.calibration_valid
        out.parameter_domain_status='parameter_domain_indeterminate';
        out.parameter_evidence='insufficient_calibration'; return;
    end
    statuses=cell(1,numel(member_evidence));
    for k=1:numel(member_evidence)
        e=member_evidence(k);
        out.profile_reliable=out.profile_reliable||e.profile_reliable;
        out.optimizer_converged=out.optimizer_converged||e.optimizer_converged;
        out.multistart_consistent=out.multistart_consistent||e.multistart_consistent;
        out.active_parameters_identifiable=out.active_parameters_identifiable||e.active_parameters_identifiable;
        if ~e.profile_reliable || e.minimum_sensitivity<model.sensitivity_floor
            statuses{k}='parameter_domain_indeterminate';
        elseif strcmp(method_id,'A6_1_M1_boundary')
            if e.boundary_hit && e.outward_decrease,statuses{k}='parameter_out_suspected';else,statuses{k}='parameter_in_domain';end
        elseif strcmp(method_id,'A6_1_M2_extended_profile')
            if e.profile_outside && (e.profile_lambda>model.lambda_threshold || ...
                    e.profile_relative_improvement>model.relative_improvement_threshold)
                statuses{k}='parameter_out_suspected';else,statuses{k}='parameter_in_domain';end
        else
            if e.profile_outside && e.boundary_hit && e.outward_decrease && ...
                    e.profile_lambda>model.lambda_threshold && ...
                    e.profile_relative_improvement>model.relative_improvement_threshold
                statuses{k}='parameter_out_suspected';
            elseif e.profile_outside && (e.profile_lambda>model.lambda_threshold || ...
                    e.profile_relative_improvement>model.relative_improvement_threshold)
                statuses{k}='parameter_domain_indeterminate';
            else
                statuses{k}='parameter_in_domain';
            end
        end
    end
    u=unique(statuses);if numel(u)>1
        out.parameter_domain_status='parameter_domain_indeterminate';
        out.parameter_evidence='equivalent-class members disagree';
    else
        out.parameter_domain_status=u{1};
        out.parameter_evidence=sprintf('%s; members=%d',u{1},numel(member_evidence));
    end
end
function s=map_topology(d)
    if ismember(d,{'unique_topology','unique_given_prior','equivalence_class'}),s=d;
    elseif strcmp(d,'reject_no_feasible_candidate'),s='reject_structure_mismatch';
    else,s='reject_low_confidence';end
end
