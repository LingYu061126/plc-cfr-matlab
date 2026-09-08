function summary = exp_stage4a7_1_candidate_generation_and_confirmation(root_dir,mode)
%EXP_STAGE4A7_1_CANDIDATE_GENERATION_AND_CONFIRMATION Independent A-grid Pilot.
%   The experiment separates engineering candidate generation, stable
%   forward-model compatibility, independent calibration, truth-free
%   confirmation and offline scoring. It is not a Final experiment.
    if nargin<1||isempty(root_dir),root_dir=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='pilot';end
    addpath(fullfile(root_dir,'src'),fullfile(root_dir,'config'));
    base=default_config(root_dir);sc=stage4a7_1_candidate_confirmation_config(base,mode);
    ensure_dir(sc.results_data);ensure_dir(sc.results_logs);total_timer=tic;
    source_hash=stage4a7_1_source_tree_hash(root_dir);
    scientific_hash=stage4a4_scientific_config_hash(scientific_payload(sc,source_hash));

    generation_timer=tic;
    old=generate_radial_topology_candidates(sc.legacy_grammar);legacy=stage4a7_1_adapt_legacy_candidates(old);
    for k=1:numel(legacy),[legacy(k),~]=check_forward_model_compatibility(legacy(k),base);end
    ids={legacy.graph_candidate_id};
    small=small_engineering_spec(sc);
    [eng,eng_audit]=generate_engineering_topology_candidates(small);
    for k=1:numel(eng),[eng(k),~]=check_forward_model_compatibility(eng(k),base);end
    [topk,topk_audit]=generate_topk_topology_candidates(small,numel(eng));
    for k=1:numel(topk),[topk(k),~]=check_forward_model_compatibility(topk(k),base);end
    exact_match=isequal(sort({eng.canonical_graph_key}),sort({topk.canonical_graph_key}));
    generation_s=toc(generation_timer);

    [calibration,pilot,final_reserved]=generate_stage4a7_1_scenarios(sc,old);
    grid=struct('id',sc.grid_id,'frequency_hz',sc.frequency_hz);
    cache_timer=tic;[cache,cache_status,cache_file]=load_or_build_cache(sc,base,old,grid,source_hash,scientific_hash);cache_s=toc(cache_timer);
    audit=cache.current_equivalence_audit;

    materialize_timer=tic;
    [calibration,cal_obs,cal_eq]=materialize(calibration,old,sc,base);
    [pilot,pilot_obs,pilot_eq]=materialize(pilot,old,sc,base);
    materialize_s=toc(materialize_timer);
    assert_no_split_overlap(calibration,pilot);

    a5=sc.stage4a5_1_config;a5.grids=grid;
    [sub8,~]=stage4a5_make_subbands(sc.frequency_hz,8,sc.grid_id,scientific_hash);
    [mask_design,mask_manifest]=build_frozen_resampling_masks(grid,{'calibration','pilot'},a5,scientific_hash);
    cal_masks=mask_design(strcmp({mask_design.replicate_id},'calibration')).masks;
    pilot_masks=mask_design(strcmp({mask_design.replicate_id},'pilot')).masks;
    calibration_score_timer=tic;cal_raw=score_observations(cal_obs,cache,sub8,cal_masks,calibration,'calibration');cal_score_s=toc(calibration_score_timer);
    pilot_score_timer=tic;pilot_raw=score_observations(pilot_obs,cache,sub8,pilot_masks,pilot,'pilot');pilot_score_s=toc(pilot_score_timer);

    calibration_model_timer=tic;
    m3_model=calibrate_stage4a5_confirmation(cal_raw,a5,sc.grid_id,scientific_hash,sc.seeds.calibration);
    specs=stage4a5_method_specs(a5);m3_spec=specs(strcmp({specs.method_id},sc.frozen_m3_method_id));
    if numel(m3_spec)~=1,error('stage4a7_1:FrozenM3Missing','Frozen M3 method ID was not found.');end
    crows=candidate_calibration_rows(cal_raw,calibration,ids);
    cset_model=calibrate_candidate_set_predictor(crows,sc.alpha,struct('minimum_per_candidate',sc.scenario_design.calibration_count_per_candidate,'compatibility_hash',scientific_hash));
    weighted_threshold=weighted_calibration_threshold(cal_raw,calibration,ids,sc);
    calibration_model_s=toc(calibration_model_timer);

    decision_timer=tic;
    decisions=decide_all(pilot_raw,pilot,ids,audit,m3_model,m3_spec,cset_model,weighted_threshold,sc,scientific_hash);
    decision_s=toc(decision_timer);
    labels=label_rows(pilot,scientific_hash);
    metrics=evaluate_stage4a7_1_pilot_metrics(decisions,labels);
    coverage=candidate_coverage_rows(legacy,eng,ids);
    complexity=candidate_complexity_rows(old,pilot_raw,numel(topology_parameter_grid(sc.parameter_search)));
    independence=independence_rows(calibration,pilot,final_reserved);
    runtime=runtime_rows(generation_s,cache_s,materialize_s,cal_score_s,pilot_score_s,calibration_model_s,decision_s,toc(total_timer),cache_status);
    manifest=configuration_manifest(sc,scientific_hash,source_hash,m3_model,cset_model,cache_file,final_reserved);

    write_rows(fullfile(sc.results_data,'legacy_candidate_audit.csv'),legacy_rows(legacy));
    write_rows(fullfile(sc.results_data,'engineering_candidate_audit.csv'),audit_rows(eng,eng_audit));
    write_rows(fullfile(sc.results_data,'topk_candidate_audit.csv'),audit_rows(topk,topk_audit));
    write_rows(fullfile(sc.results_data,'candidate_coverage_audit.csv'),coverage);
    write_rows(fullfile(sc.results_data,'candidate_complexity_audit.csv'),complexity);
    write_rows(fullfile(sc.results_data,'calibration_scenario_manifest.csv'),scenario_rows(calibration));
    write_rows(fullfile(sc.results_data,'pilot_scenario_manifest.csv'),scenario_rows(pilot));
    write_rows(fullfile(sc.results_data,'calibration_nonconformity.csv'),crows);
    write_rows(fullfile(sc.results_data,'candidate_set_calibration.csv'),class_rows(cset_model));
    write_rows(fullfile(sc.results_data,'topology_confirmation_thresholds.csv'),threshold_rows(m3_model,cset_model,weighted_threshold,sc));
    write_rows(fullfile(sc.results_data,'pilot_match_decisions.csv'),decisions);
    write_rows(fullfile(sc.results_data,'pilot_scoring_labels.csv'),labels);
    write_rows(fullfile(sc.results_data,'pilot_metrics.csv'),metrics);
    write_rows(fullfile(sc.results_data,'scenario_equivalence_audit.csv'),[cal_eq(:);pilot_eq(:)]);
    write_rows(fullfile(sc.results_data,'independence_audit.csv'),independence);
    write_rows(fullfile(sc.results_data,'resampling_manifest.csv'),mask_manifest);
    write_rows(fullfile(sc.results_data,'runtime_summary.csv'),runtime);
    write_rows(fullfile(sc.results_data,'configuration_manifest.csv'),manifest);

    summary=struct('stage_name',sc.stage_name,'status','completed_controlled_pilot_not_final', ...
        'legacy_candidate_count',numel(legacy),'engineering_candidate_count',numel(eng), ...
        'forward_compatible_legacy_count',nnz([legacy.forward_model_compatible]), ...
        'scored_legacy_count',nnz([legacy.scored_library_included]),'topk_candidate_count',numel(topk), ...
        'exact_vs_topk_key_match',exact_match,'topology_calibration_count',numel(calibration), ...
        'topology_calibration_per_candidate',sc.scenario_design.calibration_count_per_candidate, ...
        'pilot_scenario_count',numel(pilot),'parameter_calibration_count',0, ...
        'candidate_set_status',cset_model.status,'minimum_attainable_p',min([cset_model.classes.minimum_attainable_p]), ...
        'conditional_false_unique_denominator',metric_value(metrics,'C_set_plus_I','all','false_unique_conditional','denominator'), ...
        'scientific_hash',scientific_hash,'source_tree_hash',source_hash,'runtime_s',toc(total_timer), ...
        'final_reserved_status',final_reserved.status,'stage4b_started',false);
    save(fullfile(sc.results_data,'stage4a7_1_pilot_results.mat'),'summary','sc','manifest','calibration','pilot','final_reserved','decisions','labels','metrics','m3_model','cset_model','weighted_threshold','eng_audit','topk_audit','runtime','-v7.3');
    write_rows(fullfile(sc.results_data,'stage4a7_1_pilot_summary.csv'),summary_row(summary));
    fprintf('Stage 4A.7.1 controlled Pilot completed in %.3f s; calibration=%d, Pilot=%d, conditional false-unique denominator=%d.\n',summary.runtime_s,numel(calibration),numel(pilot),summary.conditional_false_unique_denominator);
end

function payload=scientific_payload(sc,source_hash)
    payload=struct('stage',sc.stage_name,'version',sc.version,'grid_id',sc.grid_id,'frequency_hz',sc.frequency_hz, ...
        'legacy_grammar',sc.legacy_grammar,'parameter_search',sc.parameter_search,'confirmation',sc.confirmation, ...
        'noise',sc.noise,'scenario_design',sc.scenario_design,'seeds',sc.seeds,'alpha',sc.alpha, ...
        'frozen_m3_method_id',sc.frozen_m3_method_id,'source_tree_hash',source_hash);
end
function s=small_engineering_spec(sc)
    s=struct('node_ids',{{'A','B','C','D'}},'allowed_edges',{{'A','B';'A','C';'A','D';'B','C';'B','D';'C','D'}}, ...
        'required_edges',{{'A','B'}},'forbidden_edges',{{'C','D'}},'maximum_degree',3,'maximum_candidate_count',128, ...
        'radial_only',true,'require_connected',true,'prior_source',sc.prior_source,'edge_prior_cost',[0;3;1;2;4;5]);
end
function [cache,status,path]=load_or_build_cache(sc,cfg,candidates,grid,source_hash,scientific_hash)
    theta=topology_parameter_grid(sc.parameter_search);path=fullfile(sc.results_data,sprintf('candidate_cache_%s.mat',source_hash(1:12)));status='rebuilt';
    if exist(path,'file'),z=load(path,'cache');if isfield(z,'cache')&&strcmp(getf(z.cache,'source_tree_hash',''),source_hash)&&isequal(z.cache.frequency_hz(:).',grid.frequency_hz(:).'),cache=z.cache;status='validated_cache';return;end,end
    nominal=theta(find([theta.regularization]==0,1));lib=build_composite_topology_library(grid.frequency_hz,candidates,nominal,sc.measurement_kind,cfg,numel(candidates));audit=audit_candidate_observability(candidates,lib,cfg,sc.confirmation.indistinguishability_resolution);
    meta=struct('measurement_kind',sc.measurement_kind,'tie_tolerance',sc.confirmation.indistinguishability_resolution, ...
        'distance_feature','complex_raw','distance_weights',[0.5 0.5],'distance_options',struct(), ...
        'scenario_id','stage4a7_1_P0','configuration_hash',scientific_hash,'max_composite_templates',numel(candidates)*numel(theta), ...
        'baseline_P0_audit',audit,'cache_schema_version','stage4a7_1_cache_v1','cache_configuration_hash',scientific_hash, ...
        'forward_model_source_hash',source_hash,'experiment_scientific_hash',scientific_hash,'source_tree_hash',source_hash);
    cache=build_stage4a5_1_template_cache(grid,candidates,theta,cfg,meta);save(path,'cache','-v7.3');
end
function [rows,obs,eqrows]=materialize(rows,candidates,sc,cfg)
    obs=cell(numel(rows),1);eqrows=repmat(eq_template(),numel(rows),1);
    for k=1:numel(rows)
        [net,local]=topology_apply_parameters(rows(k).truth_network,cfg,rows(k).truth_theta);[measurement,~]=plc_measurement_bundle(sc.measurement_kind,net,rows(k).truth_theta,local);[views,~]=plc_multiview_response(sc.frequency_hz,net,measurement,local);obs{k}=views;
        rows(k).noiseless_cfr_hash=cfr_hash(views);rows(k).observation_hash=rows(k).noiseless_cfr_hash;
        members={};comparable=false;
        if rows(k).truth_candidate_index>0
            comparable=true;
            for g=1:numel(candidates)
                [gn,gl]=topology_apply_parameters(candidates(g).network,cfg,rows(k).truth_theta);[gm,~]=plc_measurement_bundle(sc.measurement_kind,gn,rows(k).truth_theta,gl);[gv,~]=plc_multiview_response(sc.frequency_hz,gn,gm,gl);
                if cfr_distance(views,gv)<=sc.confirmation.indistinguishability_resolution,members{end+1}=candidates(g).topology_id;end %#ok<AGROW>
            end
            rows(k).truth_equivalence_set=strjoin(members,',');rows(k).truth_equivalence_member_count=numel(members);rows(k).truth_unique_under_observation=numel(members)==1;rows(k).equivalence_evaluable=true;
        else
            rows(k).truth_equivalence_set=rows(k).truth_topology_id;rows(k).truth_equivalence_member_count=1;rows(k).truth_unique_under_observation=false;rows(k).equivalence_evaluable=false;
        end
        eqrows(k)=struct('sample_id',rows(k).sample_id,'split',rows(k).split,'truth_topology_id',rows(k).truth_topology_id, ...
            'same_theta_equivalence_set',rows(k).truth_equivalence_set,'same_theta_equivalence_member_count',rows(k).truth_equivalence_member_count, ...
            'equivalence_evaluable',rows(k).equivalence_evaluable,'comparison_status',ternary(comparable,'comparable','truth_outside_scored_library'), ...
            'equivalence_tolerance',sc.confirmation.indistinguishability_resolution,'scenario_parameter_hash',rows(k).parameter_vector_hash, ...
            'scenario_observation_hash',rows(k).observation_hash);
    end
end
function raw=score_observations(obs,cache,subbands,masks,rows,rep)
    first=score_stage4a5_1_observation(obs{1},cache,subbands,masks,struct('candidate_count_before_prior',cache.candidate_count));
    first.sample_id=rows(1).sample_id;first.replicate_id=rep;first.split=rows(1).split;
    raw=repmat(first,numel(obs),1);
    for k=1:numel(obs)
        if k>1
            item=score_stage4a5_1_observation(obs{k},cache,subbands,masks,struct('candidate_count_before_prior',cache.candidate_count));
            item.sample_id=rows(k).sample_id;item.replicate_id=rep;item.split=rows(k).split;raw(k)=item;
        end
    end
end
function rows=candidate_calibration_rows(raw,scenarios,ids)
    rows=repmat(struct('sample_id','','candidate_id','','score',NaN,'split','calibration','parameter_vector_hash','','observation_hash',''),numel(raw),1);
    for k=1:numel(raw),j=find(strcmp(raw(k).topology_labels,scenarios(k).truth_topology_id),1);rows(k)=struct('sample_id',scenarios(k).sample_id,'candidate_id',ids{j},'score',raw(k).topology_scores(j),'split','calibration','parameter_vector_hash',scenarios(k).parameter_vector_hash,'observation_hash',scenarios(k).observation_hash);end
end
function threshold=weighted_calibration_threshold(raw,scenarios,ids,sc)
    z=NaN(1,numel(raw));n=numel(sc.frequency_hz);
    for k=1:numel(raw),j=find(strcmp(ids,scenarios(k).truth_topology_id),1);z(k)=n*raw(k).topology_scores(j)^2/sc.noise.sigma2;end
    threshold=struct('value',q_local(z,sc.noise.weighted_residual_quantile)*sc.noise.threshold_safety_factor,'sample_count',numel(z),'quantile',sc.noise.weighted_residual_quantile,'safety_factor',sc.noise.threshold_safety_factor,'sigma2',sc.noise.sigma2,'status','calibrated_explicit_noise_scale','interpretation','GLRT_compatible_weighted_residual_not_formal_likelihood');
end
function decisions=decide_all(raw,scenarios,ids,audit,m3_model,m3_spec,cset_model,wth,sc,scientific_hash)
    methods={'M0_min_residual','M3_frozen','W_GLRT_compatible','C_set','C_set_plus_I'};decisions=repmat(decision_template(),numel(raw)*numel(methods),1);q=0;
    for k=1:numel(raw)
        cscore=repmat(struct('candidate_id','','score',NaN),numel(ids),1);for j=1:numel(ids),cscore(j)=struct('candidate_id',ids{j},'score',raw(k).topology_scores(j));end
        cset=apply_candidate_set_predictor(cscore,cset_model,sc.alpha);
        for m=1:numel(methods),q=q+1;decisions(q)=one_decision(methods{m},raw(k),scenarios(k),ids,audit,m3_model,m3_spec,cset,wth,sc,scientific_hash);end
    end
end
function d=one_decision(method,raw,scenario,ids,audit,m3_model,m3_spec,cset,wth,sc,scientific_hash)
    d=decision_template();d.sample_id=scenario.sample_id;d.method_id=method;d.ranked_candidates=strjoin(raw.topology_labels(sort_indices(raw.topology_scores)),',');d.best_topology_id=raw.best_topology_id;d.best_residual=raw.best_distance;d.second_residual=raw.second_distance;d.margin=raw.margin;d.rho=raw.rho;d.stability=raw.stability.best_class_stability;d.candidate_generation_hash=scientific_hash;d.compatibility_hash=scientific_hash;accepted={};
    switch method
        case 'M0_min_residual'
            accepted=parse_set(raw.best_equivalence_members);d.decision=classify_set(accepted,audit);d.decision_reason='minimum exact composite residual; no rejection';d.calibration_hash='not_applicable';
        case 'M3_frozen'
            x=apply_stage4a5_confirmation(raw,m3_model,m3_spec);accepted=parse_set(x.accepted_topology_set);d.decision=x.decision;d.decision_reason=x.decision_reason;d.calibration_hash=m3_model.configuration_hash;
        case 'W_GLRT_compatible'
            weighted=numel(sc.frequency_hz)*(raw.topology_scores.^2)/sc.noise.sigma2;[d.noise_whitened_residual,j]=min(weighted);d.best_topology_id=ids{j};
            if d.noise_whitened_residual>wth.value,d.decision='reject_model_mismatch';d.decision_reason='weighted residual exceeds independent calibration threshold';else,accepted=equivalence_members(audit,ids{j});d.decision=classify_set(accepted,audit);d.decision_reason='GLRT-compatible weighted residual rank under explicit frozen covariance scale';end
            d.calibration_hash=stage4a4_scientific_config_hash(wth);
        case 'C_set'
            accepted=cset.accepted_candidate_set;d.decision=classify_set(accepted,audit);d.decision_reason='class-conditional empirical calibration set';d.p_values=encode_p(cset);d.calibration_hash=cset.calibration_hash;
        case 'C_set_plus_I'
            accepted=cset.accepted_candidate_set;d.p_values=encode_p(cset);d.calibration_hash=cset.calibration_hash;
            if isempty(accepted),d.decision='reject_model_mismatch';d.decision_reason='empirical candidate set is empty';else,ix=find(ismember(ids,accepted));g=build_candidate_indistinguishability_graph(ids(ix),raw.topology_scores(ix),sc.confirmation.indistinguishability_resolution);d.indistinguishability_component_count=numel(g.components);d.decision=classify_set(accepted,audit);d.decision_reason='empirical candidate set with calibrated residual-indistinguishability audit';end
    end
    d.accepted_candidate_set=strjoin(accepted,',');d.accepted_candidate_count=numel(accepted);
end
function decision=classify_set(ids,audit)
    if isempty(ids),decision='reject_model_mismatch';return;end
    if numel(ids)==1,decision='unique_topology';return;end
    physical=false;for k=1:numel(audit.equivalence_classes),m=audit.equivalence_classes{k}.member_topology_ids;if all(ismember(ids,m))&&all(ismember(m,ids)),physical=true;break;end,end
    decision=ternary(physical,'equivalence_class','ambiguous_candidate_set');
end
function ids=equivalence_members(audit,id),ids={id};for k=1:numel(audit.equivalence_classes),m=audit.equivalence_classes{k}.member_topology_ids;if any(strcmp(m,id)),ids=m;return;end,end,end
function s=encode_p(x),parts=cell(1,numel(x.candidate_ids));for k=1:numel(parts),parts{k}=sprintf('%s:%.17g',x.candidate_ids{k},x.p_values(k));end;s=strjoin(parts,';');end
function labels=label_rows(pilot,hash)
    labels=repmat(label_template(),numel(pilot),1);for k=1:numel(pilot),labels(k)=struct('sample_id',pilot(k).sample_id,'physical_scenario_id',pilot(k).physical_scenario_id,'category',pilot(k).category,'severity',pilot(k).severity,'truth_topology_id',pilot(k).truth_topology_id,'truth_equivalence_set',pilot(k).truth_equivalence_set,'truth_equivalence_member_count',pilot(k).truth_equivalence_member_count,'truth_unique_under_observation',pilot(k).truth_unique_under_observation,'equivalence_evaluable',pilot(k).equivalence_evaluable,'parameter_domain_truth',pilot(k).parameter_domain_truth,'parameter_vector_hash',pilot(k).parameter_vector_hash,'noiseless_cfr_hash',pilot(k).noiseless_cfr_hash,'observation_hash',pilot(k).observation_hash,'scientific_hash',hash);end
end
function rows=candidate_coverage_rows(legacy,eng,ids)
    rows=repmat(struct('case_id','','engineering_candidate_count',0,'forward_compatible_candidate_count',0,'scored_candidate_count',0,'truth_topology_id','','truth_in_engineering_space',false,'truth_forward_model_compatible',false,'truth_in_scored_library',false,'coverage_failure_reason',''),3,1);
    rows(1)=merge_case('covered_truth',build_candidate_coverage_audit(legacy,ids,struct('truth_topology_id','G003')));
    rows(2)=merge_case('stale_prior_removes_truth',build_candidate_coverage_audit(legacy,setdiff(ids,{'G003'},'stable'),struct('truth_topology_id','G003')));
    rows(3)=merge_case('engineering_feasible_forward_incompatible',build_candidate_coverage_audit(eng,{},struct('truth_topology_id',eng(1).graph_candidate_id)));
end
function r=merge_case(id,x),r=x;r.case_id=id;r=orderfields(r,{'case_id','engineering_candidate_count','forward_compatible_candidate_count','scored_candidate_count','truth_topology_id','truth_in_engineering_space','truth_forward_model_compatible','truth_in_scored_library','coverage_failure_reason'});end
function rows=independence_rows(cal,pilot,final_reserved)
    rows=repmat(struct('split','','row_count',0,'unique_physical_scenario_count',0,'unique_parameter_hash_count',0,'unique_cfr_hash_count',NaN,'duplicate_parameter_count',0,'duplicate_cfr_count',NaN,'cross_split_parameter_duplicate_count',NaN,'cross_split_cfr_duplicate_count',NaN,'status',''),3,1);
    rows(1)=ind_row('calibration',cal,pilot);rows(2)=ind_row('pilot',pilot,cal);rows(3)=struct('split','final_reserved','row_count',0,'unique_physical_scenario_count',0,'unique_parameter_hash_count',0,'unique_cfr_hash_count',NaN,'duplicate_parameter_count',0,'duplicate_cfr_count',NaN,'cross_split_parameter_duplicate_count',NaN,'cross_split_cfr_duplicate_count',NaN,'status',final_reserved.status);
end
function r=ind_row(name,x,other),np=numel(unique({x.parameter_vector_hash}));nc=numel(unique({x.noiseless_cfr_hash}));r=struct('split',name,'row_count',numel(x),'unique_physical_scenario_count',numel(unique({x.physical_scenario_id})),'unique_parameter_hash_count',np,'unique_cfr_hash_count',nc,'duplicate_parameter_count',numel(x)-np,'duplicate_cfr_count',numel(x)-nc,'cross_split_parameter_duplicate_count',numel(intersect({x.parameter_vector_hash},{other.parameter_vector_hash})),'cross_split_cfr_duplicate_count',numel(intersect({x.noiseless_cfr_hash},{other.noiseless_cfr_hash})),'status','evaluated');end
function rows=runtime_rows(a,b,c,d,e,f,g,total,cache_status),names={'candidate_generation';'cache';'scenario_materialization';'calibration_scoring';'pilot_scoring';'calibration_models';'decision_and_metrics';'total'};v=[a;b;c;d;e;f;g;total];rows=repmat(struct('phase','','runtime_s',0,'workers',1,'parallel_used',false,'cache_status',''),numel(names),1);for k=1:numel(names),rows(k)=struct('phase',names{k},'runtime_s',v(k),'workers',1,'parallel_used',false,'cache_status',ternary(k==2,cache_status,'not_applicable'));end,end
function r=configuration_manifest(sc,sci,src,m3,cset,cache_file,final_reserved),[~,n,e]=fileparts(cache_file);[~,stage_dir]=fileparts(sc.results_data);cache_rel=fullfile('results','data',stage_dir,[n e]);r=struct('stage_name',sc.stage_name,'mode',sc.mode,'grid_id',sc.grid_id,'frequency_count',numel(sc.frequency_hz),'scientific_hash',sci,'source_tree_hash',src,'candidate_generation_hash',sci,'m3_calibration_hash',m3.configuration_hash,'candidate_set_calibration_hash',cset.calibration_hash,'calibration_seed',sc.seeds.calibration,'pilot_seed',sc.seeds.pilot,'final_reserved_seed',sc.seeds.final_reserved,'calibration_count_per_candidate',sc.scenario_design.calibration_count_per_candidate,'minimum_attainable_p',min([cset.classes.minimum_attainable_p]),'cache_file',cache_rel,'use_parallel',false,'num_workers',1,'matlab_version',version,'final_reserved_status',final_reserved.status,'full_final_run',false,'stage4b_started',false);end
function rows=threshold_rows(m3,cset,w,sc),rows=repmat(struct('method_id','','threshold_name','','value',NaN,'calibration_count',0,'calibration_hash','','status',''),4,1);rows(1)=thr('M3_frozen','residual_threshold',m3.thresholds.residual_threshold,m3.calibration_sample_count,m3.configuration_hash,'calibrated');rows(2)=thr('M3_frozen','margin_threshold',m3.thresholds.margin_threshold,m3.calibration_sample_count,m3.configuration_hash,'calibrated');rows(3)=thr('W_GLRT_compatible','weighted_residual_threshold',w.value,w.sample_count,stage4a4_scientific_config_hash(w),w.status);rows(4)=thr('C_set','alpha',sc.alpha,cset.calibration_sample_count,cset.calibration_hash,cset.status);end
function r=thr(m,n,v,c,h,s),r=struct('method_id',m,'threshold_name',n,'value',v,'calibration_count',c,'calibration_hash',h,'status',s);end
function rows=class_rows(model),rows=repmat(struct('candidate_id','','sample_count',0,'minimum_attainable_p',NaN,'status','','calibration_hash',''),numel(model.classes),1);for k=1:numel(rows),rows(k)=struct('candidate_id',model.classes(k).candidate_id,'sample_count',model.classes(k).sample_count,'minimum_attainable_p',model.classes(k).minimum_attainable_p,'status',model.classes(k).status,'calibration_hash',model.calibration_hash);end,end
function rows=scenario_rows(x),rows=repmat(struct('sample_id','','physical_scenario_id','','split','','category','','severity','','truth_topology_id','','parameter_domain_truth','','outlier_dimension','','outlier_direction','','master_seed',0,'case_seed',0,'parameter_vector_hash','','noiseless_cfr_hash','','observation_hash',''),numel(x),1);for k=1:numel(x),rows(k)=struct('sample_id',x(k).sample_id,'physical_scenario_id',x(k).physical_scenario_id,'split',x(k).split,'category',x(k).category,'severity',x(k).severity,'truth_topology_id',x(k).truth_topology_id,'parameter_domain_truth',x(k).parameter_domain_truth,'outlier_dimension',x(k).outlier_dimension,'outlier_direction',x(k).outlier_direction,'master_seed',x(k).master_seed,'case_seed',x(k).case_seed,'parameter_vector_hash',x(k).parameter_vector_hash,'noiseless_cfr_hash',x(k).noiseless_cfr_hash,'observation_hash',x(k).observation_hash);end,end
function rows=legacy_rows(c),rows=repmat(struct('candidate_id','','canonical_key','','generation_route','','forward_model_compatible',false,'compatibility_reason','','scored_library_included',false),1,numel(c));for k=1:numel(c),rows(k)=struct('candidate_id',c(k).graph_candidate_id,'canonical_key',c(k).canonical_graph_key,'generation_route',c(k).generation_route,'forward_model_compatible',logical(c(k).forward_model_compatible),'compatibility_reason',c(k).compatibility_reason,'scored_library_included',logical(c(k).scored_library_included));end,end
function rows=candidate_complexity_rows(c,raw,template_count),rows=repmat(struct('candidate_id','','parameter_dimension',0,'template_count',template_count,'mean_pilot_residual',NaN,'minimum_pilot_residual',NaN,'complexity_audit_status','reported_without_AIC_BIC'),numel(c),1);for k=1:numel(c),z=arrayfun(@(x)x.topology_scores(k),raw);rows(k)=struct('candidate_id',c(k).topology_id,'parameter_dimension',nnz(topology_active_parameter_mask(c(k))),'template_count',template_count,'mean_pilot_residual',mean(z),'minimum_pilot_residual',min(z),'complexity_audit_status','reported_without_AIC_BIC');end,end
function rows=audit_rows(c,a),rows=repmat(struct('candidate_id','','canonical_graph_key','','prior_cost',NaN,'forward_model_compatible',false,'generation_route','','feasible_count',NaN,'theoretical_edge_subset_count',NaN,'search_node_count',NaN,'cycle_pruned',NaN,'connectivity_pruned',NaN,'degree_pruned',NaN),1,numel(c));for k=1:numel(c),rows(k)=struct('candidate_id',c(k).graph_candidate_id,'canonical_graph_key',c(k).canonical_graph_key,'prior_cost',c(k).prior_cost,'forward_model_compatible',logical_finite(getf(c(k),'forward_model_compatible',false)),'generation_route',c(k).generation_route,'feasible_count',getf(a,'feasible_radial_candidate_count',getf(a,'candidate_count',NaN)),'theoretical_edge_subset_count',getf(a,'theoretical_edge_subset_count',NaN),'search_node_count',getf(a,'search_node_count',NaN),'cycle_pruned',getf(a,'cycle_pruned_branch_count',NaN),'connectivity_pruned',getf(a,'connectivity_pruned_branch_count',NaN),'degree_pruned',getf(a,'degree_pruned_branch_count',NaN));end,end
function r=summary_row(s),r=s;end
function v=metric_value(m,method,category,name,field),x=m(strcmp({m.method_id},method)&strcmp({m.category},category)&strcmp({m.metric_name},name));if isempty(x),v=NaN;else,v=x(1).(field);end,end
function assert_no_split_overlap(a,b),assert(isempty(intersect({a.sample_id},{b.sample_id})),'stage4a7_1:SplitSampleOverlap');assert(isempty(intersect({a.parameter_vector_hash},{b.parameter_vector_hash})),'stage4a7_1:SplitParameterOverlap');assert(isempty(intersect({a.noiseless_cfr_hash},{b.noiseless_cfr_hash})),'stage4a7_1:SplitObservationOverlap');end
function d=cfr_distance(a,b),e=0;n=0;for k=1:numel(a),z=a{k}(:)-b{k}(:);e=e+sum(abs(z).^2);n=n+numel(z);end;d=sqrt(e/max(n,1));end
function h=cfr_hash(v),payload=cell(1,numel(v));for k=1:numel(v),payload{k}=struct('real',real(v{k}(:).'),'imag',imag(v{k}(:).'));end;h=stage4a4_scientific_config_hash(payload);end
function ix=sort_indices(x),[~,ix]=sort(x,'ascend');end
function x=parse_set(s),if isempty(s),x={};else,x=strsplit(char(s),',');x=x(~cellfun(@isempty,x));end,end
function q=q_local(x,p),x=sort(x(isfinite(x)));if isempty(x),q=NaN;elseif numel(x)==1,q=x;else,t=1+(numel(x)-1)*p;l=floor(t);h=ceil(t);q=x(l)+(t-l)*(x(h)-x(l));end,end
function write_rows(path,rows),if isempty(rows),return;end;writetable(struct2table(rows(:)),path);end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=logical_finite(v),x=(islogical(v)&&v)||(isnumeric(v)&&isscalar(v)&&isfinite(v)&&v~=0);end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function r=decision_template(),r=struct('sample_id','','method_id','','decision','','decision_reason','','ranked_candidates','','accepted_candidate_set','','accepted_candidate_count',0,'best_topology_id','','best_residual',NaN,'second_residual',NaN,'noise_whitened_residual',NaN,'margin',NaN,'rho',NaN,'stability',NaN,'p_values','','indistinguishability_component_count',NaN,'calibration_hash','','candidate_generation_hash','','compatibility_hash','');end
function r=label_template(),r=struct('sample_id','','physical_scenario_id','','category','','severity','','truth_topology_id','','truth_equivalence_set','','truth_equivalence_member_count',0,'truth_unique_under_observation',false,'equivalence_evaluable',false,'parameter_domain_truth','','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','scientific_hash','');end
function r=eq_template(),r=struct('sample_id','','split','','truth_topology_id','','same_theta_equivalence_set','','same_theta_equivalence_member_count',0,'equivalence_evaluable',false,'comparison_status','','equivalence_tolerance',NaN,'scenario_parameter_hash','','scenario_observation_hash','');end
