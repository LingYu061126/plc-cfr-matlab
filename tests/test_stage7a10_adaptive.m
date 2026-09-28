function test_stage7a10_adaptive(root)
%TEST_STAGE7A10_ADAPTIVE Verify truth-free selection and four-state safeguards.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a10_config(base,'smoke');
    [candidates,~,~]=stage7a4_fixed_topologies(base);
    bank=stage7a4_template_bank(candidates,base,cfg);
    sigma=ones(1,numel(cfg.view_names));
    selector=stage7a10_view_selection(bank,sigma,cfg.extra_view_indices);
    theta=struct('main_length_scale',1,'branch_length_scale',1, ...
        'branch_load_scale',1,'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
    [~,observed]=stage7a4_measure_views(candidates(3).network,theta,base, ...
        cfg,910000001,20,struct());
    p=stage7a10_adaptive_profile(observed,bank,1:3,sigma,selector,Inf(1,3));
    assert(ismember(p.selected_view,cfg.extra_view_indices)&& ...
        numel(p.distances)==3&&all(isfinite(p.distances)), ...
        'Adaptive selector failed to score all candidates.');
    forced_single=-Inf(1,3);forced_single(3)=Inf;
    p=stage7a10_adaptive_profile(observed,bank,1:3,sigma,selector,forced_single);
    assert(p.selected_view>0&&nnz(p.first_set)==1, ...
        'A singleton first-stage set must retain a comparison candidate.');
    a=[0.5 1 1;1 0.5 1;1 1 0.5;0.6 1 1;1 0.6 1;1 1 0.6];
    model=stage7a10_calibrate(a,[1;2;3;1;2;3],a,[1;2;3;1;2;3],a, ...
        bank,1:3,sigma,selector,cfg);
    model.first_threshold=Inf(1,3);model.class_threshold=Inf(1,3);
    model.fit_threshold=Inf;
    z=stage7a10_decide(observed,bank,model);
    assert(strcmp(z.decision_state,'MULTIPLE_AMBIGUOUS')&& ...
        z.candidate_set_size==3,'Multiple candidate safeguard failed.');
    model.first_threshold=-Inf(1,3);model.first_threshold(3)=Inf;
    z=stage7a10_decide(observed,bank,model);
    assert(z.candidate_set_size<=1, ...
        'Adaptive set must remain a subset of the first-stage H50 set.');
    model.first_threshold=-Inf(1,3);
    z=stage7a10_decide(observed,bank,model);
    assert(strcmp(z.decision_state,'REJECTED')&& ...
        strcmp(z.decision_reason,'empty_first_set')&& ...
        z.candidate_set_size==0&&all(isinf(z.all_distances)), ...
        'Empty first-stage set must reject.');
    bad=bank;bad.identity='different';
    try
        stage7a10_decide(observed,bad,model);
        error('stage7a10:ExpectedIdentityError');
    catch err
        assert(strcmp(err.identifier,'stage7a10:BankIdentity'), ...
            'Unexpected identity-check error.');
    end
    assert(numel(unique([cfg.seed_D cfg.seed_E cfg.seed_A0 cfg.seed_A1 ...
        cfg.seed_F cfg.seed_T cfg.seed_stress]))==7, ...
        'Split seed bases overlap.');
    fprintf('PASS test_stage7a10_adaptive: selection, ambiguity, rejection, identity\n');
end
