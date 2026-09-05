function out=exp_stage4a4_candidate_confirmation(cfg,sc)
%EXP_STAGE4A4_CANDIDATE_CONFIRMATION Compare calibrated confirmation rules.
%   Each cache is built once per grid/scenario.  All split observations are
%   scored once, after which the methods reuse the same raw diagnostics.
    if nargin<1||isempty(cfg), root=fileparts(fileparts(mfilename('fullpath')));cfg=default_config(root);end
    if nargin<2||isempty(sc), sc=stage4a4_candidate_confirmation_config(cfg,'formal');end
    ensure_result_dirs(cfg); if ~exist(sc.cache_dir,'dir'),mkdir(sc.cache_dir);end
    total=tic; bank=generate_stage4a4_trial_bank(sc); base=generate_radial_topology_candidates(sc.generator);
    theta_grid=topology_parameter_grid(sc.parameter_search); if numel(theta_grid)~=243, error('stage4a4:ParameterGridCount','Expected 243 templates.');end
    [scientific_hash,scientific_text]=make_scientific_hash(cfg,sc,base,theta_grid);
    write_baseline_summary(cfg,sc,scientific_hash);
    splits={'training','calibration','validation','test'}; split_ix=cellfun(@(x)find(strcmp({bank.split},x)),splits,'UniformOutput',false);
    grid_manifest=repmat(grid_row_template(),numel(sc.grids),1); decisions=repmat(decision_row_template(),0,1);
    labels_out=repmat(label_row_template(),0,1); threshold_rows=repmat(threshold_row_template(),0,1);
    runtime_rows=repmat(runtime_row_template(),0,1); validation_rows=repmat(validation_row_template(),0,1); tradeoff_rows=repmat(tradeoff_row_template(),0,1); all_models=cell(1,numel(sc.grids));
    for fg=1:numel(sc.grids)
        grid=sc.grids(fg); f=grid.frequency_hz(:).'; grid_manifest(fg)=make_grid_row(grid,sc,scientific_hash);
        fprintf('Stage 4A.4 grid %s: shared observations and P0 calibration\n',grid.id);
        observations=make_observations(bank,f,cfg,sc.measurement_kind);
        p0=generate_prior_constrained_candidates(sc.generator,sc.scenarios(1).asset_prior);
        nominal=theta_grid(find([theta_grid.regularization]==0,1));
        nominal_lib=build_composite_topology_library(f,p0,nominal,sc.measurement_kind,cfg,numel(p0));
        p0_audit=audit_candidate_observability(p0,nominal_lib,cfg,sc.tie_tolerance);
        scenario_raw=cell(1,numel(sc.scenarios)); scenario_labels=cell(1,numel(sc.scenarios)); scenario_caches=cell(1,numel(sc.scenarios));
        for ss=1:numel(sc.scenarios)
            scenario=sc.scenarios(ss); candidates=generate_prior_constrained_candidates(sc.generator,scenario.asset_prior);
            payload=struct('stage_config',sc,'base_config',cfg,'candidate_grammar',sc.generator,'asset_prior',scenario.asset_prior, ...
                'parameter_search',sc.parameter_search,'parameter_grid',theta_grid,'frequency_grid',grid, ...
                'frequency_array_hz',f,'nfft',grid.nfft,'sample_rate_hz',grid.sample_rate_hz, ...
                'active_bin_1based',grid.active_bin_1based,'observation_config',struct('measurement_kind',sc.measurement_kind,'Zs',cfg.Zs,'Zr',cfg.Zr,'port_reference',cfg.port_reference_ohm), ...
                'distance',struct('feature',sc.feature,'weights',sc.weights,'options',sc.distance_options,'tie_tolerance',sc.tie_tolerance), ...
                'calibration',sc.calibration,'sample_design',sc.sample_design,'scenario_id',scenario.id,'scientific_hash',scientific_hash);
            [hash,text]=stage4a4_scientific_config_hash(payload); %#ok<ASGLU>
            meta=struct('measurement_kind',sc.measurement_kind,'tie_tolerance',sc.tie_tolerance,'distance_feature',sc.feature, ...
                'distance_weights',sc.weights,'distance_options',sc.distance_options,'scenario_id',scenario.id, ...
                'configuration_hash',hash,'max_composite_templates',numel(candidates)*numel(theta_grid),'baseline_P0_audit',p0_audit);
            cache_file=fullfile(sc.cache_dir,sprintf('stage4a4_cache_%s_%s.mat',grid.id,scenario.id));
            cache_tic=tic; reuse=false;
            if exist(cache_file,'file')
                loaded=load(cache_file,'cache');
                if isfield(loaded,'cache') && isfield(loaded.cache,'configuration_hash') && strcmp(loaded.cache.configuration_hash,hash)
                    cache=loaded.cache; reuse=true;
                end
            end
            if ~reuse
                cache=build_stage4a3_1_template_cache(grid,candidates,theta_grid,cfg,meta);
                cache.configuration_canonical_text=text; cache=replace_cache_hash(cache,hash); save(cache_file,'cache','-v7.3');
            end
            build_time=toc(cache_tic);
            if reuse, fprintf('  cache reused after scientific-hash match: %s\n',cache_file); end
            raw=[]; raw_time=tic;
            for i=1:numel(bank)
                o=struct('feature',sc.feature,'weights',sc.weights,'distance_options',sc.distance_options,'method','baseline_abs_margin', ...
                    'candidate_count_before_prior',numel(base),'return_raw',true);
                r=match_candidate_library_calibrated(observations{i},cache,struct(),o); r.sample_id=bank(i).sample_id; r.grid_id=grid.id; r.scenario_id=scenario.id; if isempty(raw),raw=r;else,raw(end+1)=r;end %#ok<AGROW>
            end
            raw_time=toc(raw_time); scenario_raw{ss}=raw;
            scenario_labels{ss}=build_stage4a4_truth_equivalence_labels(bank,p0_audit,cache.current_equivalence_audit,candidates,grid.id,scenario.id,hash); scenario_caches{ss}=cache;
            runtime_rows(end+1)=make_runtime_row(grid,scenario,cache,cache_file,build_time,raw_time,hash,numel(split_ix{1}),numel(split_ix{2}),numel(split_ix{3}),numel(split_ix{4})); %#ok<AGROW>
            fprintf('  scenario %s: %d candidates, %d templates, raw scoring %.2f s\n',scenario.id,numel(candidates),numel(candidates)*numel(theta_grid),raw_time);
        end
        % P0 is calibrated once; the frozen thresholds are shared by P0/P1/P2.
        p0raw=scenario_raw{1}; p0lab=scenario_labels{1};
        train_raw=p0raw(split_ix{1}); train_lab=p0lab(split_ix{1}); cal_raw=p0raw(split_ix{2}); cal_lab=p0lab(split_ix{2});
        model=calibrate_candidate_confirmation(train_raw,train_lab,cal_raw,cal_lab,sc,grid.id,scientific_hash); all_models{fg}=model;
        threshold_rows(end+1)=make_threshold_row(grid,model,scientific_hash); %#ok<AGROW>
        scales=[0.80,0.90,1.00,1.10,1.20];
        for ss=1:numel(sc.scenarios)
            raw=scenario_raw{ss}; labs=scenario_labels{ss};
            for q=1:numel(scales)
                tm=model;tm.thresholds.residual_threshold=model.thresholds.residual_threshold*scales(q);
                td=apply_split(raw(split_ix{3}),tm,'baseline_abs_margin');tl=labs(split_ix{3});
                tradeoff_rows(end+1)=make_tradeoff_row(td,tl,grid.id,sc.scenarios(ss).id,scales(q)); %#ok<AGROW>
            end
        end
        for ss=1:numel(sc.scenarios)
            raw=scenario_raw{ss}; labs=scenario_labels{ss};
            for mm=1:numel(sc.methods)
                method=sc.methods{mm}; vdec=apply_split(raw(split_ix{3}),model,method); vlab=labs(split_ix{3});
                validation_rows(end+1)=make_validation_row(vdec,vlab,method,grid.id,sc.scenarios(ss).id); %#ok<AGROW>
                tdec=apply_split(raw(split_ix{4}),model,method); tlab=labs(split_ix{4});
                decisions=[decisions;decision_rows(tdec,method,grid.id,sc.scenarios(ss).id)]; %#ok<AGROW>
                labels_out=[labels_out;label_rows(tlab)]; %#ok<AGROW>
            end
        end
    end
    metrics=evaluate_stage4a4_metrics(decisions,labels_out);
    recommendations=select_recommendations(validation_rows,sc);
    write_outputs(cfg,sc,bank,decisions,labels_out,metrics,threshold_rows,runtime_rows,grid_manifest,validation_rows,tradeoff_rows,recommendations,scientific_hash,scientific_text,all_models,p0_audit);
    out=struct('runtime_s',toc(total),'bank',bank,'decisions',decisions,'labels',labels_out,'metrics',metrics,'thresholds',threshold_rows,'runtime',runtime_rows,'validation',validation_rows,'tradeoff',tradeoff_rows,'recommendations',recommendations,'scientific_hash',scientific_hash);
    fprintf('Stage 4A.4 completed in %.3f s\n',out.runtime_s);
end

function obs=make_observations(bank,f,cfg,kind)
    obs=cell(numel(bank),1); for k=1:numel(bank),[net,lc]=topology_apply_parameters(bank(k).truth_network,cfg,bank(k).truth_theta);[m,~]=plc_measurement_bundle(kind,net,bank(k).truth_theta,lc);[obs{k},~]=plc_multiview_response(f,net,m,lc);end
end
function r=raw_template(),r=struct('sample_id','','grid_id','','scenario_id','','best_template_id','','best_topology_id','','best_equivalence_class','','best_distance',NaN,'second_competing_class','','second_distance',NaN,'margin',NaN,'rho',NaN,'class_scores',[],'class_labels',{{}},'baseline_class_scores',[],'baseline_class_labels',{{}},'baseline_P0_equivalence_class','','baseline_P0_equivalence_class_size',0,'prior_conditioned_equivalence_class_size',0,'candidate_count_before_prior',0,'candidate_count_after_prior',0,'parameter_template_count',0,'composite_template_count',0,'distance_evaluations',0,'matching_time_s',NaN,'configuration_hash','');end
function rows=apply_split(raw,model,method)
    rows=[]; for k=1:numel(raw),o=struct('method',method);x=apply_candidate_confirmation(raw(k),model,o);x.sample_id=raw(k).sample_id;x.grid_id=raw(k).grid_id;x.scenario_id=raw(k).scenario_id;if isempty(rows),rows=x;else,rows(k)=x;end;end
end
function rows=decision_rows(x,method,grid_id,scenario_id)
    row=decision_row_template(); rows=repmat(row,numel(x),1);
    for k=1:numel(x),r=row;r.sample_id=x(k).sample_id;r.grid_id=grid_id;r.scenario_id=scenario_id;r.method_id=method;r.decision=x(k).decision;r.decision_reason=x(k).decision_reason;r.best_template_id=x(k).best_template_id;r.best_topology_id=x(k).best_topology_id;r.best_equivalence_class=x(k).best_equivalence_class;r.accepted_topology_set=x(k).accepted_topology_set;r.baseline_P0_equivalence_class=x(k).baseline_P0_equivalence_class;r.baseline_P0_equivalence_class_size=x(k).baseline_P0_equivalence_class_size;r.prior_conditioned_equivalence_class=x(k).prior_conditioned_equivalence_class;r.prior_conditioned_equivalence_class_size=x(k).prior_conditioned_equivalence_class_size;r.best_distance=x(k).best_distance;r.second_distance=x(k).second_distance;r.margin=x(k).margin;r.rho=x(k).rho;r.robust_best_score=x(k).robust_best_score;r.robust_margin=x(k).robust_margin;r.candidate_count_before_prior=x(k).candidate_count_before_prior;r.candidate_count_after_prior=x(k).candidate_count_after_prior;r.parameter_template_count=x(k).parameter_template_count;r.composite_template_count=x(k).composite_template_count;r.distance_evaluations=x(k).distance_evaluations;r.matching_time_s=x(k).matching_time_s;r.residual_threshold=x(k).residual_threshold;r.margin_threshold=x(k).margin_threshold;r.rho_threshold=x(k).rho_threshold;r.configuration_hash=x(k).configuration_hash;r.calibration_hash=x(k).calibration_hash;rows(k)=r;end
end
function rows=label_rows(x)
    row=label_row_template(); rows=repmat(row,numel(x),1); for k=1:numel(x),r=row;f=fieldnames(row);for j=1:numel(f),if isfield(x(k),f{j}),r.(f{j})=x(k).(f{j});end,end;rows(k)=r;end
end
function r=decision_row_template(),r=struct('sample_id','','grid_id','','scenario_id','','method_id','','decision','','decision_reason','','best_template_id','','best_topology_id','','best_equivalence_class','','accepted_topology_set','','baseline_P0_equivalence_class','','baseline_P0_equivalence_class_size',0,'prior_conditioned_equivalence_class','','prior_conditioned_equivalence_class_size',0,'best_distance',NaN,'second_distance',NaN,'margin',NaN,'rho',NaN,'robust_best_score',NaN,'robust_margin',NaN,'candidate_count_before_prior',0,'candidate_count_after_prior',0,'parameter_template_count',0,'composite_template_count',0,'distance_evaluations',0,'matching_time_s',NaN,'residual_threshold',NaN,'margin_threshold',NaN,'rho_threshold',NaN,'configuration_hash','','calibration_hash','');end
function r=label_row_template(),r=struct('sample_id','','split','','category','','truth_topology_id','','canonical_key','','coverage_status','','truth_covered',false,'truth_graph_in_current_prior',false,'baseline_P0_equivalence_class','','baseline_P0_equivalence_class_size',0,'prior_conditioned_equivalence_class','','prior_conditioned_equivalence_class_size',0,'truth_is_observationally_nonunique',false,'grid_id','','scenario_id','','configuration_hash','');end
function r=grid_row_template(),r=struct('grid_id','','source','','nfft',0,'sample_rate_hz',NaN,'frequency_count',0,'frequency_min_hz',NaN,'frequency_max_hz',NaN,'frequency_spacing_hz',NaN,'active_bin_count',0,'active_bin_1based','','frequency_array_hz','','configuration_hash','');end
function r=make_grid_row(g,sc,h),r=grid_row_template();f=g.frequency_hz(:).';d=diff(f);r.grid_id=g.id;r.source=g.source;r.nfft=g.nfft;r.sample_rate_hz=g.sample_rate_hz;r.frequency_count=numel(f);r.frequency_min_hz=min(f);r.frequency_max_hz=max(f);if isempty(d),r.frequency_spacing_hz=NaN;else,r.frequency_spacing_hz=median(d);end;r.active_bin_count=numel(g.active_bin_1based);r.active_bin_1based=mat2str(g.active_bin_1based(:).',17);r.frequency_array_hz=mat2str(f,17);r.configuration_hash=h;end
function r=runtime_row_template(),r=struct('grid_id','','scenario_id','','cache_file','','candidate_count',0,'candidate_count_before_prior',0,'parameter_template_count',0,'composite_template_count',0,'frequency_count',0,'estimated_memory_bytes',NaN,'cache_file_bytes',NaN,'cache_build_time_s',NaN,'raw_match_time_s',NaN,'training_count',0,'calibration_count',0,'validation_count',0,'test_count',0,'configuration_hash','');end
function r=make_runtime_row(g,s,c,file,bt,mt,h,ntrain,ncal,nval,ntest),r=runtime_row_template();info=dir(file);r.grid_id=g.id;r.scenario_id=s.id;r.cache_file=file;r.candidate_count=c.candidate_count;r.candidate_count_before_prior=7;r.parameter_template_count=c.parameter_template_count;r.composite_template_count=c.composite_template_count;r.frequency_count=numel(c.frequency_hz);r.estimated_memory_bytes=c.estimated_memory_bytes;r.cache_file_bytes=info.bytes;r.cache_build_time_s=bt;r.raw_match_time_s=mt;r.training_count=ntrain;r.calibration_count=ncal;r.validation_count=nval;r.test_count=ntest;r.configuration_hash=h;end
function r=threshold_row_template(),r=struct('grid_id','','residual_threshold',NaN,'margin_threshold',NaN,'rho_threshold',NaN,'robust_score_threshold',NaN,'robust_margin_threshold',NaN,'training_sample_count',0,'calibration_sample_count',0,'residual_calibration_count',0,'margin_calibration_count',0,'ratio_calibration_count',0,'robust_calibration_count',0,'residual_quantile',NaN,'margin_quantile',NaN,'rho_quantile',NaN,'safety_factor',NaN,'calibration_seed',0,'test_seed',0,'source','','configuration_hash','');end
function r=make_threshold_row(g,m,h),r=threshold_row_template();r.grid_id=g.id;r.residual_threshold=m.thresholds.residual_threshold;r.margin_threshold=m.thresholds.margin_threshold;r.rho_threshold=m.thresholds.rho_threshold;r.robust_score_threshold=m.thresholds.robust_score_threshold;r.robust_margin_threshold=m.thresholds.robust_margin_threshold;r.training_sample_count=m.training_sample_count;r.calibration_sample_count=m.calibration_sample_count;r.residual_calibration_count=m.residual_calibration_count;r.margin_calibration_count=m.margin_calibration_count;r.ratio_calibration_count=m.ratio_calibration_count;r.robust_calibration_count=m.robust_calibration_count;r.residual_quantile=m.quantiles.residual_quantile;r.margin_quantile=m.quantiles.margin_quantile;r.rho_quantile=m.quantiles.rho_quantile;r.safety_factor=m.quantiles.residual_safety_factor;r.calibration_seed=m.calibration_seed;r.test_seed=m.test_seed;r.source=m.source;r.configuration_hash=h;end
function r=validation_row_template(),r=struct('method_id','','grid_id','','scenario_id','','validation_inlibrary_set_accuracy',NaN,'validation_ool_false_accept',NaN,'validation_false_unique',NaN,'validation_inlibrary_reject',NaN,'eligible',false);end
function r=make_validation_row(d,l,m,g,s),r=validation_row_template();x=evaluate_stage4a4_metrics(d,l);r.method_id=m;r.grid_id=g;r.scenario_id=s;a=x(ismember({x.category},{'in_library_grid','in_library_continuous'}));o=x(ismember({x.category},{'structure_out','parameter_out'}));if isempty(a),r.validation_inlibrary_set_accuracy=NaN;else,r.validation_inlibrary_set_accuracy=mean([a.set_accuracy_given_covered],'omitnan');end;if isempty(o),r.validation_ool_false_accept=NaN;else,r.validation_ool_false_accept=mean([o.accepted_rate],'omitnan');end;r.validation_false_unique=mean([a.false_unique_rate_given_nonunique],'omitnan');r.validation_inlibrary_reject=mean([a.in_library_rejection_rate],'omitnan');r.eligible=r.validation_inlibrary_set_accuracy>=0.80;end
function r=tradeoff_row_template(),r=struct('grid_id','','scenario_id','','method_id','baseline_abs_margin_sweep','residual_scale',NaN,'validation_accepted_rate',NaN,'validation_inlibrary_set_accuracy',NaN,'validation_ool_false_accept',NaN,'validation_false_unique',NaN);end
function r=make_tradeoff_row(d,l,g,s,scale),r=tradeoff_row_template();x=evaluate_stage4a4_metrics(d,l);a=x(ismember({x.category},{'in_library_grid','in_library_continuous'}));o=x(ismember({x.category},{'structure_out','parameter_out'}));r.grid_id=g;r.scenario_id=s;r.residual_scale=scale;if isempty(a),return;end;r.validation_accepted_rate=mean([a.accepted_rate],'omitnan');r.validation_inlibrary_set_accuracy=mean([a.set_accuracy_given_covered],'omitnan');r.validation_false_unique=mean([a.false_unique_rate_given_nonunique],'omitnan');if ~isempty(o),r.validation_ool_false_accept=mean([o.accepted_rate],'omitnan');end;end
function rec=select_recommendations(rows,sc),rec=repmat(struct('grid_id','','method_id','','selection_basis','','validation_set_accuracy',NaN,'validation_ool_false_accept',NaN),0,1);gr=stable_unique({rows.grid_id});for k=1:numel(gr),a=rows(strcmp({rows.grid_id},gr{k})&strcmp({rows.scenario_id},'P0_no_prior'));if isempty(a),continue;end;ok=[a.eligible];if any(ok),a=a(ok);[~,j]=min([a.validation_ool_false_accept]);basis='P0 validation, eligible set accuracy >= 0.80';else,[~,j]=max([a.validation_inlibrary_set_accuracy]);basis='P0 validation fallback: no method reached set-accuracy target';end;r=rec_template();r.grid_id=gr{k};r.method_id=a(j).method_id;r.selection_basis=basis;r.validation_set_accuracy=a(j).validation_inlibrary_set_accuracy;r.validation_ool_false_accept=a(j).validation_ool_false_accept;rec(end+1)=r;end;end
function r=rec_template(),r=struct('grid_id','','method_id','','selection_basis','','validation_set_accuracy',NaN,'validation_ool_false_accept',NaN);end
function write_baseline_summary(cfg,sc,h),rows=repmat(struct('stage','Stage 4A.3.1','grid_id','','category','','sample_count',0,'strict_accuracy',NaN,'set_accuracy',NaN,'inlibrary_rejection',NaN,'structure_out_false_accept',NaN,'parameter_out_false_accept',NaN,'source_calibration_seed',20261101,'source_test_seed',20261102,'stage4a4_calibration_seed',sc.calibration_seed,'stage4a4_test_seed',sc.test_seed,'source_file','','configuration_hash',''),0,1);file=fullfile(cfg.results_data,'stage4a3_1_metrics.csv');if exist(file,'file'),T=readtable(file);for k=1:height(T),if strcmp(T.scenario_id{k},'P0_no_prior'),r=rows_template();r.grid_id=T.grid_id{k};r.category=T.category{k};r.sample_count=T.sample_count(k);r.strict_accuracy=T.unique_accuracy_given_covered(k);r.set_accuracy=T.set_accuracy_given_covered(k);r.inlibrary_rejection=T.in_library_reject_rate(k);r.structure_out_false_accept=T.structure_out_false_accept_rate(k);r.parameter_out_false_accept=T.parameter_out_false_accept_rate(k);r.source_calibration_seed=20261101;r.source_test_seed=20261102;r.stage4a4_calibration_seed=sc.calibration_seed;r.stage4a4_test_seed=sc.test_seed;r.source_file=file;r.configuration_hash=h;rows(end+1)=r;end;end;end;writetable(struct2table(rows),fullfile(cfg.results_data,[sc.output_prefix '_baseline_summary.csv']));end
function r=rows_template(),r=struct('stage','Stage 4A.3.1','grid_id','','category','','sample_count',0,'strict_accuracy',NaN,'set_accuracy',NaN,'inlibrary_rejection',NaN,'structure_out_false_accept',NaN,'parameter_out_false_accept',NaN,'source_calibration_seed',20261101,'source_test_seed',20261102,'stage4a4_calibration_seed',0,'stage4a4_test_seed',0,'source_file','','configuration_hash','');end
function [h,t]=make_scientific_hash(cfg,sc,base,g),payload=struct('stage',sc.stage_name,'version',sc.version,'code_version',sc.code_version,'generator',sc.generator,'candidates',{base},'parameter_search',sc.parameter_search,'parameter_grid',{g},'grids',sc.grids,'ofdm',cfg.ofdm,'observation',struct('measurement_kind',sc.measurement_kind,'Zs',cfg.Zs,'Zr',cfg.Zr,'port_reference',cfg.port_reference_ohm),'distance',struct('feature',sc.feature,'weights',sc.weights,'options',sc.distance_options,'tie_tolerance',sc.tie_tolerance),'calibration',sc.calibration,'sample_design',sc.sample_design,'methods',{sc.methods});[h,t]=stage4a4_scientific_config_hash(payload);end
function c=replace_cache_hash(c,h),c.configuration_hash=h;for k=1:numel(c.templates),c.templates(k).configuration_hash=h;end,end
function write_outputs(cfg,sc,bank,d,l,m,t,r,g,v,tr,rec,h,ht,models,audit),data=cfg.results_data;prefix=sc.output_prefix;writetable(struct2table(bank_table(bank,sc)),fullfile(data,[prefix '_trial_bank.csv']));writetable(struct2table(d),fullfile(data,[prefix '_match_decisions.csv']));writetable(struct2table(l),fullfile(data,[prefix '_scoring_labels.csv']));writetable(struct2table(t),fullfile(data,[prefix '_thresholds.csv']));writetable(struct2table(m),fullfile(data,[prefix '_metrics.csv']));writetable(struct2table(r),fullfile(data,[prefix '_runtime_and_cache.csv']));writetable(struct2table(g),fullfile(data,[prefix '_frequency_grid_manifest.csv']));writetable(struct2table(v),fullfile(data,[prefix '_validation_summary.csv']));writetable(struct2table(tr),fullfile(data,[prefix '_validation_tradeoff.csv']));writetable(struct2table(rec),fullfile(data,[prefix '_recommendations.csv']));manifest=struct('scientific_configuration_hash',h,'scientific_configuration_text',ht,'output_prefix',prefix,'training_seed',sc.training_seed,'calibration_seed',sc.calibration_seed,'validation_seed',sc.validation_seed,'test_seed',sc.test_seed,'methods',{sc.methods},'source_tag',sc.source_tag);writetable(struct2table(manifest),fullfile(data,[prefix '_configuration_manifest.csv']));save(fullfile(data,[prefix '_results.mat']),'sc','bank','d','l','m','t','r','g','v','tr','rec','models','audit','-v7.3');end
function x=bank_table(b,sc),x=repmat(struct('sample_id','','split','','category','','truth_topology_id','','canonical_key','','truth_main_length_scale',NaN,'truth_branch_length_scale',NaN,'truth_branch_load_scale',NaN,'truth_source_impedance_ohm',NaN,'truth_receiver_impedance_ohm',NaN,'outlier_dimension','','outlier_direction','','source_tag','','training_seed',sc.training_seed,'calibration_seed',sc.calibration_seed,'validation_seed',sc.validation_seed,'test_seed',sc.test_seed),numel(b),1);for k=1:numel(b),z=b(k).truth_theta;x(k)=struct('sample_id',b(k).sample_id,'split',b(k).split,'category',b(k).category,'truth_topology_id',b(k).truth_topology_id,'canonical_key',b(k).canonical_key,'truth_main_length_scale',z.main_length_scale,'truth_branch_length_scale',z.branch_length_scale,'truth_branch_load_scale',z.branch_load_scale,'truth_source_impedance_ohm',z.source_impedance_ohm,'truth_receiver_impedance_ohm',z.receiver_impedance_ohm,'outlier_dimension',b(k).outlier_dimension,'outlier_direction',b(k).outlier_direction,'source_tag',b(k).source_tag,'training_seed',sc.training_seed,'calibration_seed',sc.calibration_seed,'validation_seed',sc.validation_seed,'test_seed',sc.test_seed);end,end
function out=stable_unique(x),out={};for k=1:numel(x),if ~any(strcmp(out,x{k})),out{end+1}=x{k};end,end,end
