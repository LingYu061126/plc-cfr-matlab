function out=stage7a10_decide(observed,bank,model)
%STAGE7A10_DECIDE Four-state adaptive candidate-set decision without truth.
    if ~strcmp(bank.identity,model.bank_identity)
        error('stage7a10:BankIdentity','Template bank differs from calibration.');
    end
    ids=bank.candidate_ids(model.indices);
    if ~isequal(ids,model.candidate_ids)
        error('stage7a10:CandidateIdentity','Candidate order differs from calibration.');
    end
    p=stage7a10_adaptive_profile(observed,bank,model.indices, ...
        model.sigma,model.selector,model.first_threshold);
    % The adaptive stage can refine, but must not admit a graph excluded by
    % the independently calibrated first-stage H50 candidate set.
    d=p.distances;keep=(d<=model.class_threshold)&p.first_set;
    if p.selected_view==0,keep(:)=false;end
    [sorted,order]=sort(d);margin=sorted(2)-sorted(1);
    fit_pass=sorted(1)<=model.fit_threshold;
    if p.selected_view==0
        state='REJECTED';reason='empty_first_set';
    elseif ~fit_pass
        state='REJECTED';reason='fit_quality_gate';
    elseif ~any(keep)
        state='REJECTED';reason='empty_candidate_set';
    elseif nnz(keep)>1
        state='MULTIPLE_AMBIGUOUS';reason='multiple_candidates';
    elseif p.separation<model.extra_view_threshold
        state='LOW_CONFIDENCE';reason='insufficient_extra_view_separation';
    elseif ~keep(order(1))||margin<model.margin_threshold
        state='LOW_CONFIDENCE';reason='insufficient_unique_margin';
    else
        state='UNIQUE_CONFIDENT';reason='single_candidate_with_margin';
    end
    out=struct('candidate_set',strjoin(ids(keep),','), ...
        'candidate_set_size',nnz(keep),'best_candidate',ids{order(1)}, ...
        'distance',sorted(1),'second_distance',sorted(2),'margin',margin, ...
        'fit_threshold',model.fit_threshold,'fit_accepted',fit_pass, ...
        'decision_state',state,'decision_reason',reason, ...
        'all_distances',d,'selected_view',p.selected_view, ...
        'first_set',p.first_set,'extra_view_separation',p.separation, ...
        'class_threshold',model.class_threshold);
end
