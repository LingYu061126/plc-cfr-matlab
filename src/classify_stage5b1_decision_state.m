function out = classify_stage5b1_decision_state(frozen, margin, confidence, model)
%CLASSIFY_STAGE5B1_DECISION_STATE Add four-state evidence semantics.
%   REJECTED has priority and preserves the frozen Stage 4A candidate-set
%   and Rule A gates. A singleton is UNIQUE_CONFIDENT only when all added
%   evidence checks pass. No soft score can override frozen rejection.
    required={'candidate_set_size','domain_accepted','best_candidate_in_set'};
    for k=1:numel(required),assert(isfield(frozen,required{k}),'stage5b1:MissingFrozenField','Missing %s.',required{k});end
    residual_accepted=logical(frozen.domain_accepted)&&(frozen.candidate_set_size>0);
    margin_pass=isfinite(margin.margin)&&(margin.margin>=model.margin_threshold);
    confidence_pass=isfinite(confidence.top1_confidence)&&(confidence.top1_confidence>=model.top1_confidence_threshold);
    entropy_pass=isfinite(confidence.normalized_entropy)&&(confidence.normalized_entropy<=model.normalized_entropy_threshold);
    evidence_sufficient=margin_pass&&confidence_pass&&entropy_pass&&logical(frozen.best_candidate_in_set);
    if ~residual_accepted
        state='REJECTED';reason='frozen_candidate_set_empty_or_rule_a_rejected';
    elseif frozen.candidate_set_size==1&&evidence_sufficient
        state='UNIQUE_CONFIDENT';reason='singleton_and_all_evidence_checks_pass';
    elseif frozen.candidate_set_size>1&&~evidence_sufficient
        state='MULTIPLE_AMBIGUOUS';reason='multiple_frozen_candidates_and_insufficient_separation';
    else
        state='LOW_CONFIDENCE';reason='frozen_acceptance_but_unique_evidence_insufficient_or_mixed';
    end
    out=struct('enhanced_decision_state',state,'decision_reason',reason, ...
        'residual_accepted',residual_accepted,'margin_pass',margin_pass, ...
        'confidence_pass',confidence_pass,'entropy_pass',entropy_pass, ...
        'best_candidate_in_set',logical(frozen.best_candidate_in_set), ...
        'evidence_sufficient',evidence_sufficient, ...
        'definition_version','stage5b1_four_state_decision_v1');
end
