function summary = stage4a7_2_r2_1_run_independent_35_pilot(root)
%STAGE4A7_2_R2_1_RUN_INDEPENDENT_35_PILOT Run a frozen 35-case evaluation.
%   The calibration model is loaded from the completed formal split.  Truth
%   fields are retained for offline scoring only and are never passed to the
%   profile-distance or candidate-set functions.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    formal_dir=fullfile(root,'results','data','stage4a7_2_r2_1','formal');
    % The formal summary is intentionally compact; the immutable cache and
    % scored candidate structs are stored in the identity checkpoint.
    z=load(fullfile(formal_dir,'summary.mat'),'sc','selected_model');
    q=load(fullfile(formal_dir,'checkpoint_identity.mat'),'cache','scored','ids');
    z.cache=q.cache;z.scored=q.scored;z.ids=q.ids;
    outdir=fullfile(root,'results','data','stage4a7_2_r2_1','independent35');ensure_dir(outdir);
    cfg=struct('split_id','independent35','master_seed',20262951,'snr_db',20, ...
        'scenario_count',35,'categories',{{'in_domain','boundary_lower','boundary_upper', ...
        'parameter_ood_near','parameter_ood_medium','parameter_ood_far'}}, ...
        'target_parameter','main_length_scale','method',z.selected_model.method_id, ...
        'calibration_hash',z.selected_model.calibration_hash,'source_formal_experiment_hash',z.ids.experiment_hash);
    cfg.experiment_hash=stage4a4_scientific_config_hash(cfg);
    t0=tic;scenarios=make_scenarios(z.scored,cfg,z.sc);D=zeros(cfg.scenario_count,numel(z.scored));
    for k=1:numel(scenarios)
        rs=RandStream('mt19937ar','Seed',scenarios(k).case_seed);theta=scenarios(k).truth_theta;
        [net,local]=topology_apply_parameters(z.scored(scenarios(k).candidate_index).network,default_config(root),theta);
        [m,~]=plc_measurement_bundle(z.sc.measurement_kind,net,theta,local);
        [v,~]=plc_multiview_response(z.sc.frequency_hz,net,m,local);truth=v{1}(:).';
        obs=add_noise(truth,cfg.snr_db,rs);scenarios(k).noiseless_cfr_hash=stage4a4_scientific_config_hash(truth);scenarios(k).observation_hash=stage4a4_scientific_config_hash(obs);
        scenarios(k).parameter_vector_hash=stage4a4_scientific_config_hash(theta);
        o=stage4a7_2_r1_profile_distance({obs},z.cache,struct('feature',z.sc.feature,'ofdm_config',default_config(root).ofdm));D(k,:)=o.profile_distances;
        a=stage4a7_2_r1_apply_profile_candidate_set(D(k,:),z.selected_model,z.selected_model.method_id);
        scenarios(k).accepted_set=strjoin(a.accepted_candidate_set,',');scenarios(k).set_size=a.set_size;scenarios(k).empty=a.empty;scenarios(k).hit=any(strcmp(a.accepted_candidate_set,scenarios(k).truth_topology_id));
        scenarios(k).calibration_hash=a.calibration_hash;scenarios(k).experiment_hash=cfg.experiment_hash;
    end
    metrics=metrics_by_category(scenarios,cfg);write_rows(fullfile(outdir,'scenario_manifest.csv'),manifest_rows(scenarios));
    write_rows(fullfile(outdir,'pilot_decisions.csv'),decision_rows(scenarios));write_rows(fullfile(outdir,'pilot_metrics.csv'),metrics);
    independence=independence_audit(scenarios);write_rows(fullfile(outdir,'independence_audit.csv'),independence);
    configuration=configuration_row(z.sc,z.ids,cfg,z.selected_model,numel(scenarios));
    write_rows(fullfile(outdir,'configuration_manifest.csv'),configuration);
    runtime=struct('runtime_s',toc(t0),'scenario_count',numel(scenarios),'worker_count',1,'use_parallel',false, ...
        'source_formal_experiment_hash',z.ids.experiment_hash,'independent35_experiment_hash',cfg.experiment_hash, ...
        'calibration_hash',z.selected_model.calibration_hash,'status','completed');write_rows(fullfile(outdir,'runtime_summary.csv'),runtime);
    summary=struct('stage_name','Stage 4A.7.2-R.2.1','status','independent35_completed','scenario_count',numel(scenarios), ...
        'calibration_hash',z.selected_model.calibration_hash,'experiment_hash',cfg.experiment_hash,'structure_ood_status','not_evaluable_no_compatible_out_of_library_forward_model', ...
        'false_unique_status','not_evaluable_no_truth_nonunique_scenarios','elapsed_s',runtime.runtime_s);
    write_rows(fullfile(outdir,'summary.csv'),summary);save(fullfile(outdir,'summary.mat'),'summary','cfg','scenarios','metrics','independence','-v7');
    fprintf('R2.1 independent35 completed: %d scenarios in %.3f s.\n',numel(scenarios),runtime.runtime_s);
end

function s=make_scenarios(candidates,cfg,sc)
    n=cfg.scenario_count;s=repmat(row_template(),n,1);cat={'in_domain','boundary_lower','boundary_upper','parameter_ood_near','parameter_ood_medium','parameter_ood_far'};counts=[10 5 5 5 5 5];k=0;
    for c=1:numel(cat),for q=1:counts(c),k=k+1;id=sprintf('r21_independent35_%s_%02d',cat{c},q);s(k).sample_id=id;s(k).physical_scenario_id=id;s(k).split='independent35';s(k).category=cat{c};s(k).candidate_index=1+mod(k-1,numel(candidates));s(k).truth_topology_id=getid(candidates(s(k).candidate_index));s(k).case_seed=stage4a7_2_r2_1_stable_case_seed(cfg.master_seed,id);s(k).truth_theta=theta_for_category(cat{c},s(k).case_seed);end,end
end
function t=theta_for_category(cat,seed)
    rs=RandStream('mt19937ar','Seed',seed);t=struct('main_length_scale',.96+.08*rand(rs),'branch_length_scale',.96+.08*rand(rs),'branch_load_scale',.85+.30*rand(rs),'source_impedance_ohm',46+8*rand(rs),'receiver_impedance_ohm',46+8*rand(rs),'regularization',0);
    if strcmp(cat,'boundary_lower'),t.main_length_scale=.951;elseif strcmp(cat,'boundary_upper'),t.main_length_scale=1.049;elseif strcmp(cat,'parameter_ood_near'),t.main_length_scale=1.10;elseif strcmp(cat,'parameter_ood_medium'),t.main_length_scale=1.30;elseif strcmp(cat,'parameter_ood_far'),t.main_length_scale=1.60;end
end
function rows=metrics_by_category(s,cfg)
    cats=unique({s.category},'stable');rows=repmat(metric_template(),0,1);
    for k=1:numel(cats),x=s(strcmp({s.category},cats{k}));n=numel(x);hit=[x.hit];acc=~[x.empty];sizes=[x.set_size];single=sizes==1;wrong=acc&~hit;rows(end+1)=metric_row(cats{k},'truth_set_coverage',nnz(hit),n,n,cfg,x);rows(end+1)=metric_row(cats{k},'topology_acceptance_coverage',nnz(acc),n,n,cfg,x);rows(end+1)=metric_row(cats{k},'singleton_rate',nnz(single),n,n,cfg,x);rows(end+1)=metric_row(cats{k},'empty_set_rate',nnz(~acc),n,n,cfg,x);rows(end+1)=metric_row(cats{k},'topology_selective_risk',nnz(wrong),nnz(acc),n,cfg,x);r=metric_template();r.category=cats{k};r.metric_id='mean_set_size';r.numerator=sum(sizes);r.denominator=n;r.rate=mean(sizes);r.evaluable_count=n;r.mean_set_size=mean(sizes);r.median_set_size=median(sizes);r.experiment_hash=cfg.experiment_hash;r.calibration_hash=cfg.calibration_hash;rows(end+1)=r;end
end
function r=metric_row(category,name,num,den,evaluable,cfg,x),r=metric_template();r.category=category;r.metric_id=name;r.numerator=num;r.denominator=den;r.evaluable_count=evaluable;r.rate=ratio(num,den);if den>0,[r.ci_low,r.ci_high]=stage4a7_2_wilson_interval(num,den);end;r.mean_set_size=mean([x.set_size]);r.median_set_size=median([x.set_size]);r.experiment_hash=cfg.experiment_hash;r.calibration_hash=cfg.calibration_hash;end
function r=metric_template(),r=struct('category','','metric_id','','numerator',0,'denominator',0,'rate',NaN,'ci_low',NaN,'ci_high',NaN,'evaluable_count',0,'mean_set_size',NaN,'median_set_size',NaN,'experiment_hash','','calibration_hash','','definition_version','stage4a7_2_r2_1_independent35_metrics_v1');end
function rows=manifest_rows(s)
% Keep the manifest table scalar-valued and auditable.  Do not write a
% nested truth_theta struct into a CSV or remove fields with [] assignment.
rows=repmat(struct('sample_id','','physical_scenario_id','','split','','category','', ...
    'truth_topology_id','','case_seed',0,'main_length_scale',NaN, ...
    'branch_length_scale',NaN,'branch_load_scale',NaN, ...
    'source_impedance_ohm',NaN,'receiver_impedance_ohm',NaN, ...
    'parameter_domain_truth','','parameter_vector_hash','','noiseless_cfr_hash','', ...
    'observation_hash','','experiment_hash','','calibration_hash',''),numel(s),1);
for k=1:numel(s)
    rows(k).sample_id=s(k).sample_id;
    rows(k).physical_scenario_id=s(k).physical_scenario_id;
    rows(k).split=s(k).split;
    rows(k).category=s(k).category;
    rows(k).truth_topology_id=s(k).truth_topology_id;
    rows(k).case_seed=s(k).case_seed;
    rows(k).main_length_scale=s(k).truth_theta.main_length_scale;
    rows(k).branch_length_scale=s(k).truth_theta.branch_length_scale;
    rows(k).branch_load_scale=s(k).truth_theta.branch_load_scale;
    rows(k).source_impedance_ohm=s(k).truth_theta.source_impedance_ohm;
    rows(k).receiver_impedance_ohm=s(k).truth_theta.receiver_impedance_ohm;
    rows(k).parameter_domain_truth=ternary(startsWith(s(k).category,'parameter_ood'),'out_of_domain','in_domain');
    rows(k).parameter_vector_hash=s(k).parameter_vector_hash;
    rows(k).noiseless_cfr_hash=s(k).noiseless_cfr_hash;
    rows(k).observation_hash=s(k).observation_hash;
    rows(k).experiment_hash=s(k).experiment_hash;
    rows(k).calibration_hash=s(k).calibration_hash;
end
end
function rows=decision_rows(s)
rows=repmat(struct('sample_id','','physical_scenario_id','','split','','category','', ...
    'truth_topology_id','','accepted_set','','set_size',0,'hit',false,'empty',false, ...
    'calibration_hash','','experiment_hash','','parameter_domain_truth','', ...
    'parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','', ...
    'case_seed',0),numel(s),1);
for k=1:numel(s)
    rows(k).sample_id=s(k).sample_id;
    rows(k).physical_scenario_id=s(k).physical_scenario_id;
    rows(k).split=s(k).split;
    rows(k).category=s(k).category;
    rows(k).truth_topology_id=s(k).truth_topology_id;
    rows(k).accepted_set=s(k).accepted_set;
    rows(k).set_size=s(k).set_size;
    rows(k).hit=s(k).hit;
    rows(k).empty=s(k).empty;
    rows(k).calibration_hash=s(k).calibration_hash;
    rows(k).experiment_hash=s(k).experiment_hash;
    rows(k).parameter_domain_truth=ternary(startsWith(s(k).category,'parameter_ood'),'out_of_domain','in_domain');
    rows(k).parameter_vector_hash=s(k).parameter_vector_hash;
    rows(k).noiseless_cfr_hash=s(k).noiseless_cfr_hash;
    rows(k).observation_hash=s(k).observation_hash;
    rows(k).case_seed=s(k).case_seed;
end
end
function rows=independence_audit(s),p={s.parameter_vector_hash};c={s.noiseless_cfr_hash};o={s.observation_hash};rows=struct('split','independent35','row_count',numel(s),'unique_physical_scenario_count',numel(unique({s.physical_scenario_id})),'unique_parameter_hash_count',numel(unique(p)),'unique_cfr_hash_count',numel(unique(c)),'unique_observation_hash_count',numel(unique(o)),'duplicate_parameter_hash_count',numel(s)-numel(unique(p)),'duplicate_cfr_hash_count',numel(s)-numel(unique(c)),'duplicate_observation_hash_count',numel(s)-numel(unique(o)),'status','unique_hashes');end
function r=configuration_row(sc,ids,cfg,model,n)
    r=struct('stage_name','Stage 4A.7.2-R.2.1','split','independent35', ...
        'grid_id',getf(sc,'frequency_grid_id','A_stage4a1_quick61'), ...
        'frequency_count',numel(getf(sc,'frequency_hz',[])),'scenario_count',n, ...
        'snr_db',cfg.snr_db,'method_id',model.method_id, ...
        'source_formal_experiment_hash',getf(ids,'experiment_hash',''), ...
        'source_formal_source_tree_hash',getf(ids,'source_tree_hash',''), ...
        'source_formal_data_provenance_hash',getf(ids,'data_provenance_hash',''), ...
        'source_formal_candidate_library_hash',getf(ids,'candidate_library_hash',''), ...
        'source_formal_configuration_hash',getf(ids,'configuration_hash',''), ...
        'source_formal_template_cache_hash',getf(ids,'template_cache_hash',''), ...
        'independent35_experiment_hash',cfg.experiment_hash, ...
        'parameter_calibration_hash',model.calibration_hash, ...
        'final_reserved_status','manifest_only_not_materialized', ...
        'use_parallel',false,'num_workers',1,'status','completed');
end
function r=row_template(),r=struct('sample_id','','physical_scenario_id','','split','','category','','candidate_index',0,'truth_topology_id','','truth_theta',struct(),'case_seed',0,'parameter_domain_truth','','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','','accepted_set','','set_size',0,'hit',false,'empty',false,'calibration_hash','','experiment_hash','');end
function y=add_noise(x,snr,rs),sig=sqrt(mean(abs(x).^2)/10^(snr/10)/2);y=x+sig*(randn(rs,size(x))+1i*randn(rs,size(x)));end
function id=getid(c),if isfield(c,'topology_id')&&~isempty(c.topology_id),id=char(c.topology_id);else,id=char(c.graph_candidate_id);end,end
function v=getf(s,f,d),if isstruct(s)&&isfield(s,f)&&~isempty(s.(f)),v=s.(f);else,v=d;end,end
function x=ratio(a,b),if b<=0,x=NaN;else,x=a/b;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
function write_rows(p,x),if isstruct(x),writetable(struct2table(x),p);else,writetable(x,p);end,end
