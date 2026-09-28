function out=exp_stage7a10_controls(root,run_id)
%EXP_STAGE7A10_CONTROLS Separate T3/T5/close synthetic non-unique controls.
%   Control seeds are disjoint from the main experiment. Truth labels remain
%   in this experiment and never enter the decision API.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(run_id),run_id='initial';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a10_config(base,'formal');
    cfg.seed_E=870000000;cfg.seed_A0=875000000;
    cfg.seed_A1=880000000;cfg.seed_F=885000000;cfg.seed_T=890000000;
    if strcmp(run_id,'confirm1'),cfg.seed_T=920000000;end
    old=topology_candidates(base);names={'T3','T5','T4'};
    control=repmat(struct('topology_id','','network',struct()),1,3);
    for k=1:3
        j=find(strcmp({old.id},names{k}),1);
        control(k)=struct('topology_id',names{k},'network',old(j).network);
    end
    control(3).topology_id='T4_NEAR_T3';
    control(3).network.branches(1).length=1e-6;
    control(3).network.branches(1).load=1e12;
    bank=stage7a4_template_bank(control,base,cfg);
    e=stage7a4_generate_split(control,1:3,base,cfg,cfg.seed_E, ...
        cfg.n_E_per_topology,20,'standard');
    sigma=stage7a4_calibrate_view_scales(e,cfg);
    selector=stage7a10_view_selection(bank,sigma,cfg.extra_view_indices);
    a0=stage7a4_generate_split(control,1:3,base,cfg,cfg.seed_A0, ...
        cfg.n_A0_per_topology,20,'standard');
    a1=stage7a4_generate_split(control,1:3,base,cfg,cfg.seed_A1, ...
        cfg.n_A1_per_topology,20,'standard');
    f=stage7a4_generate_split(control,1:3,base,cfg,cfg.seed_F, ...
        cfg.n_F_per_topology,20,'standard');
    ix=1:3;a0d=matrix(a0,bank,ix,5,sigma);
    first=zeros(1,3);
    for k=1:3
        x=sort(a0d([a0.truth_global_index]==k,k));
        r=ceil((numel(x)+1)*(1-cfg.alpha));first(k)=x(r);
    end
    ad=adaptive(a1,bank,ix,sigma,selector,first);
    fd=adaptive(f,bank,ix,sigma,selector,first);
    model=stage7a10_calibrate(a0d,[a0.truth_global_index].', ...
        ad,[a1.truth_global_index].',fd,bank,ix,sigma,selector,cfg);
    t=stage7a4_generate_split(control,1:3,base,cfg,cfg.seed_T,30,20,'standard');
    rows=repmat(struct('truth_id','','best_id','','state','','reason','', ...
        'candidate_set','','set_size',0,'selected_view',0, ...
        'false_unique',false,'noise_seed',0),numel(t),1);
    for i=1:numel(t)
        z=stage7a10_decide(t(i).observed,bank,model);
        truth=control(t(i).truth_global_index).topology_id;
        rows(i)=struct('truth_id',truth,'best_id',z.best_candidate, ...
            'state',z.decision_state,'reason',z.decision_reason, ...
            'candidate_set',z.candidate_set,'set_size',z.candidate_set_size, ...
            'selected_view',z.selected_view, ...
            'false_unique',strcmp(z.decision_state,'UNIQUE_CONFIDENT')&& ...
                ~strcmp(z.best_candidate,truth), ...
            'noise_seed',t(i).noise_seed);
    end
    pair_rows=repmat(struct('first_id','','second_id','', ...
        'view_index',0,'separation',NaN),0,1);
    for i=1:2
        for j=i+1:3
            for v=1:numel(selector.extra_views)
                pair_rows(end+1)=struct('first_id',control(i).topology_id, ...
                    'second_id',control(j).topology_id, ...
                    'view_index',selector.extra_views(v), ...
                    'separation',selector.separation(i,j,v)); %#ok<AGROW>
            end
        end
    end
    folder=fullfile(cfg.output_dir,'controls',run_id);
    assert(exist(folder,'dir')~=7,'stage7a10:ExistingControlRun');mkdir(folder);
    writetable(struct2table(rows),fullfile(folder,'samples.csv'));
    writetable(struct2table(pair_rows),fullfile(folder,'separation.csv'));
    meta=struct('baseline_commit',cfg.verification_baseline_commit, ...
        'bank_identity',bank.identity,'calibration_identity',model.identity, ...
        'E_seed',cfg.seed_E,'A0_seed',cfg.seed_A0,'A1_seed',cfg.seed_A1, ...
        'F_seed',cfg.seed_F,'T_seed',cfg.seed_T,'matlab_version',version);
    writetable(struct2table(meta),fullfile(folder,'metadata.csv'));
    out=struct('folder',folder,'false_unique',nnz([rows.false_unique]), ...
        'unique',nnz(strcmp({rows.state},'UNIQUE_CONFIDENT')), ...
        'ambiguous',nnz(strcmp({rows.state},'MULTIPLE_AMBIGUOUS')));
    fprintf('Stage 7A.10 controls: %d observations, %d false unique, %d ambiguous.\n', ...
        numel(rows),out.false_unique,out.ambiguous);
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
