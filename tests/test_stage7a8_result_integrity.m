function test_stage7a8_result_integrity(root,mode)
%TEST_STAGE7A8_RESULT_INTEGRITY Read-only audit of paired result artifacts.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    dir=fullfile(root,'results','data','stage7a_8',mode);
    required={'samples.csv','candidate_audit.csv','paired_comparison.csv', ...
        'summary.csv','calibration.csv','metadata.csv','config_snapshot.mat'};
    for i=1:numel(required)
        assert(exist(fullfile(dir,required{i}),'file')==2, ...
            'stage7a8:MissingResult','Missing %s',required{i});
    end
    s=readtable(fullfile(dir,'samples.csv'),'TextType','string');
    c=readtable(fullfile(dir,'candidate_audit.csv'), ...
        'TextType','string','Delimiter',',');
    p=readtable(fullfile(dir,'paired_comparison.csv'),'TextType','string');
    m=readtable(fullfile(dir,'metadata.csv'),'TextType','string');
    if strcmp(mode,'formal'),n=66;else,n=11;end
    assert(height(s)==2*n&&height(c)==2*n*37&&height(p)==n);
    assert(all(p.equivalent)&&all(p.rank_match)&&all(p.set_match)&& ...
        all(p.state_match)&&all(p.distance_match)&&all(p.parameter_match));
    assert(all(s.candidate_count==37)&&all(s.optimizer_evaluations>0));
    assert(all(c.rank>=1&c.rank<=37));
    assert(height(unique(s(:,{'sample_id','method'})))==2*n);
    assert(all(strcmp(m.baseline_commit, ...
        '31082ad056dac7dbc8a8f74f9c8453cc39a258f5')));
    assert(m.worker_count==0&&~m.use_parallel&&m.template_forward_calls==1665);
    if strcmp(mode,'formal')
        assert(m.archived_calibration_match&&m.archived_baseline_samples_match);
    end
    fprintf('PASS test_stage7a8_result_integrity %s (%d pairs)\n',mode,n);
end
