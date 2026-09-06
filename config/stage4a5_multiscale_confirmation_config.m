function sc = stage4a5_multiscale_confirmation_config(base_cfg, mode)
%STAGE4A5_MULTISCALE_CONFIRMATION_CONFIG Stage 4A.5 frozen protocol.
%   The formal protocol separates two development replicates from eight
%   final replicates.  All priors and observations remain synthetic.
    if nargin < 1 || isempty(base_cfg)
        root = fileparts(fileparts(mfilename('fullpath')));
        base_cfg = default_config(root);
    end
    if nargin < 2 || isempty(mode), mode = 'formal'; end
    mode = lower(char(mode));
    if ~ismember(mode, {'formal','smoke'})
        error('stage4a5:InvalidMode','mode must be formal or smoke.');
    end
    a4 = stage4a4_candidate_confirmation_config(base_cfg,'formal');
    sc = a4;
    sc.stage_name = 'Stage 4A.5';
    sc.version = '4a5_multiscale_confirmation_v1';
    sc.code_version = 'stage4a5_multiscale_confirmation_v1';
    sc.experiment_version = 'stage4a5_multiscale_replication_v1';
    sc.mode = mode;
    sc.output_prefix = 'stage4a5';
    sc.source_tag = 'synthetic_demo_prior_not_field_data';
    sc.cache_dir = fullfile(base_cfg.results_data,'stage4a5_cache');
    sc.development_seeds = [20261201, 20261202];
    sc.final_seeds = 20261301:20261308;
    sc.development = struct('training_continuous_per_graph',2, ...
        'training_grid_per_graph',1,'calibration_continuous_per_graph',4, ...
        'calibration_grid_per_graph',1,'validation_continuous_per_graph',4, ...
        'validation_grid_per_graph',1,'structure_validation_count',20, ...
        'parameter_validation_count',20);
    sc.final = struct('calibration_continuous_per_graph',4, ...
        'calibration_grid_per_graph',1,'test_continuous_per_graph',6, ...
        'test_grid_per_graph',2,'structure_test_count',20, ...
        'parameter_test_count',20);
    sc.subband_counts = [4,8];
    sc.subband_quantiles = [0.75,0.90];
    sc.neighborhood_K = [3,5,10];
    sc.stability_thresholds = [0.70,0.80,0.90];
    sc.bootstrap_repetitions = 30;
    sc.block_count = 4;
    sc.block_fraction = 0.25;
    sc.max_topK = max(sc.neighborhood_K);
    sc.safety_factor = 1.10;
    sc.epsilon = 1e-12;
    sc.methods = {'M0_baseline','M1_multiscale','M2_neighborhood','M3_stability'};
    sc.selection_policy = struct('minimum_inlibrary_micro_set_accuracy',0.80, ...
        'maximum_false_unique_relative_to_M0',true, ...
        'primary_ool_objective','minimize_worst_case_false_accept', ...
        'development_only',true);
    sc.distance = struct('feature','complex_raw','weights',[0.5,0.5], ...
        'options',struct('phase_mask_threshold_db',base_cfg.stage2_3.phase_mask_threshold_db), ...
        'tie_tolerance',base_cfg.stage2_3.tie_tolerance);
    sc.calibration = struct('residual_quantile',0.95, ...
        'subband_quantile',0.95,'neighborhood_quantile',0.95, ...
        'margin_quantile',0.05,'neighborhood_margin_quantile',0.05, ...
        'residual_safety_factor',1.10,'subband_safety_factor',1.10, ...
        'neighborhood_safety_factor',1.10,'minimum_samples',8, ...
        'threshold_name','model-internal calibration threshold');
    sc.design_note = ['M0 is the Stage-4A.4 absolute-residual plus class-margin ' ...
        'baseline. M1 adds subband residual evidence; M2 adds equal-size ' ...
        'within-topology template neighborhoods; M3 adds contiguous-block ' ...
        'stability. Development selects hyperparameters; final test is frozen.'];
    if strcmp(mode,'smoke')
        sc.output_prefix = 'stage4a5_smoke';
        sc.development_seeds = sc.development_seeds(1);
        sc.final_seeds = sc.final_seeds(1);
        sc.development.training_continuous_per_graph = 1;
        sc.development.calibration_continuous_per_graph = 1;
        sc.development.validation_continuous_per_graph = 2;
        sc.development.structure_validation_count = 2;
        sc.development.parameter_validation_count = 2;
        sc.final.calibration_continuous_per_graph = 1;
        sc.final.test_continuous_per_graph = 2;
        sc.final.test_grid_per_graph = 1;
        sc.final.structure_test_count = 2;
        sc.final.parameter_test_count = 2;
        sc.bootstrap_repetitions = 6;
        sc.block_count = 2;
        sc.grids = sc.grids(1);
        sc.calibration.minimum_samples = 1;
    end
    sc.frequency_grid_source = 'Stage 4A.4 inherited grids; B is default_config.ofdm.active_frequency_hz';
end
