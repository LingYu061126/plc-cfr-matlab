function out = exp_stage4a6_3_1_r1_metric_calibration_closure(root)
%EXP_STAGE4A6_3_1_R1_METRIC_CALIBRATION_CLOSURE Re-run the fixed-size pilot.
% The output directory is new and the truth-bearing scenario bank is used
% only to create offline scoring labels after all decisions are complete.
    if nargin < 1 || isempty(root), root=fileparts(fileparts(mfilename('fullpath'))); end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    cfg=default_config(root); sc=stage4a6_3_1_r1_protocol_config(cfg,'pilot');
    ensure_dir(sc.results_data);ensure_dir(sc.results_logs);ensure_dir(sc.cache_dir);
    caldir=fullfile(sc.results_data,'calibration');pilotdir=fullfile(sc.results_data,'pilot');
    ensure_dir(caldir);ensure_dir(pilotdir);
    t0=tic; candidates=generate_radial_topology_candidates(sc.generator);
    theta_grid=topology_parameter_grid(sc.parameter_search); grid=sc.grids(1);
    f=grid.frequency_hz(:).'; source_hash=stage4a6_3_1_r_source_tree_hash(root);
    [cache,cache_status,cache_hash]=build_cache(sc,cfg,candidates,theta_grid,grid,f,source_hash);
    [compat_hash,canonical,identity]=stage4a6_3_1_r_build_compatibility_hash( ...
        sc,candidates,theta_grid,source_hash,cache);
    cache.compatibility_hash=compat_hash; cache.experiment_scientific_hash=compat_hash;
    cache.source_tree_hash=source_hash; cache_file=fullfile(sc.cache_dir, ...
        [sc.grid_id '_P0_no_prior_R1.mat']); save(cache_file,'cache','-v7.3');

    calbank=stage4a6_3_1_r_generate_independent_scenarios(sc,'calibration',candidates);
    pilotbank=stage4a6_3_1_r_generate_independent_scenarios(sc,'pilot',candidates);
    reserved=stage4a6_3_1_r_generate_independent_scenarios(sc,'final_reserved',candidates);
    [calbank,cal_obs]=materialize_bank(calbank,cfg,f);
    [pilotbank,pilot_obs]=materialize_bank(pilotbank,cfg,f);
    eq_audit=cache.current_equivalence_audit;
    eq_hash=stage4a4_scientific_config_hash(struct('grid_id',sc.grid_id, ...
        'audit',eq_audit,'candidate_ids',{ {candidates.topology_id} }));
    calbank=stage4a6_3_1_r1_build_truth_equivalence_labels(calbank,candidates,eq_audit,eq_hash);
    pilotbank=stage4a6_3_1_r1_build_truth_equivalence_labels(pilotbank,candidates,eq_audit,eq_hash);
    write_rows(scenario_rows([calbank(:);pilotbank(:)]),fullfile(sc.results_data,'scenario_manifest.csv'));
    write_rows(reserved_rows(reserved),fullfile(sc.results_data,'final_reserved_manifest.csv'));
    audit_rows=stage4a6_3_1_r1_independence_audit(struct('calibration',calbank, ...
        'pilot',pilotbank,'final_reserved',reserved));
    write_rows(audit_rows,fullfile(pilotdir,'independence_audit.csv'));
    write_rows(cluster_rows([calbank(:);pilotbank(:)]), ...
        fullfile(pilotdir,'observation_cluster_audit.csv'));

    write_rows(struct('stage',sc.stage_name,'version',sc.version,'grid_id',sc.grid_id, ...
        'candidate_count_before_prior',numel(candidates), ...
        'candidate_count_after_prior',cache.candidate_count, ...
        'parameter_template_count',numel(theta_grid), ...
        'composite_template_count',cache.composite_template_count, ...
        'compatibility_hash',compat_hash,'source_tree_hash',source_hash, ...
        'cache_hash',cache_hash,'equivalence_configuration_hash',eq_hash, ...
        'calibration_seed',sc.seeds.calibration,'pilot_seed',sc.seeds.pilot, ...
        'final_reserved_seed',sc.seeds.final_reserved,'use_parallel',false, ...
        'num_workers',1,'final_reserved_executed',false, ...
        'metric_definition_version',sc.metric_definition_version, ...
        'topology_calibration_hash','','parameter_calibration_hash',''), ...
        fullfile(sc.results_data,'configuration_manifest.csv'));
    [sets,subrows]=stage4a5_make_subbands(f,sc.confirmation.M,sc.grid_id,compat_hash);
    write_rows(subrows,fullfile(sc.results_data,'subband_manifest.csv'));

    % Topology calibration contains no truth labels.
    calraw=repmat(struct(),0,1);
    for k=1:numel(calbank)
        opts=score_opts(sc,calbank(k),numel(candidates));
        r=score_stage4a5_observation(cal_obs{k},cache,sets,opts);
        r.sample_id=calbank(k).sample_id;r.replicate_id=calbank(k).replicate_id;
        if isempty(calraw), calraw=r; else, calraw(end+1)=r; end %#ok<AGROW>
    end
    topology_model=calibrate_stage4a5_confirmation(calraw,sc,sc.grid_id,compat_hash,sc.seeds.calibration);
    topology_model.compatibility_hash=compat_hash;
    topology_model.topology_calibration_status='calibrated';
    topology_model.topology_calibration_seed=sc.seeds.calibration;
    topology_model.topology_calibration_split_id='stage4a6_3_1_r1_calibration';
    topology_model.topology_calibration_sample_count=numel(calraw);
    topology_model.source_tree_hash=source_hash;topology_model.matlab_version=version;
    topology_model.created_at=datestr(now,30);
    topology_model.topology_calibration_hash=stage4a4_scientific_config_hash(struct( ...
        'compatibility_hash',compat_hash,'split',topology_model.topology_calibration_split_id, ...
        'seed',sc.seeds.calibration,'sample_ids',{ {calbank.sample_id} }, ...
        'thresholds',topology_model.thresholds,'rule',sc.calibration));
    save(fullfile(caldir,'topology_confirmation_calibration_model.mat'), ...
        'topology_model','identity','-v7.3');
    write_rows(topology_threshold_rows(topology_model,compat_hash,source_hash), ...
        fullfile(sc.results_data,'topology_calibration_thresholds.csv'));

    % Parameter calibration is built from reliable calibration member evidence.
    pmodel0=struct('calibration_status','insufficient_evidence', ...
        'parameter_thresholds',struct([]),'compatibility_hash',compat_hash, ...
        'source_tree_hash',source_hash,'calibration_hash','');
    domain=build_extended_parameter_domain(sc.parameter_search,sc.extended_domain_eta);
    popt=profile_options(sc);cal_evidence=repmat(struct(),0,1);cal_members=repmat(member_row(),0,1);
    for k=1:numel(calbank)
        conf=stage4a6_3_1_r_confirm_with_frozen_stage4a5_1(cal_obs{k},cache,sets, ...
            topology_model,sc.confirmation,compat_hash);
        if conf.accepted_member_count>0
            pe=stage4a6_3_1_r_profile_all_accepted_members(cal_obs{k},f,conf, ...
                candidates,cfg,domain,popt,pmodel0);
            e=getfield_default(pe,'member_evidence',struct([]));
            if ~isempty(e)
                if isempty(cal_evidence), cal_evidence=e(:); else, cal_evidence=[cal_evidence(:);e(:)]; end %#ok<AGROW>
                mr=member_rows(calbank(k),pe,compat_hash,topology_model.topology_calibration_hash,'');
                if isempty(cal_members), cal_members=mr(:); else, cal_members=[cal_members(:);mr(:)]; end %#ok<AGROW>
            end
        end
    end
    pmodel=calibrate_stage4a6_2_parameter_thresholds(cal_evidence,sc, ...
        sc.extended_domain_eta,compat_hash);
    if ~isfield(pmodel,'calibration_status'),pmodel.calibration_status='insufficient_evidence';end
    pmodel.compatibility_hash=compat_hash;pmodel.source_tree_hash=source_hash;
    pmodel.parameter_calibration_split_id='stage4a6_3_1_r1_calibration';
    pmodel.parameter_calibration_seed=sc.seeds.calibration;
    pmodel.parameter_calibration_sample_count=numel(cal_evidence);
    pmodel.parameter_calibration_reliable_count=getfield_default(pmodel, ...
        'reliable_calibration_evidence_count',0);
    pmodel.matlab_version=version;pmodel.created_at=datestr(now,30);
    pmodel.parameter_calibration_hash=stage4a4_scientific_config_hash(struct( ...
        'compatibility_hash',compat_hash,'split',pmodel.parameter_calibration_split_id, ...
        'seed',sc.seeds.calibration,'evidence',cal_evidence, ...
        'thresholds',pmodel.parameter_thresholds,'rule',sc.parameter_calibration));
    pmodel.calibration_hash=pmodel.parameter_calibration_hash;
    save(fullfile(caldir,'parameter_domain_calibration_model.mat'), ...
        'pmodel','cal_evidence','cal_members','-v7.3');
    write_rows(parameter_threshold_rows(pmodel,compat_hash,source_hash), ...
        fullfile(sc.results_data,'parameter_calibration_thresholds.csv'));
    write_rows(parameter_calibration_summary(pmodel,compat_hash,source_hash), ...
        fullfile(caldir,'parameter_calibration_summary.csv'));

    % Pilot uses the two calibration identities and produces scoring labels
    % only after decisions are complete.
    decisions=repmat(decision_row(),0,1);labels=repmat(label_row(),0,1);
    members=repmat(member_row(),0,1);profile_cases=0;
    for k=1:numel(pilotbank)
        spec=sc.confirmation;spec.stability_seed=stable_seed(sc.seeds.pilot,pilotbank(k).sample_id);
        conf=stage4a6_3_1_r1_confirm_with_frozen_stage4a5_1(pilot_obs{k},cache,sets, ...
            topology_model,spec,compat_hash,topology_model.topology_calibration_hash);
        d=decision_row();d.sample_id=pilotbank(k).sample_id;d.method_id=conf.confirmation_method_id;
        d.decision=conf.decision;d.topology_status=conf.decision;d.topology_set=conf.accepted_topology_set;
        d.accepted_topology_set=conf.accepted_topology_set;d.decision_reason=conf.decision_reason;
        d.best_topology_id=conf.best_topology_id;d.accepted_member_count=conf.accepted_member_count;
        d.evaluated_member_count=0;d.member_profile_reliable=false;d.parameter_domain_status='parameter_not_evaluated';
        d.best_distance=conf.best_distance;d.second_distance=conf.second_distance;d.margin=conf.margin;d.rho=conf.rho;
        d.compatibility_hash=compat_hash;d.topology_calibration_hash=topology_model.topology_calibration_hash;
        d.parameter_calibration_hash=pmodel.parameter_calibration_hash;
        if conf.accepted_member_count>0
            pe=stage4a6_3_1_r1_profile_all_accepted_members(pilot_obs{k},f,conf, ...
                candidates,cfg,domain,popt,pmodel,compat_hash,pmodel.parameter_calibration_hash, ...
                'A6_3_M3_joint_diagnostic');
            d.parameter_domain_status=pe.parameter_domain_status;
            d.evaluated_member_count=getfield_default(pe,'evaluated_member_count',0);
            d.member_profile_reliable=getfield_default(pe,'parameter_decision_reliable',false);
            d.reliable_member_count=getfield_default(pe,'reliable_member_count',0);
            d.unreliable_member_count=getfield_default(pe,'unreliable_member_count',0);
            d.member_domain_statuses=strjoin(getfield_default(pe,'member_domain_statuses',{}),',');
            d.class_aggregation_reason=getfield_default(pe,'class_aggregation_reason','');
            profile_cases=profile_cases+1;
            mr=member_rows(pilotbank(k),pe,compat_hash, ...
                topology_model.topology_calibration_hash,pmodel.parameter_calibration_hash);
            if isempty(members), members=mr(:); else, members=[members(:);mr(:)]; end %#ok<AGROW>
        end
        decisions(end+1)=d; %#ok<AGROW>
        labels(end+1)=label_from_trial(pilotbank(k)); %#ok<AGROW>
    end
    metrics=stage4a6_3_1_r1_evaluate_metrics(decisions,labels);
    write_rows(decisions,fullfile(pilotdir,'pilot_match_decisions.csv'));
    write_rows(members,fullfile(pilotdir,'pilot_member_evidence.csv'));
    write_rows(labels,fullfile(pilotdir,'pilot_scoring_labels.csv'));
    write_rows(metrics,fullfile(pilotdir,'pilot_metrics.csv'));
    rt=struct('cache_status',cache_status,'cache_file',cache_file, ...
        'compatibility_hash',compat_hash,'source_tree_hash',source_hash, ...
        'topology_calibration_hash',topology_model.topology_calibration_hash, ...
        'parameter_calibration_hash',pmodel.parameter_calibration_hash, ...
        'initial_compute_runtime_s',toc(t0),'resume_check_runtime_s',0, ...
        'total_compute_runtime_s',toc(t0),'calibration_case_count',numel(calbank), ...
        'pilot_case_count',numel(pilotbank),'profile_case_count',profile_cases, ...
        'worker_count',1,'use_parallel',false,'final_reserved_executed',false);
    write_rows(rt,fullfile(sc.results_data,'runtime_summary.csv'));
    save(fullfile(sc.results_data,'stage4a6_3_1_r1_pilot_results.mat'), ...
        'sc','candidates','theta_grid','cache','calbank','pilotbank','reserved', ...
        'calraw','topology_model','pmodel','decisions','labels','members','metrics', ...
        'compat_hash','source_hash','canonical','eq_hash','-v7.3');
    write_text(fullfile(sc.results_logs,'stage4a6_3_1_r1_pilot.log'),sprintf([ ...
        'Stage 4A.6.3.1-R.1 metric/calibration closure\nMATLAB=%s\n' ...
        'compatibility_hash=%s\nsource_tree_hash=%s\n' ...
        'topology_calibration_hash=%s\nparameter_calibration_hash=%s\n' ...
        'calibration_cases=%d\npilot_cases=%d\nprofile_cases=%d\n' ...
        'final_reserved_executed=false\nuse_parallel=false\n'],version,compat_hash, ...
        source_hash,topology_model.topology_calibration_hash, ...
        pmodel.parameter_calibration_hash,numel(calbank),numel(pilotbank),profile_cases));
    out=struct('metrics',metrics,'decisions',decisions,'labels',labels,'members',members, ...
        'topology_model',topology_model,'parameter_model',pmodel, ...
        'compatibility_hash',compat_hash,'source_tree_hash',source_hash, ...
        'calibration_count',numel(calbank),'pilot_count',numel(pilotbank));
end

function [cache,status,h]=build_cache(sc,cfg,candidates,theta_grid,grid,f,source_hash)
    h=stage4a4_scientific_config_hash(struct('schema','stage4a6_3_1_r1_cache_v1', ...
        'frequency_hz',f,'candidates',{candidate_manifest(candidates)}, ...
        'parameter_grid',{theta_grid},'measurement_kind',sc.measurement_kind, ...
        'distance',sc.distance,'termination',sc.termination,'source_tree_hash',source_hash));
    file=fullfile(sc.cache_dir,[sc.grid_id '_P0_no_prior_R1.mat']);cache=[];status='rebuilt';
    if exist(file,'file')
        z=load(file,'cache');if isfield(z,'cache')&&strcmp(getfield_default(z.cache,'cache_configuration_hash',''),h),cache=z.cache;status='validated';end
    end
    if isempty(cache)
        nom=theta_grid(find([theta_grid.regularization]==0,1));
        lib=build_composite_topology_library(f,candidates,nom,sc.measurement_kind,cfg,numel(candidates));
        audit0=audit_candidate_observability(candidates,lib,cfg,sc.distance.tie_tolerance);
        meta=struct('measurement_kind',sc.measurement_kind,'tie_tolerance',sc.distance.tie_tolerance, ...
            'distance_feature',sc.distance.feature,'distance_weights',sc.distance.weights, ...
            'distance_options',sc.distance.options,'scenario_id','P0_no_prior', ...
            'configuration_hash',h,'max_composite_templates',numel(candidates)*numel(theta_grid), ...
            'baseline_P0_audit',audit0,'cache_schema_version','stage4a6_3_1_r1_cache_v1', ...
            'cache_configuration_hash',h,'forward_model_source_hash',source_hash, ...
            'experiment_scientific_hash',h,'source_tree_hash',source_hash);
        cache=build_stage4a5_1_template_cache(grid,candidates,theta_grid,cfg,meta);cache.cache_configuration_hash=h;
    end
end
function cm=candidate_manifest(c),cm=repmat(struct('topology_id','','canonical_key',''),numel(c),1);for k=1:numel(c),cm(k).topology_id=c(k).topology_id;cm(k).canonical_key=c(k).canonical_key;end,end
function [b,obs]=materialize_bank(b,cfg,f),obs=cell(numel(b),1);for k=1:numel(b),[b(k),obs{k}]=stage4a6_3_1_r_materialize_scenario(b(k),cfg,f);end,end
function p=profile_options(sc),p=sc.optimization;p.profile=sc.profile;p.minimum_sensitivity_floor=1e-10;p.profile.enabled=true;p.profile.profile_multi_start_count=1;p.profile.multistart_single_start_policy='not_applicable';end
function o=score_opts(sc,b,count),o=struct('candidate_count_before_prior',count,'repetitions',sc.confirmation.stability_repetitions,'block_count',sc.confirmation.block_count,'block_fraction',sc.confirmation.block_fraction,'stability_seed',stable_seed(sc.seeds.pilot,b.sample_id));end
function s=stable_seed(master,id),v=double(char(id));s=max(1,round(mod(double(master)+sum(v.*(1:numel(v))),2^31-1)));end
function r=decision_row(),r=struct('sample_id','','method_id','','decision','','topology_status','','topology_set','','accepted_topology_set','','decision_reason','','best_topology_id','','accepted_member_count',0,'evaluated_member_count',0,'reliable_member_count',0,'unreliable_member_count',0,'member_profile_reliable',false,'member_domain_statuses','','class_aggregation_reason','','parameter_domain_status','parameter_not_evaluated','parameter_decision_reliable',false,'best_distance',NaN,'second_distance',NaN,'margin',NaN,'rho',NaN,'compatibility_hash','','topology_calibration_hash','','parameter_calibration_hash','');end
function r=label_row(),r=struct('sample_id','','category','','truth_topology_id','','truth_equivalence_set','','truth_equivalence_member_count',NaN,'truth_unique_under_observation',NaN,'equivalence_audit_hash','','equivalence_configuration_hash','','parameter_domain_truth','','physical_scenario_id','','outlier_dimension','','outlier_severity','','outlier_direction','','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','');end
function r=label_from_trial(b),r=label_row();f=fieldnames(r);for k=1:numel(f),if isfield(b,f{k}),r.(f{k})=b.(f{k});end,end,end
function r=member_row(),r=struct('sample_id','','accepted_topology_id','','accepted_member_count',0,'evaluated_member_count',0,'profile_status','','profile_reliable',false,'in_distance',NaN,'ext_distance',NaN,'parameter_domain_status','','compatibility_hash','','topology_calibration_hash','','parameter_calibration_hash','');end
function rows=member_rows(b,pe,compat,topo,par),e=getfield_default(pe,'member_evidence',struct([]));rows=repmat(member_row(),0,1);for k=1:numel(e),r=member_row();r.sample_id=b.sample_id;r.accepted_topology_id=e(k).topology_id;r.accepted_member_count=pe.accepted_member_count;r.evaluated_member_count=pe.evaluated_member_count;r.profile_reliable=e(k).profile_reliable;r.profile_status=getfield_default(e(k),'profile_status',ternary(e(k).profile_reliable,'reliable','not_reliable'));r.in_distance=e(k).in_distance;r.ext_distance=e(k).ext_distance;r.parameter_domain_status=pe.parameter_domain_status;r.compatibility_hash=compat;r.topology_calibration_hash=topo;r.parameter_calibration_hash=par;rows(end+1)=r;end,end
function rows=scenario_rows(b),rows=repmat(struct('sample_id','','split','','seed',0,'truth_topology_id','','canonical_key','','category','','outlier_dimension','','outlier_severity','','outlier_direction','','physical_scenario_id','','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','truth_equivalence_set','','truth_equivalence_member_count',NaN,'truth_unique_under_observation',NaN,'source_tag',''),numel(b),1);for k=1:numel(b),f=fieldnames(rows);for j=1:numel(f),if isfield(b(k),f{j}),rows(k).(f{j})=b(k).(f{j});end,end,end,end
function rows=reserved_rows(b),rows=repmat(struct('sample_id','','split','','seed',0,'truth_topology_id','','canonical_key','','physical_scenario_id','','category',''),numel(b),1);for k=1:numel(b),rows(k).sample_id=b(k).sample_id;rows(k).split=b(k).split;rows(k).seed=b(k).seed;rows(k).truth_topology_id=b(k).truth_topology_id;rows(k).canonical_key=b(k).canonical_key;rows(k).physical_scenario_id=b(k).physical_scenario_id;rows(k).category=b(k).category;end,end
function rows=topology_threshold_rows(m,h,sh),rows=struct('parameter_name','topology_confirmation','status',m.topology_calibration_status,'sample_count',m.topology_calibration_sample_count,'topology_calibration_hash',m.topology_calibration_hash,'topology_calibration_split_id',m.topology_calibration_split_id,'topology_calibration_seed',m.topology_calibration_seed,'compatibility_hash',h,'source_tree_hash',sh);end
function rows=parameter_threshold_rows(m,h,sh),rows=m.parameter_thresholds;for k=1:numel(rows),rows(k).parameter_calibration_hash=m.parameter_calibration_hash;rows(k).parameter_calibration_split_id=m.parameter_calibration_split_id;rows(k).parameter_calibration_seed=m.parameter_calibration_seed;rows(k).parameter_calibration_sample_count=m.parameter_calibration_sample_count;rows(k).parameter_calibration_reliable_count=m.parameter_calibration_reliable_count;rows(k).compatibility_hash=h;rows(k).source_tree_hash=sh;end,end
function r=parameter_calibration_summary(m,h,sh),r=struct('calibration_status',m.calibration_status,'total_evidence_count',m.total_calibration_evidence_count,'reliable_evidence_count',m.reliable_calibration_evidence_count,'excluded_evidence_count',m.excluded_calibration_evidence_count,'parameter_calibration_hash',m.parameter_calibration_hash,'parameter_calibration_split_id',m.parameter_calibration_split_id,'parameter_calibration_seed',m.parameter_calibration_seed,'parameter_calibration_sample_count',m.parameter_calibration_sample_count,'parameter_calibration_reliable_count',m.parameter_calibration_reliable_count,'compatibility_hash',h,'source_tree_hash',sh);end
function rows=cluster_rows(b),keys=cell(1,numel(b));for k=1:numel(b),keys{k}=b(k).noiseless_cfr_hash;if isempty(keys{k}),keys{k}=b(k).parameter_vector_hash;end,end;u=unique(keys,'stable');rows=repmat(struct('split','','category','','observation_cluster_id','','cluster_member_count',0,'row_count',0,'duplicate_type',''),0,1);for k=1:numel(u),ix=strcmp(keys,u{k});r=rows_template();r.split=b(find(ix,1)).split;r.category=b(find(ix,1)).category;r.observation_cluster_id=u{k};r.cluster_member_count=sum(ix);r.row_count=sum(ix);r.duplicate_type=ternary(r.cluster_member_count>1,'exact_hash_duplicate','unique');rows(end+1)=r;end,end
function r=rows_template(),r=struct('split','','category','','observation_cluster_id','','cluster_member_count',0,'row_count',0,'duplicate_type','');end
function y=ternary(tf,a,b),if tf,y=a;else,y=b;end,end
function v=getfield_default(s,n,d),if isstruct(s)&&isfield(s,n),v=s.(n);else,v=d;end,end
function write_rows(x,p),if isempty(x),return;end,ensure_dir(fileparts(p));if isscalar(x),t=struct2table(x,'AsArray',true);else,t=struct2table(x(:));end,writetable(t,p);end
function write_text(p,t),ensure_dir(fileparts(p));fid=fopen(p,'w');fprintf(fid,'%s',t);fclose(fid);end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
