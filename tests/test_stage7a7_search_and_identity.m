function test_stage7a7_search_and_identity(root)
%TEST_STAGE7A7_SEARCH_AND_IDENTITY Budget semantics and calibration binding.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a7_config(base,'smoke','nominal');
    [pool,base_ix,~,catalog,groups]=stage7a7_candidate_space(base,cfg);
    bank=stage7a5_template_bank(pool,base,cfg);
    assert(bank.forward_calls==37*numel(cfg.main_scale_grid)* ...
        numel(cfg.load_scale_grid));
    s=stage7a5_generate_split(catalog,groups.reachable(1),base,cfg, ...
        1500000000,1,'unit',false);
    sigma=[0.03 1];
    a=stage7a7_score_observation(s.observed,pool,bank,base,cfg, ...
        base_ix,[1 2],sigma,5,[]);
    assert(a.search_truncated&&~a.pool_exhausted&& ...
        a.unvisited_count>0&&numel(a.candidate_ids)<=5);
    b=stage7a7_score_observation(s.observed,pool,bank,base,cfg, ...
        base_ix,[1 2],sigma,37,[]);
    assert(~b.search_truncated&&b.pool_exhausted&& ...
        b.unvisited_count==0&&numel(b.candidate_ids)==37&& ...
        b.profile_evaluations==37);
    assert(numel(unique(b.candidate_ids))==37);
    fake=struct('kind','C','budget',37,'bank_identity',bank.identity, ...
        'search_identity',bank.search_identity,'views',[1 2], ...
        'sigma',sigma,'condition_identity', ...
        stage7a7_condition_identity(cfg,bank,[1 2],sigma,'C37',37));
    bad=cfg;bad.condition='zin3';bad.zin_error_rms_ohm=3;
    caught=false;
    try
        stage7a7_score_observation(s.observed,pool,bank,base,bad, ...
            base_ix,[1 2],sigma,37,fake);
    catch ME
        caught=strcmp(ME.identifier,'stage7a7:CalibrationIdentityMismatch');
    end
    assert(caught,'Mismatched noise condition was not rejected.');
    fprintf('PASS test_stage7a7_search_and_identity\n');
end
