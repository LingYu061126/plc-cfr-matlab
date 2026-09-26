function out=exp_stage7a5_candidate_extension(root,mode)
%EXP_STAGE7A5_CANDIDATE_EXTENSION Paired fixed-library and graph-edit study.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a5_config(base,mode);
    if ~exist(cfg.output_dir,'dir'),mkdir(cfg.output_dir);end
    if ~exist(cfg.log_dir,'dir'),mkdir(cfg.log_dir);end
    started=tic;[pool,base_ix,grammar]=stage7a5_candidate_pool(base);
    bank=stage7a5_template_bank(pool,base,cfg);
    fprintf('Stage 7A.5 %s: MATLAB %s %s; candidates=%d, cached forwards=%d, cache=%d bytes\n', ...
        mode,version,computer('arch'),numel(pool),bank.forward_calls,bank.logical_cache_bytes);

    E=stage7a5_generate_split(pool,base_ix,base,cfg,cfg.seed_E, ...
        cfg.n_E_per_class,'E',false);
    sigma=estimate_sigma(E);
    A=stage7a5_generate_split(pool,base_ix,base,cfg,cfg.seed_A, ...
        cfg.n_A_per_class,'A',false);
    F=stage7a5_generate_split(pool,base_ix,base,cfg,cfg.seed_F, ...
        cfg.n_F_per_class,'F',false);
    models=cell(3,3,2);calRows=empty_cal_row();
    for v=1:3
        views=cfg.observation_views{v};
        a=score_batch(A,'A',0,views,sigma,pool,bank,base,cfg,base_ix);
        f=score_batch(F,'A',0,views,sigma,pool,bank,base,cfg,base_ix);
        models{v,1,1}=stage7a5_calibrate_legacy(distance_matrix(a,base_ix), ...
            [A.truth_index].',distance_matrix(f,base_ix),bank,base_ix,views,sigma,cfg);
        calRows(end+1)=cal_row(v,'A',0,models{v,1,1},A,F); %#ok<AGROW>
        a=score_batch(A,'B',0,views,sigma,pool,bank,base,cfg,base_ix);
        f=score_batch(F,'B',0,views,sigma,pool,bank,base,cfg,base_ix);
        [delta,~]=nonconformity(a,A);
        models{v,2,1}=stage7a5_calibrate_split(delta,[f.fit_statistic].', ...
            bank,cfg,base_ix,views,sigma,'B',0);
        calRows(end+1)=cal_row(v,'B',0,models{v,2,1},A,F); %#ok<AGROW>
        for bi=1:numel(cfg.candidate_budgets)
            budget=cfg.candidate_budgets(bi);
            a=score_batch(A,'C',budget,views,sigma,pool,bank,base,cfg,base_ix);
            f=score_batch(F,'C',budget,views,sigma,pool,bank,base,cfg,base_ix);
            [delta,~]=nonconformity(a,A);
            models{v,3,bi}=stage7a5_calibrate_split(delta,[f.fit_statistic].', ...
                bank,cfg,1:numel(pool),views,sigma,'C',budget);
            calRows(end+1)=cal_row(v,'C',budget,models{v,3,bi},A,F); %#ok<AGROW>
        end
    end
    fprintf('E/A/F done: E=%d, A=%d, F=%d; sigma=[%.5g %.5g]\n', ...
        numel(E),numel(A),numel(F),sigma);

    dev_ix=find_ids(pool,cfg.development_topology_ids);
    D=stage7a5_generate_split(pool,[base_ix dev_ix],base,cfg,cfg.seed_D, ...
        cfg.n_D_per_topology,'D',false);
    [selection,selected]=select_budgets(D,models,cfg,sigma,pool,bank,base,base_ix);
    writetable(struct2table(selection),fullfile(cfg.output_dir,'method_selection.csv'));
    fprintf('Method-selection budgets by scheme: %s\n',mat2str(selected));

    ood_ix=find_ids(pool,cfg.target_topology_ids);
    T=stage7a5_generate_split(pool,[base_ix ood_ix],base,cfg,cfg.seed_T, ...
        cfg.n_T_per_topology,'T',false);
    domain_ix=find_ids(pool,{'G002','G003'});
    Td=stage7a5_generate_split(pool,domain_ix,base,cfg,cfg.seed_T+50000000, ...
        cfg.n_T_per_topology,'T_domain',true);
    T=[T;Td];
    rows=empty_sample_rows();candidateRows=empty_candidate_rows();
    for v=1:3
        views=cfg.observation_views{v};
        for flow={'A','B','C'}
            name=flow{1};fi=flow_index(name);budget=0;
            if strcmp(name,'C'),budget=selected(v);end
            bi=budget_index(cfg.candidate_budgets,budget,fi);
            [r,c]=evaluate(T,name,budget,models{v,fi,bi},views,sigma, ...
                pool,bank,base,cfg,base_ix);
            rows=[rows;r(:)];candidateRows=[candidateRows;c(:)]; %#ok<AGROW>
        end
        fprintf('T scored: %s\n',cfg.observation_schemes{v});
    end
    [controlRows,controlCandidateRows,controlMeta]= ...
        stage7a5_nonunique_controls(base,cfg);

    summary=summarize(rows);topologyRows=topology_inventory(pool,base_ix,cfg);
    scaleRows=scale_benchmark(E(1),pool,bank,base,cfg,sigma,base_ix);
    writetable(struct2table(rows),fullfile(cfg.output_dir,'samples.csv'));
    writetable(struct2table(candidateRows),fullfile(cfg.output_dir,'candidate_audit.csv'));
    writetable(struct2table(summary),fullfile(cfg.output_dir,'summary.csv'));
    writetable(struct2table(calRows),fullfile(cfg.output_dir,'calibration.csv'));
    writetable(struct2table(controlRows),fullfile(cfg.output_dir,'nonunique_controls.csv'));
    writetable(struct2table(controlCandidateRows), ...
        fullfile(cfg.output_dir,'control_candidate_audit.csv'));
    writetable(struct2table(topologyRows),fullfile(cfg.output_dir,'topology_inventory.csv'));
    writetable(struct2table(scaleRows),fullfile(cfg.output_dir,'candidate_scale_benchmark.csv'));
    write_seed_manifest(cfg,pool,base_ix,dev_ix,ood_ix,domain_ix);
    runtime=toc(started);
    meta=table(string(cfg.verification_baseline_commit),string(version), ...
        string(computer('arch')),string(bank.identity),string(bank.search_identity), ...
        runtime,bank.forward_calls,bank.logical_cache_bytes,selected(1),selected(2),selected(3), ...
        cfg.use_parallel,cfg.worker_count,string(datetime('now','TimeZone','UTC', ...
        'Format','yyyy-MM-dd HH:mm:ss')),controlMeta.h50_nonunique_control_pass, ...
        'VariableNames',{'baseline_commit','matlab_version','computer_arch','bank_identity', ...
        'search_identity','runtime_s','template_forward_calls','template_cache_bytes', ...
        'budget_H50','budget_Zin50','budget_joint','use_parallel','worker_count', ...
        'verification_time_utc','h50_nonunique_control_pass'});
    writetable(meta,fullfile(cfg.output_dir,'metadata.csv'));
    save(fullfile(cfg.output_dir,'config_snapshot.mat'),'cfg','grammar','sigma', ...
        'meta','controlMeta','-v7');
    stage7a5_write_manifests(root,cfg.output_dir,cfg.verification_baseline_commit);
    if ~controlMeta.h50_nonunique_control_pass
        error('stage7a5:NonuniqueControlForcedUnique', ...
            ['H50 mirror/close positive control was forced to a unique topology; ' ...
             'all diagnostics were archived before stopping.']);
    end
    fprintf('Stage 7A.5 %s complete: %d rows, %.2f s\n',mode,numel(rows),runtime);
    out=struct('summary',summary,'runtime_s',runtime,'output_dir',cfg.output_dir, ...
        'selected_budget',selected);
end

function result=score_batch(samples,flow,budget,views,sigma,pool,bank,base,cfg,base_ix)
    result=repmat(struct('candidate_indices',[],'candidate_ids',{{}}, ...
        'distances',[],'params',[],'grid_distances',[],'optimizer_evaluations',0, ...
        'fit_statistic',NaN,'holdout_statistic',NaN,'search_truncated',false, ...
        'generated_ids',{{}},'profile_candidate_count',0,'views',[], ...
        'forward_model_calls_search',0,'forward_model_calls_holdout',0),numel(samples),1);
    for i=1:numel(samples)
        result(i)=stage7a5_score_observation(samples(i).observed,pool,bank,base, ...
            cfg,base_ix,views,sigma,flow,budget,[]);
    end
end

function d=distance_matrix(results,candidate_indices)
    d=zeros(numel(results),numel(candidate_indices));
    for i=1:numel(results)
        assert(isequal(results(i).candidate_indices,candidate_indices), ...
            'stage7a5:CalibrationCandidateOrder');
        d(i,:)=results(i).distances;
    end
end

function [delta,present]=nonconformity(results,samples)
    delta=nan(numel(results),1);present=false(numel(results),1);
    for i=1:numel(results)
        j=find(strcmp(results(i).candidate_ids,samples(i).truth_id),1);
        if ~isempty(j)
            delta(i)=results(i).distances(j)-min(results(i).distances);
            present(i)=true;
        end
    end
    assert(all(present),'stage7a5:CalibrationMissedTruth');
end

function [selection,selected]=select_budgets(D,models,cfg,sigma,pool,bank,base,base_ix)
    selection=repmat(struct('scheme','','budget',0,'ood_generated_k',0,'ood_n',0, ...
        'generator_recall',NaN,'inlib_correct_C_k',0,'inlib_correct_B_k',0, ...
        'inlib_n',0,'delta_correct_unique',NaN,'ood_false_unique_C_k',0, ...
        'ood_false_unique_B_k',0,'eligible',false),0,1);
    selected=zeros(1,3);
    for v=1:3
        views=cfg.observation_views{v};
        b=evaluate(D,'B',0,models{v,2,1},views,sigma,pool,bank,base,cfg,base_ix);
        start=numel(selection)+1;
        for bi=1:numel(cfg.candidate_budgets)
            budget=cfg.candidate_budgets(bi);
            c=evaluate(D,'C',budget,models{v,3,bi},views,sigma,pool,bank,base,cfg,base_ix);
            ood=~[c.truth_in_library]&~[c.domain_out];in=[c.truth_in_library];
            ng=sum([c(ood).truth_active]);no=sum(ood);
            kc=sum([c(in).correct_unique]);kb=sum([b(in).correct_unique]);ni=sum(in);
            recall=ng/max(no,1);delta=(kc-kb)/max(ni,1);
            selection(end+1)=struct('scheme',cfg.observation_schemes{v}, ...
                'budget',budget,'ood_generated_k',ng,'ood_n',no, ...
                'generator_recall',recall,'inlib_correct_C_k',kc, ...
                'inlib_correct_B_k',kb,'inlib_n',ni,'delta_correct_unique',delta, ...
                'ood_false_unique_C_k',sum([c(ood).false_unique]), ...
                'ood_false_unique_B_k',sum([b(ood).false_unique]), ...
                'eligible',recall>=0.90&&delta>=-0.05); %#ok<AGROW>
        end
        sv=selection(start:end);ok=find([sv.eligible]);
        if isempty(ok),selected(v)=max(cfg.candidate_budgets);
        else,selected(v)=min([sv(ok).budget]);end
    end
end

function [rows,candidates]=evaluate(samples,flow,budget,model,views,sigma, ...
        pool,bank,base,cfg,base_ix)
    rows=empty_sample_rows();candidates=empty_candidate_rows();
    v=find(cellfun(@(x)isequal(x,views),cfg.observation_views),1);
    base_sig=bank.candidate_signatures(base_ix);
    for i=1:numel(samples)
        s=samples(i);
        scored=stage7a5_score_observation(s.observed,pool,bank,base,cfg, ...
            base_ix,views,sigma,flow,budget,model);
        dec=stage7a5_decide(scored,model,bank);
        inlib=any(strcmp(base_sig,s.truth_signature));domain=s.domain_out;
        ood=~inlib&&~domain;active=any(strcmp(scored.candidate_ids,s.truth_id));
        truth_rank=0;
        if active
            [~,ord]=sort(scored.distances);truth_rank=find(strcmp(scored.candidate_ids(ord),s.truth_id),1);
        end
        unique=strcmp(dec.decision_state,'UNIQUE_CONFIDENT');
        q=sample_row();q.split=s.split;q.scenario=s.scenario;
        q.scheme=cfg.observation_schemes{v};q.flow=flow;q.budget=budget;
        q.truth_id=s.truth_id;q.truth_signature=s.truth_signature;
        q.truth_in_library=inlib;q.library_out=ood;q.domain_out=domain;
        q.parameter_seed=s.parameter_seed;q.noise_seed=s.noise_seed;
        q.true_main_scale=s.theta_true.main_length_scale;
        q.true_load_scale=s.theta_true.branch_load_scale;
        q.candidate_count=numel(scored.candidate_ids);
        q.candidate_set=strjoin(dec.candidate_set,';');q.set_size=dec.candidate_set_size;
        q.best_candidate=dec.best_candidate;q.truth_candidate_rank=truth_rank;
        q.truth_active=active;q.truth_generated=any(strcmp(scored.generated_ids,s.truth_id));
        q.truth_pruned=ood&&~active;
        q.truth_covered=inlib&&any(strcmp(dec.candidate_set,s.truth_id));
        q.correct_unique=unique&&strcmp(dec.best_candidate,s.truth_id);
        % Initial-library exclusion is not itself an error when the generic
        % editor generated and uniquely selected the true graph. False unique
        % means that the unique selected graph is not the evaluation truth.
        q.false_unique=unique&&~strcmp(dec.best_candidate,s.truth_id);
        q.library_out_nonempty=ood&&dec.candidate_set_size>0;
        q.domain_out_accepted=domain&&unique;q.state=dec.decision_state;q.reason=dec.decision_reason;
        q.distance_1=dec.distance_1;q.distance_2=dec.distance_2;q.margin=dec.margin;
        q.fit_statistic=dec.fit_statistic;q.fit_threshold=dec.fit_threshold;
        q.search_truncated=dec.search_truncated;
        q.optimizer_evaluations=scored.optimizer_evaluations;
        q.forward_model_calls=scored.optimizer_evaluations+ ...
            scored.forward_model_calls_search+scored.forward_model_calls_holdout;
        rows(end+1)=q; %#ok<AGROW>
        [~,ord]=sort(scored.distances);
        for j=1:numel(scored.candidate_ids)
            ci=scored.candidate_indices(j);c=candidate_row();
            c.split=s.split;c.scenario=s.scenario;c.scheme=q.scheme;c.flow=flow;c.budget=budget;
            c.truth_id=s.truth_id;c.candidate_id=scored.candidate_ids{j};
            c.signature=bank.candidate_signatures{ci};c.rank=find(ord==j,1);
            c.distance=scored.distances(j);c.fit_main_scale=scored.params(j,1);
            c.fit_load_scale=scored.params(j,2);
            c.generated=any(strcmp(scored.generated_ids,c.candidate_id));
            c.truth_candidate=strcmp(c.candidate_id,s.truth_id);
            c.in_candidate_set=any(strcmp(dec.candidate_set,c.candidate_id));
            c.decision_state=dec.decision_state;candidates(end+1)=c; %#ok<AGROW>
        end
    end
end

function sigma=estimate_sigma(samples)
    e=zeros(1,2);
    for i=1:numel(samples),for v=1:2
        e(v)=e(v)+mean(abs(samples(i).observed{v}-samples(i).clean{v}).^2);
    end,end
    sigma=sqrt(e/numel(samples));
end
function ix=find_ids(pool,ids)
    ix=zeros(1,numel(ids));
    for k=1:numel(ids),ix(k)=find(strcmp({pool.topology_id},ids{k}),1);end
    assert(all(ix>0),'stage7a5:TopologyIdentity');
end
function ix=flow_index(x),switch x,case 'A',ix=1;case 'B',ix=2;case 'C',ix=3;end,end
function ix=budget_index(budgets,budget,flow),if flow<3,ix=1;else,ix=find(budgets==budget,1);end,end
function q=cal_row(v,flow,budget,m,A,F)
    q=struct('scheme_index',v,'flow',flow,'budget',budget, ...
        'A_n',numel(A),'F_n',numel(F),'set_threshold',m.set_threshold, ...
        'fit_threshold',m.fit_threshold,'class_thresholds',mat2str(m.class_threshold,16), ...
        'calibration_identity',m.calibration_identity, ...
        'bank_identity',m.bank_identity,'search_identity',m.search_identity);
end
function x=empty_cal_row()
    x=repmat(struct('scheme_index',0,'flow','','budget',0,'A_n',0,'F_n',0, ...
        'set_threshold',NaN,'fit_threshold',NaN,'class_thresholds','', ...
        'calibration_identity','','bank_identity','','search_identity',''),0,1);
end
function q=sample_row()
    q=struct('split','','scenario','','scheme','','flow','','budget',0,'truth_id','', ...
        'truth_signature','','truth_in_library',false,'library_out',false,'domain_out',false, ...
        'parameter_seed',0,'noise_seed',0,'true_main_scale',NaN,'true_load_scale',NaN, ...
        'candidate_count',0,'candidate_set','','set_size',0,'best_candidate','', ...
        'truth_candidate_rank',0,'truth_active',false,'truth_generated',false, ...
        'truth_pruned',false,'truth_covered',false,'correct_unique',false,'false_unique',false, ...
        'library_out_nonempty',false,'domain_out_accepted',false,'state','','reason','', ...
        'distance_1',NaN,'distance_2',NaN,'margin',NaN,'fit_statistic',NaN, ...
        'fit_threshold',NaN,'search_truncated',false,'optimizer_evaluations',0, ...
        'forward_model_calls',0);
end
function r=empty_sample_rows(),r=repmat(sample_row(),0,1);end
function q=candidate_row()
    q=struct('split','','scenario','','scheme','','flow','','budget',0, ...
        'truth_id','','candidate_id','','signature','','rank',0,'distance',NaN, ...
        'fit_main_scale',NaN,'fit_load_scale',NaN,'generated',false, ...
        'truth_candidate',false,'in_candidate_set',false,'decision_state','');
end
function r=empty_candidate_rows(),r=repmat(candidate_row(),0,1);end
function rows=topology_inventory(pool,base_ix,cfg)
    rows=repmat(struct('candidate_id','','signature','','initial_library',false, ...
        'development_family',false,'test_family',false,'grammar_valid',false),numel(pool),1);
    for k=1:numel(pool)
        rows(k)=struct('candidate_id',pool(k).topology_id, ...
            'signature',stage6b_network_signature(pool(k).network), ...
            'initial_library',ismember(k,base_ix), ...
            'development_family',ismember(pool(k).topology_id,cfg.development_topology_ids), ...
            'test_family',ismember(pool(k).topology_id,cfg.target_topology_ids), ...
            'grammar_valid',pool(k).validation.connected&&pool(k).validation.acyclic);
    end
end
function rows=scale_benchmark(sample,pool,bank,base,cfg,sigma,base_ix)
    order=[base_ix setdiff(1:numel(pool),base_ix,'stable')];sizes=[3 7 10];
    rows=repmat(struct('candidate_count',0,'profile_time_s',0, ...
        'optimizer_evaluations',0,'cache_bytes',0),numel(sizes),1);
    for k=1:numel(sizes)
        ticid=tic;p=stage7a5_profile(sample.observed,pool,bank,base,cfg, ...
            order(1:sizes(k)),[1 2],sigma,cfg.frequency_train_indices,true);
        t=toc(ticid);tmp=bank.templates(order(1:sizes(k)),:);w=whos('tmp');
        rows(k)=struct('candidate_count',sizes(k),'profile_time_s',t, ...
            'optimizer_evaluations',sum(p.evaluations),'cache_bytes',w.bytes);
    end
end
function write_seed_manifest(cfg,pool,base_ix,dev_ix,ood_ix,domain_ix)
    names={'E';'A';'F';'D';'T';'T_domain'; ...
        'control_E';'control_A';'control_F';'control_T'};
    seeds=[cfg.seed_E;cfg.seed_A;cfg.seed_F;cfg.seed_D;cfg.seed_T;cfg.seed_T+50000000];
    seeds=[seeds;cfg.seed_control_E;cfg.seed_control_A;cfg.seed_control_F;cfg.seed_control_T];
    repetitions=[cfg.n_E_per_class;cfg.n_A_per_class;cfg.n_F_per_class; ...
        cfg.n_D_per_topology;cfg.n_T_per_topology;cfg.n_T_per_topology; ...
        cfg.n_E_per_class;cfg.n_A_per_class;cfg.n_F_per_class;cfg.n_control_per_topology];
    scopes={strjoin({pool(base_ix).topology_id},';'); ...
        strjoin({pool(base_ix).topology_id},';');strjoin({pool(base_ix).topology_id},';'); ...
        'base+development';strjoin({pool([base_ix ood_ix]).topology_id},';'); ...
        strjoin({pool(domain_ix).topology_id},';');'T3;T4_NEAR_T3;T5'; ...
        'T3;T4_NEAR_T3;T5';'T3;T4_NEAR_T3;T5';'T3;T4_NEAR_T3;T5'};
    writetable(table(string(names),seeds,repetitions,string(scopes), ...
        'VariableNames',{'split','seed_base','repetitions_per_topology','topology_scope'}), ...
        fullfile(cfg.output_dir,'seed_manifest.csv'));
end
function summary=summarize(rows)
    summary=repmat(struct('split','','scenario','','scheme','','flow','','budget',0, ...
        'n',0,'truth_in_library_n',0,'correct_unique_k',0,'false_unique_k',0, ...
        'truth_covered_k',0,'mean_set_size',NaN,'rejected_k',0,'ambiguous_k',0, ...
        'low_confidence_k',0,'truth_generated_k',0,'truth_pruned_k',0, ...
        'library_out_n',0,'library_out_nonempty_k',0,'library_out_false_unique_k',0, ...
        'domain_out_n',0,'domain_out_accepted_k',0,'correct_unique_low',NaN, ...
        'correct_unique_high',NaN,'false_unique_low',NaN,'false_unique_high',NaN, ...
        'library_out_false_unique_low',NaN,'library_out_false_unique_high',NaN),0,1);
    keys=unique(strcat(string({rows.split})',"|",string({rows.scenario})',"|", ...
        string({rows.scheme})',"|",string({rows.flow})'));
    for k=1:numel(keys)
        z=split(keys(k),"|");ix=strcmp({rows.split},z(1))&strcmp({rows.scenario},z(2))& ...
            strcmp({rows.scheme},z(3))&strcmp({rows.flow},z(4));
        x=rows(ix);in=[x.truth_in_library];ood=[x.library_out];dom=[x.domain_out];
        ck=sum([x.correct_unique]);fk=sum([x.false_unique]);of=sum([x(ood).false_unique]);
        [cl,ch]=stage7a4_wilson(ck,numel(x));[fl,fh]=stage7a4_wilson(fk,numel(x));
        [ol,oh]=stage7a4_wilson(of,sum(ood));
        q=struct('split',char(z(1)),'scenario',char(z(2)),'scheme',char(z(3)), ...
            'flow',char(z(4)),'budget',x(1).budget,'n',numel(x), ...
            'truth_in_library_n',sum(in),'correct_unique_k',ck,'false_unique_k',fk, ...
            'truth_covered_k',sum([x(in).truth_covered]), ...
            'mean_set_size',mean([x.set_size]),'rejected_k',sum(strcmp({x.state},'REJECTED')), ...
            'ambiguous_k',sum(strcmp({x.state},'MULTIPLE_AMBIGUOUS')), ...
            'low_confidence_k',sum(strcmp({x.state},'LOW_CONFIDENCE')), ...
            'truth_generated_k',sum([x.truth_generated]),'truth_pruned_k',sum([x.truth_pruned]), ...
            'library_out_n',sum(ood),'library_out_nonempty_k',sum([x(ood).library_out_nonempty]), ...
            'library_out_false_unique_k',of,'domain_out_n',sum(dom), ...
            'domain_out_accepted_k',sum([x(dom).domain_out_accepted]), ...
            'correct_unique_low',cl,'correct_unique_high',ch, ...
            'false_unique_low',fl,'false_unique_high',fh, ...
            'library_out_false_unique_low',ol,'library_out_false_unique_high',oh);
        summary(end+1)=q; %#ok<AGROW>
    end
end
