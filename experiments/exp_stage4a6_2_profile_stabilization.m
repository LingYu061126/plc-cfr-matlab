function out = exp_stage4a6_2_profile_stabilization(root_dir, mode)
%EXP_STAGE4A6_2_PROFILE_STABILIZATION Small profile-enabled checkpoint audit.
%   The smoke protocol intentionally uses a short frequency subset and two
%   representative topologies. It is an execution-stability test, not a
%   final parameter-domain performance claim.
    if nargin < 1 || isempty(root_dir), root_dir=fileparts(fileparts(mfilename('fullpath'))); end
    if nargin < 2 || isempty(mode), mode='smoke'; end
    addpath(fullfile(root_dir,'src'),fullfile(root_dir,'config'));
    cfg=default_config(root_dir);sc=stage4a6_2_profile_config(cfg,mode);
    ensure_dir(sc.results_data);ensure_dir(sc.results_logs);ensure_dir(sc.shard_dir);
    source_hash=stage4a6_2_source_tree_hash(root_dir);
    frequency_hz=sc.grids(1).frequency_hz(1:min(9,numel(sc.grids(1).frequency_hz)));
    candidates=generate_radial_topology_candidates(sc.generator);
    domain=build_extended_parameter_domain(sc.parameter_search,0.5);
    theta=nominal_theta(cfg);
    scientific_payload=struct('stage',sc.stage_name,'version',sc.version,'mode',mode, ...
        'frequency_hz',frequency_hz,'candidate_ids',{ {candidates(1).topology_id,candidates(end).topology_id} }, ...
        'candidate_keys',{ {candidates(1).canonical_key,candidates(end).canonical_key} }, ...
        'domain',domain,'optimization',sc.optimization,'profile',sc.profile, ...
        'execution',sc.execution,'source_tree_hash',source_hash);
    [science_hash,canonical]=stage4a4_scientific_config_hash(scientific_payload); %#ok<ASGLU>
    context_base=struct('scientific_hash',science_hash,'source_tree_hash',source_hash, ...
        'frequency_hz',frequency_hz,'cfg',cfg,'domain',domain,'initial_thetas',theta, ...
        'options',merge_options(sc),'candidate',candidates(1),'observed_views',{{}});
    ids=[1 numel(candidates)];
    shards=cell(0,1);manifest=repmat(manifest_template(),numel(ids),1);started=tic;
    for q=1:numel(ids)
        g=candidates(ids(q));
        [net,local_cfg]=topology_apply_parameters(g.network,cfg,theta);
        [measurements,~]=plc_measurement_bundle('siso_forward',net,theta,local_cfg);
        [obs,~]=plc_multiview_response(frequency_hz,net,measurements,local_cfg);
        case_id=sprintf('stage4a6_2_%s_%s',mode,g.topology_id);
        path=fullfile(sc.shard_dir,[case_id '.mat']);
        manifest(q).case_id=case_id;manifest(q).grid_id=sc.grids(1).id;manifest(q).split=mode;
        manifest(q).topology_id=g.topology_id;manifest(q).parameter_name='all_active';manifest(q).case_seed=stage4a6_2_case_seed(cfg.random_seed,case_id);
        manifest(q).scientific_hash=science_hash;manifest(q).source_tree_hash=source_hash;manifest(q).expected_output_path=path;manifest(q).status='pending';
        if sc.execution.resume && exist(path,'file')
            z=load(path,'shard');[ok,~]=validate_stage4a6_2_shard(z.shard,struct('case_id',case_id,'scientific_hash',science_hash,'source_tree_hash',source_hash,'parameter_name','all_active'));
            if ok,shards{end+1}=z.shard;manifest(q).status='resumed';continue;end
        end
        context=context_base;context.candidate=g;context.observed_views=obs;
        case_spec=manifest(q);case_spec.parameter_name='all_active';
        shard=run_stage4a6_2_case(case_spec,context);
        if shard.exit_status==0
            save_stage4a6_2_shard_atomic(shard,path,struct('case_id',case_id,'scientific_hash',science_hash,'source_tree_hash',source_hash,'parameter_name','all_active'));
            manifest(q).status='completed';shards{end+1}=shard;
        else
            manifest(q).status='failed';shards{end+1}=shard;
        end
        fprintf('  %s status=%s runtime=%.3fs profile=%d reliable=%d\n',case_id,manifest(q).status,shard.runtime_s,shard.optimizer_state.profile_computed,shard.optimizer_state.profile_reliable);
    end
    rows=summary_rows(shards,manifest);runtime=struct('mode',mode,'frequency_count',numel(frequency_hz),'case_count',numel(ids), ...
        'completed_count',sum(strcmp({manifest.status},'completed')),'resumed_count',sum(strcmp({manifest.status},'resumed')), ...
        'failed_count',sum(strcmp({manifest.status},'failed')),'runtime_s',toc(started),'solver',solver_name(), ...
        'workers',1,'scientific_hash',science_hash,'source_tree_hash',source_hash);
    write_rows(manifest,fullfile(sc.results_data,[sc.output_prefix '_case_manifest.csv']));
    write_rows(rows,fullfile(sc.results_data,[sc.output_prefix '_profile_summary.csv']));
    write_rows(runtime,fullfile(sc.results_data,[sc.output_prefix '_runtime.csv']));
    save(fullfile(sc.results_data,[sc.output_prefix '_results.mat']),'sc','manifest','shards','runtime','science_hash','canonical','-v7.3');
    out=struct('manifest',manifest,'shards',shards,'runtime',runtime,'scientific_hash',science_hash,'source_tree_hash',source_hash);
end

function o=merge_options(sc),o=sc.optimization;o.profile=sc.profile;end
function t=nominal_theta(cfg),t=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1,'source_impedance_ohm',cfg.Zs,'receiver_impedance_ohm',cfg.Zr,'regularization',NaN);end
function r=manifest_template(),r=struct('case_id','','grid_id','','split','','topology_id','','parameter_name','','case_seed',0,'scientific_hash','','source_tree_hash','','expected_output_path','','status','');end
function rows=summary_rows(shards,manifest)
    rows=repmat(struct('case_id','','topology_id','','status','','runtime_s',NaN,'profile_computed',false,'profile_reliable',false,'optimizer_converged',false,'multistart_consistent',false,'active_parameter_count',0,'profile_statuses',''),numel(manifest),1);
    for k=1:numel(manifest),rows(k).case_id=manifest(k).case_id;rows(k).topology_id=manifest(k).topology_id;rows(k).status=manifest(k).status; j=find(cellfun(@(x) strcmp(x.case_id,manifest(k).case_id),shards),1);if ~isempty(j),s=shards{j};rows(k).runtime_s=s.runtime_s;rows(k).profile_computed=s.optimizer_state.profile_computed;rows(k).profile_reliable=s.optimizer_state.profile_reliable;rows(k).optimizer_converged=s.optimizer_state.optimizer_converged;rows(k).multistart_consistent=s.optimizer_state.multistart_consistent;if ~isempty(s.profile_summary),rows(k).active_parameter_count=s.profile_summary.active_parameter_count;rows(k).profile_statuses=strjoin({s.profile_summary.parameter_evidence.profile_status},',');end,end,end
end
function write_rows(x,p),if ~isempty(x),writetable(struct2table(x(:)),p);end,end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
function s=solver_name(),if exist('lsqnonlin','file')==2,s='lsqnonlin';else,s='fminsearch_logistic_bounded';end,end
