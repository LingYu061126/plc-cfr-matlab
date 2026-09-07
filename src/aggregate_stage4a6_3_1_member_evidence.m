function out = aggregate_stage4a6_3_1_member_evidence(confirmation,member_evidence,parameter_model,method_id)
%AGGREGATE_STAGE4A6_3_1_MEMBER_EVIDENCE Enforce complete member coverage.
    ids=getfield_default(confirmation,'accepted_member_ids',{});if ischar(ids),ids={ids};end
    evaluated={};for k=1:numel(member_evidence),if isfield(member_evidence(k),'topology_id'),evaluated{end+1}=member_evidence(k).topology_id;end,end
    out=struct('topology_status',getfield_default(confirmation,'decision','reject_low_confidence'), ...
        'topology_set',getfield_default(confirmation,'accepted_topology_set',''), ...
        'best_topology_id',getfield_default(confirmation,'best_topology_id',''), ...
        'parameter_domain_status','parameter_not_evaluated','parameter_evidence','', ...
        'method_id',method_id,'accepted_member_ids',{ids},'accepted_member_count',numel(ids), ...
        'evaluated_member_ids',{evaluated},'evaluated_member_count',numel(evaluated), ...
        'member_evidence',member_evidence,'member_count',numel(ids));
    if isempty(ids)||startsWith(out.topology_status,'reject_'),out.parameter_domain_status='parameter_not_evaluated';return;end
    if numel(evaluated)~=numel(ids)||~all(ismember(ids,evaluated))
        out.parameter_domain_status='parameter_domain_indeterminate';out.parameter_evidence='incomplete accepted-member evidence';return;
    end
    q=apply_stage4a6_2_parameter_decision(confirmation,member_evidence,parameter_model,method_id);
    f=fieldnames(q);for k=1:numel(f),out.(f{k})=q.(f{k});end
    out.accepted_member_ids=ids;out.accepted_member_count=numel(ids);out.evaluated_member_ids=evaluated;out.evaluated_member_count=numel(evaluated);out.member_evidence=member_evidence;out.member_count=numel(ids);
end
function v=getfield_default(s,n,d),if isstruct(s)&&isfield(s,n),v=s.(n);else,v=d;end,end
