function out = exp_stage4a5_multiscale_confirmation(cfg,sc)
%EXP_STAGE4A5_MULTISCALE_CONFIRMATION Develop and replicate M0--M3.
%   Forward responses are cached once per grid/scenario.  Raw full-band,
%   subband, top-K and block-stability evidence is then shared by methods.
    if nargin<1||isempty(cfg),root=fileparts(fileparts(mfilename('fullpath')));cfg=default_config(root);end
    if nargin<2||isempty(sc),sc=stage4a5_multiscale_confirmation_config(cfg,'formal');end
    root=cfg.root_dir;ensure_result_dirs(cfg);if ~exist(sc.cache_dir,'dir'),mkdir(sc.cache_dir);end
    started=tic;source_hash=stage4a5_source_tree_hash(root);bank=generate_stage4a5_trial_bank(sc,'all');base=generate_radial_topology_candidates(sc.generator);theta_grid=topology_parameter_grid(sc.parameter_search);specs=stage4a5_method_specs(sc);
    [global_hash,canonical_text]=scientific_hash(cfg,sc,base,theta_grid,source_hash);write_baseline(cfg,sc,global_hash);
    splits={bank.split}; grids=sc.grids; final_decisions=repmat(decision_template(),0,1);final_labels=repmat(label_template(),0,1);dev_metrics=repmat(metric_template_for_selection(),0,1);seed_metrics=repmat(metric_template_for_selection(),0,1);selection_rows=repmat(selection_output_template(),0,1);threshold_rows=repmat(threshold_output_template(),0,1);runtime_rows=repmat(runtime_output_template(),0,1);raw_rows=repmat(raw_output_template(),0,1);subband_rows=repmat(subband_output_template(),0,1);grid_rows=repmat(grid_output_template(),0,1);
    for fg=1:numel(grids)
        grid=grids(fg);f=grid.frequency_hz(:).';[sets4,sm4]=stage4a5_make_subbands(f,4,grid.id,global_hash);[sets8,sm8]=stage4a5_make_subbands(f,8,grid.id,global_hash);subband_rows=[subband_rows;sm4;sm8];grid_rows(end+1)=make_grid_output(grid,global_hash);fprintf('Stage 4A.5 grid %s (%d points)\n',grid.id,numel(f));
        observations=make_observations(bank,f,cfg,sc.measurement_kind);set_by_m={4,{sets4},8,{sets8}}; %#ok<NASGU>
        p0=generate_prior_constrained_candidates(sc.generator,sc.scenarios(1).asset_prior);p0_cache=load_or_build_cache(cfg,sc,grid,p0,theta_grid,global_hash,'P0_no_prior');p0_audit=p0_cache.current_equivalence_audit;
        p0_raw=score_bank(observations,p0_cache,bank,sets8,sc,'all');p0_labels=build_stage4a5_truth_labels(bank,p0_audit,p0_audit,p0,sc.parameter_search,grid.id,'P0_no_prior',global_hash);
        chosen=select_on_development(p0_raw,p0_labels,sc,specs,grid.id,global_hash);selection_rows(end+1)=chosen.output;dev_metrics=[dev_metrics;chosen.metrics];fprintf('  selected methods: M1=%s, M2=%s, M3=%s\n',chosen.m1.method_id,chosen.m2.method_id,chosen.m3.method_id);
        final_specs=[specs(strcmp({specs.family},'M0'));chosen.m1;chosen.m2;chosen.m3];
        [fd,fl,thr,rr,raw_out,p0_models]=finalize_scenario(p0_raw,p0_labels,bank,sc,grid,p0_cache,final_specs,global_hash,'P0_no_prior',true,{});final_decisions=[final_decisions;fd];final_labels=[final_labels;fl];threshold_rows=[threshold_rows;thr];runtime_rows=[runtime_rows;rr];raw_rows=[raw_rows;raw_out];
        for ss=2:numel(sc.scenarios)
            scenario=sc.scenarios(ss);candidates=generate_prior_constrained_candidates(sc.generator,scenario.asset_prior);cache=load_or_build_cache(cfg,sc,grid,candidates,theta_grid,global_hash,scenario.id);raw=score_bank(observations,cache,bank,sets8,sc,'final');labs=build_stage4a5_truth_labels(bank,p0_audit,cache.current_equivalence_audit,candidates,sc.parameter_search,grid.id,scenario.id,global_hash);[fd,fl,thr,rr,raw_out]=finalize_scenario(raw,labs,bank,sc,grid,cache,final_specs,global_hash,scenario.id,false,p0_models);final_decisions=[final_decisions;fd];final_labels=[final_labels;fl];threshold_rows=[threshold_rows;thr];runtime_rows=[runtime_rows;rr];raw_rows=[raw_rows;raw_out];clear cache raw labs fd fl thr rr raw_out;
        end
        clear p0_cache p0_raw observations;
    end
    final_metrics=evaluate_stage4a5_metrics(final_decisions,final_labels);seed_metrics=[seed_metrics;metrics_to_seed_summary(final_metrics)];write_outputs(cfg,sc,bank,final_decisions,final_labels,final_metrics,seed_metrics,selection_rows,threshold_rows,runtime_rows,grid_rows,subband_rows,raw_rows,dev_metrics,global_hash,canonical_text,source_hash);make_figures(cfg,final_metrics,selection_rows);out=struct('runtime_s',toc(started),'source_tree_hash',source_hash,'scientific_hash',global_hash,'selection',selection_rows,'metrics',final_metrics,'seed_metrics',seed_metrics,'runtime',runtime_rows);fprintf('Stage 4A.5 completed in %.3f s\n',out.runtime_s);
end

function obs=make_observations(bank,f,cfg,kind)
    % Generate each truth observation once; all methods reuse this cell.
    obs=cell(numel(bank),1);
    for k=1:numel(bank)
        [net,lc]=topology_apply_parameters(bank(k).truth_network,cfg,bank(k).truth_theta);
        [measurement,~]=plc_measurement_bundle(kind,net,bank(k).truth_theta,lc);
        [obs{k},~]=plc_multiview_response(f,net,measurement,lc);
    end
end

function raw=score_bank(obs,cache,bank,sets8,sc,mode)
    raw=cell(numel(bank),1);mode=lower(char(mode));
    if strcmp(mode,'development'),idx=find(~ismember({bank.split},{'final_replication_calibration','final_replication_test'}));
    elseif strcmp(mode,'final'),idx=find(ismember({bank.split},{'final_replication_calibration','final_replication_test'}));
    elseif strcmp(mode,'all'),idx=1:numel(bank);
    else,error('stage4a5:InvalidScoreMode','Unknown score-bank mode %s.',mode);end
    for q=1:numel(idx),i=idx(q);o=struct('repetitions',sc.bootstrap_repetitions,'block_count',sc.block_count,'block_fraction',sc.block_fraction,'stability_seed',stability_seed(bank(i)));raw{i}=score_stage4a5_observation(obs{i},cache,sets8,o);raw{i}.sample_id=bank(i).sample_id;raw{i}.replicate_id=bank(i).replicate_id;raw{i}.split=bank(i).split;end
end

function selected=select_on_development(raw,labels,sc,specs,grid_id,hash)
    rows=repmat(metric_template_for_selection(),0,1);for r=1:numel(sc.development_seeds),rep=sprintf('dev%02d',r);cal=find(strcmp({labels.replicate_id},rep)&strcmp({labels.split},'development_calibration'));val=find(strcmp({labels.replicate_id},rep)&strcmp({labels.split},'development_validation'));if isempty(cal)||isempty(val),continue;end
        model=calibrate_stage4a5_confirmation([raw{cal}],sc,grid_id,hash,sc.development_seeds(r));for s=1:numel(specs),dec=apply_spec_subset(raw(val),model,specs(s));dd=decision_rows(dec,labels(val),specs(s));ll=labels(val);mm=evaluate_stage4a5_metrics(dd,ll);rows=[rows;selection_metrics(mm)];end
    end
    sel=select_stage4a5_method(rows,specs,sc);m1=select_family(sel,specs,'M1');m2=select_family(sel,specs,'M2');m3=select_family(sel,specs,'M3');out=selection_output_template();out.grid_id=grid_id;out.M1_method_id=m1.method_id;out.M1_M=m1.M;out.M1_q=m1.q;out.M1_K=m1.K;out.M1_stability_threshold=m1.stability_threshold;out.M2_method_id=m2.method_id;out.M2_M=m2.M;out.M2_q=m2.q;out.M2_K=m2.K;out.M2_stability_threshold=m2.stability_threshold;out.M3_method_id=m3.method_id;out.M3_M=m3.M;out.M3_q=m3.q;out.M3_K=m3.K;out.M3_stability_threshold=m3.stability_threshold;out.M0_method_id='M0_M0_q900_K5_qs00';out.scientific_hash=hash;out.selection_basis='development validation only';
    selected=struct('m1',m1,'m2',m2,'m3',m3,'output',out,'metrics',rows);
end

function s=select_family(sel,specs,fam),x=sel(strcmp({sel.family},fam));if isempty(x),error('stage4a5:FamilySelection','No selected %s method.',fam);end;s=specs(strcmp({specs.method_id},x(1).method_id));end

function [decisions,labels_out,thresholds,runtime,raw_out,model_bank]=finalize_scenario(raw,labels,bank,sc,grid,cache,specs,hash,scenario_id,is_p0,prior_models)
    if nargin<11,prior_models={};end
    decisions=repmat(decision_template(),0,1);labels_out=repmat(label_template(),0,1);thresholds=repmat(threshold_output_template(),0,1);runtime=repmat(runtime_output_template(),0,1);raw_out=repmat(raw_output_template(),0,1);reps=stable_unique({bank.replicate_id});model_bank=cell(1,numel(reps));
    for r=1:numel(reps)
        rep=reps{r};cal=find(strcmp({labels.replicate_id},rep)&strcmp({labels.split},'final_replication_calibration'));test=find(strcmp({labels.split},'final_replication_test')&strcmp({labels.replicate_id},rep));
        if isempty(test),continue;end
        if is_p0
            if isempty(cal),continue;end
            model=calibrate_stage4a5_confirmation([raw{cal}],sc,grid.id,hash,seed_for_rep(sc.final_seeds,rep));model_bank{r}=model;
        else
            if numel(prior_models)<r||isempty(prior_models{r}),error('stage4a5:MissingCalibrationModel','Missing frozen P0 calibration model for %s.',rep);end
            model=prior_models{r};
        end
        for s=1:numel(specs),dec=apply_spec_subset(raw(test),model,specs(s));d=decision_rows(dec,labels(test),specs(s));decisions=[decisions;d];labels_out=[labels_out;label_rows(labels(test))];end
        thresholds(end+1)=make_threshold_output(grid,rep,model,hash);runtime(end+1)=make_runtime_output(grid,scenario_id,cache,rep,hash);for j=1:numel(test),raw_out(end+1)=make_raw_output(raw{test(j)},labels(test(j)));end
    end
end

function d=apply_spec_subset(raw,model,spec)
    if isempty(raw),d=struct([]);return;end
    for k=1:numel(raw)
        if iscell(raw),x=raw{k};else,x=raw(k);end
        y=apply_stage4a5_confirmation(x,model,spec);
        if k==1,d=y;else,d(k)=y;end
    end
    d=d(:);
end
function rows=decision_rows(x,labs,spec),rows=repmat(decision_template(),numel(x),1);for k=1:numel(x),r=decision_template();r.sample_id=x(k).sample_id;r.replicate_id=x(k).replicate_id;r.split=x(k).split;r.grid_id=x(k).cache_frequency_grid_id;r.scenario_id=labs(k).scenario_id;r.method_id=x(k).method_id;r.method_family=x(k).method_family;r.decision=x(k).decision;r.decision_reason=x(k).decision_reason;r.best_template_id=x(k).best_template_id;r.best_topology_id=x(k).best_topology_id;r.best_equivalence_class=x(k).best_equivalence_class;r.accepted_topology_set=x(k).accepted_topology_set;r.baseline_P0_equivalence_class=x(k).baseline_P0_equivalence_class;r.baseline_P0_equivalence_class_size=x(k).baseline_P0_equivalence_class_size;r.prior_conditioned_equivalence_class_size=x(k).prior_conditioned_equivalence_class_size;r.best_distance=x(k).best_distance;r.second_distance=x(k).second_distance;r.margin=x(k).margin;r.rho=x(k).rho;r.subband_max_stat=x(k).subband_max_stat;r.subband_quantile_stat=x(k).subband_quantile_stat;r.neighborhood_score=x(k).neighborhood_score;r.neighborhood_margin=x(k).neighborhood_margin;r.stability_value=x(k).stability_value;r.stability_threshold=x(k).stability_threshold;r.candidate_count_before_prior=x(k).candidate_count_before_prior;r.candidate_count_after_prior=x(k).candidate_count_after_prior;r.parameter_template_count=x(k).parameter_template_count;r.composite_template_count=x(k).composite_template_count;r.configuration_hash=x(k).configuration_hash;r.calibration_hash=x(k).calibration_hash;rows(k)=r;end,end
function rows=label_rows(x),rows=repmat(label_template(),numel(x),1);for k=1:numel(x),rows(k)=x(k);end,end

function r=make_raw_output(x,l),r=raw_output_template();r.sample_id=x.sample_id;r.replicate_id=x.replicate_id;r.split=x.split;r.grid_id=x.cache_frequency_grid_id;r.scenario_id=l.scenario_id;r.best_topology_id=x.best_topology_id;r.best_equivalence_class=x.best_equivalence_class;r.best_distance=x.best_distance;r.margin=x.margin;r.rho=x.rho;r.best_subband_distance=mat2str(x.best_subband_distance,6);r.best_amplitude_distance=x.best_amplitude_distance;r.best_phase_distance=x.best_phase_distance;r.topology_best_distances=mat2str(x.topology_scores,6);r.topK_neighborhood_scores=mat2str(x.topk_evidence.neighborhood_scores,6);r.topK_neighborhood_std=mat2str(x.topk_evidence.neighborhood_std,6);r.stability_value=x.stability.best_class_stability;r.block_repetitions=x.stability.repetitions;r.uses_topK_cache=x.stability.uses_topK_cache;r.distance_evaluations=x.distance_evaluations;r.configuration_hash=x.configuration_hash;end

function c=load_or_build_cache(cfg,sc,grid,candidates,theta_grid,hash,scenario_id)
    old=fullfile(cfg.results_data,'stage4a4_cache',sprintf('stage4a4_cache_%s_%s.mat',grid.id,scenario_id));new=fullfile(sc.cache_dir,sprintf('stage4a5_cache_%s_%s.mat',grid.id,scenario_id));c=[];
    if exist(old,'file'),z=load(old,'cache');if isfield(z,'cache')&&valid_cache(z.cache,grid,candidates),c=z.cache;return;end,end
    if exist(new,'file'),z=load(new,'cache');if isfield(z,'cache')&&valid_cache(z.cache,grid,candidates),c=z.cache;return;end,end
    p0=generate_prior_constrained_candidates(sc.generator,sc.scenarios(1).asset_prior);nom=theta_grid(find([theta_grid.regularization]==0,1));nl=build_composite_topology_library(grid.frequency_hz,p0,nom,sc.measurement_kind,cfg,numel(p0));audit=audit_candidate_observability(p0,nl,cfg,sc.distance.tie_tolerance);
    meta=struct('measurement_kind',sc.measurement_kind,'tie_tolerance',sc.distance.tie_tolerance,'distance_feature',sc.distance.feature,'distance_weights',sc.distance.weights,'distance_options',sc.distance.options,'scenario_id',scenario_id,'configuration_hash',hash,'max_composite_templates',numel(candidates)*numel(theta_grid),'baseline_P0_audit',audit);c=build_stage4a3_1_template_cache(grid,candidates,theta_grid,cfg,meta);if ~exist(sc.cache_dir,'dir'),mkdir(sc.cache_dir);end;save(new,'c','-v7.3');
end
function tf=valid_cache(c,g,candidates),tf=isfield(c,'frequency_hz')&&numel(c.frequency_hz)==numel(g.frequency_hz)&&max(abs(c.frequency_hz(:)-g.frequency_hz(:)))==0&&isfield(c,'candidate_count')&&c.candidate_count==numel(candidates)&&isfield(c,'cfr_views')&&~isempty(c.cfr_views);end
function [h,t]=scientific_hash(cfg,sc,base,g,source_hash),p=struct('stage',sc.stage_name,'version',sc.version,'code_version',sc.code_version,'source_tree_hash',source_hash,'generator',sc.generator,'candidates',{base},'parameter_search',sc.parameter_search,'parameter_grid',{g},'grids',sc.grids,'ofdm',cfg.ofdm,'observation',struct('measurement_kind',sc.measurement_kind,'Zs',cfg.Zs,'Zr',cfg.Zr,'reference',cfg.port_reference_ohm),'distance',sc.distance,'subbands',{sc.subband_counts},'quantiles',{sc.subband_quantiles},'K',{sc.neighborhood_K},'stability',struct('B',sc.bootstrap_repetitions,'blocks',sc.block_count,'fraction',sc.block_fraction),'development_seeds',sc.development_seeds,'final_seeds',sc.final_seeds,'sample_design',struct('development',sc.development,'final',sc.final));[h,t]=stage4a4_scientific_config_hash(p);end
function write_baseline(cfg,sc,h),src=fullfile(cfg.results_data,'stage4a4_metrics.csv');if ~exist(src,'file'),return;end;T=readtable(src);T.stage4a5_source_hash(:)=repmat({h},height(T),1);writetable(T,fullfile(cfg.results_data,[sc.output_prefix '_baseline_summary.csv']));end

function write_outputs(cfg,sc,bank,d,l,m,sm,sel,th,rt,gr,sb,raw,dev,h,txt,source_hash)
    p=sc.output_prefix;data=cfg.results_data;
    write_struct_table(bank_output(bank,sc),fullfile(data,[p '_trial_bank.csv']));
    write_struct_table(d,fullfile(data,[p '_match_decisions.csv']));
    write_struct_table(l,fullfile(data,[p '_scoring_labels.csv']));
    write_struct_table(m,fullfile(data,[p '_metrics.csv']));
    write_struct_table(sm,fullfile(data,[p '_seed_metrics.csv']));
    write_struct_table(sel,fullfile(data,[p '_method_selection.csv']));
    write_struct_table(th,fullfile(data,[p '_thresholds.csv']));
    write_struct_table(rt,fullfile(data,[p '_runtime.csv']));
    write_struct_table(gr,fullfile(data,[p '_frequency_grid_manifest.csv']));
    write_struct_table(sb,fullfile(data,[p '_subband_manifest.csv']));
    write_struct_table(raw,fullfile(data,[p '_raw_evidence.csv']));
    write_struct_table(dev,fullfile(data,[p '_development_metrics.csv']));
    manifest=struct('scientific_configuration_hash',h,'scientific_configuration_text',txt, ...
        'source_tree_hash',source_hash,'output_prefix',p,'development_seeds',mat2str(sc.development_seeds), ...
        'final_seeds',mat2str(sc.final_seeds),'source_tag',sc.source_tag, ...
        'historical_consumed_test','stage4a4_test');
    write_struct_table(manifest,fullfile(data,[p '_configuration_manifest.csv']));
    save(fullfile(data,[p '_results.mat']),'sc','bank','d','l','m','sm','sel','th','rt','gr','sb','raw','dev','manifest','-v7.3');
end
function write_struct_table(s,path)
    if isempty(s),s=s(:);else,s=s(:);end
    writetable(struct2table(s),path);
end

function x=bank_output(b,sc),x=repmat(struct('sample_id','','replicate_id','','split','','category','','truth_topology_id','','canonical_key','','outlier_dimension','','outlier_direction','','source_tag','','seed',0,'development_seed',0,'final_seed',0),numel(b),1);for k=1:numel(b),x(k)=struct('sample_id',b(k).sample_id,'replicate_id',b(k).replicate_id,'split',b(k).split,'category',b(k).category,'truth_topology_id',b(k).truth_topology_id,'canonical_key',b(k).canonical_key,'outlier_dimension',b(k).outlier_dimension,'outlier_direction',b(k).outlier_direction,'source_tag',b(k).source_tag,'seed',b(k).seed,'development_seed',first_or_zero(sc.development_seeds,b(k).replicate_id,'dev'),'final_seed',first_or_zero(sc.final_seeds,b(k).replicate_id,'final'));end,end
function x=first_or_zero(v,rep,expected_prefix)
    x=0;
    if startsWith(rep,expected_prefix)
        if strcmp(expected_prefix,'dev'),span=[4,5];else,span=[6,7];end
        k=str2double(rep(span(1):span(2)));
        if isfinite(k)&&k>=1&&k<=numel(v),x=v(k);end
    end
end

function r=make_grid_output(g,h),r=grid_output_template();f=g.frequency_hz(:).';r.grid_id=g.id;r.source=g.source;r.nfft=g.nfft;r.sample_rate_hz=g.sample_rate_hz;r.frequency_count=numel(f);r.frequency_min_hz=min(f);r.frequency_max_hz=max(f);r.frequency_spacing_hz=median(diff(f));r.active_bin_count=numel(g.active_bin_1based);r.active_bin_1based=mat2str(g.active_bin_1based(:).',17);r.frequency_array_hz=mat2str(f,17);r.configuration_hash=h;end
function r=make_threshold_output(g,rep,m,h),r=threshold_output_template();r.grid_id=g.id;r.replicate_id=rep;r.residual_threshold=m.thresholds.residual_threshold;r.margin_threshold=m.thresholds.margin_threshold;r.calibration_sample_count=m.calibration_sample_count;r.calibration_seed=m.calibration_seed;r.configuration_hash=h;end
function r=make_runtime_output(g,scenario,c,rep,h),r=runtime_output_template();r.grid_id=g.id;r.scenario_id=scenario;r.replicate_id=rep;r.candidate_count=c.candidate_count;r.candidate_count_before_prior=7;r.parameter_template_count=c.parameter_template_count;r.composite_template_count=c.composite_template_count;r.frequency_count=numel(c.frequency_hz);r.estimated_memory_bytes=c.estimated_memory_bytes;r.cache_source='stage4a4_cache_or_stage4a5_cache';r.configuration_hash=h;end
function y=metrics_to_seed_summary(m),y=repmat(metric_template_for_selection(),0,1);for k=1:numel(m),r=metric_template_for_selection();f=fieldnames(r);for j=1:numel(f),if isfield(m(k),f{j}),r.(f{j})=m(k).(f{j});end,end;y(end+1)=r;end,end

function make_figures(cfg,m,sel)
    fig=cfg.results_figures;if ~exist(fig,'dir'),mkdir(fig);end
    try
        plot_metric_bar(m,fig,'set_accuracy_given_covered','M0-M3 in-library set accuracy');plot_metric_bar(m,fig,'accepted_rate','M0-M3 accepted rate / OOL false accept');plot_seed_metric(m,fig);plot_parameter_out(m,fig);plot_distribution(m,fig,'mean_subband_max','maximum subband statistic');plot_distribution(m,fig,'mean_neighborhood_score','neighborhood score');plot_distribution(m,fig,'mean_stability','stability');plot_tradeoff(m,fig);
    catch ME
        warning('stage4a5:FigureGeneration','Figure generation skipped: %s',ME.message);
    end
end
function plot_metric_bar(m,dir,field,title_text),x=m((strcmp({m.metric_scope},'detail')|strcmp({m.metric_scope},'micro_and_macro'))&ismember({m.category},{'in_library_summary','structure_out','parameter_out'}));if isempty(x),return;end;ids=stable_unique({x.method_id});v=NaN(1,numel(ids));for k=1:numel(ids),z=x(strcmp({x.method_id},ids{k}));v(k)=mean([z.(field)],'omitnan');end;h=figure('Visible','off');bar(v);set(gca,'XTick',1:numel(ids),'XTickLabel',ids,'XTickLabelRotation',45);ylabel(field);title(title_text);saveas(h,fullfile(dir,['stage4a5_' field '.png']));close(h);end
function plot_seed_metric(m,dir),x=m(ismember({m.category},{'in_library_summary','structure_out','parameter_out'}));if isempty(x),return;end;ids=stable_unique({x.method_id});h=figure('Visible','off');hold on;for k=1:numel(ids),z=x(strcmp({x.method_id},ids{k}));plot(k*ones(1,numel(z)),[z.set_accuracy_given_covered],'o','DisplayName',ids{k});end;set(gca,'XTick',1:numel(ids),'XTickLabel',ids,'XTickLabelRotation',45);ylabel('set accuracy');title('per-replicate set accuracy');legend('Location','best');saveas(h,fullfile(dir,'stage4a5_seed_paired_improvement.png'));close(h);end
function plot_parameter_out(m,dir),x=m(strcmp({m.category},'parameter_out'));if isempty(x),return;end;dims=stable_unique({x.outlier_dimension});v=NaN(1,numel(dims));for k=1:numel(dims),z=x(strcmp({x.outlier_dimension},dims{k}));v(k)=mean([z.accepted_rate],'omitnan');end;h=figure('Visible','off');bar(v);set(gca,'XTick',1:numel(dims),'XTickLabel',dims,'XTickLabelRotation',45);ylabel('false accept rate');title('parameter-out dimensions');saveas(h,fullfile(dir,'stage4a5_parameter_out_false_accept.png'));close(h);end
function plot_distribution(m,dir,field,ttl),x=m(ismember({m.category},{'in_library_summary','structure_out','parameter_out'}));if isempty(x),return;end;cats=stable_unique({x.category});h=figure('Visible','off');hold on;for k=1:numel(cats),z=x(strcmp({x.category},cats{k}));plot(k*ones(1,numel(z)),[z.(field)],'o','DisplayName',cats{k});end;set(gca,'XTick',1:numel(cats),'XTickLabel',cats);ylabel(field);title(ttl);legend('Location','best');saveas(h,fullfile(dir,['stage4a5_' field '.png']));close(h);end
function plot_tradeoff(m,dir),x=m(strcmp({m.category},'in_library_summary'));if isempty(x),return;end;h=figure('Visible','off');scatter([x.set_accuracy_given_covered],[x.accepted_rate],40,'filled');xlabel('in-library set accuracy');ylabel('accepted rate');title('accuracy-acceptance tradeoff');saveas(h,fullfile(dir,'stage4a5_accuracy_ool_tradeoff.png'));close(h);end

function r=decision_template(),r=struct('sample_id','','replicate_id','','split','','grid_id','','scenario_id','','method_id','','method_family','','decision','','decision_reason','','best_template_id','','best_topology_id','','best_equivalence_class','','accepted_topology_set','','baseline_P0_equivalence_class','','baseline_P0_equivalence_class_size',0,'prior_conditioned_equivalence_class_size',0,'best_distance',NaN,'second_distance',NaN,'margin',NaN,'rho',NaN,'subband_max_stat',NaN,'subband_quantile_stat',NaN,'neighborhood_score',NaN,'neighborhood_margin',NaN,'stability_value',NaN,'stability_threshold',NaN,'candidate_count_before_prior',0,'candidate_count_after_prior',0,'parameter_template_count',0,'composite_template_count',0,'configuration_hash','','calibration_hash','');end
function r=label_template(),r=struct('sample_id','','replicate_id','','split','','category','','outlier_dimension','','truth_topology_id','','canonical_key','','grid_id','','scenario_id','','truth_covered',false,'truth_graph_in_current_prior',false,'coverage_status','','baseline_P0_equivalence_class','','baseline_P0_equivalence_class_size',0,'prior_conditioned_equivalence_class','','prior_conditioned_equivalence_class_size',0,'truth_is_observationally_nonunique',false,'configuration_hash','');end
function r=raw_output_template(),r=struct('sample_id','','replicate_id','','split','','grid_id','','scenario_id','','best_topology_id','','best_equivalence_class','','best_distance',NaN,'margin',NaN,'rho',NaN,'best_subband_distance','','best_amplitude_distance',NaN,'best_phase_distance',NaN,'topology_best_distances','','topK_neighborhood_scores','','topK_neighborhood_std','','stability_value',NaN,'block_repetitions',0,'uses_topK_cache',false,'distance_evaluations',0,'configuration_hash','');end
function r=threshold_output_template(),r=struct('grid_id','','replicate_id','','residual_threshold',NaN,'margin_threshold',NaN,'calibration_sample_count',0,'calibration_seed',0,'configuration_hash','');end
function r=runtime_output_template(),r=struct('grid_id','','scenario_id','','replicate_id','','candidate_count',0,'candidate_count_before_prior',0,'parameter_template_count',0,'composite_template_count',0,'frequency_count',0,'estimated_memory_bytes',NaN,'cache_source','','configuration_hash','');end
function r=selection_output_template(),r=struct('grid_id','','M0_method_id','','M1_method_id','','M1_M',0,'M1_q',0,'M1_K',0,'M1_stability_threshold',0,'M2_method_id','','M2_M',0,'M2_q',0,'M2_K',0,'M2_stability_threshold',0,'M3_method_id','','M3_M',0,'M3_q',0,'M3_K',0,'M3_stability_threshold',0,'selection_basis','','scientific_hash','');end
function r=metric_template_for_selection(),r=struct('method_id','','grid_id','','scenario_id','','replicate_id','','category','','outlier_dimension','','metric_scope','','sample_count',0,'truth_coverage_rate',NaN,'truth_coverage_num',0,'truth_coverage_den',0,'unique_accuracy_given_covered',NaN,'unique_accuracy_num',0,'unique_accuracy_den',0,'unique_accuracy_ci_low',NaN,'unique_accuracy_ci_high',NaN,'set_accuracy_given_covered',NaN,'set_accuracy_num',0,'set_accuracy_den',0,'set_accuracy_ci_low',NaN,'set_accuracy_ci_high',NaN,'set_accuracy_macro',NaN,'set_accuracy_macro_component_count',0,'nearest_topology_hit_rate',NaN,'nearest_topology_hit_num',0,'nearest_topology_hit_den',0,'nearest_topology_hit_ci_low',NaN,'nearest_topology_hit_ci_high',NaN,'false_unique_rate_given_nonunique',NaN,'false_unique_num',0,'false_unique_den',0,'false_unique_ci_low',NaN,'false_unique_ci_high',NaN,'accepted_rate',NaN,'accepted_num',0,'accepted_den',0,'accepted_ci_low',NaN,'accepted_ci_high',NaN,'unique_output_precision',NaN,'unique_output_precision_num',0,'unique_output_precision_den',0,'unique_output_precision_ci_low',NaN,'unique_output_precision_ci_high',NaN,'structure_out_false_accept_rate',NaN,'structure_out_false_accept_num',0,'structure_out_false_accept_den',0,'structure_out_false_accept_ci_low',NaN,'structure_out_false_accept_ci_high',NaN,'parameter_out_false_accept_rate',NaN,'parameter_out_false_accept_num',0,'parameter_out_false_accept_den',0,'parameter_out_false_accept_ci_low',NaN,'parameter_out_false_accept_ci_high',NaN,'structure_out_unique_accept_rate',NaN,'parameter_out_unique_accept_rate',NaN,'unique_given_prior_rate',NaN,'reject_model_mismatch_rate',NaN,'reject_model_mismatch_num',0,'reject_model_mismatch_den',0,'reject_model_mismatch_ci_low',NaN,'reject_model_mismatch_ci_high',NaN,'reject_subband_mismatch_rate',NaN,'reject_subband_mismatch_num',0,'reject_subband_mismatch_den',0,'reject_subband_mismatch_ci_low',NaN,'reject_subband_mismatch_ci_high',NaN,'reject_neighborhood_mismatch_rate',NaN,'reject_neighborhood_mismatch_num',0,'reject_neighborhood_mismatch_den',0,'reject_neighborhood_mismatch_ci_low',NaN,'reject_neighborhood_mismatch_ci_high',NaN,'reject_low_stability_rate',NaN,'reject_low_stability_num',0,'reject_low_stability_den',0,'reject_low_stability_ci_low',NaN,'reject_low_stability_ci_high',NaN,'reject_low_margin_rate',NaN,'reject_low_margin_num',0,'reject_low_margin_den',0,'reject_low_margin_ci_low',NaN,'reject_low_margin_ci_high',NaN,'mean_best_distance',NaN,'mean_margin',NaN,'mean_subband_max',NaN,'mean_neighborhood_score',NaN,'mean_stability',NaN,'mean_accepted_set_size',NaN);end
function r=grid_output_template(),r=struct('grid_id','','source','','nfft',0,'sample_rate_hz',NaN,'frequency_count',0,'frequency_min_hz',NaN,'frequency_max_hz',NaN,'frequency_spacing_hz',NaN,'active_bin_count',0,'active_bin_1based','','frequency_array_hz','','configuration_hash','');end
function r=subband_output_template(),r=struct('grid_id','','subband_id',0,'start_index',0,'end_index',0,'start_frequency_hz',NaN,'end_frequency_hz',NaN,'frequency_count',0,'configuration_hash','');end
function r=metric_template_for_selection_dummy(),r=metric_template_for_selection();end
function y=selection_metrics(m),y=repmat(metric_template_for_selection(),0,1);for k=1:numel(m),r=metric_template_for_selection();f=fieldnames(r);for j=1:numel(f),if isfield(m(k),f{j}),r.(f{j})=m(k).(f{j});end,end;y(end+1)=r;end,end
function s=stability_seed(b),s=abs(sum(double(b.sample_id)))+b.seed;end
function s=seed_for_rep(v,rep),if startsWith(rep,'final'),s=v(str2double(rep(6:7)));else,s=v(str2double(rep(4:5)));end,end
function y=stable_unique(x),y={};for k=1:numel(x),if ~any(strcmp(y,x{k})),y{end+1}=x{k};end,end,end
