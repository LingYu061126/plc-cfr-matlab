function sc = stage4a6_3_1_r2_protocol_config(base_cfg, mode, use_parallel, num_workers)
%STAGE4A6_3_1_R2_PROTOCOL_CONFIG Scenario-equivalence and parallel audit.
    if nargin < 1 || isempty(base_cfg)
        root=fileparts(fileparts(mfilename('fullpath')));base_cfg=default_config(root);
    end
    if nargin < 2 || isempty(mode),mode='pilot';end
    if nargin < 3 || isempty(use_parallel),use_parallel=false;end
    if nargin < 4 || isempty(num_workers),num_workers=1;end
    old=stage4a6_3_1_r1_protocol_config(base_cfg,'pilot');sc=old;
    sc.stage_name='Stage 4A.6.3.1-R.2';
    sc.version='4a6_3_1_r2_equivalence_parallel_v1';
    sc.code_version=sc.version;sc.mode=lower(char(mode));
    sc.output_prefix='stage4a6_3_1_r2';
    sc.results_data=fullfile(base_cfg.results_data,'stage4a6_3_1_r2');
    sc.results_figures=fullfile(base_cfg.results_figures,'stage4a6_3_1_r2');
    sc.results_logs=fullfile(base_cfg.root_dir,'results','logs','stage4a6_3_1_r2');
    sc.cache_dir=fullfile(sc.results_data,'cache');
    sc.execution=struct('use_parallel',logical(use_parallel),'num_workers',max(1,round(num_workers)), ...
        'pool_profile','processes','auto_create_pool',true,'close_pool_after_run',false, ...
        'parallel_batch_size',1,'worker_memory_limit_note','16 GB host; monitor RSS/swap', ...
        'deterministic_order',true,'parallel_version','stage4a6_3_1_r2_outer_tasks_v1');
    sc.equivalence=struct('definition_version','stage4a6_3_1_r2_scenario_equivalence_v1', ...
        'same_theta_relative_tolerance',1e-9,'composite_relative_distance_tolerance',1e-9, ...
        'nominal_source','cache.current_equivalence_audit','same_theta_source','forward_model_same_theta', ...
        'composite_source','best_template_topology_scores','not_comparable_status','not_comparable_under_same_theta');
    sc.metric_definition_version='stage4a6_3_1_r2_metrics_v2';
    sc.independence_definition_version='stage4a6_3_1_r2_independence_v1';
    sc.parallel_execution_version=sc.execution.parallel_version;
    sc.protocol=sc.protocol;
    sc.protocol.parallel_execution_version=sc.parallel_execution_version;
    sc.protocol.equivalence_definition_version=sc.equivalence.definition_version;
    sc.protocol.final_reserved_is_manifest_only=true;
    sc.protocol.truth_free_confirmation_adapter='stage4a6_3_1_r1_confirm_with_frozen_stage4a5_1';
end
