function out=stage7a5_decide(scored,model,bank)
%STAGE7A5_DECIDE Four-state evidence-aware decision, without truth labels.
    if ~strcmp(model.bank_identity,bank.identity)|| ...
            ~strcmp(model.search_identity,bank.search_identity)
        error('stage7a5:DecisionCalibrationIdentity', ...
            'Decision calibration does not match this model/search identity.');
    end
    if ~all(ismember(scored.candidate_ids,model.candidate_ids))
        error('stage7a5:DecisionCandidateIdentity', ...
            'Scored candidate identities exceed the calibrated candidate domain.');
    end
    if ~isequal(model.views,scored.views)
        error('stage7a5:ViewIdentity','Observation view differs from calibration.');
    end
    d=scored.distances(:).';ids=scored.candidate_ids;
    [sorted,order]=sort(d);best=order(1);
    if numel(sorted)>1,margin=sorted(2)-sorted(1);else,margin=Inf;end
    if strcmp(model.kind,'legacy_full_profile')
        keep=d<=model.class_threshold;
    else
        keep=(d-min(d))<=model.set_threshold;
    end
    if strcmp(model.kind,'legacy_full_profile')
        fit_pass=scored.fit_statistic<=model.fit_threshold;
    else
        fit_pass=scored.fit_statistic<=model.fit_threshold;
    end
    set_ids=ids(keep);
    if ~fit_pass
        state='REJECTED';reason='fit_quality_gate';
    elseif isempty(set_ids)
        state='REJECTED';reason='empty_candidate_set';
    elseif numel(set_ids)>1
        state='MULTIPLE_AMBIGUOUS';reason='multiple_candidates';
    elseif margin<model.margin_threshold
        state='LOW_CONFIDENCE';reason='insufficient_unique_margin';
    elseif scored.search_truncated
        state='LOW_CONFIDENCE';reason='search_budget_truncated';
    else
        state='UNIQUE_CONFIDENT';reason='single_candidate_with_margin';
    end
    out=struct('decision_state',state,'decision_reason',reason, ...
        'best_candidate',ids{best},'candidate_set',{set_ids}, ...
        'candidate_set_size',numel(set_ids),'distance_1',sorted(1), ...
        'distance_2',sorted(min(2,numel(sorted))),'margin',margin, ...
        'fit_statistic',scored.fit_statistic,'fit_threshold',model.fit_threshold, ...
        'fit_pass',fit_pass,'search_truncated',scored.search_truncated, ...
        'generated_ids',{scored.generated_ids});
end
