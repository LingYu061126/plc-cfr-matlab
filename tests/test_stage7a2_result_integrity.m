function test_stage7a2_result_integrity(root)
%TEST_STAGE7A2_RESULT_INTEGRITY Check archived formal rows against summaries.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    p=fullfile(root,'results','data','stage7a_2','formal');
    samples=readtable(fullfile(p,'stage7a2_samples.csv'),'TextType','string');
    summary=readtable(fullfile(p,'stage7a2_group_summary.csv'),'TextType','string');
    curves=readtable(fullfile(p,'stage7a2_coverage_size_curve.csv'),'TextType','string');
    risks=readtable(fullfile(p,'stage7a2_risk_certification.csv'),'TextType','string');
    seeds=readtable(fullfile(p,'stage7a2_split_seeds.csv'),'TextType','string');
    assert(isequal(sort(unique(samples.candidate_count)),[3;7;23]));
    assert(height(seeds)==numel(unique(seeds.seed)), ...
        'Development, calibration, risk and test seeds must be disjoint.');
    assert(~any(isfinite(seeds.truth_candidate_index(seeds.split=="T_library_out"))), ...
        'Library-out truth must not be present in the evaluated library.');
    all_rows=summary(summary.stratum=="all",:);
    for k=1:height(all_rows)
        r=all_rows(k,:);ix=samples.library==r.library & ...
            samples.scenario==r.scenario & samples.method==r.method;
        g=samples(ix,:);assert(height(g)==r.n);
        assert(nnz(g.truth_in_candidate_set)==r.truth_set_covered_k);
        assert(nnz(g.false_unique)==r.wrong_unique_k);
        assert(nnz(g.correct_unique)==r.correct_unique_k);
        assert(nnz(g.decision_state=="UNIQUE_CONFIDENT")==r.unique_k);
        assert(nnz(g.candidate_set_size==0)==r.empty_k);
        assert(nnz(g.candidate_set_size==1)==r.singleton_k);
        assert(nnz(g.candidate_set_size>1)==r.multiple_k);
        assert(abs(mean(g.candidate_set_size)-r.mean_set_size)<1e-10);
        if r.scenario=="library_out",assert(~any(g.truth_in_library));end
        if r.scenario=="in_domain",assert(all(g.truth_in_library));end
    end
    for k=1:height(risks)
        x=risks(k,:);
        if x.method=="M2_class_conditional",target="M2R_class_risk_gated";
        else,target="M3R_pooled_risk_gated";end
        if ~x.certified
            ix=summary.library==x.library & summary.method==target & ...
                summary.stratum=="all";
            assert(all(summary.unique_k(ix)==0), ...
                'Uncertified risk gate emitted a unique result.');
        end
    end
    for k=1:height(curves)
        if abs(curves.alpha(k)-0.05)>eps,continue;end
        ix=all_rows.library==curves.library(k) & all_rows.method==curves.method(k) & ...
            all_rows.scenario=="in_domain";
        assert(nnz(ix)==1&&all_rows.truth_set_covered_k(ix)==curves.covered(k) && ...
            abs(all_rows.mean_set_size(ix)-curves.mean_set_size(k))<1e-10);
    end
    fprintf('PASS test_stage7a2_result_integrity: %d sample-method rows, %d summaries.\n', ...
        height(samples),height(all_rows));
end
