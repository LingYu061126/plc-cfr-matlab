function out = stage4a6_3_1_r1_aggregate_class_evidence( ...
        confirmation, member_evidence, parameter_model, method_id, ...
        compatibility_hash, parameter_calibration_hash)
%STAGE4A6_3_1_R1_AGGREGATE_CLASS_EVIDENCE Conservative member aggregation.
% Every accepted member must be present and profile-reliable before a
% deterministic class-level parameter conclusion is allowed.
    ids = getfield_default(confirmation, 'accepted_member_ids', {});
    if ischar(ids), ids = {ids}; end
    evaluated = cell(1, numel(member_evidence));
    for k = 1:numel(member_evidence)
        evaluated{k} = getfield_default(member_evidence(k), 'topology_id', '');
    end
    evaluated = evaluated(~cellfun(@isempty, evaluated));
    out = struct('topology_status', getfield_default(confirmation, 'decision', ...
            'reject_low_confidence'), ...
        'topology_set', getfield_default(confirmation, 'accepted_topology_set', ''), ...
        'best_topology_id', getfield_default(confirmation, 'best_topology_id', ''), ...
        'parameter_domain_status', 'parameter_not_evaluated', ...
        'parameter_evidence', '', 'method_id', method_id, ...
        'accepted_member_ids', {ids}, 'accepted_member_count', numel(ids), ...
        'evaluated_member_ids', {evaluated}, ...
        'evaluated_member_count', numel(evaluated), ...
        'reliable_member_count', 0, 'unreliable_member_count', 0, ...
        'member_domain_statuses', {{}}, 'class_aggregation_reason', '', ...
        'parameter_decision_reliable', false, 'member_evidence', member_evidence, ...
        'member_count', numel(ids), 'compatibility_hash', compatibility_hash, ...
        'parameter_calibration_hash', parameter_calibration_hash);
    if isempty(ids) || startsWith(out.topology_status, 'reject_')
        out.class_aggregation_reason = 'topology rejected or no accepted member';
        return;
    end
    if numel(evaluated) ~= numel(ids) || ~all(ismember(ids, evaluated))
        out.parameter_domain_status = 'parameter_domain_indeterminate';
        out.class_aggregation_reason = 'accepted/evaluated member count mismatch';
        return;
    end
    reliable = false(1, numel(member_evidence));
    member_statuses = cell(1, numel(member_evidence));
    for k = 1:numel(member_evidence)
        reliable(k) = getfield_default(member_evidence(k), 'profile_reliable', false);
        one = confirmation;
        one.accepted_member_ids = {member_evidence(k).topology_id};
        one.accepted_member_count = 1;
        one.accepted_topology_set = member_evidence(k).topology_id;
        q = apply_stage4a6_2_parameter_decision(one, member_evidence(k), ...
            parameter_model, method_id);
        member_statuses{k} = getfield_default(q, 'parameter_domain_status', ...
            'parameter_domain_indeterminate');
    end
    out.reliable_member_count = sum(reliable);
    out.unreliable_member_count = sum(~reliable);
    out.member_domain_statuses = member_statuses;
    if any(~reliable)
        out.parameter_domain_status = 'parameter_domain_indeterminate';
        out.class_aggregation_reason = 'at least one accepted member has unreliable profile';
        return;
    end
    if any(strcmp(member_statuses, 'parameter_domain_indeterminate')) || ...
            any(strcmp(member_statuses, 'parameter_not_evaluated')) || ...
            any(startsWith(member_statuses, 'parameter_domain_indeterminate'))
        out.parameter_domain_status = 'parameter_domain_indeterminate';
        out.class_aggregation_reason = 'member evidence is indeterminate';
    elseif all(strcmp(member_statuses, 'parameter_in_domain'))
        out.parameter_domain_status = 'parameter_in_domain';
        out.parameter_decision_reliable = true;
        out.class_aggregation_reason = 'all accepted members support in-domain';
    elseif all(strcmp(member_statuses, 'parameter_out_suspected'))
        out.parameter_domain_status = 'parameter_out_suspected';
        out.parameter_decision_reliable = true;
        out.class_aggregation_reason = 'all accepted members support out-of-domain';
    else
        out.parameter_domain_status = 'parameter_domain_indeterminate';
        out.class_aggregation_reason = 'accepted members have conflicting conclusions';
    end
    out.parameter_evidence = out.class_aggregation_reason;
end

function v = getfield_default(s, n, d)
    if isstruct(s) && isfield(s, n), v = s.(n); else, v = d; end
end
