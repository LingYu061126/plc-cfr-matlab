function test_stage7a13_split(root)
%TEST_STAGE7A13_SPLIT Check graph/seed isolation and small-stratum fallback.
    if nargin<1||isempty(root)
        root=fileparts(fileparts(mfilename('fullpath')));
    end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a13_config(base,'smoke');
    [pool,~,~,~]=stage7a6_candidate_space(base);
    [~,~,~,catalog]=stage7a7_candidate_space(base, ...
        stage7a7_config(base,'formal','nominal'));
    ids={catalog.topology_id};
    cal=map(cfg.calibration_graph_ids,ids);
    test=map(cfg.test_ids,ids);
    cal_signatures=arrayfun(@(g)stage6b_network_signature(g.network), ...
        catalog(cal),'UniformOutput',false);
    test_signatures=arrayfun(@(g)stage6b_network_signature(g.network), ...
        catalog(test),'UniformOutput',false);
    assert(isempty(intersect(cal_signatures,test_signatures)), ...
        'stage7a13:StructureLeakage');
    assert(numel(unique([cfg.seed_cfr_E,cfg.seed_cfr_A, ...
        cfg.seed_cfr_F,cfg.seed_cfr_T,cfg.seed_lf_test]))==5, ...
        'stage7a13:SeedLeakage');
    assert(nnz(arrayfun(@(g)isempty(g.network.branches), ...
        catalog(1:17)))==1, ...
        'stage7a13:ZeroBranchGraphIdentity');
    assert(all(cellfun(@(id)~ismember(id,{pool.topology_id}), ...
        cfg.calibration_graph_ids)), ...
        'stage7a13:CalibrationGraphInInferenceBank');
    small=struct('topology_id',catalog(cal(1)).topology_id, ...
        'network',catalog(cal(1)).network);
    bank=stage7a4_template_bank(small,base,cfg);
    cfg.n_cfr_cal_per_graph=2;
    model=stage7a13_calibrate_h50(small,bank,base,cfg);
    assert(all([model.strata.fallback]) && ...
        model.strata(2).class_n==2 && ...
        model.strata(2).class_structures==1, ...
        'stage7a13:SmallStratumFallback');
    fprintf('PASS test_stage7a13_split: independent identities and fallback\n');
end

function ix=map(wanted,all)
    ix=zeros(1,numel(wanted));
    for k=1:numel(wanted)
        ix(k)=find(strcmp(all,wanted{k}),1);
        assert(~isempty(ix(k)),'stage7a13:MissingGraph');
    end
end
