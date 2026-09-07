function out = exp_stage4a6_3_1_protocol_pilot(root)
%EXP_STAGE4A6_3_1_PROTOCOL_PILOT A-grid frozen-confirmation pilot only.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));cfg=default_config(root);sc=stage4a6_3_1_protocol_config(cfg,'pilot');ensure_dir(sc.results_data);ensure_dir(sc.results_logs);ensure_dir(sc.cache_dir);
    candidates=generate_radial_topology_candidates(sc.generator);theta_grid=topology_parameter_grid(sc.parameter_search);source_hash=stage4a6_3_1_source_tree_hash(root);grid=sc.grids(1);f=grid.frequency_hz(:).';
    cache_hash=stage4a4_scientific_config_hash(struct('schema','stage4a6_3_1_cache_v1','frequency_hz',f,'candidates',{candidate_manifest(candidates)},'parameter_grid',{theta_grid},'measurement_kind',sc.measurement_kind,'distance',sc.distance,'termination',sc.termination,'source_tree_hash',source_hash));cache_file=fullfile(sc.cache_dir,[sc.grid_id '_P0_no_prior.mat']);cache=[];cache_status='rebuilt';
    if exist(cache_file,'file'),z=load(cache_file,'cache');if isfield(z,'cache')&&cache_ok(z.cache,candidates,theta_grid,sc,source_hash,cache_hash),cache=z.cache;cache_status='validated';end,end
    if isempty(cache)
        nom=theta_grid(find([theta_grid.regularization]==0,1));audit0=audit_candidate_observability(candidates,build_composite_topology_library(f,candidates,nom,sc.measurement_kind,cfg,numel(candidates)),cfg,sc.distance.tie_tolerance);
        meta=struct('measurement_kind',sc.measurement_kind,'tie_tolerance',sc.distance.tie_tolerance,'distance_feature',sc.distance.feature,'distance_weights',sc.distance.weights,'distance_options',sc.distance.options,'scenario_id','P0_no_prior','configuration_hash',cache_hash,'max_composite_templates',numel(candidates)*numel(theta_grid),'baseline_P0_audit',audit0,'cache_schema_version','stage4a6_3_1_cache_v1','cache_configuration_hash',cache_hash,'forward_model_source_hash',source_hash,'experiment_scientific_hash',cache_hash,'source_tree_hash',source_hash);
        cache=build_stage4a5_1_template_cache(grid,candidates,theta_grid,cfg,meta);cache.compatibility_hash='';save(cache_file,'cache','-v7.3');cache_status='rebuilt';
    end
    [compat_hash,canonical]=stage4a6_3_1_compatibility_hash(sc,candidates,theta_grid,source_hash,cache);cache.compatibility_hash=compat_hash;cache.experiment_scientific_hash=compat_hash;save(cache_file,'cache','-v7.3');
    calbank=generate_stage4a6_3_1_independent_trials(sc,'calibration',candidates);allpilot=generate_stage4a6_3_1_independent_trials(sc,'pilot',candidates);evalbank=allpilot(strcmp({allpilot.split},'pilot'));bank=[calbank(:);evalbank(:)];write_rows(bank_rows(bank),fullfile(sc.results_data,'stage4a6_3_1_trial_bank.csv'));
    audit=trial_audit(calbank,evalbank,bank);write_rows(audit,fullfile(sc.results_data,'stage4a6_3_1_trial_bank_audit.csv'));write_rows(struct('stage',sc.stage_name,'version',sc.version,'mode',sc.mode,'grid_id',sc.grid_id,'frequency_count',numel(f),'candidate_count_before_prior',numel(candidates),'candidate_count_after_prior',cache.candidate_count,'parameter_template_count',numel(theta_grid),'composite_template_count',cache.composite_template_count,'compatibility_hash',compat_hash,'source_tree_hash',source_hash,'canonical_configuration_text',canonical,'calibration_seed',sc.seeds.calibration,'pilot_seed',sc.seeds.pilot,'use_parallel',false,'num_workers',1),fullfile(sc.results_data,'stage4a6_3_1_configuration_manifest.csv'));
    [sets,subrows]=stage4a5_make_subbands(f,sc.confirmation.M,sc.grid_id,compat_hash);write_rows(subrows,fullfile(sc.results_data,'stage4a6_3_1_subband_manifest.csv'));
    calraw=[];cal_profiles=[];cal_labels=repmat(label_template(),0,1);t0=tic;
    for k=1:numel(calbank),obs=make_observation(calbank(k),cfg,f);o=score_opts(sc,calbank(k),numel(candidates));r=score_stage4a5_observation(obs,cache,sets,o);r.sample_id=calbank(k).sample_id;r.replicate_id=calbank(k).replicate_id;if isempty(calraw),calraw=r;else,calraw(end+1)=r;end;cal_labels(end+1)=label_from_trial(calbank(k)); %#ok<AGROW>
    end
    calmodel=calibrate_stage4a5_confirmation(calraw,sc,sc.grid_id,compat_hash,sc.seeds.calibration);calmodel.compatibility_hash=compat_hash;calmodel.calibration_split_id='stage4a6_3_1_calibration';calmodel.source_tree_hash=source_hash;calmodel.calibration_scientific_hash=stage4a4_scientific_config_hash(struct('compatibility_hash',compat_hash,'calibration_ids',{ {calbank.sample_id} },'seed',sc.seeds.calibration));calmodel.created_at=datestr(now,30);calmodel.matlab_version=version;save(fullfile(sc.results_data,'stage4a6_3_1_calibration_model.mat'),'calmodel','-v7.3');write_rows(threshold_rows(calmodel,compat_hash,source_hash),fullfile(sc.results_data,'stage4a6_3_1_calibration_thresholds.csv'));
    decisions=repmat(decision_row(),0,1);labels=repmat(label_template(),0,1);profiles=[];popt=profile_options(sc);profile_count=0;
    for k=1:numel(evalbank)
        obs=make_observation(evalbank(k),cfg,f);spec=sc.confirmation;spec.stability_seed=stable_seed(sc.seeds.pilot,evalbank(k).sample_id);conf=confirm_stage4a6_3_1_topology(obs,cache,sets,calmodel,spec,compat_hash);d=decision_row();d.sample_id=evalbank(k).sample_id;d.method_id=spec.method_id;d.decision=conf.decision;d.topology_status=conf.decision;d.topology_set=conf.accepted_topology_set;d.decision_reason=conf.decision_reason;d.best_topology_id=conf.best_topology_id;d.accepted_topology_set=conf.accepted_topology_set;d.accepted_member_count=conf.accepted_member_count;d.best_distance=conf.best_distance;d.second_distance=conf.second_distance;d.margin=conf.margin;d.rho=conf.rho;d.compatibility_hash=compat_hash;d.calibration_hash=conf.calibration_hash;
        if profile_count<sc.pilot_profile_case_limit&&conf.accepted_member_count>0
            pe=run_stage4a6_3_1_member_profiles(obs,f,conf,candidates,cfg,build_extended_parameter_domain(sc.parameter_search,sc.extended_domain_eta),popt,invalid_parameter_model(compat_hash));d.parameter_domain_status=pe.parameter_domain_status;d.evaluated_member_count=pe.evaluated_member_count;d.accepted_member_count=pe.accepted_member_count;if isempty(profiles),profiles=pe;else,profiles(end+1)=pe;end;profile_count=profile_count+1;
        else,d.parameter_domain_status='parameter_not_evaluated';d.evaluated_member_count=0;end
        decisions(end+1)=d;labels(end+1)=label_from_trial(evalbank(k)); %#ok<AGROW>
    end
    metrics=evaluate_stage4a6_3_1_metrics(decisions,labels);write_rows(decisions,fullfile(sc.results_data,'stage4a6_3_1_pilot_match_decisions.csv'));write_rows(labels,fullfile(sc.results_data,'stage4a6_3_1_pilot_scoring_labels.csv'));write_rows(metrics,fullfile(sc.results_data,'stage4a6_3_1_pilot_metrics.csv'));write_rows(struct('cache_status',cache_status,'cache_file',cache_file,'compatibility_hash',compat_hash,'source_tree_hash',source_hash,'calibration_runtime_s',toc(t0),'profile_case_count',profile_count,'calibration_count',numel(calbank),'evaluation_count',numel(evalbank),'worker_count',1,'use_parallel',false),fullfile(sc.results_data,'stage4a6_3_1_runtime_summary.csv'));save(fullfile(sc.results_data,'stage4a6_3_1_pilot_results.mat'),'sc','candidates','theta_grid','cache','bank','calraw','calmodel','decisions','labels','profiles','metrics','compat_hash','source_hash','canonical','-v7.3');write_text(fullfile(sc.results_logs,'stage4a6_3_1_pilot.log'),sprintf('Stage 4A.6.3.1 pilot\nMATLAB=%s\ncompatibility_hash=%s\nsource_tree_hash=%s\ncalibration_cases=%d\nevaluation_cases=%d\nprofile_cases=%d\ncache_status=%s\nfull_final_rerun=false\n',version,compat_hash,source_hash,numel(calbank),numel(evalbank),profile_count,cache_status));out=struct('compatibility_hash',compat_hash,'source_tree_hash',source_hash,'calibration_model',calmodel,'decisions',decisions,'labels',labels,'metrics',metrics,'profile_count',profile_count,'cache_status',cache_status);
end
function p=profile_options(sc),p=sc.optimization;p.profile=sc.profile;p.minimum_sensitivity_floor=1e-10;p.profile.enabled=true;p.profile.profile_multi_start_count=1;p.profile.multistart_single_start_policy='not_applicable';end
function m=invalid_parameter_model(h),m=struct('calibration_status','insufficient_calibration','parameter_thresholds',struct([]),'compatibility_hash',h,'calibration_hash','','minimum_profile_reliable_samples',2);end
function o=score_opts(sc,b,count),o=struct('candidate_count_before_prior',count,'repetitions',sc.confirmation.stability_repetitions,'block_count',sc.confirmation.block_count,'block_fraction',sc.confirmation.block_fraction,'stability_seed',stable_seed(sc.seeds.pilot,b.sample_id));end
function v=make_observation(b,cfg,f),[n,lc]=topology_apply_parameters(b.truth_network,cfg,b.truth_theta);[m,~]=plc_measurement_bundle('siso_forward',n,b.truth_theta,lc);[v,~]=plc_multiview_response(f,n,m,lc);end
function tf=cache_ok(c,ca,t,sc,sh,h),tf=isfield(c,'compatibility_hash')&&isfield(c,'cache_schema_version')&&strcmp(c.cache_schema_version,'stage4a6_3_1_cache_v1')&&strcmp(getfield_default(c,'cache_configuration_hash',''),h)&&strcmp(getfield_default(c,'forward_model_source_hash',''),sh)&&isequal(c.frequency_hz(:),sc.grids(1).frequency_hz(:))&&isequal({c.candidates.topology_id},{ca.topology_id})&&isequal({c.candidates.canonical_key},{ca.canonical_key})&&isequal(c.parameter_grid,t)&&c.parameter_template_count==numel(t)&&strcmp(c.measurement_kind,sc.measurement_kind)&&isequal(c.distance_weights,sc.distance.weights);end
function cm=candidate_manifest(c),cm=repmat(struct('topology_id','','canonical_key',''),numel(c),1);for k=1:numel(c),cm(k).topology_id=c(k).topology_id;cm(k).canonical_key=c(k).canonical_key;end,end
function r=label_from_trial(b),r=label_template();r.sample_id=b.sample_id;r.category=b.category;r.truth_topology_id=b.truth_topology_id;r.parameter_domain_truth=b.parameter_domain_truth;r.physical_scenario_id=b.physical_scenario_id;r.outlier_dimension=b.outlier_dimension;r.outlier_severity=b.outlier_severity;r.outlier_direction=b.outlier_direction;end
function r=label_template(),r=struct('sample_id','','category','','truth_topology_id','','parameter_domain_truth','','physical_scenario_id','','outlier_dimension','','outlier_severity','','outlier_direction','');end
function r=decision_row(),r=struct('sample_id','','method_id','','decision','','topology_status','','topology_set','','decision_reason','','best_topology_id','','accepted_topology_set','','accepted_member_count',0,'evaluated_member_count',0,'parameter_domain_status','parameter_not_evaluated','best_distance',NaN,'second_distance',NaN,'margin',NaN,'rho',NaN,'compatibility_hash','','calibration_hash','');end
function r=bank_rows(b),r=repmat(struct('sample_id','','split','','replicate_id','','seed',0,'truth_topology_id','','canonical_key','','category','','outlier_dimension','','outlier_severity','','outlier_direction','','parameter_domain_truth','','physical_scenario_id','','nuisance_sample_id','','parameter_jitter_fraction',NaN,'active_parameter_names','','active_parameter_count',0,'frequency_count',61,'source_tag',''),numel(b),1);for k=1:numel(b),f=fieldnames(r);for j=1:numel(f),if isfield(b(k),f{j}),r(k).(f{j})=b(k).(f{j});end,end,end,end
function r=threshold_rows(m,h,sh)
    if ~isfield(m,'parameter_thresholds') || isempty(m.parameter_thresholds)
        n=getfield_default(m,'reliable_calibration_evidence_count',0);s=getfield_default(m,'calibration_status','not_applicable');
        r=struct('parameter_name','','status',s,'reliable_sample_count',n,'compatibility_hash',h,'source_tree_hash',sh,'threshold_kind','topology_confirmation_only');
    else
        r=m.parameter_thresholds;for k=1:numel(r),r(k).compatibility_hash=h;r(k).source_tree_hash=sh;r(k).threshold_kind='parameter_domain';end
    end
end
function r=trial_audit(cal,ev,b)
    ci={cal.sample_id};ei={ev.sample_id};pi={b.physical_scenario_id};
    r=struct('audit_status',ternary(isempty(intersect(ci,ei))&&numel(unique(pi))==numel(pi),'passed','failed'), ...
        'calibration_count',numel(cal),'evaluation_count',numel(ev),'combined_count',numel(b), ...
        'calibration_evaluation_id_overlap',numel(intersect(ci,ei)), ...
        'unique_physical_scenario_count',numel(unique(pi)),'duplicate_physical_scenario_count',numel(pi)-numel(unique(pi)), ...
        'candidate_count',7,'source_tag','synthetic_demo_prior_not_field_data');
end
function y=ternary(tf,a,b),if tf,y=a;else,y=b;end,end
function s=stable_seed(master,id),v=double(char(id));s=max(1,round(mod(master+sum(v.*(1:numel(v))),2^31-1)));end
function write_rows(x,p)
    if isempty(x),return;end
    if ~exist(fileparts(p),'dir'),mkdir(fileparts(p));end
    if isscalar(x),t=struct2table(x,'AsArray',true);else,t=struct2table(x(:));end
    writetable(t,p);
end
function write_text(p,t),if ~exist(fileparts(p),'dir'),mkdir(fileparts(p));end,f=fopen(p,'w');fprintf(f,'%s',t);fclose(f);end
function v=getfield_default(s,n,d),if isstruct(s)&&isfield(s,n),v=s.(n);else,v=d;end,end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
