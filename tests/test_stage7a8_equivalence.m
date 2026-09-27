function test_stage7a8_equivalence(root)
%TEST_STAGE7A8_EQUIVALENCE Paired full-pool score and decision smoke check.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a7_config(base,'smoke','nominal');
    audit_cfg=stage7a8_config(base,'smoke');
    assert(strcmp(audit_cfg.version,cfg.version)&& ...
        isequal(audit_cfg.frequency_hz,cfg.frequency_hz)&& ...
        isequal(audit_cfg.frequency_train_indices,cfg.frequency_train_indices));
    [pool,base_ix,~,catalog,groups]=stage7a7_candidate_space(base,cfg);
    bank=stage7a5_template_bank(pool,base,cfg);
    sigma=[0.03 1];views=[1 2];budget=numel(pool);
    model=stage7a5_calibrate_split([0;0.1],[1;2],bank,cfg, ...
        1:budget,views,sigma,'C',budget);
    model.condition_identity=stage7a7_condition_identity( ...
        cfg,bank,views,sigma,'C37',budget);
    theta=struct('main_length_scale',1.03,'branch_length_scale',1, ...
        'branch_load_scale',1.07,'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
    for k=[1 numel(pool)]
        full=stage7a4_forward_state(pool(k).network,theta,base, ...
            cfg.frequency_hz,cfg.state_50);
        for ix={cfg.frequency_train_indices,cfg.frequency_holdout_indices}
            keep=ix{1};sliced=stage7a4_forward_state( ...
                pool(k).network,theta,base,cfg.frequency_hz(keep),cfg.state_50);
            assert(max(abs(full.H_endpoint(keep)-sliced.H_endpoint))<=1e-12);
            assert(max(abs(full.Zin(keep)-sliced.Zin))<=1e-10);
        end
    end
    sets={groups.inlib(1),groups.old_out(1),groups.reachable(1)};
    for i=1:numel(sets)
        s=stage7a5_generate_split(catalog,sets{i},base,cfg, ...
            1700000000+i*10000,1,'unit',false);
        a=stage7a7_score_observation(s.observed,pool,bank,base,cfg, ...
            base_ix,views,sigma,budget,model);
        b=stage7a8_score_observation(s.observed,pool,bank,base,cfg, ...
            base_ix,views,sigma,model);
        assert(isequal(a.candidate_ids,b.candidate_ids));
        assert(all(abs(a.distances-b.distances)<= ...
            1e-9+1e-10*abs(a.distances)));
        assert(all(abs(a.params(:)-b.params(:))<=1e-6));
        assert(abs(a.fit_statistic-b.fit_statistic)<= ...
            1e-9+1e-10*abs(a.fit_statistic));
        da=stage7a5_decide(a,model,bank);db=stage7a5_decide(b,model,bank);
        assert(isequal(da.candidate_set,db.candidate_set)&& ...
            strcmp(da.decision_state,db.decision_state)&& ...
            strcmp(da.best_candidate,db.best_candidate));
    end
    bad=model;bad.condition_identity='wrong';caught=false;
    try
        stage7a8_score_observation(s.observed,pool,bank,base,cfg, ...
            base_ix,views,sigma,bad);
    catch ME
        caught=strcmp(ME.identifier,'stage7a8:CalibrationIdentityMismatch');
    end
    assert(caught,'Mismatched calibrated model was accepted.');
    fprintf('PASS test_stage7a8_equivalence (3 pairs, complex H/Z slices)\n');
end
