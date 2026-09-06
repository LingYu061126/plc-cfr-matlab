function sc = stage4a6_2_1_protocol_config(base_cfg, mode)
%STAGE4A6_2_1_PROTOCOL_CONFIG Short protocol-closure configuration.
    if nargin<1||isempty(base_cfg)
        root=fileparts(fileparts(mfilename('fullpath')));base_cfg=default_config(root);
    end
    if nargin<2||isempty(mode),mode='smoke';end
    sc=stage4a6_2_profile_config(base_cfg,mode);
    sc.stage_name='Stage 4A.6.2.1';sc.version='4a6_2_1_protocol_closure_v1';
    sc.code_version=sc.version;sc.output_prefix='stage4a6_2_1';
    sc.results_data=fullfile(base_cfg.results_data,'stage4a6_2_1');
    sc.results_logs=fullfile(base_cfg.root_dir,'results','logs','stage4a6_2_1');
    sc.shard_dir=fullfile(sc.results_data,'shards');
    sc.execution.resume=true;sc.execution.overwrite_completed=false;sc.execution.retry_failed=false;
    sc.execution.use_parallel=false;sc.execution.num_workers=1;sc.execution.batch_size=1;
    sc.profile.grid_strategy='fixed_grid_with_midpoints';
    sc.profile.use_adaptive_refinement=false;sc.profile.refinement_points=0;sc.profile.max_refinement_rounds=0;
    sc.profile.multistart_single_start_policy='not_applicable';
end
