function out=stage4a7_2_r1_apply_profile_candidate_set(distances,model,method_id)
%STAGE4A7_2_R1_APPLY_PROFILE_CANDIDATE_SET Apply one frozen method.
    fam=stage4a7_2_r1_profile_score_families(distances,model.scales,model.resolution);
    if ~isfield(fam,method_id),error('stage4a7_2_r1:UnknownMethod','Unknown method.');end
    scores=fam.(method_id);ids=model.candidate_ids;classes=model.classes;
    p=NaN(1,numel(ids));
    for j=1:numel(ids)
        if strcmp(classes(j).status,'calibrated')
            z=classes(j).scores;p(j)=(1+sum(z>=scores(1,j)))/(numel(z)+1);
        end
    end
    keep=p>model.alpha;accepted=ids(keep);
    out=struct('method_id',method_id,'p_values',p,'accepted_candidate_set',{accepted}, ...
        'set_size',numel(accepted),'empty',isempty(accepted), ...
        'status',ternary(isempty(accepted),'empty_set','accepted_set'), ...
        'minimum_attainable_p',min([classes.minimum_attainable_p]), ...
        'calibration_hash',model.calibration_hash,'compatibility_hash',model.compatibility_hash);
end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
