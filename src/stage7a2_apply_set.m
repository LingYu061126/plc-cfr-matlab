function out=stage7a2_apply_set(distances,model)
%STAGE7A2_APPLY_SET Truth-free candidate-set construction from fixed A model.
    d=double(distances(:).');m=numel(model.candidate_ids);
    assert(numel(d)==m&&all(isfinite(d))&&all(d>=0), ...
        'stage7a2:InvalidDistances','Distance shape or values are invalid.');
    switch model.kind
        case 'class_conditional'
            a=stage4a7_2_r1_apply_profile_candidate_set(d,model.topology_model,'absolute');
            keep=ismember(model.candidate_ids,a.accepted_candidate_set);p=a.p_values;
        case 'pooled_empirical'
            keep=d<=model.pooled_threshold;p=NaN(1,m);
        otherwise
            error('stage7a2:UnknownSetKind','Unknown set kind.');
    end
    out=struct('keep',logical(keep),'candidate_set',{model.candidate_ids(keep)}, ...
        'set_size',nnz(keep),'p_values',p);
end
