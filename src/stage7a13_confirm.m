function out=stage7a13_confirm(observed,bank,model,selected,eligible,meter_count,mode)
%STAGE7A13_CONFIRM Paired pooled/stratified H50 four-state confirmation.
%   selected and eligible are bank indices. Truth is not an input. The
%   margin uses all eligible competitors, including graphs pruned by CI.
    assert(ismember(mode,{'pooled','stratified'}),'stage7a13:Mode');
    if ~strcmp(bank.identity,model.bank_identity) || ...
            ~isequal(bank.candidate_signatures,model.candidate_signatures)
        error('stage7a13:BankIdentity', ...
            'Calibration and candidate-bank identities differ.');
    end
    assert(numel(unique(selected))==numel(selected) && ...
        all(ismember(selected,eligible)) && ...
        numel(unique(eligible))==numel(eligible), ...
        'stage7a13:CandidateSubset');
    if strcmp(mode,'stratified') && meter_count<=numel(model.strata)
        stratum=model.strata(meter_count);
        class_threshold=stratum.class_threshold;
        fit_threshold=stratum.fit_threshold;
        fallback=stratum.fallback;
    else
        class_threshold=model.pooled_class_threshold;
        fit_threshold=model.pooled_fit_threshold;
        fallback=true;
    end
    if isempty(selected)
        out=struct('candidate_set','','candidate_set_size',0, ...
            'best_candidate','','decision_state','REJECTED', ...
            'decision_reason','empty_generated_library', ...
            'distance',Inf,'margin',NaN,'selected_only_margin',NaN, ...
            'all_distances',[],'class_threshold',class_threshold, ...
            'fit_threshold',fit_threshold,'margin_threshold', ...
            model.margin_threshold,'stratum_fallback',fallback);
        return;
    end
    profile=stage7a4_profile_views(observed,bank,eligible,5,model.sigma);
    d=profile.distances;
    [~,position]=ismember(selected,eligible);
    chosen_distances=d(position);
    [best,best_position]=min(chosen_distances);
    best_index=selected(best_position);
    other=d(eligible~=best_index);
    if isempty(other),margin=Inf;else,margin=min(other)-best;end
    if numel(chosen_distances)<2
        selected_margin=Inf;
    else
        ordered=sort(chosen_distances);
        selected_margin=ordered(2)-ordered(1);
    end
    keep=chosen_distances<=class_threshold;
    if best>fit_threshold
        state='REJECTED';reason='fit_quality_gate';
    elseif ~any(keep)
        state='REJECTED';reason='empty_candidate_set';
    elseif nnz(keep)>1
        state='MULTIPLE_AMBIGUOUS';reason='multiple_candidates';
    elseif ~keep(best_position) || margin<model.margin_threshold
        state='LOW_CONFIDENCE';reason='insufficient_unique_margin';
    else
        state='UNIQUE_CONFIDENT';reason='single_candidate_with_margin';
    end
    out=struct('candidate_set', ...
        strjoin(bank.candidate_ids(selected(keep)),','), ...
        'candidate_set_size',nnz(keep), ...
        'best_candidate',bank.candidate_ids{best_index}, ...
        'decision_state',state,'decision_reason',reason, ...
        'distance',best,'margin',margin, ...
        'selected_only_margin',selected_margin, ...
        'all_distances',d,'class_threshold',class_threshold, ...
        'fit_threshold',fit_threshold, ...
        'margin_threshold',model.margin_threshold, ...
        'stratum_fallback',fallback);
end
