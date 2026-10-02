function out=stage7a12_confirm(observed,bank,model,generated_indices,eligible_indices)
%STAGE7A12_CONFIRM Pooled-calibration four-state H50 confirmer.
%   generated_indices/eligible_indices are bank rows, never truth labels.
%   The best eligible competitor is kept for margin safety even if pruned.
    if ~strcmp(bank.identity,model.bank_identity)
        error('stage7a12:BankIdentity','Bank differs from calibration.');
    end
    if ~isequal(bank.candidate_signatures,model.candidate_signatures)
        error('stage7a12:CandidateIdentity', ...
            'Candidate order differs from calibration.');
    end
    if isempty(generated_indices)
        out=struct('candidate_set','','candidate_set_size',0, ...
            'best_candidate','','decision_state','REJECTED', ...
            'decision_reason','empty_generated_library', ...
            'distance',Inf,'margin',NaN,'all_distances',[]);
        return;
    end
    assert(all(ismember(generated_indices,eligible_indices))&& ...
        numel(unique(generated_indices))==numel(generated_indices), ...
        'stage7a12:CandidateSubset');
    profile=stage7a4_profile_views(observed,bank,eligible_indices,5,model.sigma);
    d=profile.distances;[~,pos]=ismember(generated_indices,eligible_indices);
    selected_d=d(pos);[best,best_pos]=min(selected_d);
    best_ix=generated_indices(best_pos);
    other=d(eligible_indices~=best_ix);
    if isempty(other),margin=Inf;else,margin=min(other)-best;end
    keep=selected_d<=model.class_threshold;
    fit_ok=best<=model.fit_threshold;
    if ~fit_ok
        state='REJECTED';reason='fit_quality_gate';
    elseif ~any(keep)
        state='REJECTED';reason='empty_candidate_set';
    elseif nnz(keep)>1
        state='MULTIPLE_AMBIGUOUS';reason='multiple_candidates';
    elseif ~keep(best_pos)||margin<model.margin_threshold
        state='LOW_CONFIDENCE';reason='insufficient_unique_margin';
    else
        state='UNIQUE_CONFIDENT';reason='single_candidate_with_margin';
    end
    out=struct('candidate_set',strjoin(bank.candidate_ids(generated_indices(keep)),','), ...
        'candidate_set_size',nnz(keep),'best_candidate', ...
        bank.candidate_ids{best_ix},'decision_state',state, ...
        'decision_reason',reason,'distance',best,'margin',margin, ...
        'all_distances',d,'generated_distances',selected_d);
end
