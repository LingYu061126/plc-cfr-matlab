function result=exp_stage7a10_ports_off(root,run_id)
%EXP_STAGE7A10_PORTS_OFF Recalibrated adaptive CFR without internal node port.
%   H25/H100 are the only supplemental views. Uses independent A0/A1/F;
%   the formal T observations and seeds are paired with the full-port study.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(run_id),run_id='initial';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a10_config(base,'formal');
    if strcmp(run_id,'confirm1'),cfg.seed_T=900000000;end
    cfg.extra_view_indices=[3 7];
    [pool,~,~,catalog]=stage7a6_candidate_space(base);
    names={'G001','G002','G003','MIRROR_M3','ADD_M1_M3', ...
        'EXT_111','EXT_021','MID30'};
    truths=repmat(struct('topology_id','','network',struct()),1,8);
    for i=1:8
        j=find(strcmp({catalog.topology_id},names{i}),1);
        truths(i)=struct('topology_id',names{i},'network',catalog(j).network);
    end
    assert(numel(pool)==17,'stage7a10:PoolIdentity');
    bank=stage7a4_template_bank(truths(1:6),base,cfg);
    e=stage7a4_generate_split(truths,1:6,base,cfg,cfg.seed_E, ...
        cfg.n_E_per_topology,20,'standard');
    sigma=stage7a4_calibrate_view_scales(e,cfg);
    selector=stage7a10_view_selection(bank,sigma,cfg.extra_view_indices);
    a0=stage7a4_generate_split(truths,1:6,base,cfg,cfg.seed_A0, ...
        cfg.n_A0_per_topology,20,'standard');
    a1=stage7a4_generate_split(truths,1:6,base,cfg,cfg.seed_A1, ...
        cfg.n_A1_per_topology,20,'standard');
    f=stage7a4_generate_split(truths,1:6,base,cfg,cfg.seed_F, ...
        cfg.n_F_per_topology,20,'standard');
    libraries={1:3,1:6,[3 4]};lib_names={'original_three','expanded_six','diagnostic_pair'};
    models=cell(1,3);
    for q=1:3
        ix=libraries{q};a0q=a0(ismember([a0.truth_global_index],ix));
        a1q=a1(ismember([a1.truth_global_index],ix));
        fq=f(ismember([f.truth_global_index],ix));
        d0=matrix(a0q,bank,ix,5,sigma);first=zeros(1,numel(ix));
        for k=1:numel(ix)
            x=sort(d0([a0q.truth_global_index]==ix(k),k));
            rank=ceil((numel(x)+1)*(1-cfg.alpha));
            first(k)=x(rank);
        end
        ad=adaptive(a1q,bank,ix,sigma,selector,first);
        fd=adaptive(fq,bank,ix,sigma,selector,first);
        tr0=arrayfun(@(x)find(ix==x.truth_global_index,1),a0q);
        tr1=arrayfun(@(x)find(ix==x.truth_global_index,1),a1q);
        models{q}=stage7a10_calibrate(d0,tr0,ad,tr1,fd,bank,ix, ...
            sigma,selector,cfg);
    end
    test=stage7a4_generate_split(truths,1:8,base,cfg,cfg.seed_T, ...
        cfg.n_T_per_topology,20,'standard');
    rows=repmat(struct('library','','truth_id','','noise_seed',0, ...
        'selected_view',0,'state','','reason','','best_id','', ...
        'candidate_set','','set_size',0,'truth_in_library',false, ...
        'truth_in_set',false,'correct_unique',false,'false_unique',false),0,1);
    for i=1:numel(test)
        truth=truths(test(i).truth_global_index).topology_id;
        for q=1:3
            z=stage7a10_decide(test(i).observed,bank,models{q});
            in=ismember(truth,bank.candidate_ids(libraries{q}));
            r=struct('library',lib_names{q},'truth_id',truth, ...
                'noise_seed',test(i).noise_seed,'selected_view',z.selected_view, ...
                'state',z.decision_state,'reason',z.decision_reason, ...
                'best_id',z.best_candidate,'candidate_set',z.candidate_set, ...
                'set_size',z.candidate_set_size,'truth_in_library',in, ...
                'truth_in_set',in&&ismember(truth,strsplit(z.candidate_set,',')), ...
                'correct_unique',strcmp(z.decision_state,'UNIQUE_CONFIDENT')&& ...
                    strcmp(z.best_candidate,truth), ...
                'false_unique',strcmp(z.decision_state,'UNIQUE_CONFIDENT')&& ...
                    ~strcmp(z.best_candidate,truth));
            rows(end+1)=r; %#ok<AGROW>
        end
    end
    folder=fullfile(cfg.output_dir,'ports_off',run_id);
    assert(exist(folder,'dir')~=7,'stage7a10:ExistingPortRun');mkdir(folder);
    writetable(struct2table(rows),fullfile(folder,'samples.csv'));
    meta=struct('baseline_commit',cfg.verification_baseline_commit, ...
        'bank_identity',bank.identity,'extra_view_indices',mat2str(cfg.extra_view_indices), ...
        'E_seed',cfg.seed_E,'A0_seed',cfg.seed_A0,'A1_seed',cfg.seed_A1, ...
        'F_seed',cfg.seed_F,'T_seed',cfg.seed_T, ...
        'matlab_version',version,'parallel_workers',0);
    writetable(struct2table(meta),fullfile(folder,'metadata.csv'));
    result=struct('folder',folder,'rows',numel(rows));
    fprintf('Stage 7A.10 no-node-port: %d paired method rows.\n',numel(rows));
end
function d=matrix(samples,bank,ix,views,sigma)
    d=zeros(numel(samples),numel(ix));
    for i=1:numel(samples)
        p=stage7a4_profile_views(samples(i).observed,bank,ix,views,sigma);
        d(i,:)=p.distances;
    end
end
function d=adaptive(samples,bank,ix,sigma,selector,first)
    d=zeros(numel(samples),numel(ix));
    for i=1:numel(samples)
        p=stage7a10_adaptive_profile(samples(i).observed,bank,ix,sigma,selector,first);
        d(i,:)=p.distances;
    end
end
