function out=apply_candidate_nonconformity_set(distances,model,alpha)
%APPLY_CANDIDATE_NONCONFORMITY_SET Apply frozen empirical candidate scores.
if nargin<3||isempty(alpha),alpha=model.alpha;end;f=score_candidate_nonconformity_family(distances,model.candidate_ids,model.equivalence_group,model.scales);methods={'absolute','scaled','ratio','margin'};out=repmat(struct('method_id','','p_values',[],'accepted_candidate_set',{{}},'status',''),1,numel(methods));
for q=1:numel(methods),v=f.(methods{q});p=NaN(1,numel(model.candidate_ids));for j=1:numel(p),if strcmp(model.classes(j).status,'calibrated'),z=model.classes(j).scores.(methods{q});p(j)=(1+sum(z>=v(1,j)))/(numel(z)+1);end,end;keep=p>alpha;out(q).method_id=methods{q};out(q).p_values=p;out(q).accepted_candidate_set=model.candidate_ids(keep);out(q).status=ternary(any(keep),'accepted','reject_model_mismatch');end
end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
