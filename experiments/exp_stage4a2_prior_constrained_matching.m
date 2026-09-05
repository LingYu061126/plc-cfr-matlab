function output = exp_stage4a2_prior_constrained_matching(cfg, sc)
%EXP_STAGE4A2_PRIOR_CONSTRAINED_MATCHING Synthetic prior/coverage audit.
%   Results are model-internal: they do not represent GIS, a PLC modem, or
%   field topology recovery. CFRs are noiseless complete-network responses.

    if nargin<1||isempty(cfg),root=fileparts(fileparts(mfilename('fullpath')));cfg=default_config(root);end
    if nargin<2||isempty(sc),sc=stage4a2_prior_config(cfg);end
    ensure_result_dirs(cfg); rng(sc.random_seed,'twister'); started=tic;
    theta_grid=topology_parameter_grid(sc.parameter_search);
    assert(numel(theta_grid)==sc.parameter_template_count_expected,'Unexpected stage-2.3 grid size.');
    prior_rows=struct([]); candidate_rows=struct([]); summary_rows=struct([]); equivalence_rows=struct([]);
    scenarios=sc.prior_scenarios; candidate_sets=cell(1,numel(scenarios));
    for s=1:numel(scenarios)
        candidate_sets{s}=generate_prior_constrained_candidates(sc.generator,scenarios(s).asset_prior);
        prior_rows=[prior_rows;prior_row(scenarios(s))]; %#ok<AGROW>
        candidate_rows=[candidate_rows;candidate_manifest_rows(scenarios(s).id,candidate_sets{s})]; %#ok<AGROW>
    end
    trials=struct([]); grid_records=struct([]); thresholds=cell(1,numel(sc.frequency_grids));
    for g=1:numel(sc.frequency_grids)
        fg=sc.frequency_grids(g); f=fg.frequency_hz;
        thresholds{g}=calibrate_thresholds(f,candidate_sets{1},theta_grid,cfg,sc,g);
        grid_records=[grid_records;frequency_row(fg)]; %#ok<AGROW>
        for s=1:numel(scenarios)
            cand=candidate_sets{s}; composite=numel(cand)*numel(theta_grid);
            summary_rows=[summary_rows;struct('scenario_id',scenarios(s).id,'frequency_grid_id',fg.id, ...
                'candidate_count_before_prior',numel(candidate_sets{1}),'candidate_count_after_prior',numel(cand), ...
                'parameter_template_count',numel(theta_grid),'composite_template_count',composite, ...
                'streaming_used',true,'prior_config_hash',prior_hash(scenarios(s)), ...
                'configuration_hash',run_hash(sc,scenarios(s),fg,thresholds{g}))]; %#ok<AGROW>
            if ~isempty(cand)
                nominal=theta_grid(find([theta_grid.regularization]==0,1));
                nominal_library=build_composite_topology_library(f,cand,nominal,sc.measurement_kind,cfg,numel(cand));
                audit=audit_candidate_observability(cand,nominal_library,cfg,sc.tie_tolerance);
                equivalence_rows=[equivalence_rows;equivalence_manifest_rows(scenarios(s).id,fg.id,audit)]; %#ok<AGROW>
            end
        end
        % Shared truth/observation conditions make P0/P1/P2 comparable.
        p0=candidate_sets{1}; p1=candidate_sets{2}; p2=candidate_sets{3}; nominal_i=find([theta_grid.regularization]==0,1);
        trials=[trials;run_trial('P0_no_prior',fg.id,'library_in_grid',p0,p0(3),theta_grid(nominal_i),'covered',f,theta_grid,cfg,sc,thresholds{g})]; %#ok<AGROW>
        if strcmp(fg.id,'A_stage4a1_quick61')
            out_theta=continuous_theta(theta_grid(nominal_i));
            trials=[trials;run_trial('P0_no_prior',fg.id,'library_in_grid_out',p0,p0(7),out_theta,'covered',f,theta_grid,cfg,sc,thresholds{g})]; %#ok<AGROW>
            truth_all=generate_radial_topology_candidates(with_three_branches(sc.generator)); truth_out=truth_all(end);
            trials=[trials;run_trial('P0_no_prior',fg.id,'library_out_legal_tree',p0,truth_out,out_theta,'out_of_library',f,theta_grid,cfg,sc,thresholds{g})]; %#ok<AGROW>
            trials=[trials;run_trial('P1_partial_consistent_prior',fg.id,'partial_prior_covered',p1,p1(min(3,numel(p1))),theta_grid(nominal_i),'covered',f,theta_grid,cfg,sc,thresholds{g})]; %#ok<AGROW>
            trials=[trials;run_trial('P2_stale_or_inconsistent_prior',fg.id,'stale_prior_truth_excluded',p2,p0(3),theta_grid(nominal_i),'excluded_by_prior',f,theta_grid,cfg,sc,thresholds{g})]; %#ok<AGROW>
        end
    end
    metric_rows=metrics_rows(trials);
    prefix=sc.output_prefix;
    writetable(struct2table(prior_rows),fullfile(cfg.results_data,[prefix '_prior_manifest.csv']));
    writetable(struct2table(candidate_rows),fullfile(cfg.results_data,[prefix '_candidate_manifest.csv']));
    writetable(struct2table(summary_rows),fullfile(cfg.results_data,[prefix '_composite_library_summary.csv']));
    writetable(struct2table(trials),fullfile(cfg.results_data,[prefix '_match_trials.csv']));
    writetable(struct2table(metric_rows),fullfile(cfg.results_data,[prefix '_metrics_by_scenario.csv']));
    writetable(struct2table(equivalence_rows),fullfile(cfg.results_data,[prefix '_equivalence_audit.csv']));
    writetable(struct2table(grid_records,'AsArray',true),fullfile(cfg.results_data,[prefix '_frequency_grid_manifest.csv']));
    elapsed=toc(started);
    save(fullfile(cfg.results_data,[prefix '_results.mat']),'sc','theta_grid','candidate_sets','thresholds','trials','metric_rows','summary_rows','equivalence_rows','grid_records','elapsed','-v7.3');
    fprintf('Stage 4A.2: grid=%d templates/graph, trials=%d, elapsed=%.3f s\n',numel(theta_grid),numel(trials),elapsed);
    output=struct('sc',sc,'theta_grid',theta_grid,'candidate_sets',{candidate_sets},'thresholds',{thresholds}, ...
        'trials',trials,'metrics',metric_rows,'elapsed_s',elapsed);
end

function threshold=calibrate_thresholds(f,candidates,grid,cfg,sc,grid_index)
    rng(sc.calibration_seed+grid_index,'twister'); samples=[]; margins=[]; ni=find([grid.regularization]==0,1);
    ncal=2; if numel(f)>100, ncal=1; end
    for k=1:ncal
        theta=continuous_theta(grid(ni)); theta.main_length_scale=1+(2*rand-1)*0.004; theta.branch_length_scale=1+(2*rand-1)*0.004;
        obs=observed(f,candidates(2*k-1).network,theta,sc.measurement_kind,cfg);
        r=match_once(obs,f,candidates,grid,cfg,sc,struct('mismatch_distance_threshold',Inf,'margin_threshold',0),'covered');
        samples(end+1)=r.best_distance; %#ok<AGROW>
        if isfinite(r.margin)&&r.margin>0,margins(end+1)=r.margin;end %#ok<AGROW>
    end
    threshold=struct('mismatch_distance_threshold',max(sc.calibration.minimum_mismatch_threshold, ...
        percentile(samples,sc.calibration.mismatch_quantile)*sc.calibration.mismatch_safety_factor), ...
        'margin_threshold',max(sc.calibration.minimum_margin_threshold,percentile(margins,sc.calibration.margin_quantile)), ...
        'name',sc.calibration.threshold_name,'calibration_seed',sc.calibration_seed+grid_index);
end
function row=run_trial(scenario,grid_id,kind,candidates,truth,truth_theta,coverage,f,grid,cfg,sc,threshold)
    obs=observed(f,truth.network,truth_theta,sc.measurement_kind,cfg);
    r=match_once(obs,f,candidates,grid,cfg,sc,threshold,coverage);
    truth_class='not_in_library'; truth_nonunique=false;
    if strcmp(coverage,'covered')
        ti=find(strcmp({candidates.topology_id},truth.topology_id),1);
        truth_class=r.class_audit.core.class_labels{ti}; truth_nonunique=r.class_audit.core.class_sizes(r.class_audit.core.class_index(ti))>1;
    end
    row=struct('scenario_id',scenario,'frequency_grid_id',grid_id,'trial_kind',kind, ...
        'truth_topology_id',truth.topology_id,'coverage_status',coverage,'truth_equivalence_class',truth_class, ...
        'truth_nonunique',truth_nonunique,'best_template_id',r.best_template_id,'best_topology_id',r.best_topology_id, ...
        'best_equivalence_class',r.best_equivalence_class,'best_distance',r.best_distance, ...
        'second_competing_class',r.second_competing_class,'second_distance',r.second_distance,'margin',r.margin, ...
        'decision',r.decision,'candidate_count_before_prior',r.candidate_count_before_prior, ...
        'candidate_count_after_prior',r.candidate_count_after_prior,'parameter_template_count',r.parameter_template_count, ...
        'composite_template_count',r.composite_template_count,'streaming_used',r.streaming_used, ...
        'mismatch_threshold',threshold.mismatch_distance_threshold,'margin_threshold',threshold.margin_threshold, ...
        'configuration_hash',stage4a2_config_hash(struct('scenario',scenario,'grid',grid_id,'threshold',threshold)));
end
function r=match_once(obs,f,candidates,grid,cfg,sc,threshold,coverage)
    options=struct('measurement_kind',sc.measurement_kind,'tie_tolerance',sc.tie_tolerance, ...
        'distance_feature',sc.distance_feature,'distance_weights',sc.distance_weights, ...
        'distance_options',sc.distance_options,'batch_size',sc.batch_size,'thresholds',threshold, ...
        'candidate_count_before_prior',7,'coverage_status',coverage);
    r=match_composite_topology_library(obs,f,candidates,grid,cfg,options);
end
function views=observed(f,network,theta,kind,cfg)
    [net,local]=topology_apply_parameters(network,cfg,theta); [m,~]=plc_measurement_bundle(kind,net,theta,local); views=plc_multiview_response(f,net,m,local);
end
function theta=continuous_theta(theta)
    theta.main_length_scale=1.017; theta.branch_length_scale=0.983; theta.branch_load_scale=1.07;
    theta.source_impedance_ohm=52; theta.receiver_impedance_ohm=48; theta.regularization=NaN;
end
function grammar=with_three_branches(grammar),grammar.max_branches=3;grammar.max_nodes=9;grammar.max_candidates=16;end
function p=percentile(x,q)
    x=sort(x(isfinite(x))); if isempty(x),p=0;return;end
    i=max(1,min(numel(x),round(1+(numel(x)-1)*q))); p=x(i);
end
function row=prior_row(s)
    row=struct('scenario_id',s.id,'source_tag',s.source_tag,'prior_config_hash',prior_hash(s), ...
        'node_inventory_count',numel(s.asset_prior.node_inventory),'edge_prior_count',numel(s.asset_prior.edge_prior), ...
        'field_data_used',false,'scope','synthetic_demo_prior_not_field_data');
end
function h=prior_hash(s),h=stage4a2_config_hash(s.asset_prior);end
function rows=candidate_manifest_rows(id,c)
    rows=repmat(struct('scenario_id','','topology_id','','canonical_key','','node_count',0,'edge_count',0,'soft_prior_score',0,'prior_config_hash',''),numel(c),1);
    for k=1:numel(c),rows(k)=struct('scenario_id',id,'topology_id',c(k).topology_id,'canonical_key',c(k).canonical_key, ...
        'node_count',c(k).node_count,'edge_count',c(k).edge_count,'soft_prior_score',c(k).soft_prior_score,'prior_config_hash',c(k).prior_config_hash);end
end
function rows=equivalence_manifest_rows(scenario,grid,a)
    rows=repmat(struct('scenario_id','','frequency_grid_id','','class_label','','member_topology_ids','','member_count',0,'tie_tolerance',0,'config_hash',''),numel(a.equivalence_classes),1);
    for k=1:numel(a.equivalence_classes),x=a.equivalence_classes{k};rows(k)=struct('scenario_id',scenario,'frequency_grid_id',grid, ...
        'class_label',x.label,'member_topology_ids',strjoin(x.member_topology_ids,','),'member_count',numel(x.member_indices),'tie_tolerance',a.tie_tolerance,'config_hash',a.config_hash);end
end
function row=frequency_row(g)
    f=g.frequency_hz; bins='';if ~isempty(g.active_bin_1based),bins=sprintf('%d,',g.active_bin_1based);end
    row=struct('frequency_grid_id',g.id,'source',g.source,'nfft',g.nfft,'sample_rate_hz',g.sample_rate_hz, ...
        'frequency_count',numel(f),'frequency_band_hz',sprintf('%.17g,%.17g',min(f),max(f)), ...
        'frequency_spacing_hz',g.subcarrier_spacing_hz,'active_bin_1based',bins, ...
        'frequency_hz_full',sprintf('%.17g,',f));
end
function h=run_hash(sc,scenario,grid,threshold)
    h=stage4a2_config_hash(struct('generator',sc.generator,'asset_prior',scenario.asset_prior, ...
        'parameter_search',sc.parameter_search,'frequency_hz',grid.frequency_hz,'measurement_kind',sc.measurement_kind, ...
        'tie_tolerance',sc.tie_tolerance,'distance_feature',sc.distance_feature,'threshold',threshold, ...
        'seed',sc.random_seed,'version',sc.version));
end
function rows=metrics_rows(trials)
    all_keys=strcat({trials.scenario_id},'|',{trials.frequency_grid_id}); keys={};
    for i=1:numel(all_keys), if ~any(strcmp(keys,all_keys{i})), keys{end+1}=all_keys{i}; end, end %#ok<AGROW>
    rows=repmat(struct('scenario_id','','frequency_grid_id','','trial_count',0, ...
        'candidate_count_after_prior',0,'truth_coverage_rate',0,'strict_accuracy',0, ...
        'equivalent_class_accuracy',0,'false_unique_rate',0,'reject_rate',0, ...
        'out_of_library_false_accept_rate',0,'mean_margin',NaN),0,1);
    for k=1:numel(keys)
        mask=strcmp(strcat({trials.scenario_id},'|',{trials.frequency_grid_id}),keys{k}); x=trials(mask); covered=strcmp({x.coverage_status},'covered');
        strict=covered & strcmp({x.best_topology_id},{x.truth_topology_id}); eq=covered & strcmp({x.best_equivalence_class},{x.truth_equivalence_class});
        unique_decision=strcmp({x.decision},'unique_topology'); reject=startsWith({x.decision},'reject_'); out=strcmp({x.coverage_status},'out_of_library');
        rows(end+1)=struct('scenario_id',x(1).scenario_id,'frequency_grid_id',x(1).frequency_grid_id, ...
            'trial_count',numel(x),'candidate_count_after_prior',x(1).candidate_count_after_prior, ...
            'truth_coverage_rate',mean(covered),'strict_accuracy',mean(strict),'equivalent_class_accuracy',mean(eq), ...
            'false_unique_rate',mean([x.truth_nonunique]&unique_decision),'reject_rate',mean(reject), ...
            'out_of_library_false_accept_rate',mean(out&unique_decision),'mean_margin',mean([x.margin],'omitnan')); %#ok<AGROW>
    end
end
