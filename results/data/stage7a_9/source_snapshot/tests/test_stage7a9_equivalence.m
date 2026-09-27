function test_stage7a9_equivalence(root)
%TEST_STAGE7A9_EQUIVALENCE Complex-view and C37 decision paired checks.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a9_config(base,'smoke');
    [pool,base_ix,~,catalog,groups]=stage7a7_candidate_space(base,cfg);
    bank=stage7a5_template_bank(pool,base,cfg);
    empty=pool(1).network;empty.branches=empty.branches([]);
    networks={empty,pool(end).network};
    settings=[0.97 0.85;1.06 1.18];
    max_h=0;max_z=0;requests=0;calculations=0;
    for k=1:numel(networks)
        for p=1:size(settings,1)
            theta=struct('main_length_scale',settings(p,1), ...
                'branch_length_scale',1,'branch_load_scale',settings(p,2), ...
                'first_segment_scale',1,'source_impedance_ohm',50, ...
                'receiver_impedance_ohm',50);
            for ix={cfg.frequency_train_indices,cfg.frequency_holdout_indices}
                f=cfg.frequency_hz(ix{1});
                a=stage7a4_forward_state(networks{k},theta,base,f,cfg.state_50);
                b=stage7a9_forward_state(networks{k},theta,base,f,cfg.state_50);
                max_h=max(max_h,max(abs(a.H_endpoint-b.H_endpoint)));
                max_z=max(max_z,max(abs(a.Zin-b.Zin)));
                assert(b.spectrum_evaluations<=b.spectrum_requests);
                requests=requests+b.spectrum_requests;
                calculations=calculations+b.spectrum_evaluations;
            end
        end
    end
    assert(max_h<=1e-12&&max_z<=1e-10, ...
        'stage7a9:ComplexViewMismatch');
    assert(calculations<requests,'stage7a9:NoCacheHits');
    sigma=[0.03 1];views=[1 2];budget=numel(pool);
    model=stage7a5_calibrate_split([0;0.1],[1;2],bank,cfg, ...
        1:budget,views,sigma,'C',budget);
    model.condition_identity=stage7a7_condition_identity( ...
        cfg,bank,views,sigma,'C37',budget);
    sets={groups.inlib(1),groups.old_out(1),groups.reachable(1)};
    for i=1:numel(sets)
        s=stage7a5_generate_split(catalog,sets{i},base,cfg, ...
            1900000000+i*10000,1,'unit',false);
        a=stage7a8_score_observation(s.observed,pool,bank,base,cfg, ...
            base_ix,views,sigma,model);
        b=stage7a9_score_observation(s.observed,pool,bank,base,cfg, ...
            base_ix,views,sigma,model);
        assert(isequal(a.candidate_ids,b.candidate_ids));
        assert(all(abs(a.distances-b.distances)<=1e-9+1e-10*abs(a.distances)));
        assert(all(abs(a.params(:)-b.params(:))<=1e-6));
        assert(abs(a.fit_statistic-b.fit_statistic)<= ...
            1e-9+1e-10*abs(a.fit_statistic));
        assert(a.optimizer_evaluations==b.optimizer_evaluations);
        da=stage7a5_decide(a,model,bank);db=stage7a5_decide(b,model,bank);
        assert(isequal(da.candidate_set,db.candidate_set)&& ...
            strcmp(da.decision_state,db.decision_state)&& ...
            strcmp(da.decision_reason,db.decision_reason));
    end
    fprintf('PASS test_stage7a9_equivalence: H %.3g, Zin %.3g ohm, %d/%d spectra, 3 C37 pairs\n', ...
        max_h,max_z,calculations,requests);
end
