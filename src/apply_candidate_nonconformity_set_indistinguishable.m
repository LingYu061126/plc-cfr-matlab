function out = apply_candidate_nonconformity_set_indistinguishable(distances,model,alpha,resolution)
%APPLY_CANDIDATE_NONCONFORMITY_SET_INDISTINGUISHABLE C-set plus calibrated ambiguity.
%   The empirical set is first obtained from the frozen absolute score. Any
%   candidate in the same observation-conditioned indistinguishability
%   component is retained.  This is not a physical equivalence assertion.
    if nargin<3||isempty(alpha),alpha=model.alpha;end
    if nargin<4||isempty(resolution),resolution=0;end
    base=apply_candidate_nonconformity_set(distances,model,alpha);
    q=find(strcmp({base.method_id},'absolute'),1);
    ids=model.candidate_ids;
    fam=score_candidate_nonconformity_family(distances,ids,model.equivalence_group,model.scales);
    graph=build_candidate_indistinguishability_graph(ids,fam.absolute(1,:),resolution);
    accepted=base(q).accepted_candidate_set;
    keep=false(1,numel(ids));
    for k=1:numel(accepted)
        j=find(strcmp(ids,accepted{k}),1);
        if ~isempty(j),keep(graph.component_index==graph.component_index(j))=true;end
    end
    out=struct('method_id','absolute_I','base_method_id','absolute', ...
        'p_values',base(q).p_values,'accepted_candidate_set',{ids(keep)}, ...
        'base_accepted_candidate_set',{accepted},'status',ternary(any(keep),'accepted','reject_model_mismatch'), ...
        'indistinguishability_graph',graph,'resolution',resolution, ...
        'calibration_hash',getf(model,'calibration_hash',''));
end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
