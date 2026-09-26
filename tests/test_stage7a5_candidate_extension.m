function test_stage7a5_candidate_extension(root)
%TEST_STAGE7A5_CANDIDATE_EXTENSION Grammar, identity, search and state checks.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a5_config(base,'smoke');
    [pool,base_ix]=stage7a5_candidate_pool(base);
    assert(numel(pool)==10&&numel(base_ix)==3);
    ids={pool.topology_id};
    assert(isequal(sort(ids),sort({'G001','G002','G003','MIRROR_M3', ...
        'ADD_M1_M2','ADD_M1_M3','ADD_M2_M3','DOUBLE_M1','DOUBLE_M2','DOUBLE_M3'})));
    sigs=arrayfun(@(x)stage6b_network_signature(x.network),pool,'UniformOutput',false);
    assert(numel(unique(sigs))==10);
    m3=find(strcmp(ids,'MIRROR_M3'),1);g3=find(strcmp(ids,'G003'),1);
    assert(ismember(m3,stage7a5_graph_edit_neighbors(pool,g3)), ...
        'Moving the G003 branch to M3 must be a one-edit neighbor.');
    assert(numel(cfg.frequency_train_indices)==41&&numel(cfg.frequency_holdout_indices)==20);
    bank=stage7a5_template_bank(pool,base,cfg);
    assert(bank.forward_calls==450&&bank.candidate_count==10);
    sample=stage7a5_generate_split(pool,m3,base,cfg,100100001,1,'unit',false);
    sigma=[0.01 1];
    p=stage7a5_profile(sample.observed,pool,bank,base,cfg,base_ix,1,sigma, ...
        cfg.frequency_train_indices,true);
    assert(all(p.distances<=p.grid_distances+1e-9));
    q=stage7a5_expand_candidates(sample.observed,pool,bank,base,cfg, ...
        base_ix,1,sigma,cfg.frequency_train_indices,10);
    assert(any(strcmp(q.active_ids,'MIRROR_M3'))&& ...
        any(strcmp(q.generated_ids,'MIRROR_M3')), ...
        'The generic branch-move search did not generate M3.');
    bad=cfg;bad.main_scale_bounds=[0.8 1.2];caught=false;
    try
        stage7a5_profile(sample.observed,pool,bank,base,bad,base_ix,1,sigma, ...
            cfg.frequency_train_indices,false);
    catch ME
        caught=strcmp(ME.identifier,'stage7a5:SearchIdentityMismatch');
    end
    assert(caught,'Search/cache identity mismatch was not rejected.');

    model=struct('kind','split','candidate_ids',{bank.candidate_ids(base_ix)}, ...
        'views',1,'fit_threshold',1,'set_threshold',0.05, ...
        'margin_threshold',0.1,'bank_identity',bank.identity, ...
        'search_identity',bank.search_identity);
    scored=synthetic_score(bank.candidate_ids(base_ix),[0 0.2 0.5],0.1,false,1);
    z=stage7a5_decide(scored,model,bank);
    assert(strcmp(z.decision_state,'UNIQUE_CONFIDENT'));
    scored=synthetic_score(bank.candidate_ids(base_ix),[0 0.01 0.5],0.1,false,1);
    z=stage7a5_decide(scored,model,bank);
    assert(strcmp(z.decision_state,'MULTIPLE_AMBIGUOUS'));
    scored=synthetic_score(bank.candidate_ids(base_ix),[0 0.05 0.5],0.1,false,1);
    model.set_threshold=0;
    z=stage7a5_decide(scored,model,bank);
    assert(strcmp(z.decision_state,'LOW_CONFIDENCE'));
    scored=synthetic_score(bank.candidate_ids(base_ix),[0 0.2 0.5],1.1,false,1);
    z=stage7a5_decide(scored,model,bank);
    assert(strcmp(z.decision_state,'REJECTED'));
    control_rows=stage7a5_nonunique_controls(base,cfg);
    h=strcmp({control_rows.scheme},'H50');
    nonunique=ismember({control_rows.truth_id},{'T3','T4_NEAR_T3','T5'});
    assert(~any(strcmp({control_rows(h&nonunique).state},'UNIQUE_CONFIDENT')));
    fprintf('PASS test_stage7a5_candidate_extension\n');
end

function s=synthetic_score(ids,d,fit,truncated,view)
    s=struct('candidate_indices',1:numel(ids),'candidate_ids',{ids}, ...
        'distances',d,'params',zeros(numel(ids),2),'grid_distances',d, ...
        'optimizer_evaluations',0,'fit_statistic',fit,'holdout_statistic',fit, ...
        'search_truncated',truncated,'generated_ids',{{}}, ...
        'profile_candidate_count',numel(ids),'views',view, ...
        'forward_model_calls_search',0,'forward_model_calls_holdout',0);
end
