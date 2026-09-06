function out=exp_stage4a6_2_1_protocol_closure(root_dir,mode)
%EXP_STAGE4A6_2_1_PROTOCOL_CLOSURE Unified two-case serial smoke protocol.
    if nargin<1||isempty(root_dir),root_dir=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='smoke';end
    addpath(fullfile(root_dir,'src'),fullfile(root_dir,'config'));
    cfg=default_config(root_dir);sc=stage4a6_2_1_protocol_config(cfg,mode);
    ensure_dir(sc.results_data);ensure_dir(sc.results_logs);ensure_dir(sc.shard_dir);
    source_hash=stage4a6_2_1_source_tree_hash(root_dir);
    freq=sc.grids(1).frequency_hz(1:min(9,numel(sc.grids(1).frequency_hz)));
    candidates=generate_radial_topology_candidates(sc.generator);ids=[1 numel(candidates)];domain=build_extended_parameter_domain(sc.parameter_search,0.5);theta=nominal_theta(cfg);
    payload=struct('stage',sc.stage_name,'version',sc.version,'mode',mode,'frequency_hz',freq, ...
        'candidate_ids',{ {candidates(ids).topology_id} },'candidate_keys',{ {candidates(ids).canonical_key} }, ...
        'domain',domain,'optimization',sc.optimization,'profile',sc.profile,'execution',sc.execution);
    [science_hash,canonical]=stage4a4_scientific_config_hash(payload); %#ok<ASGLU>
    manifest=repmat(manifest_template(),numel(ids),1);contexts=cell(numel(ids),1);
    for q=1:numel(ids)
        g=candidates(ids(q));[net,lc]=topology_apply_parameters(g.network,cfg,theta);[meas,~]=plc_measurement_bundle('siso_forward',net,theta,lc);[obs,~]=plc_multiview_response(freq,net,meas,lc);
        case_id=sprintf('stage4a6_2_1_%s_%s',mode,g.topology_id);
        manifest(q).case_id=case_id;manifest(q).grid_id=sc.grids(1).id;manifest(q).split=mode;manifest(q).replicate_id=1;manifest(q).sample_id=case_id;
        manifest(q).topology_id=g.topology_id;manifest(q).parameter_name='all_active';manifest(q).case_seed=stage4a6_2_case_seed(cfg.random_seed,case_id);
        manifest(q).scientific_hash=science_hash;manifest(q).source_tree_hash=source_hash;manifest(q).expected_output_path=fullfile('results','data','stage4a6_2_1','shards',[case_id '.mat']);manifest(q).status='pending';
        contexts{q}=struct('root_dir',root_dir,'scientific_hash',science_hash,'source_tree_hash',source_hash,'frequency_hz',freq,'cfg',cfg,'domain',domain,'initial_thetas',theta,'options',merge_options(sc),'candidate',g);
        contexts{q}.observed_views=obs;
    end
    started=tic;summary=run_stage4a6_2_batch(manifest,struct('root_dir',root_dir,'scientific_hash',science_hash,'source_tree_hash',source_hash,'case_contexts',{contexts}),sc.execution);
    for q=1:numel(manifest),manifest(q).status=summary.results(q).status;end
    agg=aggregate_stage4a6_2_shards(manifest,struct('root_dir',root_dir,'scientific_hash',science_hash,'source_tree_hash',source_hash),'allow_failed',true);
    runtime=struct('mode',mode,'frequency_count',numel(freq),'case_count',numel(manifest),'attempted_count',summary.attempted, ...
        'completed_count',summary.completed,'resumed_count',summary.resumed,'failed_count',summary.failed,'pending_count',summary.pending, ...
        'retry_count',summary.retry_count,'hash_mismatch_count',summary.hash_mismatch,'aggregate_completed',agg.completed,'aggregate_failed',agg.failed, ...
        'runtime_s',toc(started),'workers',1,'parallel_strategy','serial','scientific_hash',science_hash,'source_tree_hash',source_hash);
    rows=summary_rows(manifest,agg);prefix=fullfile(sc.results_data,'stage4a6_2_1_smoke');
    writetable(struct2table(manifest),[prefix '_case_manifest.csv']);writetable(struct2table(rows),[prefix '_profile_summary.csv']);writetable(struct2table(runtime),[prefix '_runtime.csv']);
    save([prefix '_results.mat'],'sc','manifest','summary','agg','runtime','science_hash','source_hash','canonical','-v7.3');
    out=struct('manifest',manifest,'summary',summary,'aggregate',agg,'runtime',runtime,'scientific_hash',science_hash,'source_tree_hash',source_hash);
end
function o=merge_options(sc),o=sc.optimization;o.profile=sc.profile;end
function t=nominal_theta(cfg),t=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1,'source_impedance_ohm',cfg.Zs,'receiver_impedance_ohm',cfg.Zr,'regularization',NaN);end
function r=manifest_template(),r=struct('case_id','','grid_id','','split','','replicate_id',0,'sample_id','','topology_id','','parameter_name','','case_seed',0,'scientific_hash','','source_tree_hash','','expected_output_path','','status','pending','attempt_count',0,'retry_count',0);end
function rows=summary_rows(manifest,agg)
    rows=repmat(struct('case_id','','topology_id','','status','','runtime_s',NaN,'profile_computed',false,'profile_reliable',false,'active_parameter_count',0),numel(manifest),1);
    for k=1:numel(manifest),rows(k).case_id=manifest(k).case_id;rows(k).topology_id=manifest(k).topology_id;rows(k).status=manifest(k).status;end
    if isfield(agg,'shards')&&~isempty(agg.shards)
        for k=1:numel(agg.shards),j=find(strcmp({manifest.case_id},agg.shards(k).case_id),1);if isempty(j),continue;end;s=agg.shards(k);rows(j).runtime_s=s.runtime_s;rows(j).profile_computed=s.optimizer_state.profile_computed;rows(j).profile_reliable=s.optimizer_state.profile_reliable;rows(j).active_parameter_count=s.profile_summary.active_parameter_count;end
    end
end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
