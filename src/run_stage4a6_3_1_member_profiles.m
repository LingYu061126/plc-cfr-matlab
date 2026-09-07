function out = run_stage4a6_3_1_member_profiles(observed_views,frequency_hz,confirmation,candidates,cfg,domain,profile_options,parameter_model)
%RUN_STAGE4A6_3_1_MEMBER_PROFILES Evaluate every accepted equivalence member.
    ids=getfield_default(confirmation,'accepted_member_ids',{});if ischar(ids),ids={ids};end
    e=[];evaluated={};
    if isempty(ids),out=aggregate_stage4a6_3_1_member_evidence(confirmation,e,parameter_model,'A6_3_M3_joint_diagnostic');return;end
    for k=1:numel(ids)
        j=find(strcmp({candidates.topology_id},ids{k}),1);if isempty(j),continue;end
        initial=getfield_default(confirmation,'best_parameter_values',[]);
        q=compute_stage4a6_2_member_evidence(observed_views,frequency_hz,candidates(j),cfg,domain,initial,profile_options);
        if isempty(e),e=q;else,e(end+1)=q;end %#ok<AGROW>
        evaluated{end+1}=ids{k}; %#ok<AGROW>
    end
    out=aggregate_stage4a6_3_1_member_evidence(confirmation,e,parameter_model,'A6_3_M3_joint_diagnostic');
    out.member_evidence=e;out.evaluated_member_ids=evaluated;out.evaluated_member_count=numel(evaluated);
end
function v=getfield_default(s,n,d),if isstruct(s)&&isfield(s,n),v=s.(n);else,v=d;end,end
