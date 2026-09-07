function out = exp_stage4a6_3_1_r_independent_pilot(root)
%EXP_STAGE4A6_3_1_R_INDEPENDENT_PILOT Independent A-grid calibration/pilot.
% The matcher receives observations, cache and calibration only. Truth is
% attached to scoring labels after decisions have been produced.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    cfg=default_config(root);sc=stage4a6_3_1_r_protocol_config(cfg,'pilot');
    ensure_dir(sc.results_data);ensure_dir(sc.results_logs);ensure_dir(sc.cache_dir);
    caldir=fullfile(sc.results_data,'calibration');pilotdir=fullfile(sc.results_data,'pilot');
    ensure_dir(caldir);ensure_dir(pilotdir);
    candidates=generate_radial_topology_candidates(sc.generator);
    theta_grid=topology_parameter_grid(sc.parameter_search);grid=sc.grids(1);f=grid.frequency_hz(:).';
    source_hash=stage4a6_3_1_r_source_tree_hash(root);
    [cache,cache_status,cache_hash]=load_or_build_cache(sc,cfg,candidates,theta_grid,grid,f,source_hash);
    [compat_hash,canonical,identity]=stage4a6_3_1_r_build_compatibility_hash(sc,candidates,theta_grid,source_hash,cache);
    cache.compatibility_hash=compat_hash;cache.experiment_scientific_hash=compat_hash;
    cache_file=fullfile(sc.cache_dir,[sc.grid_id '_P0_no_prior_R.mat']);save(cache_file,'cache','-v7.3');
    calbank=stage4a6_3_1_r_generate_independent_scenarios(sc,'calibration',candidates);
    pilotbank=stage4a6_3_1_r_generate_independent_scenarios(sc,'pilot',candidates);
    reserved=stage4a6_3_1_r_generate_independent_scenarios(sc,'final_reserved',candidates);
    [calbank,cal_obs]=materialize_bank(calbank,cfg,f);
    [pilotbank,pilot_obs]=materialize_bank(pilotbank,cfg,f);
    write_rows(scenario_rows([calbank(:);pilotbank(:)]),fullfile(sc.results_data,'scenario_manifest.csv'));
    write_rows(reserved_rows(reserved),fullfile(sc.results_data,'final_reserved_manifest.csv'));
    write_rows(independence_rows([calbank(:);pilotbank(:)]),fullfile(pilotdir,'stage4a6_3_1_r_independence_audit.csv'));
    write_rows(struct('stage',sc.stage_name,'version',sc.version,'grid_id',sc.grid_id, ...
        'candidate_count_before_prior',numel(candidates),'candidate_count_after_prior',cache.candidate_count, ...
        'parameter_template_count',numel(theta_grid),'composite_template_count',cache.composite_template_count, ...
        'compatibility_hash',compat_hash,'source_tree_hash',source_hash,'cache_hash',cache_hash, ...
        'canonical_configuration_text',canonical,'calibration_seed',sc.seeds.calibration, ...
        'pilot_seed',sc.seeds.pilot,'final_reserved_seed',sc.seeds.final_reserved, ...
        'use_parallel',false,'num_workers',1,'final_reserved_executed',false), ...
        fullfile(sc.results_data,'configuration_manifest.csv'));
    [sets,subrows]=stage4a5_make_subbands(f,sc.confirmation.M,sc.grid_id,compat_hash);
    write_rows(subrows,fullfile(sc.results_data,'subband_manifest.csv'));
    t0=tic;calraw=[];
    for k=1:numel(calbank)
        opts=score_opts(sc,calbank(k),numel(candidates));r=score_stage4a5_observation(cal_obs{k},cache,sets,opts);
        r.sample_id=calbank(k).sample_id;r.replicate_id=calbank(k).replicate_id;
        if isempty(calraw),calraw=r;else,calraw(end+1)=r;end %#ok<AGROW>
    end
    calmodel=calibrate_stage4a5_confirmation(calraw,sc,sc.grid_id,compat_hash,sc.seeds.calibration);
    calmodel.compatibility_hash=compat_hash;calmodel.calibration_hash=stage4a4_scientific_config_hash(struct('compatibility_hash',compat_hash,'split','calibration','seed',sc.seeds.calibration,'sample_ids',{ {calbank.sample_id} }));
    calmodel.calibration_split_id='stage4a6_3_1_r_calibration';calmodel.source_tree_hash=source_hash;calmodel.matlab_version=version;calmodel.created_at=datestr(now,30);
    save(fullfile(caldir,'topology_confirmation_calibration_model.mat'),'calmodel','identity','-v7.3');
    write_rows(threshold_rows(calmodel,compat_hash,source_hash),fullfile(caldir,'topology_confirmation_thresholds.csv'));
    % Parameter calibration is generated only from this new calibration split.
    % If reliable evidence is insufficient, the model remains explicitly unusable.
    pmodel0=invalid_parameter_model(compat_hash,source_hash);
    cal_evidence=[];cal_member_rows=repmat(member_row_template(),0,1);
    popt=profile_options(sc);domain=build_extended_parameter_domain(sc.parameter_search,sc.extended_domain_eta);
    for k=1:numel(calbank)
        conf=stage4a6_3_1_r_confirm_with_frozen_stage4a5_1(cal_obs{k},cache,sets,calmodel,sc.confirmation,compat_hash);
        if conf.accepted_member_count>0
            pe=stage4a6_3_1_r_profile_all_accepted_members(cal_obs{k},f,conf,candidates,cfg,domain,popt,pmodel0);
            if isfield(pe,'member_evidence')&&~isempty(pe.member_evidence)
                if isempty(cal_evidence),cal_evidence=pe.member_evidence(:);else,cal_evidence=[cal_evidence(:);pe.member_evidence(:)];end %#ok<AGROW>
                mr=member_rows(calbank(k),pe,compat_hash,calmodel.calibration_hash);
                if isempty(cal_member_rows),cal_member_rows=mr(:);else,cal_member_rows=[cal_member_rows(:);mr(:)];end %#ok<AGROW>
            end
        end
    end
    pmodel=calibrate_stage4a6_2_parameter_thresholds(cal_evidence,sc,sc.extended_domain_eta,compat_hash);
    pmodel.compatibility_hash=compat_hash;pmodel.source_tree_hash=source_hash;pmodel.calibration_split_id='stage4a6_3_1_r_calibration';pmodel.matlab_version=version;pmodel.created_at=datestr(now,30);
    if ~isfield(pmodel,'calibration_status'),pmodel.calibration_status='insufficient_evidence';end
    save(fullfile(caldir,'parameter_domain_calibration_model.mat'),'pmodel','cal_evidence','cal_member_rows','-v7.3');
    write_rows(parameter_calibration_rows(pmodel,cal_evidence,compat_hash,source_hash),fullfile(caldir,'parameter_calibration_profiles.csv'));
    write_rows(parameter_threshold_rows(pmodel,compat_hash,source_hash),fullfile(caldir,'parameter_domain_thresholds.csv'));
    % Pilot decisions are created without passing any truth fields.
    decisions=repmat(decision_template(),0,1);labels=repmat(label_template(),0,1);member_rows_all=repmat(member_row_template(),0,1);profile_cases=0;
    for k=1:numel(pilotbank)
        spec=sc.confirmation;spec.stability_seed=stable_seed(sc.seeds.pilot,pilotbank(k).sample_id);
        conf=stage4a6_3_1_r_confirm_with_frozen_stage4a5_1(pilot_obs{k},cache,sets,calmodel,spec,compat_hash);
        d=decision_template();d.sample_id=pilotbank(k).sample_id;d.method_id=conf.confirmation_method_id;d.topology_status=conf.decision;d.topology_set=conf.accepted_topology_set;d.decision=conf.decision;d.decision_reason=conf.decision_reason;d.best_topology_id=conf.best_topology_id;d.accepted_topology_set=conf.accepted_topology_set;d.accepted_member_count=conf.accepted_member_count;d.best_distance=conf.best_distance;d.second_distance=conf.second_distance;d.margin=conf.margin;d.rho=conf.rho;d.compatibility_hash=compat_hash;d.calibration_hash=calmodel.calibration_hash;d.parameter_domain_status='parameter_not_evaluated';d.evaluated_member_count=0;
        if conf.accepted_member_count>0
            pe=stage4a6_3_1_r_profile_all_accepted_members(pilot_obs{k},f,conf,candidates,cfg,domain,popt,pmodel);
            d.parameter_domain_status=getfield_default(pe,'parameter_domain_status','parameter_domain_indeterminate');d.evaluated_member_count=getfield_default(pe,'evaluated_member_count',0);d.member_profile_reliable=getfield_default(pe,'profile_reliable',false);profile_cases=profile_cases+1;
            if isfield(pe,'member_evidence')&&~isempty(pe.member_evidence)
                mr=member_rows(pilotbank(k),pe,compat_hash,calmodel.calibration_hash);
                if isempty(member_rows_all),member_rows_all=mr(:);else,member_rows_all=[member_rows_all(:);mr(:)];end %#ok<AGROW>
            end
        end
        decisions(end+1)=d;labels(end+1)=label_from_trial(pilotbank(k)); %#ok<AGROW>
    end
    metrics=stage4a6_3_1_r_evaluate_metrics(decisions,labels);
    write_rows(decisions,fullfile(pilotdir,'pilot_match_decisions.csv'));write_rows(labels,fullfile(pilotdir,'pilot_scoring_labels.csv'));write_rows(member_rows_all,fullfile(pilotdir,'pilot_member_evidence.csv'));write_rows(metrics,fullfile(pilotdir,'pilot_metrics.csv'));
    rt=struct('cache_status',cache_status,'cache_file',cache_file,'compatibility_hash',compat_hash,'source_tree_hash',source_hash,'initial_compute_runtime_s',toc(t0),'resume_check_runtime_s',0,'total_compute_runtime_s',toc(t0),'calibration_case_count',numel(calbank),'pilot_case_count',numel(pilotbank),'profile_case_count',profile_cases,'worker_count',1,'use_parallel',false,'final_reserved_executed',false);
    write_rows(rt,fullfile(sc.results_data,'runtime_summary.csv'));
    save(fullfile(sc.results_data,'stage4a6_3_1_r_pilot_results.mat'),'sc','candidates','theta_grid','cache','calbank','pilotbank','reserved','calraw','calmodel','pmodel','decisions','labels','member_rows_all','metrics','compat_hash','source_hash','canonical','-v7.3');
    write_text(fullfile(sc.results_logs,'stage4a6_3_1_r_independent_pilot.log'),sprintf(['Stage 4A.6.3.1-R independent pilot\nMATLAB=%s\n' ...
        'compatibility_hash=%s\nsource_tree_hash=%s\ncalibration_cases=%d\npilot_cases=%d\n' ...
        'profile_cases=%d\nfinal_reserved_executed=false\nuse_parallel=false\n'],version,compat_hash,source_hash,numel(calbank),numel(pilotbank),profile_cases));
    out=struct('compatibility_hash',compat_hash,'source_tree_hash',source_hash,'calmodel',calmodel,'pmodel',pmodel,'decisions',decisions,'labels',labels,'metrics',metrics,'profile_cases',profile_cases,'calibration_count',numel(calbank),'pilot_count',numel(pilotbank));
end

function [cache,status,h]=load_or_build_cache(sc,cfg,candidates,theta_grid,grid,f,source_hash)
    h=stage4a4_scientific_config_hash(struct('schema','stage4a6_3_1_r_cache_v1','frequency_hz',f,'candidates',{candidate_manifest(candidates)},'parameter_grid',{theta_grid},'measurement_kind',sc.measurement_kind,'distance',sc.distance,'termination',sc.termination,'source_tree_hash',source_hash));
    file=fullfile(sc.cache_dir,[sc.grid_id '_P0_no_prior_R.mat']);cache=[];status='rebuilt';
    if exist(file,'file'),z=load(file,'cache');if isfield(z,'cache')&&cache_valid(z.cache,candidates,theta_grid,sc,cfg,source_hash,h),cache=z.cache;status='validated';end,end
    if isempty(cache)
        nom=theta_grid(find([theta_grid.regularization]==0,1));lib=build_composite_topology_library(f,candidates,nom,sc.measurement_kind,cfg,numel(candidates));audit0=audit_candidate_observability(candidates,lib,cfg,sc.distance.tie_tolerance);
        meta=struct('measurement_kind',sc.measurement_kind,'tie_tolerance',sc.distance.tie_tolerance,'distance_feature',sc.distance.feature,'distance_weights',sc.distance.weights,'distance_options',sc.distance.options,'scenario_id','P0_no_prior','configuration_hash',h,'max_composite_templates',numel(candidates)*numel(theta_grid),'baseline_P0_audit',audit0,'cache_schema_version','stage4a6_3_1_r_cache_v1','cache_configuration_hash',h,'forward_model_source_hash',source_hash,'experiment_scientific_hash',h,'source_tree_hash',source_hash);
        cache=build_stage4a5_1_template_cache(grid,candidates,theta_grid,cfg,meta);status='rebuilt';
    end
end
function tf=cache_valid(c,ca,t,sc,cfg,sh,h)
    tf=isfield(c,'cache_configuration_hash')&&strcmp(c.cache_configuration_hash,h) && ...
        strcmp(getfield_default(c,'forward_model_source_hash',''),sh) && ...
        strcmp(getfield_default(c,'source_tree_hash',''),sh) && ...
        strcmp(getfield_default(c,'cache_schema_version',''),'stage4a6_3_1_r_cache_v1') && ...
        isequal(c.frequency_hz(:),sc.grids(1).frequency_hz(:)) && ...
        strcmp(getfield_default(c,'frequency_grid_id',''),sc.grid_id) && ...
        isequal({c.candidates.topology_id},{ca.topology_id}) && ...
        isequal({c.candidates.canonical_key},{ca.canonical_key}) && ...
        isequal(c.parameter_grid,t) && ...
        getfield_default(c,'parameter_template_count',-1)==numel(t) && ...
        getfield_default(c,'composite_template_count',-1)==numel(ca)*numel(t) && ...
        strcmp(getfield_default(c,'measurement_kind',''),sc.measurement_kind) && ...
        isequal(getfield_default(c,'distance_feature',''),sc.distance.feature) && ...
        isequal(getfield_default(c,'distance_weights',[]),sc.distance.weights) && ...
        isequal(getfield_default(c,'distance_options',struct()),sc.distance.options) && ...
        isequal(getfield_default(c,'tie_tolerance',NaN),sc.distance.tie_tolerance) && ...
        isequal(getfield_default(c,'source_impedance_ohm',NaN),cfg.Zs) && ...
        isequal(getfield_default(c,'receiver_impedance_ohm',NaN),cfg.Zr);
end
function cm=candidate_manifest(c),cm=repmat(struct('topology_id','','canonical_key',''),numel(c),1);for k=1:numel(c),cm(k).topology_id=c(k).topology_id;cm(k).canonical_key=c(k).canonical_key;end,end
function [b,obs]=materialize_bank(b,cfg,f)
    obs=cell(numel(b),1);for k=1:numel(b)
        if isempty(fieldnames(b(k).truth_theta)),continue;end
        [b(k),obs{k}]=stage4a6_3_1_r_materialize_scenario(b(k),cfg,f);
    end
end
function model=invalid_parameter_model(h,sh),model=struct('calibration_status','insufficient_evidence','parameter_thresholds',struct([]),'compatibility_hash',h,'source_tree_hash',sh,'calibration_hash','');end
function p=profile_options(sc),p=sc.optimization;p.profile=sc.profile;p.minimum_sensitivity_floor=1e-10;p.profile.enabled=true;p.profile.profile_multi_start_count=1;p.profile.multistart_single_start_policy='not_applicable';end
function o=score_opts(sc,b,count),o=struct('candidate_count_before_prior',count,'repetitions',sc.confirmation.stability_repetitions,'block_count',sc.confirmation.block_count,'block_fraction',sc.confirmation.block_fraction,'stability_seed',stable_seed(sc.seeds.pilot,b.sample_id));end
function s=stable_seed(master,id),v=double(char(id));s=max(1,round(mod(double(master)+sum(v.*(1:numel(v))),2^31-1)));end
function r=decision_template(),r=struct('sample_id','','method_id','','decision','','topology_status','','topology_set','','decision_reason','','best_topology_id','','accepted_topology_set','','accepted_member_count',0,'evaluated_member_count',0,'member_profile_reliable',false,'parameter_domain_status','parameter_not_evaluated','best_distance',NaN,'second_distance',NaN,'margin',NaN,'rho',NaN,'compatibility_hash','','calibration_hash','');end
function r=label_template(),r=struct('sample_id','','category','','truth_topology_id','','parameter_domain_truth','','physical_scenario_id','','outlier_dimension','','outlier_severity','','outlier_direction','','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','');end
function r=label_from_trial(b),r=label_template();f=fieldnames(r);for k=1:numel(f),if isfield(b,f{k}),r.(f{k})=b.(f{k});end,end,end
function r=member_row_template(),r=struct('sample_id','','accepted_topology_id','','accepted_member_count',0,'evaluated_member_count',0,'profile_status','','profile_reliable',false,'in_distance',NaN,'ext_distance',NaN,'parameter_domain_status','','compatibility_hash','','calibration_hash','');end
function rows=member_rows(b,pe,compat_hash,calibration_hash)
    rows=repmat(member_row_template(),0,1);e=getfield_default(pe,'member_evidence',struct([]));for k=1:numel(e),r=member_row_template();r.sample_id=b.sample_id;r.accepted_topology_id=e(k).topology_id;r.accepted_member_count=pe.accepted_member_count;r.evaluated_member_count=pe.evaluated_member_count;r.profile_status=ternary(e(k).profile_reliable,'reliable','not_reliable');r.profile_reliable=e(k).profile_reliable;r.in_distance=e(k).in_distance;r.ext_distance=e(k).ext_distance;r.parameter_domain_status=pe.parameter_domain_status;rows(end+1)=r;end
    for k=1:numel(rows)
        rows(k).compatibility_hash=compat_hash;
        rows(k).calibration_hash=calibration_hash;
    end
end
function rows=scenario_rows(b)
    rows=repmat(struct('sample_id','','split','','seed',0,'truth_topology_id','','canonical_key','','category','','outlier_dimension','','outlier_severity','','outlier_direction','','physical_scenario_id','','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','active_parameter_names','','active_parameter_count',0,'source_tag',''),numel(b),1);for k=1:numel(b),f=fieldnames(rows);for j=1:numel(f),if isfield(b(k),f{j}),rows(k).(f{j})=b(k).(f{j});end,end,end
end
function rows=reserved_rows(b),rows=repmat(struct('sample_id','','split','','seed',0,'truth_topology_id','','canonical_key','','physical_scenario_id','','category',''),numel(b),1);for k=1:numel(b),rows(k).sample_id=b(k).sample_id;rows(k).split=b(k).split;rows(k).seed=b(k).seed;rows(k).truth_topology_id=b(k).truth_topology_id;rows(k).canonical_key=b(k).canonical_key;rows(k).physical_scenario_id=b(k).physical_scenario_id;rows(k).category=b(k).category;end,end
function rows=independence_rows(b)
    cats=unique(strcat({b.split},{b.category}));rows=repmat(struct('split','','category','','row_count',0,'unique_physical_scenario_count',0,'unique_parameter_hash_count',0,'unique_cfr_hash_count',0,'duplicate_parameter_count',0,'duplicate_cfr_count',0,'cross_split_duplicate_count',0,'equivalent_observation_count',0),0,1);
    for k=1:numel(cats)
        ix=strcmp(strcat({b.split},{b.category}),cats{k});q=b(ix);ph={q.parameter_vector_hash};ch={q.noiseless_cfr_hash};
        r=rows_template();r.split=q(1).split;r.category=q(1).category;r.row_count=numel(q);
        r.unique_physical_scenario_count=numel(unique({q.physical_scenario_id}));r.unique_parameter_hash_count=numel(unique(ph));r.unique_cfr_hash_count=numel(unique(ch));
        r.duplicate_parameter_count=numel(q)-r.unique_parameter_hash_count;r.duplicate_cfr_count=numel(q)-r.unique_cfr_hash_count;
        other=~strcmp({b.split},r.split);oph=unique({b(other).parameter_vector_hash});och=unique({b(other).noiseless_cfr_hash});
        r.cross_split_duplicate_count=numel(intersect(unique(ph),oph));r.equivalent_observation_count=r.duplicate_cfr_count;rows(end+1)=r;
    end
end
function r=rows_template(),r=struct('split','','category','','row_count',0,'unique_physical_scenario_count',0,'unique_parameter_hash_count',0,'unique_cfr_hash_count',0,'duplicate_parameter_count',0,'duplicate_cfr_count',0,'cross_split_duplicate_count',0,'equivalent_observation_count',0);end
function rows=threshold_rows(m,h,sh),rows=repmat(struct('parameter_name','','status','','sample_count',0,'compatibility_hash','','source_tree_hash',''),0,1);r=struct('parameter_name','topology_confirmation','status',getfield_default(m,'calibration_status',''),'sample_count',getfield_default(m,'calibration_sample_count',0),'compatibility_hash',h,'source_tree_hash',sh);rows(end+1)=r;end
function rows=parameter_threshold_rows(m,h,sh)
    if ~isfield(m,'parameter_thresholds')||isempty(m.parameter_thresholds),rows=struct('parameter_name','','status',m.calibration_status,'reliable_sample_count',m.reliable_calibration_evidence_count,'compatibility_hash',h,'source_tree_hash',sh);return;end
    rows=m.parameter_thresholds;for k=1:numel(rows),rows(k).compatibility_hash=h;rows(k).source_tree_hash=sh;end
end
function rows=parameter_calibration_rows(m,e,h,sh),rows=struct('calibration_status',m.calibration_status,'total_evidence_count',m.total_calibration_evidence_count,'reliable_evidence_count',m.reliable_calibration_evidence_count,'excluded_evidence_count',m.excluded_calibration_evidence_count,'compatibility_hash',h,'source_tree_hash',sh);end
function y=ternary(tf,a,b),if tf,y=a;else,y=b;end,end
function v=getfield_default(s,n,d),if isstruct(s)&&isfield(s,n),v=s.(n);else,v=d;end,end
function write_rows(x,p)
    if isempty(x),return;end
    ensure_dir(fileparts(p));
    if isscalar(x)
        t=struct2table(x,'AsArray',true);
    else
        t=struct2table(x(:));
    end
    writetable(t,p);
end
function write_text(p,t),ensure_dir(fileparts(p));fid=fopen(p,'w');fprintf(fid,'%s',t);fclose(fid);end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
