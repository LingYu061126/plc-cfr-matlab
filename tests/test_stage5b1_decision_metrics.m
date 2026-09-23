function test_stage5b1_decision_metrics()
%TEST_STAGE5B1_DECISION_METRICS Four required Stage 5B.1 cases.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    ids={'A','B','C'};model=struct('beta',10,'margin_threshold',0.10, ...
        'top1_confidence_threshold',0.70,'normalized_entropy_threshold',0.45);

    % Case 1: an accepted singleton with clear separation is unique.
    d=[0.01 0.50 0.80];m=compute_candidate_margin(d,ids);c=compute_candidate_confidence(d,model.beta,ids);
    frozen=struct('candidate_set_size',1,'domain_accepted',true,'best_candidate_in_set',true);
    out=classify_stage5b1_decision_state(frozen,scalar_margin(m),scalar_confidence(c),model);
    assert(strcmp(out.enhanced_decision_state,'UNIQUE_CONFIDENT'),'Clear Top-1 was not UNIQUE_CONFIDENT.');

    % Case 2: two accepted near-ties are ambiguous.
    d=[0.01 0.011 0.80];m=compute_candidate_margin(d,ids);c=compute_candidate_confidence(d,model.beta,ids);
    frozen.candidate_set_size=2;
    out=classify_stage5b1_decision_state(frozen,scalar_margin(m),scalar_confidence(c),model);
    assert(strcmp(out.enhanced_decision_state,'MULTIPLE_AMBIGUOUS'),'Near tie was not MULTIPLE_AMBIGUOUS.');

    % Case 3: no frozen candidate passes; soft confidence cannot undo rejection.
    d=[2 3 4];m=compute_candidate_margin(d,ids);c=compute_candidate_confidence(d,model.beta,ids);
    frozen=struct('candidate_set_size',0,'domain_accepted',false,'best_candidate_in_set',false);
    out=classify_stage5b1_decision_state(frozen,scalar_margin(m),scalar_confidence(c),model);
    assert(strcmp(out.enhanced_decision_state,'REJECTED'),'Empty/all-bad case was not REJECTED.');

    % Case 4: actual T3/T5 matched-end SISO responses are indistinguishable.
    cfg=default_config(root);cfg.frequency_hz=linspace(2e6,30e6,61);cand=topology_candidates(cfg);
    c3=cand(strcmp({cand.id},'T3'));c5=cand(strcmp({cand.id},'T5'));
    h=topology_reference_cfr(cfg.frequency_hz,[c3 c5],cfg);
    assert(max(abs(h(1).reference_H-h(2).reference_H))<=1e-10,'T3/T5 positive control drifted.');
    distances=[sqrt(mean(abs(h(1).reference_H-h(1).reference_H).^2)), ...
        sqrt(mean(abs(h(1).reference_H-h(2).reference_H).^2))];
    m=compute_candidate_margin(distances,{'T3','T5'});c=compute_candidate_confidence(distances,model.beta,{'T3','T5'});
    % Simulate the dangerous Stage 4A singleton case: Stage 5B.1 must not
    % promote it to a confident unique decision when the physical scores tie.
    frozen=struct('candidate_set_size',1,'domain_accepted',true,'best_candidate_in_set',true);
    out=classify_stage5b1_decision_state(frozen,scalar_margin(m),scalar_confidence(c),model);
    assert(~strcmp(out.enhanced_decision_state,'UNIQUE_CONFIDENT'),'T3/T5 produced a false confident unique decision.');
    fprintf('  PASS Stage 5B.1 clear, near-tie, rejected and T3/T5 cases\n');
end

function m=scalar_margin(x),m=struct('margin',x.margin(1));end
function c=scalar_confidence(x),c=struct('top1_confidence',x.top1_confidence(1),'normalized_entropy',x.normalized_entropy(1));end
