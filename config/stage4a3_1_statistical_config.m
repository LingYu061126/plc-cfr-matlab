function sc = stage4a3_1_statistical_config(cfg, mode)
%STAGE4A3_1_STATISTICAL_CONFIG Frozen repeated-sample audit configuration.
%   Formal mode uses eight calibration and twelve test samples per P0 graph.
%   Smoke mode changes only sample counts and frequency-array length; the
%   parameter definition and candidate grammar remain the project defaults.

    if nargin < 1 || isempty(cfg)
        root = fileparts(fileparts(mfilename('fullpath')));
        cfg = default_config(root);
    end
    if nargin < 2 || isempty(mode), mode = 'formal'; end
    mode = lower(char(mode));
    if ~ismember(mode, {'formal','smoke'})
        error('stage4a3_1_statistical_config:InvalidMode', ...
            'mode must be formal or smoke.');
    end

    a2 = stage4a2_prior_config(cfg);
    sc = struct();
    sc.stage_name = 'Stage 4A.3.1';
    sc.version = '4a3_1_open_set_statistical_v1';
    sc.mode = mode;
    sc.code_version = 'stage4a3_1_open_set_statistical_v1';
    sc.source_tag = 'synthetic_demo_prior_not_field_data';
    sc.calibration_seed = 20261101;
    sc.test_seed = 20261102;
    sc.random_seed = sc.test_seed;
    sc.per_graph_calibration = 8;
    sc.per_graph_test = 12;
    sc.structure_out_sample_count = 20;
    sc.parameter_out_sample_count = 20;
    sc.max_candidates = a2.max_candidates;
    sc.max_composite_templates = 1701;
    sc.parameter_search_source = 'default_config.stage2_3.search';
    sc.parameter_search = cfg.stage2_3.search;
    sc.parameter_template_count_expected = parameter_count(sc.parameter_search);
    sc.measurement_kind = a2.measurement_kind;
    sc.feature = a2.distance_feature;
    sc.weights = a2.distance_weights;
    sc.distance_options = a2.distance_options;
    sc.tie_tolerance = a2.tie_tolerance;
    sc.batch_size = a2.batch_size;
    sc.generator = a2.generator;
    sc.grids = a2.frequency_grids;
    sc.scenarios = a2.prior_scenarios;
    sc.calibration = struct( ...
        'residual_quantile',0.95, ...
        'residual_safety_factor',1.10, ...
        'margin_quantile',0.05, ...
        'minimum_residual_threshold',1e-9, ...
        'minimum_margin_threshold',1e-12, ...
        'minimum_residual_samples',sc.per_graph_calibration, ...
        'minimum_margin_samples',sc.per_graph_calibration, ...
        'threshold_name','model-internal calibration threshold');
    sc.cache_dir = fullfile(cfg.results_data, 'stage4a3_1_cache');
    sc.output_prefix = 'stage4a3_1';
    sc.forward_model_scope = 'complete-tree distributed-line nodal-admittance model';
    sc.design_note = ['Calibration uses P0 only. Test samples and labels are ' ...
        'not used to set thresholds. All priors are synthetic demonstrations.'];

    if strcmp(mode, 'smoke')
        sc.per_graph_calibration = 1;
        sc.per_graph_test = 1;
        sc.structure_out_sample_count = 2;
        sc.parameter_out_sample_count = 2;
        sc.output_prefix = 'stage4a3_1_smoke';
        sc.calibration.minimum_residual_samples = 1;
        sc.calibration.minimum_margin_samples = 1;
        for k = 1:numel(sc.grids)
            sc.grids(k).frequency_hz = sc.grids(k).frequency_hz(1:min(5,numel(sc.grids(k).frequency_hz)));
            if isfield(sc.grids(k), 'active_bin_1based') && ~isempty(sc.grids(k).active_bin_1based)
                sc.grids(k).active_bin_1based = sc.grids(k).active_bin_1based(1:min(5,numel(sc.grids(k).active_bin_1based)));
            end
        end
    end
    sc.sample_design = struct('calibration_seed',sc.calibration_seed, ...
        'test_seed',sc.test_seed,'per_graph_calibration',sc.per_graph_calibration, ...
        'per_graph_test',sc.per_graph_test, ...
        'structure_out_sample_count',sc.structure_out_sample_count, ...
        'parameter_out_sample_count',sc.parameter_out_sample_count);
end

function n = parameter_count(search)
    n = numel(search.main_length_scale) * numel(search.branch_length_scale) * ...
        numel(search.branch_load_scale) * numel(search.source_impedance_ohm) * ...
        numel(search.receiver_impedance_ohm);
end
