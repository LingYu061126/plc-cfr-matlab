function result=exp_stage7a10_study(root,mode,run_id)
%EXP_STAGE7A10_STUDY Disjoint E/A0/A1/F/T synthetic CFR study.
%   Truth indices and generating theta stay here, never inside decision APIs.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='smoke';end
    if nargin<3||isempty(run_id),run_id='initial';end
    assert(~isempty(regexp(run_id,'^[A-Za-z0-9_]+$','once')),'stage7a10:RunId');
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a10_config(base,mode);
    if strcmp(run_id,'confirm1')
        cfg.seed_T=900000000;cfg.seed_stress=910000000;
    end
    out=fullfile(cfg.output_dir,run_id);
    assert(exist(out,'dir')~=7,'stage7a10:ExistingRun', ...
        'Run directory already exists: %s',out);
    t_all=tic;[candidates,truths,library]=topologies(base);
    bank=stage7a4_template_bank(candidates,base,cfg);
    [e,~]=stage7a4_generate_split(truths,1:numel(candidates),base,cfg, ...
        cfg.seed_E,cfg.n_E_per_topology,20,'standard');
    sigma=stage7a4_calibrate_view_scales(e,cfg);
    selector=stage7a10_view_selection(bank,sigma,cfg.extra_view_indices);
    [a0,~]=stage7a4_generate_split(truths,1:numel(candidates),base,cfg, ...
        cfg.seed_A0,cfg.n_A0_per_topology,20,'standard');
    [a1,~]=stage7a4_generate_split(truths,1:numel(candidates),base,cfg, ...
        cfg.seed_A1,cfg.n_A1_per_topology,20,'standard');
    [f,~]=stage7a4_generate_split(truths,1:numel(candidates),base,cfg, ...
        cfg.seed_F,cfg.n_F_per_topology,20,'standard');
    methods=struct('name',{'A_H50','B_H50_H200','C_M2_node', ...
        'C_M2_simple_joint','D_adaptive','E_H50_Zin50'}, ...
        'views',{5,[5 9],14,[13 14],[],[5 6]});
    libraries={'original_three','expanded_six','diagnostic_pair'};
    models=cell(numel(methods),numel(library));firsts=cell(1,numel(library));
    for q=1:numel(library)
        ix=library{q};am=ismember([a0.truth_global_index],ix);
        firsts{q}=first_threshold(a0(am),ix,bank,sigma,cfg.alpha);
        for m=1:numel(methods)
            aa=a1(ismember([a1.truth_global_index],ix));
            ff=f(ismember([f.truth_global_index],ix));
            local_truth=arrayfun(@(x)find(ix==x.truth_global_index,1),aa);
            if strcmp(methods(m).name,'D_adaptive')
                a0h=distance_matrix(a0(am),bank,ix,5,sigma);
                ad=adaptive_matrix(aa,bank,ix,sigma,selector,firsts{q});
                fd=adaptive_matrix(ff,bank,ix,sigma,selector,firsts{q});
                tr0=arrayfun(@(x)find(ix==x.truth_global_index,1),a0(am));
                models{m,q}=stage7a10_calibrate(a0h,tr0,ad,local_truth,fd, ...
                    bank,ix,sigma,selector,cfg);
            else
                ad=distance_matrix(aa,bank,ix,methods(m).views,sigma);
                fd=distance_matrix(ff,bank,ix,methods(m).views,sigma);
                models{m,q}=stage7a4_calibrate_decision(ad,local_truth,fd,bank, ...
                    ix,methods(m).views,sigma,cfg, ...
                    [libraries{q} '_' methods(m).name]);
            end
        end
    end
    cal_time=toc(t_all);
    calibration_rows=repmat(struct('method','','library','','bank_identity','', ...
        'calibration_identity','','class_thresholds','','fit_threshold',NaN, ...
        'first_thresholds','','A0_seed',0,'A1_seed',0,'F_seed',0),0,1);
    for q=1:numel(library)
        for m=1:numel(methods)
            model=models{m,q};first='';
            if strcmp(methods(m).name,'D_adaptive'),first=mat2str(firsts{q},16);end
            if isfield(model,'identity')
                ident=model.identity;
            else
                ident=model.calibration_identity;
            end
            calibration_rows(end+1)=struct('method',methods(m).name, ...
                'library',libraries{q},'bank_identity',bank.identity, ...
                'calibration_identity',ident, ...
                'class_thresholds',mat2str(model.class_threshold,16), ...
                'fit_threshold',model.fit_threshold, ...
                'first_thresholds',first,'A0_seed',cfg.seed_A0, ...
                'A1_seed',cfg.seed_A1,'F_seed',cfg.seed_F); %#ok<AGROW>
        end
    end
    scenarios={'T20','T10','T_node_port_error','T_termination_error', ...
        'T_load_drift'};
    conditions={'standard','standard','node_port_error', ...
        'termination_error','load_drift'};
    rows=repmat(sample_row(),0,1);
    for s=1:numel(scenarios)
        n=cfg.n_stress_per_topology;snr=20;
        if s==1,n=cfg.n_T_per_topology;end
        if s==2,snr=10;end
        seed=cfg.seed_T;if s>1,seed=cfg.seed_stress+(s-2)*1000000;end
        [samples,~]=stage7a4_generate_split(truths,1:numel(truths),base,cfg, ...
            seed,n,snr,conditions{s});
        for i=1:numel(samples)
            for q=1:numel(library)
                ix=library{q};
                for m=1:numel(methods)
                    zt=tic;
                    if strcmp(methods(m).name,'D_adaptive')
                        z=stage7a10_decide(samples(i).observed,bank,models{m,q});
                        selected=z.selected_view;
                    else
                        z=stage7a4_decide(samples(i).observed,bank,models{m,q});
                        selected=0;
                    end
                    rr=sample_row();rr.scenario=scenarios{s};rr.method=methods(m).name;
                    rr.library=libraries{q};rr.truth_id=truths(samples(i).truth_global_index).topology_id;
                    rr.truth_signature=stage6b_network_signature( ...
                        truths(samples(i).truth_global_index).network);
                    rr.truth_in_library=ismember(rr.truth_id,bank.candidate_ids(ix));
                    rr.parameter_seed=samples(i).parameter_seed;
                    rr.noise_seed=samples(i).noise_seed;rr.snr_db=snr;
                    rr.true_main_scale=samples(i).theta.main_length_scale;
                    rr.true_branch_load_scale=samples(i).theta.branch_load_scale;
                    mods=samples(i).modifiers;
                    if isfield(mods,'node_port_error_fraction')
                        rr.node_port_error_fraction=mods.node_port_error_fraction;
                    end
                    if isfield(mods,'second_termination_error_fraction')
                        rr.termination_error_fraction=mods.second_termination_error_fraction;
                    end
                    if isfield(mods,'second_branch_load_drift_fraction')
                        rr.load_drift_fraction=mods.second_branch_load_drift_fraction;
                    end
                    rr.condition=conditions{s};rr.selected_view=selected;
                    rr.best_candidate=z.best_candidate;rr.candidate_set=z.candidate_set;
                    rr.candidate_set_size=z.candidate_set_size;
                    rr.decision_state=z.decision_state;rr.decision_reason=z.decision_reason;
                    rr.truth_in_set=rr.truth_in_library&& ...
                        ismember(rr.truth_id,strsplit(z.candidate_set,','));
                    rr.correct_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT')&& ...
                        strcmp(z.best_candidate,rr.truth_id);
                    rr.false_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT')&& ...
                        ~rr.correct_unique;
                    rr.distance=z.distance;rr.second_distance=z.second_distance;
                    rr.margin=z.margin;rr.fit_threshold=z.fit_threshold;
                    rr.distances=mat2str(z.all_distances,16);rr.wall_s=toc(zt);
                    rows(end+1)=rr; %#ok<AGROW>
                end
            end
        end
        fprintf('Stage 7A.10 %s %s: %d observations scored.\n', ...
            mode,scenarios{s},numel(samples));
    end
    summary=summarize(rows);total_s=toc(t_all);
    mkdir(out);
    writetable(struct2table(rows),fullfile(out,'samples.csv'));
    writetable(struct2table(summary),fullfile(out,'summary.csv'));
    writetable(struct2table(calibration_rows),fullfile(out,'calibration.csv'));
    selection_rows=repmat(struct('first_candidate','','second_candidate','', ...
        'extra_view','','view_index',0,'min_profile_separation',NaN),0,1);
    for i=1:numel(candidates)-1
        for j=i+1:numel(candidates)
            for v=1:numel(selector.extra_views)
                selection_rows(end+1)=struct( ...
                    'first_candidate',bank.candidate_ids{i}, ...
                    'second_candidate',bank.candidate_ids{j}, ...
                    'extra_view',cfg.view_names{selector.extra_views(v)}, ...
                    'view_index',selector.extra_views(v), ...
                    'min_profile_separation',selector.separation(i,j,v)); %#ok<AGROW>
            end
        end
    end
    writetable(struct2table(selection_rows),fullfile(out,'view_selection.csv'));
    catalog=repmat(struct('id','','signature','','in_original_three',false, ...
        'in_expanded_six',false),numel(truths),1);
    for i=1:numel(truths)
        catalog(i)=struct('id',truths(i).topology_id, ...
            'signature',stage6b_network_signature(truths(i).network), ...
            'in_original_three',i<=3,'in_expanded_six',i<=6);
    end
    writetable(struct2table(catalog),fullfile(out,'topologies.csv'));
    metadata=struct('stage','Stage 7A.10','mode',mode,'run_id',run_id, ...
        'baseline_commit',cfg.verification_baseline_commit, ...
        'matlab_version',version,'architecture',computer('arch'), ...
        'parallel_workers',0,'bank_identity',bank.identity, ...
        'template_bytes',bank.logical_cache_bytes, ...
        'template_forward_calls',bank.forward_calls, ...
        'observation_forward_calls',numel(cfg.states)* ...
            (6*(cfg.n_E_per_topology+cfg.n_A0_per_topology+ ...
            cfg.n_A1_per_topology+cfg.n_F_per_topology)+ ...
            8*(cfg.n_T_per_topology+4*cfg.n_stress_per_topology)), ...
        'calibration_wall_s',cal_time,'total_wall_s',total_s, ...
        'D_seed',cfg.seed_D,'E_seed',cfg.seed_E,'A0_seed',cfg.seed_A0, ...
        'A1_seed',cfg.seed_A1,'F_seed',cfg.seed_F,'T_seed',cfg.seed_T, ...
        'stress_seed',cfg.seed_stress);
    writetable(struct2table(metadata),fullfile(out,'metadata.csv'));
    save(fullfile(out,'config_snapshot.mat'),'cfg','metadata','sigma', ...
        'selector','methods','models','library');
    result=struct('output_dir',out,'metadata',metadata,'summary',summary);
end

function [candidates,truths,library]=topologies(base)
    [pool,~,~,catalog]=stage7a6_candidate_space(base);
    names={'G001','G002','G003','MIRROR_M3','ADD_M1_M3','EXT_111'};
    wanted=[names,{'EXT_021','MID30'}];
    truths=repmat(struct('topology_id','','network',struct()),1,numel(wanted));
    ids={catalog.topology_id};
    for i=1:numel(wanted)
        j=find(strcmp(ids,wanted{i}),1);assert(~isempty(j),'stage7a10:MissingGraph');
        truths(i)=struct('topology_id',wanted{i},'network',catalog(j).network);
    end
    candidates=truths(1:6);library={1:3,1:6,[3 4]};
    sigs=arrayfun(@(x)stage6b_network_signature(x.network),truths,'UniformOutput',false);
    assert(numel(unique(sigs))==numel(sigs)&&numel(pool)==17,'stage7a10:GraphIdentity');
end

function first=first_threshold(samples,ix,bank,sigma,alpha)
    d=distance_matrix(samples,bank,ix,5,sigma);first=zeros(1,numel(ix));
    for k=1:numel(ix)
        x=sort(d([samples.truth_global_index]==ix(k),k));
        rank=ceil((numel(x)+1)*(1-alpha));
        if rank>numel(x),first(k)=Inf;else,first(k)=x(rank);end
    end
end
function d=distance_matrix(samples,bank,ix,views,sigma)
    d=zeros(numel(samples),numel(ix));
    for i=1:numel(samples)
        p=stage7a4_profile_views(samples(i).observed,bank,ix,views,sigma);
        d(i,:)=p.distances;
    end
end
function d=adaptive_matrix(samples,bank,ix,sigma,selector,first)
    d=zeros(numel(samples),numel(ix));
    for i=1:numel(samples)
        p=stage7a10_adaptive_profile(samples(i).observed,bank,ix,sigma,selector,first);
        d(i,:)=p.distances;
    end
end
function r=sample_row()
    r=struct('scenario','','condition','','method','','library','', ...
        'truth_id','','truth_signature','','truth_in_library',false, ...
        'parameter_seed',0,'noise_seed',0,'snr_db',NaN,'selected_view',0, ...
        'true_main_scale',NaN,'true_branch_load_scale',NaN, ...
        'node_port_error_fraction',NaN,'termination_error_fraction',NaN, ...
        'load_drift_fraction',NaN, ...
        'best_candidate','','candidate_set','','candidate_set_size',0, ...
        'decision_state','','decision_reason','','truth_in_set',false, ...
        'correct_unique',false,'false_unique',false,'distance',NaN, ...
        'second_distance',NaN,'margin',NaN,'fit_threshold',NaN, ...
        'distances','','wall_s',NaN);
end
function rows=summarize(samples)
    scenarios=unique({samples.scenario});methods=unique({samples.method});
    libraries=unique({samples.library});truths=unique({samples.truth_id});
    truths=[{'ALL'},truths];rows=repmat(summary_row(),0,1);
    for s=1:numel(scenarios)
        for m=1:numel(methods)
            for q=1:numel(libraries)
                for t=1:numel(truths)
                    mask=strcmp({samples.scenario},scenarios{s}) & ...
                        strcmp({samples.method},methods{m}) & ...
                        strcmp({samples.library},libraries{q});
                    if t>1,mask=mask&strcmp({samples.truth_id},truths{t});end
                    x=samples(mask);if isempty(x),continue;end
                    n=numel(x);r=summary_row();r.scenario=scenarios{s};
                    r.method=methods{m};r.library=libraries{q};r.truth_group=truths{t};
                    r.n=n;r.truth_in_library_n=nnz([x.truth_in_library]);
                    r.correct_unique_k=nnz([x.correct_unique]);
                    r.false_unique_k=nnz([x.false_unique]);
                    r.truth_in_set_k=nnz([x.truth_in_set]);
                    r.nonempty_set_k=nnz([x.candidate_set_size]>0);
                    r.ambiguous_k=nnz(strcmp({x.decision_state},'MULTIPLE_AMBIGUOUS'));
                    r.low_confidence_k=nnz(strcmp({x.decision_state},'LOW_CONFIDENCE'));
                    r.rejected_k=nnz(strcmp({x.decision_state},'REJECTED'));
                    r.mean_set_size=mean([x.candidate_set_size]);
                    r.mean_wall_s=mean([x.wall_s]);
                    [r.truth_in_set_low95,r.truth_in_set_high95]= ...
                        stage7a4_wilson(r.truth_in_set_k,r.truth_in_library_n);
                    [r.nonempty_set_low95,r.nonempty_set_high95]= ...
                        stage7a4_wilson(r.nonempty_set_k,n);
                    [r.false_unique_low95,r.false_unique_high95]= ...
                        stage7a4_wilson(r.false_unique_k,n);
                    [r.correct_unique_low95,r.correct_unique_high95]= ...
                        stage7a4_wilson(r.correct_unique_k,n);
                    rows(end+1)=r; %#ok<AGROW>
                end
            end
        end
    end
end
function r=summary_row()
    r=struct('scenario','','method','','library','','truth_group','', ...
        'n',0,'truth_in_library_n',0,'correct_unique_k',0, ...
        'false_unique_k',0,'truth_in_set_k',0,'nonempty_set_k',0, ...
        'ambiguous_k',0,'low_confidence_k',0,'rejected_k',0, ...
        'mean_set_size',NaN,'mean_wall_s',NaN, ...
        'truth_in_set_low95',NaN,'truth_in_set_high95',NaN, ...
        'nonempty_set_low95',NaN,'nonempty_set_high95',NaN, ...
        'false_unique_low95',NaN,'false_unique_high95',NaN, ...
        'correct_unique_low95',NaN,'correct_unique_high95',NaN);
end
