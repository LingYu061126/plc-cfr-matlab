function test_stage7a9_result_integrity(root,mode,run_identity)
%TEST_STAGE7A9_RESULT_INTEGRITY Read-only A/B archive and resource checks.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='smoke';end
    folder=fullfile(root,'results','data','stage7a_9',mode);
    if nargin>=3,folder=fullfile(root,'results','data','stage7a_9',run_identity,mode);end
    files={'samples.csv','candidate_audit.csv','paired_comparison.csv', ...
        'summary.csv','calibration.csv','metadata.csv','config_snapshot.mat'};
    for k=1:numel(files),assert(isfile(fullfile(folder,files{k})));end
    opts={'TextType','string','Delimiter',','};
    s=readtable(fullfile(folder,'samples.csv'),opts{:});
    c=readtable(fullfile(folder,'candidate_audit.csv'),opts{:});
    p=readtable(fullfile(folder,'paired_comparison.csv'),opts{:});
    m=readtable(fullfile(folder,'metadata.csv'),opts{:});
    expected=11;if strcmp(mode,'formal'),expected=66;end
    assert(height(p)==expected&&height(s)==2*expected&& ...
        height(c)==2*expected*37);
    assert(all(p.equivalent)&all(p.candidate_ids_match)&all(p.rank_match)& ...
        all(p.set_match)&all(p.state_match)&all(p.reason_match)& ...
        all(p.distance_match)&all(p.grid_distance_match)& ...
        all(p.parameter_match)&all(p.fit_match)&all(p.holdout_match)& ...
        all(p.optimizer_evaluations_match));
    assert(all(s.candidate_count==37)&&all(s.forward_model_calls== ...
        s.optimizer_evaluations+1));
    a=s(s.method=="A",:);b=s(s.method=="B",:);
    assert(height(a)==expected&&height(b)==expected);
    assert(isequal(a.sample_id,b.sample_id));
    assert(all(b.spectrum_requests>b.spectrum_evaluations)& ...
        all(b.spectrum_hits==b.spectrum_requests-b.spectrum_evaluations));
    assert(all(b.frequency_point_requests>b.frequency_point_evaluations));
    assert(all(isnan(a.spectrum_requests))); % A did not expose per-candidate counts.
    assert(all(m.archived_calibration_match)& ...
        all(m.archived_baseline_samples_match));
    for i=1:expected
        for method=["A","B"]
            ix=c.sample_id==p.sample_id(i)&c.method==method;
            assert(sum(ix)==37&&numel(unique(c.candidate_id(ix)))==37);
            assert(isequal(sort(c.rank(ix)),(1:37).'));
        end
    end
    fprintf('PASS test_stage7a9_result_integrity %s: %d pairs, %d candidate rows\n', ...
        mode,expected,height(c));
end
