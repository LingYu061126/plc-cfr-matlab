function sc = stage4a6_1_optimizer_config(base_cfg, mode)
%STAGE4A6_1_OPTIMIZER_CONFIG Stable optimizer/profile audit protocol.
%   This configuration is independent of the historical Stage 4A.6 output.
%   It keeps the existing forward model and candidate cache unchanged.

    if nargin < 1 || isempty(base_cfg)
        root = fileparts(fileparts(mfilename('fullpath')));
        base_cfg = default_config(root);
    end
    if nargin < 2 || isempty(mode), mode = 'development'; end
    mode = lower(char(mode));
    valid = {'smoke','development','formal_a','formal_b'};
    if ~ismember(mode, valid)
        error('stage4a6_1:Mode', 'Unsupported mode: %s', mode);
    end

    old = stage4a6_parameter_domain_config(base_cfg, 'formal');
    sc = old;
    sc.stage_name = 'Stage 4A.6.1';
    sc.version = '4a6_1_optimizer_stabilization_v1';
    sc.code_version = sc.version;
    sc.mode = mode;
    sc.output_prefix = 'stage4a6_1';
    sc.results_data = fullfile(base_cfg.results_data, 'stage4a6_1');
    sc.results_figures = fullfile(base_cfg.results_figures, 'stage4a6_1');
    sc.results_logs = fullfile(base_cfg.root_dir, 'results', 'logs');

    sc.development_seeds = [20261801 20261802];
    sc.final_seeds = 20261901:20261905;
    sc.parameter_calibration_seed = 20261820;
    sc.extended_domain_eta_candidates = [0.5 1.0];
    sc.optimization = struct( ...
        'solver','auto', ...
        'multi_start_count',5, ...
        'max_iterations',500, ...
        'max_function_evaluations',2000, ...
        'tolerance_x',1e-8, ...
        'tolerance_fun',1e-10, ...
        'boundary_fraction',0.05, ...
        'finite_difference_step',1e-3, ...
        'multistart_distance_tolerance',1e-3, ...
        'multistart_parameter_tolerance',0.05);
    sc.profile = struct( ...
        'enabled',true, ...
        'grid_points',3, ...
        'flatness_threshold',0.05, ...
        'profile_max_iterations',100, ...
        'profile_max_function_evaluations',300, ...
        'profile_multi_start_count',1);
    sc.parameter_calibration = struct( ...
        'improvement_quantile',0.95, ...
        'relative_improvement_quantile',0.95, ...
        'sensitivity_floor_quantile',0.05, ...
        'minimum_samples',8, ...
        'indeterminate_band',0.10);
    sc.parallel = struct( ...
        'use_parallel',false, ...
        'num_workers',1, ...
        'parallel_strategy','outer_cases', ...
        'benchmark_workers',[1 4 6 8]);
    sc.diagnostic_methods = {'A6_1_M0_topology_only', ...
        'A6_1_M1_boundary','A6_1_M2_extended_profile', ...
        'A6_1_M3_joint_diagnostic'};
    sc.protocol_note = ['Truth labels are offline only. The optimizer receives ' ...
        'observations, candidate definitions, domains and calibration models.'];

    if strcmp(mode,'smoke')
        sc.output_prefix = 'stage4a6_1_smoke';
        sc.development_seeds = sc.development_seeds(1);
        sc.final_seeds = sc.final_seeds(1);
        sc.grids = sc.grids(1);
        sc.optimization.multi_start_count = 3;
        sc.optimization.max_iterations = 80;
        sc.optimization.max_function_evaluations = 300;
        sc.profile.grid_points = 3;
        sc.profile.profile_max_iterations = 60;
        sc.profile.profile_max_function_evaluations = 180;
        sc.profile.profile_multi_start_count = 1;
        sc.sample_design.calibration_per_graph = 1;
        sc.sample_design.in_domain_per_replicate = 2;
        sc.sample_design.dimensions = sc.sample_design.dimensions(1:2);
        sc.calibration.minimum_samples = 1;
        sc.parameter_calibration.minimum_samples = 1;
    elseif strcmp(mode,'development')
        sc.output_prefix = 'stage4a6_1_development';
        sc.final_seeds = [];
    elseif strcmp(mode,'formal_a')
        sc.output_prefix = 'stage4a6_1_final_A';
        sc.grids = sc.grids(1);
        sc.development_seeds = [];
    elseif strcmp(mode,'formal_b')
        sc.output_prefix = 'stage4a6_1_final_B';
        sc.grids = sc.grids(2);
        sc.development_seeds = [];
    end
end
