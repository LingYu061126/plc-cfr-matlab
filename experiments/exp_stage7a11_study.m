function result=exp_stage7a11_study(root,mode,run_id)
%EXP_STAGE7A11_STUDY Paired synthetic CFR view selection, serial execution.
%   Truth graph and generating theta remain here; decision APIs receive only
%   complex spectra, candidate templates and calibration. Output paths are new.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='smoke';end
    if nargin<3||isempty(run_id),run_id='initial';end
    assert(~isempty(regexp(run_id,'^[A-Za-z0-9_]+$','once')),'stage7a11:RunId');
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a11_config(base,mode);
    out=fullfile(cfg.output_dir,run_id);
    assert(exist(out,'dir')~=7,'stage7a11:ExistingRun');
    all_timer=tic;[fixed_graphs,new_graphs]=graphs(base);
    fixed_bank=stage7a4_template_bank(fixed_graphs(1:6),base,cfg);
    new_bank=stage7a4_template_bank(new_graphs(1:8),base,cfg);
    old=load(fullfile(root,'results','data','stage7a_10','formal', ...
        'confirm1','config_snapshot.mat'),'models','metadata');
    assert(strcmp(char(old.metadata.bank_identity),fixed_bank.identity), ...
        'stage7a11:FrozenBankIdentity');
    fixed_ix={1:3,1:6,[3 4]};fixed_cal=cell(1,3);
    for q=1:3
        fixed_cal{q}=calibrate(fixed_graphs(1:6),fixed_bank,base,cfg,fixed_ix{q});
    end
    new_cal=calibrate(new_graphs(1:8),new_bank,base,cfg,1:8);
    calibration_wall_s=toc(all_timer);
    fixed_samples=stage7a4_generate_split(fixed_graphs,1:8,base,cfg, ...
        cfg.seed_fixed_T,cfg.n_T_per_topology,20,'standard');
    new_samples=stage7a4_generate_split(new_graphs,7:10,base,cfg, ...
        cfg.seed_new_T,cfg.n_T_per_topology,20,'standard');
    rows=repmat(sample_row(),0,1);candidate_rows=repmat(candidate_row(),0,1);
    [a,b]=score_batch(fixed_samples,fixed_graphs,fixed_bank,fixed_cal, ...
        old.models,cfg,'fixed_graph_new_noise');
    rows=[rows(:);a(:)];candidate_rows=[candidate_rows(:);b(:)]; %#ok<AGROW>
    [a,b]=score_batch(new_samples,new_graphs,new_bank,new_cal, ...
        [],cfg,'new_structure_diagnostic');
    rows=[rows(:);a(:)];candidate_rows=[candidate_rows(:);b(:)]; %#ok<AGROW>
    samples=struct2table(rows);candidate_audit=struct2table(candidate_rows);
    summary=summarize(samples);
    graph_rows=repmat(struct('batch',"",'graph_id',"",'signature',"", ...
        'in_bank',false),0,1);
    for i=1:numel(fixed_graphs)
        graph_rows(end+1)=struct('batch',"fixed_graph_new_noise", ...
            'graph_id',string(fixed_graphs(i).topology_id), ...
            'signature',string(stage6b_network_signature(fixed_graphs(i).network)), ...
            'in_bank',i<=6); %#ok<AGROW>
    end
    for i=1:numel(new_graphs)
        graph_rows(end+1)=struct('batch',"new_structure_diagnostic", ...
            'graph_id',string(new_graphs(i).topology_id), ...
            'signature',string(stage6b_network_signature(new_graphs(i).network)), ...
            'in_bank',i<=8); %#ok<AGROW>
    end
    metadata=struct('stage',string(cfg.stage),'mode',string(mode), ...
        'run_id',string(run_id),'verification_baseline_commit', ...
        string(cfg.verification_baseline_commit),'matlab_version',string(version), ...
        'computer_arch',string(computer('arch')),'parallel_workers',0, ...
        'fixed_bank_identity',string(fixed_bank.identity), ...
        'new_bank_identity',string(new_bank.identity), ...
        'fixed_selector_identity',string(fixed_cal{2}.selector_j.identity), ...
        'new_selector_identity',string(new_cal.selector_j.identity), ...
        'fixed_template_bytes',fixed_bank.logical_cache_bytes, ...
        'new_template_bytes',new_bank.logical_cache_bytes, ...
        'fixed_template_forward_calls',fixed_bank.forward_calls, ...
        'new_template_forward_calls',new_bank.forward_calls, ...
        'E_seed',cfg.seed_E,'A0_seed',cfg.seed_A0, ...
        'A1_seed',cfg.seed_A1,'F_seed',cfg.seed_F, ...
        'fixed_test_seed',cfg.seed_fixed_T,'new_test_seed',cfg.seed_new_T, ...
        'calibration_wall_s',calibration_wall_s,'total_wall_s',toc(all_timer));
    mkdir(out);
    writetable(samples,fullfile(out,'samples.csv'));
    writetable(candidate_audit,fullfile(out,'candidate_audit.csv'));
    writetable(summary,fullfile(out,'summary.csv'));
    writetable(struct2table(graph_rows),fullfile(out,'graph_catalog.csv'));
    writetable(struct2table(metadata),fullfile(out,'metadata.csv'));
    save(fullfile(out,'config_snapshot.mat'),'cfg','metadata','fixed_cal', ...
        'new_cal','graph_rows');
    fprintf('PASS Stage 7A.11 %s %s: %d scored rows, %.3f s\n', ...
        mode,run_id,height(samples),metadata.total_wall_s);
    result=struct('output_dir',out,'metadata',metadata,'summary',summary);
end

function cal=calibrate(candidates,bank,base,cfg,ix)
    e=stage7a4_generate_split(candidates,ix,base,cfg,cfg.seed_E, ...
        cfg.n_E_per_topology,20,'standard');
    sigma=stage7a4_calibrate_view_scales(e,cfg);
    selector_d=stage7a10_view_selection(bank,sigma,cfg.extra_view_indices);
    selector_j=stage7a11_view_selector(bank,sigma,cfg.extra_view_indices);
    a0=stage7a4_generate_split(candidates,ix,base,cfg,cfg.seed_A0, ...
        cfg.n_A0_per_topology,20,'standard');
    a1=stage7a4_generate_split(candidates,ix,base,cfg,cfg.seed_A1, ...
        cfg.n_A1_per_topology,20,'standard');
    f=stage7a4_generate_split(candidates,ix,base,cfg,cfg.seed_F, ...
        cfg.n_F_per_topology,20,'standard');
    truth0=arrayfun(@(x)find(ix==x.truth_global_index,1),a0)';
    truth1=arrayfun(@(x)find(ix==x.truth_global_index,1),a1)';
    h0=matrix(a0,bank,ix,5,sigma,'static',[],[]);
    first=zeros(1,numel(ix));
    for k=1:numel(ix)
        x=sort(h0(truth0==k,k));n=numel(x);
        rank=ceil((n+1)*(1-cfg.alpha));
        if rank>n,first(k)=Inf;else,first(k)=x(rank);end
    end
    da=matrix(a1,bank,ix,[],sigma,'D',selector_d,first);
    df=matrix(f,bank,ix,[],sigma,'D',selector_d,first);
    ja=matrix(a1,bank,ix,[],sigma,'J',selector_j,first);
    jf=matrix(f,bank,ix,[],sigma,'J',selector_j,first);
    model_d=stage7a10_calibrate(h0,truth0,da,truth1,df, ...
        bank,ix,sigma,selector_d,cfg);
    model_j=stage7a10_calibrate(h0,truth0,ja,truth1,jf, ...
        bank,ix,sigma,selector_j,cfg);
    views={5,[13 14],[5 6]};names={'A_H50','C_M2_simple_joint','E_H50_Zin50'};
    simple=cell(1,numel(views));
    for k=1:numel(views)
        aa=matrix(a1,bank,ix,views{k},sigma,'static',[],[]);
        ff=matrix(f,bank,ix,views{k},sigma,'static',[],[]);
        simple{k}=stage7a4_calibrate_decision(aa,truth1,ff,bank, ...
            ix,views{k},sigma,cfg,['stage7a11_' names{k}]);
    end
    cal=struct('sigma',sigma,'selector_d',selector_d, ...
        'selector_j',selector_j,'model_d',model_d,'model_j',model_j, ...
        'simple',{simple},'first_threshold',first,'E_n',numel(e), ...
        'A0_n',numel(a0),'A1_n',numel(a1),'F_n',numel(f));
end

function d=matrix(samples,bank,ix,views,sigma,kind,selector,first)
    d=zeros(numel(samples),numel(ix));
    for i=1:numel(samples)
        switch kind
            case 'static'
                p=stage7a4_profile_views(samples(i).observed,bank,ix,views,sigma);
            case 'D'
                p=stage7a10_adaptive_profile(samples(i).observed,bank,ix, ...
                    sigma,selector,first);
            case 'J'
                p=stage7a11_adaptive_profile(samples(i).observed,bank,ix, ...
                    sigma,selector,first);
        end
        d(i,:)=p.distances;
    end
end

function [rows,candidate_rows]=score_batch(samples,graphs,bank,cal,old_models,cfg,batch)
    if strcmp(batch,'fixed_graph_new_noise')
        libraries={'original_three','expanded_six','diagnostic_pair'};
        indices={1:3,1:6,[3 4]};
    else
        libraries={'expanded_eight'};indices={1:8};
    end
    rows=repmat(sample_row(),0,1);candidate_rows=repmat(candidate_row(),0,1);
    for i=1:numel(samples)
        s=samples(i);truth=graphs(s.truth_global_index).topology_id;
        for q=1:numel(libraries)
            ix=indices{q};in=ismember(truth,bank.candidate_ids(ix));
            if iscell(cal),local_cal=cal{q};else,local_cal=cal;end
            methods=methods_for(batch,q,local_cal,old_models);
            for m=1:numel(methods)
                zt=tic;md=methods(m);model=md.model;
                if strcmp(md.kind,'J')
                    z=stage7a11_decide(s.observed,bank,model);
                elseif strcmp(md.kind,'D')
                    z=stage7a10_decide(s.observed,bank,model);
                else
                    z=stage7a4_decide(s.observed,bank,model);
                end
                elapsed=toc(zt);r=sample_row();
                r.batch=string(batch);r.library=string(libraries{q});
                r.method=string(md.name);r.truth_id=string(truth);
                r.truth_signature=string(stage6b_network_signature( ...
                    graphs(s.truth_global_index).network));
                r.truth_in_library=in;r.parameter_seed=s.parameter_seed;
                r.noise_seed=s.noise_seed;r.selected_view=0;
                if isfield(z,'selected_view'),r.selected_view=z.selected_view;end
                r.best_candidate=string(z.best_candidate);
                r.candidate_set=string(z.candidate_set);
                r.candidate_set_size=z.candidate_set_size;
                r.decision_state=string(z.decision_state);
                r.decision_reason=string(z.decision_reason);
                r.truth_in_set=in && ismember(truth,strsplit(z.candidate_set,','));
                r.correct_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT') && ...
                    strcmp(truth,z.best_candidate);
                r.false_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT') && ...
                    ~r.correct_unique;
                r.distance=z.distance;r.second_distance=z.second_distance;
                r.margin=z.margin;r.fit_threshold=z.fit_threshold;
                r.margin_threshold=model.margin_threshold;
                r.wall_s=elapsed;
                r.distances=string(mat2str(z.all_distances,16));
                if isfield(z,'first_set')
                    r.first_set=string(strjoin(bank.candidate_ids(ix(z.first_set)),','));
                    r.truth_in_first=in && ismember(truth, ...
                        bank.candidate_ids(ix(z.first_set)));
                end
                first_d=[];
                if strcmp(md.kind,'J')
                    r.first_distances=string(mat2str(z.first_distances,16));
                    first_d=z.first_distances;
                    r.joint_separation=z.extra_view_separation;
                    r.view_scores=string(mat2str(z.view_scores,16));
                    r.competition_set=string(strjoin( ...
                        bank.candidate_ids(z.competition_indices),','));
                elseif strcmp(md.kind,'D')
                    p=stage7a4_profile_views(s.observed,bank,ix,5,model.sigma);
                    r.first_distances=string(mat2str(p.distances,16));
                    first_d=p.distances;
                    r.joint_separation=z.extra_view_separation;
                end
                [r.source_states,r.node_port_access]=cost(md.kind,r.selected_view,md.name);
                rows(end+1)=r; %#ok<AGROW>
                if strcmp(md.kind,'J') || strcmp(md.kind,'D')
                    for k=1:numel(ix)
                        c=candidate_row();c.batch=r.batch;c.library=r.library;
                        c.method=r.method;c.truth_id=r.truth_id;
                        c.noise_seed=r.noise_seed;c.candidate_id=string(bank.candidate_ids{ix(k)});
                        c.first_distance=first_d(k);
                        c.final_distance=z.all_distances(k);
                        c.first_in_set=ismember(char(c.candidate_id),strsplit(char(r.first_set),','));
                        c.final_in_set=ismember(char(c.candidate_id),strsplit(z.candidate_set,','));
                        c.first_threshold=model.first_threshold(k);
                        c.final_threshold=model.class_threshold(k);
                        c.selected_view=r.selected_view;
                        candidate_rows(end+1)=c; %#ok<AGROW>
                    end
                end
            end
        end
        if mod(i,max(1,cfg.n_T_per_topology))==0
            fprintf('Stage 7A.11 %s: %d/%d observations scored.\n', ...
                batch,i,numel(samples));
        end
    end
end

function methods=methods_for(batch,q,cal,old_models)
    if strcmp(batch,'fixed_graph_new_noise')
        methods=struct('name',{'A_H50','C_M2_simple_joint','D_frozen', ...
            'E_H50_Zin50','D_samecal','J_joint_select'}, ...
            'kind',{'static','static','D','static','D','J'}, ...
            'model',{old_models{1,q},old_models{4,q},old_models{5,q}, ...
            old_models{6,q},[],[]});
        methods(5).model=cal.model_d;methods(6).model=cal.model_j;
    else
        methods=struct('name',{'A_H50','C_M2_simple_joint','D_samecal', ...
            'E_H50_Zin50','J_joint_select'}, ...
            'kind',{'static','static','D','static','J'}, ...
            'model',{cal.simple{1},cal.simple{2},cal.model_d, ...
            cal.simple{3},cal.model_j});
    end
end

function [states,nodes]=cost(kind,selected,name)
    states=1;nodes=0;
    if ismember(kind,{'D','J'}) && selected>0
        states=2;if selected>=12,nodes=1;end
    elseif strcmp(name,'C_M2_simple_joint')
        nodes=1;
    end
end

function out=summarize(samples)
    keys=unique(samples(:,{'batch','library','method','truth_id'}));
    allkeys=unique(samples(:,{'batch','library','method'}));
    allkeys.truth_id=repmat("ALL",height(allkeys),1);
    keys=[keys;allkeys];rows=repmat(summary_row(),height(keys),1);
    for i=1:height(keys)
        k=keys(i,:);mask=samples.batch==k.batch & ...
            samples.library==k.library & samples.method==k.method;
        if k.truth_id~="ALL",mask=mask & samples.truth_id==k.truth_id;end
        x=samples(mask,:);in=x.truth_in_library;outlib=~in;
        r=summary_row();r.batch=k.batch;r.library=k.library;
        r.method=k.method;r.truth_id=k.truth_id;r.n=height(x);
        r.in_library_n=nnz(in);r.out_library_n=nnz(outlib);
        r.correct_unique_k=nnz(x.correct_unique & in);
        r.truth_in_set_k=nnz(x.truth_in_set & in);
        r.false_unique_out_k=nnz(x.false_unique & outlib);
        r.nonempty_out_k=nnz(x.candidate_set_size>0 & outlib);
        r.unique_k=nnz(x.decision_state=="UNIQUE_CONFIDENT");
        r.ambiguous_k=nnz(x.decision_state=="MULTIPLE_AMBIGUOUS");
        r.low_confidence_k=nnz(x.decision_state=="LOW_CONFIDENCE");
        r.rejected_k=nnz(x.decision_state=="REJECTED");
        r.first_truth_k=nnz(x.truth_in_first & in);
        r.mean_set_size=mean(x.candidate_set_size);
        r.mean_source_states=mean(x.source_states);
        r.mean_wall_s=mean(x.wall_s);rows(i)=r;
    end
    out=struct2table(rows);
end

function [fixed,new]=graphs(base)
    [~,~,~,catalog]=stage7a6_candidate_space(base);
    fixed_ids={'G001','G002','G003','MIRROR_M3','ADD_M1_M3', ...
        'EXT_111','EXT_021','MID30'};
    new_ids={'G001','G002','G003','MIRROR_M3','ADD_M1_M3', ...
        'EXT_111','DOUBLE_M1','EXT_120','DOUBLE_M2','EXT_201'};
    fixed=take(catalog,fixed_ids);new=take(catalog,new_ids);
    sigs=[arrayfun(@(x)stage6b_network_signature(x.network),fixed, ...
        'UniformOutput',false),arrayfun(@(x)stage6b_network_signature(x.network), ...
        new,'UniformOutput',false)];
    assert(numel(unique(sigs))>=12,'stage7a11:GraphSignature');
end
function out=take(catalog,ids)
    all={catalog.topology_id};out=repmat(struct('topology_id','','network',struct()),1,numel(ids));
    for k=1:numel(ids)
        j=find(strcmp(ids{k},all),1);assert(~isempty(j),'stage7a11:GraphMissing');
        out(k)=struct('topology_id',ids{k},'network',catalog(j).network);
    end
end
function r=sample_row()
    r=struct('batch',"",'library',"",'method',"",'truth_id',"", ...
        'truth_signature',"",'truth_in_library',false,'parameter_seed',0, ...
        'noise_seed',0,'selected_view',0,'competition_set',"", ...
        'first_set',"",'truth_in_first',false,'first_distances',"", ...
        'best_candidate',"",'candidate_set',"",'candidate_set_size',0, ...
        'decision_state',"",'decision_reason',"",'truth_in_set',false, ...
        'correct_unique',false,'false_unique',false,'distance',NaN, ...
        'second_distance',NaN,'margin',NaN,'fit_threshold',NaN, ...
        'margin_threshold',NaN,'joint_separation',NaN,'view_scores',"", ...
        'distances',"",'source_states',0,'node_port_access',0,'wall_s',NaN);
end
function r=candidate_row()
    r=struct('batch',"",'library',"",'method',"",'truth_id',"", ...
        'noise_seed',0,'candidate_id',"",'first_distance',NaN, ...
        'first_threshold',NaN,'first_in_set',false,'final_distance',NaN, ...
        'final_threshold',NaN,'final_in_set',false,'selected_view',0);
end
function r=summary_row()
    r=struct('batch',"",'library',"",'method',"",'truth_id',"", ...
        'n',0,'in_library_n',0,'out_library_n',0, ...
        'correct_unique_k',0,'truth_in_set_k',0,'first_truth_k',0, ...
        'false_unique_out_k',0,'nonempty_out_k',0, ...
        'unique_k',0,'ambiguous_k',0,'low_confidence_k',0, ...
        'rejected_k',0,'mean_set_size',NaN,'mean_source_states',NaN, ...
        'mean_wall_s',NaN);
end
