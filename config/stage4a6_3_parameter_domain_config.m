function sc = stage4a6_3_parameter_domain_config(base_cfg, mode)
%STAGE4A6_3_PARAMETER_DOMAIN_CONFIG A-grid calibration/final protocol.
%   This stage is deliberately independent from historical Stage 4A.6 files.
%   Truth labels are retained only in the offline scoring bank.
    if nargin < 1 || isempty(base_cfg)
        root = fileparts(fileparts(mfilename('fullpath')));
        base_cfg = default_config(root);
    end
    if nargin < 2 || isempty(mode), mode = 'pilot'; end
    mode = lower(char(mode));
    valid = {'pilot','calibration','final','audit'};
    if ~ismember(mode, valid)
        error('stage4a6_3:InvalidMode','Unsupported mode: %s', mode);
    end

    parent = stage4a6_2_1_protocol_config(base_cfg, 'smoke');
    sc = parent;
    sc.stage_name = 'Stage 4A.6.3';
    sc.version = '4a6_3_parameter_domain_validation_v1';
    sc.code_version = sc.version;
    sc.mode = mode;
    sc.output_prefix = 'stage4a6_3';
    sc.results_data = fullfile(base_cfg.results_data, 'stage4a6_3');
    sc.results_figures = fullfile(base_cfg.results_figures, 'stage4a6_3');
    sc.results_logs = fullfile(base_cfg.root_dir, 'results', 'logs', 'stage4a6_3');
    sc.cache_dir = fullfile(base_cfg.results_data, 'stage4a5_1_cache');
    sc.grids = sc.grids(1); % A_stage4a1_quick61 only.
    sc.grid_id = 'A_stage4a1_quick61';
    sc.source_tag = 'synthetic_demo_prior_not_field_data';
    sc.extended_domain_eta = 0.5;
    sc.profile.enabled = true;
    sc.profile.grid_strategy = 'fixed_grid_with_midpoints';
    sc.profile.initial_grid_points = 3;
    sc.profile.refinement_points = 0;
    sc.profile.max_refinement_rounds = 0;
    sc.profile.use_adaptive_refinement = false;
    sc.profile.minimum_valid_fraction = 0.80;
    sc.profile.critical_points_required = true;
    sc.profile.profile_multi_start_count = 1;
    sc.profile.multistart_single_start_policy = 'not_applicable';
    sc.profile.warm_start = true;
    sc.optimization.solver = 'auto';
    sc.optimization.multi_start_count = 2;
    sc.optimization.max_iterations = 60;
    sc.optimization.max_function_evaluations = 180;
    sc.profile.profile_max_iterations = 40;
    sc.profile.profile_max_function_evaluations = 120;
    sc.execution = struct('resume',true,'overwrite_completed',false, ...
        'retry_failed',false,'batch_size',1,'use_parallel',false,'num_workers',1);
    sc.seeds = struct('development',[20263701 20263702], ...
        'calibration',20263801,'final',[20263901 20263902 20263903]);
    sc.trial_design = struct( ...
        'calibration_per_graph',10, ...
        'final_in_domain_per_graph',4, ...
        'final_per_parameter_severity_direction',2, ...
        'pilot_categories',{{'in_domain_interior','out_of_domain_near', ...
            'out_of_domain_medium','out_of_domain_far'}}, ...
        'severities',{{'near','medium','far'}}, ...
        'directions',{{'lower','upper'}}, ...
        'outlier_parameters',{{'main_length_scale','branch_length_scale', ...
            'branch_load_scale','source_impedance_ohm','receiver_impedance_ohm'}}, ...
        'parameter_jitter_fraction',0.08);
    sc.parameter_calibration = struct( ...
        'minimum_profile_reliable_samples',10, ...
        'improvement_quantile',0.95, ...
        'relative_improvement_quantile',0.95, ...
        'sensitivity_floor_quantile',0.05, ...
        'indeterminate_band',0.10);
    sc.diagnostic_methods = {'A6_3_M0_topology_only', ...
        'A6_3_M1_boundary','A6_3_M2_profile','A6_3_M3_joint_diagnostic'};
    sc.protocol_note = ['Only A_stage4a1_quick61 is run. Calibration and final ' ...
        'seeds are disjoint; labels are offline scoring data.'];
    if strcmp(mode,'pilot')
        sc.output_prefix = 'stage4a6_3_pilot';
        sc.seeds.development = sc.seeds.development(1);
        sc.trial_design.calibration_per_graph = 1;
        sc.optimization.multi_start_count = 1;
        sc.optimization.max_iterations = 20;
        sc.optimization.max_function_evaluations = 60;
        sc.profile.profile_max_iterations = 20;
        sc.profile.profile_max_function_evaluations = 60;
    elseif strcmp(mode,'calibration')
        sc.output_prefix = 'stage4a6_3_calibration';
        sc.seeds.development = [];
        sc.seeds.final = [];
    elseif strcmp(mode,'final')
        sc.output_prefix = 'stage4a6_3_final';
        sc.seeds.development = [];
        sc.seeds.calibration = [];
        sc.execution.batch_size = 32;
    elseif strcmp(mode,'audit')
        sc.output_prefix = 'stage4a6_3_audit';
    end
end
