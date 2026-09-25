function out=stage7a4_decide(observed,bank,model)
%STAGE7A4_DECIDE Truth-free four-state candidate-set decision.
%   The candidate set is calibrated on in-library A data. A separate F
%   fit-quality gate may reject while preserving that set unchanged.
    if ~strcmp(bank.identity,model.bank_identity)
        error('stage7a4:BankIdentity','Template bank identity differs from calibration.');
    end
    ids=bank.candidate_ids(model.candidate_indices);
    if ~isequal(ids,model.candidate_ids)
        error('stage7a4:CandidateIdentity','Candidate order differs from calibration.');
    end
    p=stage7a4_profile_views(observed,bank,model.candidate_indices, ...
        model.view_indices,model.sigma);
    d=p.distances;keep=d<=model.class_threshold;set=ids(keep);
    [sorted,order]=sort(d);margin=sorted(2)-sorted(1);
    fit_pass=sorted(1)<=model.fit_threshold;
    if ~fit_pass
        state='REJECTED';reason='fit_quality_gate';
    elseif ~any(keep)
        state='REJECTED';reason='empty_candidate_set';
    elseif nnz(keep)>1
        state='MULTIPLE_AMBIGUOUS';reason='multiple_candidates';
    elseif ~keep(order(1)) || margin<model.margin_threshold
        state='LOW_CONFIDENCE';reason='insufficient_unique_margin';
    else
        state='UNIQUE_CONFIDENT';reason='single_candidate_with_margin';
    end
    out=struct('candidate_set',strjoin(set,','),'candidate_set_size',nnz(keep), ...
        'best_candidate',ids{order(1)},'best_index',order(1), ...
        'distance',sorted(1),'second_distance',sorted(2),'margin',margin, ...
        'fit_accepted',fit_pass,'fit_threshold',model.fit_threshold, ...
        'decision_state',state,'decision_reason',reason, ...
        'all_distances',d,'best_template_indices',p.best_template_indices, ...
        'class_threshold',model.class_threshold);
end
