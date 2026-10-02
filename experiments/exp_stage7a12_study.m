function result=exp_stage7a12_study(root,mode,run_id)
%EXP_STAGE7A12_STUDY Paired low-frequency CI generation and H50 confirmation.
%   Truth/parameter labels remain only in this experiment and its CSV audit.
%   Scoring functions receive observations, graph banks and frozen gates.
    assert(~isempty(regexp(run_id,'^[A-Za-z0-9_]+$','once')), ...
        'stage7a12:RunId');
    base=default_config(root);cfg=stage7a12_config(base,mode);
    out=fullfile(cfg.output_dir,run_id);
    assert(exist(out,'dir')~=7,'stage7a12:ExistingRun');
    clock_start=datetime('now','TimeZone','UTC');all_time=tic;
    [pool,~,~,catalog]=stage7a6_candidate_space(base);
    [~,~,~,extra_catalog]=stage7a7_candidate_space(base, ...
        stage7a7_config(base,'formal','nominal'));
    catalog=[catalog(:);extra_catalog(end-1:end)];
    dev=take(catalog,cfg.dev_ids);test_graphs=take(catalog,cfg.test_ids);
    fixed=take(catalog,{'G001','G002','G003','MIRROR_M3', ...
        'ADD_M1_M3','EXT_111'});
    bank=stage7a4_template_bank(pool,base,cfg);
    fixed_bank=stage7a4_template_bank(fixed,base,cfg);
    prior=load(fullfile(root,'results','data','stage7a_11','formal', ...
        'formal1','config_snapshot.mat'),'fixed_cal');
    assert(strcmp(prior.fixed_cal{2}.model_d.bank_identity,fixed_bank.identity), ...
        'stage7a12:FrozenBankIdentity');
    lf_cal=calibrate_lf(dev,cfg);
    cfr_model=calibrate_cfr(dev,pool,bank,base,cfg);
    cal_wall=toc(all_time);
    [samples,~]=stage7a4_generate_split(test_graphs,1:numel(test_graphs), ...
        base,cfg,cfg.seed_cfr_T,cfg.n_test_per_graph,20,'standard');
    rows=repmat(sample_row(),0,1);ci_rows=repmat(ci_row(),0,1);
    conditions={'synchronous','asynchronous','high_noise'};
    for i=1:numel(samples)
        s=samples(i);truth=test_graphs(s.truth_global_index);
        true_sig=stage6b_network_signature(truth.network);
        lf_network=truth.network;
        lf_network.main_lengths=lf_network.main_lengths* ...
            s.theta.main_length_scale;
        ci_true=stage7a12_ci_matrix(lf_network,cfg);
        tic_ideal=tic;
        ideal=stage7a12_generate_candidates(ci_true.R,ci_true.labels, ...
            pool,cfg,1e-12,cfg.lf_top_k);
        ideal_wall=toc(tic_ideal);
        for c=1:numel(conditions)
            condition=conditions{c};
            seed=cfg.seed_lf_test+i*1000;
            tic_measure=tic;
            low=stage7a12_measure_ci(ci_true,cfg,seed,condition);
            measure_wall=toc(tic_measure);
            tic_estimate=tic;
            estimate=stage7a12_estimate_ci(low,cfg.lf_ridge_lambda);
            estimate_wall=toc(tic_estimate);
            timer=tic;
            generated=stage7a12_generate_candidates(estimate.symmetric_ridge, ...
                ci_true.labels,pool,cfg,lf_cal.tolerance,cfg.lf_top_k);
            generation_wall=toc(timer);
            tic_noinfo=tic;
            noinfo=stage7a12_noinfo_candidates(ci_true.labels,pool,cfg, ...
                generated.candidate_count,cfg.seed_lf_test+700000+i*100);
            noinfo_wall=toc(tic_noinfo);
            cr=ci_row();cr.sample_id=i;cr.truth_id=string(truth.topology_id);
            cr.condition=string(condition);cr.meter_count=numel(ci_true.labels);
            cr.true_main_scale=s.theta.main_length_scale;
            cr.shifted_meter_count=nnz(low.shifts);
            cr.ols_rms=rmse(estimate.ols,ci_true.R);
            cr.post_rms=rmse(estimate.post_symmetric,ci_true.R);
            cr.symmetric_ridge_rms=rmse(estimate.symmetric_ridge,ci_true.R);
            cr.measure_wall_s=measure_wall;
            cr.estimation_wall_s=estimate_wall;
            cr.estimated_R=string(mat2str(estimate.symmetric_ridge,12));
            cr.truth_R=string(mat2str(ci_true.R,12));
            ci_rows(end+1)=cr; %#ok<AGROW>
            base_methods={'A_D_samecal_3','A_D_samecal_6','J_frozen_6', ...
                'B_ideal_ci','C_estimated_ci','D_count_matched'};
            for k=1:numel(base_methods)
                method=base_methods{k};tick=tic;
                switch method
                    case 'A_D_samecal_3'
                        z=stage7a10_decide(s.observed,fixed_bank, ...
                            prior.fixed_cal{1}.model_d);
                        chosen=1:3;eligible=1:3;source_bank=fixed_bank;
                        gen_time=0;graph_search_wall=0;gen_scores=[];
                    case 'A_D_samecal_6'
                        z=stage7a10_decide(s.observed,fixed_bank, ...
                            prior.fixed_cal{2}.model_d);
                        chosen=1:6;eligible=1:6;source_bank=fixed_bank;
                        gen_time=0;graph_search_wall=0;gen_scores=[];
                    case 'J_frozen_6'
                        z=stage7a11_decide(s.observed,fixed_bank, ...
                            prior.fixed_cal{2}.model_j);
                        chosen=1:6;eligible=1:6;source_bank=fixed_bank;
                        gen_time=0;graph_search_wall=0;gen_scores=[];
                    case 'B_ideal_ci'
                        chosen=ideal.indices;eligible=ideal.eligible_indices;
                        z=stage7a12_confirm(s.observed,bank,cfr_model,chosen,eligible);
                        source_bank=bank;gen_time=ideal_wall;
                        graph_search_wall=ideal_wall;gen_scores=ideal.scores;
                    case 'C_estimated_ci'
                        chosen=generated.indices;eligible=generated.eligible_indices;
                        z=stage7a12_confirm(s.observed,bank,cfr_model,chosen,eligible);
                        source_bank=bank;
                        gen_time=measure_wall+estimate_wall+generation_wall;
                        graph_search_wall=generation_wall;
                        gen_scores=generated.scores;
                    otherwise
                        chosen=noinfo;eligible=generated.eligible_indices;
                        z=stage7a12_confirm(s.observed,bank,cfr_model,chosen,eligible);
                        source_bank=bank;gen_time=noinfo_wall;
                        graph_search_wall=noinfo_wall;gen_scores=[];
                end
                r=sample_row();r.sample_id=i;r.condition=string(condition);
                r.method=string(method);r.truth_id=string(truth.topology_id);
                r.truth_signature=string(true_sig);
                r.truth_in_initial=ismember(truth.topology_id,cfg.initial_ids);
                r.truth_in_confirm_library=ismember(truth.topology_id, ...
                    source_bank.candidate_ids(chosen));
                r.truth_generated=r.truth_in_confirm_library;
                r.meter_count=numel(ci_true.labels);
                r.parameter_seed=s.parameter_seed;r.cfr_noise_seed=s.noise_seed;
                r.lf_seed=seed;r.candidate_count=numel(chosen);
                r.true_main_scale=s.theta.main_length_scale;
                r.eligible_count=numel(eligible);
                r.candidate_ids=string(strjoin(source_bank.candidate_ids(chosen),','));
                r.candidate_signatures=string(strjoin( ...
                    source_bank.candidate_signatures(chosen),';'));
                r.generated_rank=rank_of_truth(eligible,source_bank.candidate_ids, ...
                    truth.topology_id);
                structural=stage7a12_structure_audit(truth.network, ...
                    source_bank_to_graphs(chosen,source_bank,pool,fixed));
                r.min_wrong_branch_edges=structural.min_wrong_branch_edges;
                r.truth_hidden_junction_count=structural.truth_hidden_junction_count;
                r.max_recovered_hidden_junctions= ...
                    structural.max_recovered_hidden_junctions;
                r.generator_scores=string(mat2str(gen_scores,12));
                r.best_candidate=string(z.best_candidate);
                r.candidate_set=string(z.candidate_set);
                r.candidate_set_size=z.candidate_set_size;
                r.decision_state=string(z.decision_state);
                r.decision_reason=string(z.decision_reason);
                r.truth_in_set=ismember(truth.topology_id, ...
                    strsplit(z.candidate_set,','));
                r.correct_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT')&& ...
                    strcmp(z.best_candidate,truth.topology_id);
                r.false_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT')&& ...
                    ~r.correct_unique;
                r.distance=z.distance;r.margin=z.margin;
                r.generation_wall_s=gen_time;
                r.graph_search_wall_s=graph_search_wall;
                r.lf_measure_wall_s=measure_wall;
                r.lf_estimation_wall_s=estimate_wall;
                r.confirmation_wall_s=toc(tick);
                rows(end+1)=r; %#ok<AGROW>
            end
        end
        if mod(i,cfg.n_test_per_graph)==0
            fprintf('Stage 7A.12: %d/%d paired test observations.\n', ...
                i,numel(samples));
        end
    end
    sample_table=struct2table(rows);ci_table=struct2table(ci_rows);
    summary=summarize(sample_table);
    catalog_table=graph_catalog(pool,test_graphs,cfg);
    metadata=struct('stage',string(cfg.stage),'run_id',string(run_id), ...
        'mode',string(mode),'baseline_commit',string(cfg.baseline_commit), ...
        'matlab_version',string(version),'computer_arch',string(computer('arch')), ...
        'start_utc',string(clock_start),'parallel_workers',0, ...
        'bank_identity',string(bank.identity), ...
        'frozen_bank_identity',string(fixed_bank.identity), ...
        'lf_tolerance_ohm',lf_cal.tolerance, ...
        'cfr_class_threshold',cfr_model.class_threshold, ...
        'cfr_fit_threshold',cfr_model.fit_threshold, ...
        'cfr_sigma_h50',cfr_model.sigma(5), ...
        'lf_cal_seed',cfg.seed_lf_cal,'lf_test_seed',cfg.seed_lf_test, ...
        'cfr_E_seed',cfg.seed_cfr_E,'cfr_A_seed',cfg.seed_cfr_A, ...
        'cfr_F_seed',cfg.seed_cfr_F,'cfr_T_seed',cfg.seed_cfr_T, ...
        'lf_cal_n',lf_cal.n,'cfr_cal_n',cfr_model.cal_n, ...
        'template_forward_calls',bank.forward_calls+fixed_bank.forward_calls, ...
        'template_logical_bytes',bank.logical_cache_bytes+ ...
            fixed_bank.logical_cache_bytes, ...
        'calibration_wall_s',cal_wall,'total_wall_s',toc(all_time));
    mkdir(out);
    writetable(sample_table,fullfile(out,'samples.csv'));
    writetable(ci_table,fullfile(out,'ci_estimation.csv'));
    writetable(summary,fullfile(out,'summary.csv'));
    writetable(catalog_table,fullfile(out,'graph_catalog.csv'));
    writetable(struct2table(metadata),fullfile(out,'metadata.csv'));
    save(fullfile(out,'config_snapshot.mat'),'cfg','metadata','lf_cal', ...
        'cfr_model','catalog_table');
    fprintf('PASS Stage 7A.12 %s %s: %d rows, %.3f s\n', ...
        mode,run_id,height(sample_table),metadata.total_wall_s);
    result=struct('output_dir',out,'summary',summary,'metadata',metadata);
end

function out=take(catalog,ids)
    all={catalog.topology_id};
    out=repmat(struct('topology_id','','network',struct()),1,numel(ids));
    for k=1:numel(ids)
        j=find(strcmp(all,ids{k}),1);
        assert(~isempty(j),'stage7a12:MissingGraph');
        out(k)=struct('topology_id',ids{k},'network',catalog(j).network);
    end
end
function cal=calibrate_lf(graphs,cfg)
    errors=zeros(1,numel(graphs)*cfg.n_lf_cal_per_graph);p=0;
    for k=1:numel(graphs)
        for r=1:cfg.n_lf_cal_per_graph
            p=p+1;seed=cfg.seed_lf_cal+k*100000+r;
            scale_rng=RandStream('mt19937ar','Seed',seed+500000000);
            scale=cfg.true_main_bounds(1)+diff(cfg.true_main_bounds)* ...
                rand(scale_rng);
            lf_network=graphs(k).network;
            lf_network.main_lengths=lf_network.main_lengths*scale;
            ci=stage7a12_ci_matrix(lf_network,cfg);
            m=stage7a12_measure_ci(ci,cfg,seed,'asynchronous');
            e=stage7a12_estimate_ci(m,cfg.lf_ridge_lambda);
            errors(p)=rmse(e.symmetric_ridge,ci.R);
        end
    end
    cal=struct('n',p,'seed_base',cfg.seed_lf_cal, ...
        'tolerance',quantile_ceil(errors,0.95),'errors',errors);
end
function model=calibrate_cfr(dev,pool,bank,base,cfg)
    E=stage7a4_generate_split(dev,1:numel(dev),base,cfg, ...
        cfg.seed_cfr_E,cfg.n_cfr_cal_per_graph,20,'standard');
    sigma=stage7a4_calibrate_view_scales(E,cfg);
    A=stage7a4_generate_split(dev,1:numel(dev),base,cfg, ...
        cfg.seed_cfr_A,cfg.n_cfr_cal_per_graph,20,'standard');
    F=stage7a4_generate_split(dev,1:numel(dev),base,cfg, ...
        cfg.seed_cfr_F,cfg.n_cfr_cal_per_graph,20,'standard');
    a=zeros(1,numel(A));f=zeros(1,numel(F));ids={pool.topology_id};
    for i=1:numel(A)
        id=dev(A(i).truth_global_index).topology_id;
        j=find(strcmp(ids,id),1);assert(~isempty(j));
        x=stage7a4_profile_views(A(i).observed,bank,j,5,sigma);
        a(i)=x.distances;
    end
    for i=1:numel(F)
        id=dev(F(i).truth_global_index).topology_id;
        j=find(strcmp(ids,id),1);assert(~isempty(j));
        x=stage7a4_profile_views(F(i).observed,bank,j,5,sigma);
        f(i)=x.distances;
    end
    model=struct('bank_identity',bank.identity, ...
        'candidate_signatures',{bank.candidate_signatures}, ...
        'sigma',sigma,'class_threshold',quantile_ceil(a,0.95), ...
        'fit_threshold',quantile_ceil(f,0.95), ...
        'margin_threshold',cfg.separation_threshold, ...
        'cal_n',numel(A),'E_seed',cfg.seed_cfr_E, ...
        'A_seed',cfg.seed_cfr_A,'F_seed',cfg.seed_cfr_F);
end
function q=quantile_ceil(x,p)
    x=sort(x(:));q=x(min(numel(x),ceil((numel(x)+1)*p)));
end
function e=rmse(x,y)
    e=norm(x-y,'fro')/sqrt(numel(y));
end
function r=rank_of_truth(order,ids,truth)
    r=find(strcmp(ids(order),truth),1);
    if isempty(r),r=NaN;end
end
function graphs=source_bank_to_graphs(chosen,source_bank,pool,fixed)
    if strcmp(source_bank.candidate_ids{1},pool(1).topology_id) && ...
            numel(source_bank.candidate_ids)==numel(pool)
        graphs=pool(chosen);
    else
        graphs=fixed(chosen);
    end
end
function out=graph_catalog(pool,test_graphs,cfg)
    ids={pool.topology_id};
    missing=test_graphs(~ismember({test_graphs.topology_id},ids));
    all_graphs=repmat(struct('topology_id','','network',struct()), ...
        numel(pool)+numel(missing),1);
    for k=1:numel(pool)
        all_graphs(k)=struct('topology_id',pool(k).topology_id, ...
            'network',pool(k).network);
    end
    all_graphs(numel(pool)+(1:numel(missing)))=missing(:);
    n=numel(all_graphs);rows=repmat(struct('graph_id',"",'signature',"", ...
        'branch_count',0,'development',false,'formal_test',false, ...
        'initial_library',false,'searchable',false),n,1);
    for k=1:n
        id=all_graphs(k).topology_id;
        rows(k)=struct('graph_id',string(id), ...
            'signature',string(stage6b_network_signature(all_graphs(k).network)), ...
            'branch_count',numel(all_graphs(k).network.branches), ...
            'development',ismember(id,cfg.dev_ids), ...
            'formal_test',ismember(id,cfg.test_ids), ...
            'initial_library',ismember(id,cfg.initial_ids), ...
            'searchable',k<=numel(pool));
    end
    out=struct2table(rows);
end
function out=summarize(samples)
    keys=unique(samples(:,{'condition','method','truth_id'}));
    rows=repmat(summary_row(),height(keys),1);
    for j=1:height(keys)
        key=keys(j,:);x=samples(samples.condition==key.condition & ...
            samples.method==key.method & samples.truth_id==key.truth_id,:);
        r=summary_row();r.condition=key.condition;r.method=key.method;
        r.truth_id=key.truth_id;r.n=height(x);
        r.original_library_in=all(x.truth_in_initial);
        r.generated_truth_k=nnz(x.truth_generated);
        r.correct_unique_k=nnz(x.correct_unique);
        r.false_unique_k=nnz(x.false_unique);
        r.truth_in_set_k=nnz(x.truth_in_set);
        r.nonempty_set_k=nnz(x.candidate_set_size>0);
        r.unique_k=nnz(x.decision_state=="UNIQUE_CONFIDENT");
        r.ambiguous_k=nnz(x.decision_state=="MULTIPLE_AMBIGUOUS");
        r.low_confidence_k=nnz(x.decision_state=="LOW_CONFIDENCE");
        r.rejected_k=nnz(x.decision_state=="REJECTED");
        r.mean_candidate_count=mean(x.candidate_count);
        r.mean_set_size=mean(x.candidate_set_size);
        r.mean_generator_wall_s=mean(x.generation_wall_s);
        r.mean_confirm_wall_s=mean(x.confirmation_wall_s);
        rows(j)=r;
    end
    out=struct2table(rows);
end
function r=sample_row()
    r=struct('sample_id',0,'condition',"",'method',"",'truth_id',"", ...
        'truth_signature',"",'truth_in_initial',false, ...
        'truth_in_confirm_library',false,'truth_generated',false, ...
        'meter_count',0,'parameter_seed',0,'cfr_noise_seed',0, ...
        'true_main_scale',NaN, ...
        'lf_seed',0,'candidate_count',0,'eligible_count',0, ...
        'candidate_ids',"",'candidate_signatures',"", ...
        'generated_rank',NaN,'generator_scores',"", ...
        'best_candidate',"",'candidate_set',"",'candidate_set_size',0, ...
        'decision_state',"",'decision_reason',"", ...
        'truth_in_set',false,'correct_unique',false,'false_unique',false, ...
        'distance',NaN,'margin',NaN,'generation_wall_s',NaN, ...
        'graph_search_wall_s',NaN,'lf_measure_wall_s',NaN, ...
        'lf_estimation_wall_s',NaN,'confirmation_wall_s',NaN, ...
        'min_wrong_branch_edges',NaN, ...
        'truth_hidden_junction_count',NaN, ...
        'max_recovered_hidden_junctions',NaN);
end
function r=ci_row()
    r=struct('sample_id',0,'truth_id',"",'condition',"", ...
        'meter_count',0,'shifted_meter_count',0,'true_main_scale',NaN, ...
        'ols_rms',NaN, ...
        'post_rms',NaN,'symmetric_ridge_rms',NaN, ...
        'estimated_R',"",'truth_R',"", ...
        'measure_wall_s',NaN,'estimation_wall_s',NaN);
end
function r=summary_row()
    r=struct('condition',"",'method',"",'truth_id',"",'n',0, ...
        'original_library_in',false,'generated_truth_k',0, ...
        'correct_unique_k',0,'false_unique_k',0,'truth_in_set_k',0, ...
        'nonempty_set_k',0,'unique_k',0,'ambiguous_k',0, ...
        'low_confidence_k',0,'rejected_k',0, ...
        'mean_candidate_count',NaN,'mean_set_size',NaN, ...
        'mean_generator_wall_s',NaN,'mean_confirm_wall_s',NaN);
end
