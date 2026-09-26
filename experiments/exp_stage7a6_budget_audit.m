function out=exp_stage7a6_budget_audit(root,mode,budget)
%EXP_STAGE7A6_BUDGET_AUDIT Paired fixed/expanded synthetic topology audit.
%   Each run has one candidate budget and a separate MATLAB process; the
%   source/test topology, nuisance parameters and noisy observations are
%   exactly paired between B and C. Truth is used only for calibration A
%   and post-decision evaluation, never as a scorer input.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    if nargin<3||isempty(budget),budget=17;end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);
    cfg=stage7a6_config(base,mode,budget);
    if ~exist(cfg.output_dir,'dir'),mkdir(cfg.output_dir);end
    if ~exist(cfg.log_dir,'dir'),mkdir(cfg.log_dir);end
    started=tic;
    [pool,base_ix,grammar,catalog,groups,steps]=stage7a6_candidate_space(base);
    bank=stage7a5_template_bank(pool,base,cfg);
    E=stage7a5_generate_split(catalog,groups.inlib,base,cfg,cfg.seed_E, ...
        cfg.n_E_per_class,'E',false);
    sigma=estimate_sigma(E);
    A=stage7a5_generate_split(catalog,groups.inlib,base,cfg,cfg.seed_A, ...
        cfg.n_A_per_class,'A',false);
    F=stage7a5_generate_split(catalog,groups.inlib,base,cfg,cfg.seed_F, ...
        cfg.n_F_per_class,'F',false);
    tests=[ ...
        stage7a5_generate_split(catalog,groups.inlib,base,cfg, ...
            cfg.seed_T_inlib,cfg.n_T_inlib_per_topology,'T_inlib',false); ...
        stage7a5_generate_split(catalog,groups.old_out,base,cfg, ...
            cfg.seed_T_old_out,cfg.n_T_old_out_per_topology,'T_old_out',false); ...
        stage7a5_generate_split(catalog,groups.reachable,base,cfg, ...
            cfg.seed_T_reachable,cfg.n_T_reachable_per_topology,'T_reachable',false); ...
        stage7a5_generate_split(catalog,groups.grammar_out,base,cfg, ...
            cfg.seed_T_grammar_out,cfg.n_T_grammar_out_per_topology,'T_grammar_out',false); ...
        stage7a5_generate_split(catalog,groups.domain,base,cfg, ...
            cfg.seed_T_domain,cfg.n_T_domain_per_topology,'T_domain',true)];
    assert_unique_scenarios(E,A,F,tests);
    sample_rows=repmat(sample_row(),0,1);
    candidate_rows=repmat(candidate_row(),0,1);
    cal_rows=repmat(cal_row(),0,1);
    for v=1:numel(cfg.observation_schemes)
        views=cfg.observation_views{v};
        aB=score_batch(A,'B',0,views,sigma,pool,bank,base,cfg,base_ix);
        fB=score_batch(F,'B',0,views,sigma,pool,bank,base,cfg,base_ix);
        bdelta=nonconformity(aB,A);
        modelB=stage7a5_calibrate_split(bdelta,fit_values(fB),bank,cfg, ...
            base_ix,views,sigma,'B',0);
        aC=score_batch(A,'C',budget,views,sigma,pool,bank,base,cfg,base_ix);
        fC=score_batch(F,'C',budget,views,sigma,pool,bank,base,cfg,base_ix);
        cdelta=nonconformity(aC,A);
        modelC=stage7a5_calibrate_split(cdelta,fit_values(fC),bank,cfg, ...
            1:numel(pool),views,sigma,'C',budget);
        cal_rows(end+1)=make_cal_row(cfg.observation_schemes{v},'B',0,modelB,A,F); %#ok<AGROW>
        cal_rows(end+1)=make_cal_row(cfg.observation_schemes{v},'C',budget,modelC,A,F); %#ok<AGROW>
        for i=1:numel(tests)
            s=tests(i);
            [r,c]=evaluate_one(s,'B',0,modelB,views,sigma,pool,bank, ...
                base,cfg,base_ix,steps);
            sample_rows(end+1)=r;candidate_rows=[candidate_rows;c(:)]; %#ok<AGROW>
            [r,c]=evaluate_one(s,'C',budget,modelC,views,sigma,pool,bank, ...
                base,cfg,base_ix,steps);
            sample_rows(end+1)=r;candidate_rows=[candidate_rows;c(:)]; %#ok<AGROW>
        end
        fprintf('Stage 7A.6 %s budget %d: %s, %d paired observations scored\n', ...
            mode,budget,cfg.observation_schemes{v},numel(tests));
    end
    summary=summarize(sample_rows,cfg);
    topology_summary=summarize_topologies(sample_rows,cfg);
    inventory=topology_inventory(catalog,pool,base_ix,steps);
    seeds=seed_manifest(cfg);
    writetable(struct2table(sample_rows),fullfile(cfg.output_dir,'samples.csv'));
    writetable(struct2table(candidate_rows),fullfile(cfg.output_dir,'candidate_audit.csv'));
    writetable(struct2table(summary),fullfile(cfg.output_dir,'summary.csv'));
    writetable(struct2table(topology_summary), ...
        fullfile(cfg.output_dir,'topology_summary.csv'));
    writetable(struct2table(cal_rows),fullfile(cfg.output_dir,'calibration.csv'));
    writetable(struct2table(inventory),fullfile(cfg.output_dir,'topology_inventory.csv'));
    writetable(struct2table(seeds),fullfile(cfg.output_dir,'seed_manifest.csv'));
    protocol_identity=stage4a4_scientific_config_hash(struct( ...
        'version',cfg.version,'budget',budget,'frequency_hz',cfg.frequency_hz, ...
        'main_bounds',cfg.main_scale_bounds,'load_bounds',cfg.load_scale_bounds, ...
        'alpha',cfg.alpha,'margin',cfg.margin_threshold, ...
        'train_indices',cfg.frequency_train_indices, ...
        'holdout_indices',cfg.frequency_holdout_indices, ...
        'seed_manifest',seeds,'pool_signatures',{bank.candidate_signatures}));
    runtime_s=toc(started);
    peak_rss_kb=process_peak_rss_kb();
    meta=table(string(cfg.verification_baseline_commit),string(version), ...
        string(computer('arch')),string(protocol_identity),string(bank.identity), ...
        string(bank.search_identity),budget,numel(pool),numel(tests), ...
        bank.forward_calls,bank.logical_cache_bytes,peak_rss_kb, ...
        runtime_s,cfg.use_parallel,cfg.worker_count, ...
        string(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss')), ...
        'VariableNames',{'baseline_commit','matlab_version','computer_arch', ...
        'protocol_identity','bank_identity','search_identity','budget', ...
        'pool_size','test_observations','template_forward_calls', ...
        'template_cache_bytes','process_peak_rss_kb','runtime_s', ...
        'use_parallel','worker_count','verification_time_utc'});
    writetable(meta,fullfile(cfg.output_dir,'metadata.csv'));
    save(fullfile(cfg.output_dir,'config_snapshot.mat'), ...
        'cfg','grammar','groups','sigma','meta','-v7');
    stage7a6_write_inventory(root,cfg.output_dir,cfg.verification_baseline_commit);
    fprintf('Stage 7A.6 %s budget %d complete: %d decisions, %.2f s, peak RSS %.0f kB\n', ...
        mode,budget,numel(sample_rows),runtime_s,peak_rss_kb);
    out=struct('output_dir',cfg.output_dir,'runtime_s',runtime_s, ...
        'summary',summary,'protocol_identity',protocol_identity, ...
        'peak_rss_kb',peak_rss_kb);
end

function scored=score_batch(samples,flow,budget,views,sigma,pool,bank,base,cfg,base_ix)
    scored=cell(numel(samples),1);
    for i=1:numel(samples)
        if strcmp(flow,'B')
            scored{i}=stage7a5_score_observation(samples(i).observed,pool,bank, ...
                base,cfg,base_ix,views,sigma,'B',0,[]);
        else
            scored{i}=stage7a6_score_observation(samples(i).observed,pool,bank, ...
                base,cfg,base_ix,views,sigma,budget,[]);
        end
    end
end
function x=fit_values(scored)
    x=cellfun(@(s)s.fit_statistic,scored);
end
function delta=nonconformity(scored,samples)
    delta=zeros(numel(samples),1);
    for i=1:numel(samples)
        j=find(strcmp(scored{i}.candidate_ids,samples(i).truth_id),1);
        assert(~isempty(j),'stage7a6:CalibrationMissedTruth');
        delta(i)=scored{i}.distances(j)-min(scored{i}.distances);
    end
end
function sigma=estimate_sigma(samples)
    squared=zeros(1,2);
    for i=1:numel(samples)
        for v=1:2
            squared(v)=squared(v)+mean(abs(samples(i).observed{v}- ...
                samples(i).clean{v}).^2);
        end
    end
    sigma=sqrt(squared/numel(samples));
end
function assert_unique_scenarios(E,A,F,T)
    all=[E;A;F;T];
    seeds=[all.parameter_seed];
    noise=[all.noise_seed];
    assert(numel(unique(seeds))==numel(seeds)&& ...
        numel(unique(noise))==numel(noise)&& ...
        isempty(intersect(seeds,noise)), ...
        'stage7a6:SeedOverlap');
end
function [row,candidates]=evaluate_one(s,flow,budget,model,views,sigma, ...
        pool,bank,base,cfg,base_ix,steps)
    ticid=tic;
    if strcmp(flow,'B')
        scored=stage7a5_score_observation(s.observed,pool,bank,base,cfg, ...
            base_ix,views,sigma,'B',0,model);
        profile_evaluations=numel(base_ix);
    else
        scored=stage7a6_score_observation(s.observed,pool,bank,base,cfg, ...
            base_ix,views,sigma,budget,model);
        profile_evaluations=scored.profile_evaluations;
    end
    decision=stage7a5_decide(scored,model,bank);
    elapsed=toc(ticid);
    scheme=cfg.observation_schemes{find(cellfun(@(x)isequal(x,views), ...
        cfg.observation_views),1)};
    sample_id=sprintf('%s_%s_%03d',s.split,s.truth_id,s.replicate);
    ix=find(strcmp(scored.candidate_ids,s.truth_id),1);
    ordered=sortrows([(1:numel(scored.distances)).' scored.distances(:)],2);
    ranked=ordered(:,1).';
    best=scored.candidate_ids{ranked(1)};
    second='';second_d=NaN;
    if numel(ranked)>1
        second=scored.candidate_ids{ranked(2)};
        second_d=scored.distances(ranked(2));
    end
    truth_d=NaN;truth_rank=0;
    if ~isempty(ix)
        truth_d=scored.distances(ix);
        truth_rank=find(ranked==ix,1);
    end
    competitor='';competitor_d=NaN;
    jj=find(~strcmp(scored.candidate_ids(ranked),s.truth_id),1);
    if ~isempty(jj)
        competitor=scored.candidate_ids{ranked(jj)};
        competitor_d=scored.distances(ranked(jj));
    end
    unique=strcmp(decision.decision_state,'UNIQUE_CONFIDENT');
    truth_in_set=any(strcmp(decision.candidate_set,s.truth_id));
    truth_in_initial=ismember(s.truth_index,base_ix);
    truth_in_pool=s.truth_index<=numel(pool);
    generated=any(strcmp(scored.generated_ids,s.truth_id));
    row=sample_row();
    row.sample_id=sample_id;row.split=s.split;row.scenario=s.scenario;
    row.scheme=scheme;row.flow=flow;row.budget=budget;
    row.truth_id=s.truth_id;row.truth_signature=s.truth_signature;
    row.truth_in_initial=truth_in_initial;row.truth_in_search_pool=truth_in_pool;
    row.theoretically_reachable=isfinite(steps(s.truth_index));
    row.min_edit_steps=steps(s.truth_index);
    row.domain_out=s.domain_out;
    row.parameter_seed=s.parameter_seed;row.noise_seed=s.noise_seed;
    row.true_main_scale=s.theta_true.main_length_scale;
    row.true_load_scale=s.theta_true.branch_load_scale;
    row.generated=generated;row.active=~isempty(ix);
    row.not_generated=truth_in_pool&&~truth_in_initial&&~generated;
    row.pruned=generated&&~row.active;
    row.truth_in_set=truth_in_set;
    row.candidate_count=numel(scored.candidate_ids);
    row.profile_evaluations=profile_evaluations;
    row.optimizer_evaluations=scored.optimizer_evaluations;
    row.forward_calls=scored.optimizer_evaluations+scored.forward_model_calls_holdout;
    row.wall_clock_s=elapsed;
    row.best_candidate=best;row.second_candidate=second;
    row.truth_rank=truth_rank;row.truth_distance=truth_d;
    row.closest_competitor=competitor;row.competitor_distance=competitor_d;
    row.distance_1=decision.distance_1;row.distance_2=second_d;
    row.margin=decision.margin;
    row.candidate_set=strjoin(decision.candidate_set,';');
    row.set_size=decision.candidate_set_size;
    row.fit_statistic=decision.fit_statistic;
    row.fit_threshold=decision.fit_threshold;
    row.fit_pass=decision.fit_pass;
    row.search_truncated=decision.search_truncated;
    row.state=decision.decision_state;row.reason=decision.decision_reason;
    row.correct_unique=unique&&strcmp(best,s.truth_id);
    row.false_unique=unique&&~strcmp(best,s.truth_id);
    candidates=repmat(candidate_row(),numel(scored.candidate_ids),1);
    for j=1:numel(scored.candidate_ids)
        ci=scored.candidate_indices(j);
        c=candidate_row();
        c.sample_id=sample_id;c.split=s.split;c.scheme=scheme;
        c.flow=flow;c.budget=budget;c.truth_id=s.truth_id;
        c.candidate_id=scored.candidate_ids{j};
        c.signature=bank.candidate_signatures{ci};
        c.rank=find(ranked==j,1);
        c.distance=scored.distances(j);
        c.fit_main_scale=scored.params(j,1);
        c.fit_load_scale=scored.params(j,2);
        c.generated=any(strcmp(scored.generated_ids,c.candidate_id));
        c.truth_candidate=strcmp(c.candidate_id,s.truth_id);
        c.in_candidate_set=any(strcmp(decision.candidate_set,c.candidate_id));
        candidates(j)=c;
    end
end
function s=sample_row()
    s=struct('sample_id','','split','','scenario','','scheme','', ...
        'flow','','budget',0,'truth_id','','truth_signature','', ...
        'truth_in_initial',false,'truth_in_search_pool',false, ...
        'theoretically_reachable',false,'min_edit_steps',NaN, ...
        'domain_out',false,'parameter_seed',0,'noise_seed',0, ...
        'true_main_scale',NaN,'true_load_scale',NaN,'generated',false, ...
        'active',false,'not_generated',false,'pruned',false, ...
        'truth_in_set',false, ...
        'candidate_count',0,'profile_evaluations',0, ...
        'optimizer_evaluations',0,'forward_calls',0,'wall_clock_s',NaN, ...
        'best_candidate','','second_candidate','','truth_rank',0, ...
        'truth_distance',NaN,'closest_competitor','', ...
        'competitor_distance',NaN,'distance_1',NaN,'distance_2',NaN, ...
        'margin',NaN,'candidate_set','','set_size',0, ...
        'fit_statistic',NaN,'fit_threshold',NaN,'fit_pass',false, ...
        'search_truncated',false,'state','','reason','', ...
        'correct_unique',false,'false_unique',false);
end
function c=candidate_row()
    c=struct('sample_id','','split','','scheme','','flow','', ...
        'budget',0,'truth_id','','candidate_id','','signature','', ...
        'rank',0,'distance',NaN,'fit_main_scale',NaN,'fit_load_scale',NaN, ...
        'generated',false,'truth_candidate',false,'in_candidate_set',false);
end
function c=cal_row()
    c=struct('scheme','','flow','','budget',0,'A_n',0,'F_n',0, ...
        'set_threshold',NaN,'fit_threshold',NaN,'calibration_identity','', ...
        'bank_identity','','search_identity','');
end
function c=make_cal_row(scheme,flow,budget,model,A,F)
    c=cal_row();c.scheme=scheme;c.flow=flow;c.budget=budget;
    c.A_n=numel(A);c.F_n=numel(F);
    c.set_threshold=model.set_threshold;c.fit_threshold=model.fit_threshold;
    c.calibration_identity=model.calibration_identity;
    c.bank_identity=model.bank_identity;c.search_identity=model.search_identity;
end
function rows=summarize(samples,cfg)
    rows=repmat(struct('split','','scheme','','flow','','budget',0, ...
        'n',0,'correct_unique_k',0,'false_unique_k',0,'rejected_k',0, ...
        'ambiguous_k',0,'low_confidence_k',0,'truth_generated_k',0, ...
        'truth_not_generated_k',0,'truth_pruned_k',0, ...
        'truth_active_k',0,'truth_in_set_k',0,'nonempty_set_k',0, ...
        'truncated_k',0,'mean_set_size',NaN,'mean_scored_candidates',NaN, ...
        'mean_optimizer_evaluations',NaN,'mean_wall_clock_s',NaN, ...
        'correct_unique_low',NaN,'correct_unique_high',NaN, ...
        'false_unique_low',NaN,'false_unique_high',NaN),0,1);
    splits=unique({samples.split},'stable');
    for v=1:numel(cfg.observation_schemes)
        for f={'B','C'}
            flow=f{1};
            for g=1:numel(splits)
                ix=strcmp({samples.scheme},cfg.observation_schemes{v}) & ...
                    strcmp({samples.flow},flow) & strcmp({samples.split},splits{g});
                x=samples(ix);n=numel(x);
                assert(n>0,'stage7a6:MissingSummaryGroup');
                ck=sum([x.correct_unique]);fk=sum([x.false_unique]);
                [cl,ch]=stage7a4_wilson(ck,n);
                [fl,fh]=stage7a4_wilson(fk,n);
                q=rows_template();q.split=splits{g};q.scheme=cfg.observation_schemes{v};
                q.flow=flow;q.budget=x(1).budget;q.n=n;
                q.correct_unique_k=ck;q.false_unique_k=fk;
                q.rejected_k=sum(strcmp({x.state},'REJECTED'));
                q.ambiguous_k=sum(strcmp({x.state},'MULTIPLE_AMBIGUOUS'));
                q.low_confidence_k=sum(strcmp({x.state},'LOW_CONFIDENCE'));
                q.truth_generated_k=sum([x.generated]);
                q.truth_not_generated_k=sum([x.not_generated]);
                q.truth_pruned_k=sum([x.pruned]);
                q.truth_active_k=sum([x.active]);
                q.truth_in_set_k=sum([x.truth_in_set]);
                q.nonempty_set_k=sum([x.set_size]>0);
                q.truncated_k=sum([x.search_truncated]);
                q.mean_set_size=mean([x.set_size]);
                q.mean_scored_candidates=mean([x.candidate_count]);
                q.mean_optimizer_evaluations=mean([x.optimizer_evaluations]);
                q.mean_wall_clock_s=mean([x.wall_clock_s]);
                q.correct_unique_low=cl;q.correct_unique_high=ch;
                q.false_unique_low=fl;q.false_unique_high=fh;
                rows(end+1)=q; %#ok<AGROW>
            end
        end
    end
end
function q=rows_template()
    q=struct('split','','scheme','','flow','','budget',0, ...
        'n',0,'correct_unique_k',0,'false_unique_k',0,'rejected_k',0, ...
        'ambiguous_k',0,'low_confidence_k',0,'truth_generated_k',0, ...
        'truth_not_generated_k',0,'truth_pruned_k',0, ...
        'truth_active_k',0,'truth_in_set_k',0,'nonempty_set_k',0, ...
        'truncated_k',0,'mean_set_size',NaN,'mean_scored_candidates',NaN, ...
        'mean_optimizer_evaluations',NaN,'mean_wall_clock_s',NaN, ...
        'correct_unique_low',NaN,'correct_unique_high',NaN, ...
        'false_unique_low',NaN,'false_unique_high',NaN);
end
function rows=summarize_topologies(samples,cfg)
    rows=repmat(struct('split','','scenario','','scheme','','flow','', ...
        'budget',0,'n',0,'correct_unique_k',0,'false_unique_k',0, ...
        'rejected_k',0,'ambiguous_k',0,'low_confidence_k',0, ...
        'generated_k',0,'active_k',0,'truth_in_set_k',0, ...
        'correct_unique_low',NaN,'correct_unique_high',NaN, ...
        'false_unique_low',NaN,'false_unique_high',NaN),0,1);
    splits=unique({samples.split},'stable');
    for v=1:numel(cfg.observation_schemes)
        for f={'B','C'}
            for g=1:numel(splits)
                scenarios=unique({samples(strcmp({samples.split},splits{g})).scenario}, ...
                    'stable');
                for h=1:numel(scenarios)
                    ix=strcmp({samples.scheme},cfg.observation_schemes{v}) & ...
                        strcmp({samples.flow},f{1}) & ...
                        strcmp({samples.split},splits{g}) & ...
                        strcmp({samples.scenario},scenarios{h});
                    x=samples(ix);n=numel(x);
                    [cl,ch]=stage7a4_wilson(sum([x.correct_unique]),n);
                    [fl,fh]=stage7a4_wilson(sum([x.false_unique]),n);
                    rows(end+1)=struct('split',splits{g}, ...
                        'scenario',scenarios{h}, ...
                        'scheme',cfg.observation_schemes{v},'flow',f{1}, ...
                        'budget',x(1).budget,'n',n, ...
                        'correct_unique_k',sum([x.correct_unique]), ...
                        'false_unique_k',sum([x.false_unique]), ...
                        'rejected_k',sum(strcmp({x.state},'REJECTED')), ...
                        'ambiguous_k',sum(strcmp({x.state},'MULTIPLE_AMBIGUOUS')), ...
                        'low_confidence_k',sum(strcmp({x.state},'LOW_CONFIDENCE')), ...
                        'generated_k',sum([x.generated]), ...
                        'active_k',sum([x.active]), ...
                        'truth_in_set_k',sum([x.truth_in_set]), ...
                        'correct_unique_low',cl,'correct_unique_high',ch, ...
                        'false_unique_low',fl,'false_unique_high',fh); %#ok<AGROW>
                end
            end
        end
    end
end
function rows=topology_inventory(catalog,pool,base_ix,steps)
    old=cellfun(@(x)~startsWith(x,'EXT_'),{pool.topology_id});
    rows=repmat(struct('topology_id','','signature','', ...
        'in_initial_library',false,'in_old_ten',false, ...
        'in_expanded_pool',false,'min_edit_steps',NaN),numel(catalog),1);
    for k=1:numel(catalog)
        rows(k)=struct('topology_id',catalog(k).topology_id, ...
            'signature',stage6b_network_signature(catalog(k).network), ...
            'in_initial_library',ismember(k,base_ix), ...
            'in_old_ten',k<=numel(pool)&&old(min(k,numel(pool))), ...
            'in_expanded_pool',k<=numel(pool), ...
            'min_edit_steps',steps(k));
    end
end
function rows=seed_manifest(cfg)
    names={'E','A','F','T_inlib','T_old_out','T_reachable', ...
        'T_grammar_out','T_domain'};
    bases=[cfg.seed_E cfg.seed_A cfg.seed_F cfg.seed_T_inlib, ...
        cfg.seed_T_old_out cfg.seed_T_reachable ...
        cfg.seed_T_grammar_out cfg.seed_T_domain];
    n=[cfg.n_E_per_class cfg.n_A_per_class cfg.n_F_per_class, ...
        cfg.n_T_inlib_per_topology cfg.n_T_old_out_per_topology, ...
        cfg.n_T_reachable_per_topology cfg.n_T_grammar_out_per_topology, ...
        cfg.n_T_domain_per_topology];
    rows=repmat(struct('split','','seed_base',0, ...
        'replicates_per_topology',0),numel(names),1);
    for k=1:numel(names)
        rows(k)=struct('split',names{k},'seed_base',bases(k), ...
            'replicates_per_topology',n(k));
    end
end
function peak=process_peak_rss_kb()
    peak=NaN;
    if ~isunix,return;end
    data=fileread('/proc/self/status');
    token=regexp(data,'VmHWM:\s*(\d+)\s*kB','tokens','once');
    if ~isempty(token),peak=str2double(token{1});end
end
