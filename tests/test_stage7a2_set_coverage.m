function test_stage7a2_set_coverage()
%TEST_STAGE7A2_SET_COVERAGE Independent set construction and risk boundaries.
    root=fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    ids={'A','B'};d=[1 5;2 4;3 3;4 2;5 1;6 0.5];truth=[1;1;1;2;2;2];
    class=stage7a2_calibrate_set(d,truth,ids,0.20,'class_conditional','fixed_identity');
    pooled=stage7a2_calibrate_set(d,truth,ids,0.20,'pooled_empirical','fixed_identity');
    assert(all(class.class_counts==[3;3])&&pooled.calibration_count==6);
    a=stage7a2_apply_set([2 1],class);assert(a.set_size>=1&&numel(a.p_values)==2);
    b=stage7a2_apply_set([1e3 1e3],pooled);assert(b.set_size==0, ...
        'Pooled set must remain empty for out-of-domain scores.');
    c=stage7a2_apply_set([pooled.pooled_threshold pooled.pooled_threshold],pooled);
    assert(c.set_size==2,'Threshold ties must be conservatively included.');
    assert(abs(stage7a2_binomial_upper(0,100,0.05)-(1-0.05^(1/100)))<1e-12);
    assert(stage7a2_binomial_upper(0,0,0.05)==1);
    assert(stage7a2_binomial_upper(1,100,0.05)>stage7a2_binomial_upper(0,100,0.05));
    pooled.pooled_threshold=1.5;
    evidence=struct('beta',1,'margin_threshold',0, ...
        'top1_confidence_threshold',0,'normalized_entropy_threshold',1);
    model=struct('candidate_ids',{ids},'frequency_hz',[1 2], ...
        'identity','fixed_identity','set_model',pooled, ...
        'evidence_model',evidence,'domain_threshold',Inf, ...
        'risk_gate',struct('certified',true));
    z=stage7a2_score_distances([1 1],[1 3],model);
    assert(strcmp(z.decision_state,'UNIQUE_CONFIDENT')&&z.candidate_set_size==1);
    model.risk_gate.certified=false;
    z=stage7a2_score_distances([1 1],[1 3],model);
    assert(strcmp(z.decision_state,'LOW_CONFIDENCE')&&z.candidate_set_size==1, ...
        'Failed risk certificate must demote unique without changing its set.');
    model.identity='wrong';failed=false;
    try,stage7a2_score_distances([1 1],[1 3],model);
    catch ME,failed=strcmp(ME.identifier,'stage7a2:CalibrationIdentityMismatch');end
    assert(failed,'Calibration identity mismatch must fail closed.');
    failed=false;
    try,stage7a2_calibrate_set([1 NaN;2 3],[1;2],ids,.05,'pooled_empirical','x');
    catch ME,failed=strcmp(ME.identifier,'stage7a2:InvalidCalibration');end
    assert(failed,'Nonfinite calibration must fail.');
    fprintf('PASS test_stage7a2_set_coverage\n');
end
