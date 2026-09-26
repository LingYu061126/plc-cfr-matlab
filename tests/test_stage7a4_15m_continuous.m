function test_stage7a4_15m_continuous(root)
%TEST_STAGE7A4_15M_CONTINUOUS Original mirror and shared-theta score checks.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a4_15m_continuous_config(base,'smoke');
    [all4,pair,original]=stage7a4_fixed_topologies(base);
    assert(isequal(pair,[3 4])&&isequal(original,1:3));
    assert(strcmp(all4(3).topology_id,'G003')&& ...
        strcmp(all4(4).topology_id,'MIRROR_M3'));
    assert(~ismember(stage6b_network_signature(all4(4).network), ...
        arrayfun(@(x)stage6b_network_signature(x.network), ...
        all4(original),'UniformOutput',false)));
    bank=stage7a4_template_bank(all4,base,cfg);
    theta=struct('main_length_scale',1.007,'branch_length_scale',1, ...
        'branch_load_scale',1.037,'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
    [clean,~]=stage7a4_measure_views(all4(3).network,theta,base,cfg, ...
        998100001,20);
    sigma=ones(1,numel(cfg.view_names));sigma([3 5 13 14])=0.01;
    p=stage7a4_15m_profile(clean,all4,bank,base,cfg,pair,[5 6],sigma,1);
    assert(all(p.continuous_distances<=p.grid_distances+1e-9));
    assert(p.continuous_distances(1)<p.grid_distances(1));
    assert(all(p.continuous_params(:)>=0.8-1e-8)&& ...
        all(p.continuous_params(:)<=1.2+1e-8));
    q=stage7a4_15m_profile(clean,all4,bank,base,cfg,pair,[13 14],sigma,3);
    assert(all(q.continuous_distances<=q.grid_distances+1e-9));
    assert(all(isfinite(q.continuous_distances)));
    legacy=topology_candidates(base);
    ix3=find(strcmp({legacy.id},'T3'),1);
    ix5=find(strcmp({legacy.id},'T5'),1);
    controls=repmat(struct('topology_id','','network',struct()),1,2);
    controls(1).topology_id='T3';controls(1).network=legacy(ix3).network;
    controls(2).topology_id='T5';controls(2).network=legacy(ix5).network;
    cb=stage7a4_template_bank(controls,base,cfg);
    theta.main_length_scale=1;theta.branch_load_scale=1;
    [yc,~]=stage7a4_measure_views(controls(1).network,theta,base,cfg, ...
        998100002,20);
    cp=stage7a4_15m_profile(yc,controls,cb,base,cfg,1:2,5,sigma,1);
    assert(abs(diff(cp.continuous_distances))<1e-8, ...
        'Numerically equivalent original CFR control was forced apart.');
    fprintf('PASS test_stage7a4_15m_continuous: 15m identity and bounded shared-parameter fits\n');
end
