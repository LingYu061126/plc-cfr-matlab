function sc = stage4a4_candidate_confirmation_config(base_cfg, mode)
%STAGE4A4_CANDIDATE_CONFIRMATION_CONFIG Frozen Stage 4A.4 protocol.
%   This is a model-internal calibration/validation/frozen-test design.  It
%   reuses the Stage-2.3 parameter search and the Stage-4A.2 prior schema.

    if nargin < 1 || isempty(base_cfg)
        root = fileparts(fileparts(mfilename('fullpath')));
        base_cfg = default_config(root);
    end
    if nargin < 2 || isempty(mode), mode = 'formal'; end
    mode = lower(char(mode));
    if ~ismember(mode, {'formal','smoke'})
        error('stage4a4:InvalidMode','mode must be formal or smoke.');
    end
    old = stage4a3_1_statistical_config(base_cfg, 'formal');
    sc = old;
    sc.stage_name = 'Stage 4A.4';
    sc.version = '4a4_candidate_confirmation_v1';
    sc.code_version = 'stage4a4_candidate_confirmation_v1';
    sc.mode = mode;
    sc.output_prefix = 'stage4a4';
    sc.source_tag = 'synthetic_demo_prior_not_field_data';
    sc.training_seed = 20261111;
    sc.calibration_seed = 20261112;
    sc.validation_seed = 20261113;
    sc.test_seed = 20261114;
    sc.random_seed = sc.test_seed;
    sc.split_counts = struct('continuous_train_per_graph',4, ...
        'continuous_calibration_per_graph',4, ...
        'continuous_validation_per_graph',6, ...
        'continuous_test_per_graph',6, ...
        'grid_train_per_graph',1,'grid_calibration_per_graph',1, ...
        'grid_validation_per_graph',2,'grid_test_per_graph',2, ...
        'structure_validation_count',20,'structure_test_count',20, ...
        'parameter_validation_count',20,'parameter_test_count',20);
    sc.methods = {'baseline_abs_margin','absolute_ratio', ...
        'joint_abs_margin_ratio','class_conditioned'};
    sc.subband_count = 4;
    sc.calibration = struct('residual_quantile',0.95, ...
        'residual_safety_factor',1.10,'margin_quantile',0.05, ...
        'rho_quantile',0.95,'robust_score_quantile',0.95, ...
        'robust_margin_quantile',0.05,'minimum_samples',8, ...
        'epsilon',1e-12,'threshold_name','model-internal calibration threshold');
    sc.validation_policy = struct('minimum_set_accuracy',0.80, ...
        'minimum_baseline_set_accuracy',0.80,'prefer_lower_ool_false_accept',true);
    sc.cache_dir = fullfile(base_cfg.results_data,'stage4a4_cache');
    sc.results_data = base_cfg.results_data;
    sc.results_figures = base_cfg.results_figures;
    sc.results_logs = fullfile(base_cfg.root_dir,'results','logs');
    sc.experiment_version = 'stage4a4_confirmatory_protocol_v1';
    sc.design_note = ['Training fits class-conditioned distance statistics; ' ...
        'calibration freezes thresholds; validation selects a method; frozen ' ...
        'test is evaluated once. All prior data are synthetic demonstrations.'];
    if strcmp(mode,'smoke')
        sc.split_counts.continuous_train_per_graph = 1;
        sc.split_counts.continuous_calibration_per_graph = 1;
        sc.split_counts.continuous_validation_per_graph = 2;
        sc.split_counts.continuous_test_per_graph = 2;
        sc.split_counts.grid_train_per_graph = 1;
        sc.split_counts.grid_calibration_per_graph = 1;
        sc.split_counts.grid_validation_per_graph = 1;
        sc.split_counts.grid_test_per_graph = 1;
        sc.split_counts.structure_validation_count = 2;
        sc.split_counts.structure_test_count = 2;
        sc.split_counts.parameter_validation_count = 2;
        sc.split_counts.parameter_test_count = 2;
        sc.subband_count = 2;
        % Smoke validates the cache and decision path on the quick grid only.
        % Formal mode below retains both the 61-point and OFDM-active grids.
        sc.grids = sc.grids(1);
        sc.output_prefix = 'stage4a4_smoke';
        sc.calibration.minimum_samples = 1;
    end
    sc.sample_design = struct('training_seed',sc.training_seed, ...
        'calibration_seed',sc.calibration_seed,'validation_seed',sc.validation_seed, ...
        'test_seed',sc.test_seed,'split_counts',sc.split_counts);
end
