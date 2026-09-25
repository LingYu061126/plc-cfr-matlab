function out=stage7a3_apply_residual_gate(decision,statistic,model)
%STAGE7A3_APPLY_RESIDUAL_GATE Add a one-way fit-quality rejection gate.
%   The candidate set is never changed. The gate cannot create a unique
%   decision; it only preserves the input state or maps it to REJECTED.
    assert(isstruct(decision)&&isscalar(decision)&&isfield(decision,'decision_state')&& ...
        isfield(decision,'candidate_set_size'),'stage7a3:InvalidDecision', ...
        'Decision must include its state and candidate-set size.');
    assert(isfinite(statistic)&&statistic>=0&&isfield(model,'threshold')&& ...
        ~isnan(model.threshold),'stage7a3:InvalidGateInput','Invalid residual or gate threshold.');
    out=decision;out.pre_gate_decision_state=decision.decision_state;
    out.fit_quality_statistic=statistic;out.fit_quality_threshold=model.threshold;
    out.fit_quality_accepted=statistic<=model.threshold;out.gate_rejected=false;
    if ~out.fit_quality_accepted
        out.decision_state='REJECTED';out.decision_reason='library_fit_quality_gate_reject';
        out.gate_rejected=true;
    end
    out.nonempty_set_rejected=out.gate_rejected&&decision.candidate_set_size>0;
    assert(out.candidate_set_size==decision.candidate_set_size&& ...
        ~(strcmp(out.decision_state,'UNIQUE_CONFIDENT')&& ...
          ~strcmp(decision.decision_state,'UNIQUE_CONFIDENT')), ...
        'stage7a3:GatePromotedDecision','Residual gate must not shrink sets or promote uniqueness.');
end
