function sc = stage4a7_2_r1_data_driven_config(base_cfg, mode)
%STAGE4A7_2_R1_DATA_DRIVEN_CONFIG Shared-prior Stage 4A.7.2-R.1 settings.
%   The ENWL-derived ledger is a controlled uncertainty layer over a
%   processed public OpenDSS model.  It is not a raw field GIS ledger.
    if nargin < 1 || isempty(base_cfg)
        root = fileparts(fileparts(mfilename('fullpath')));
        base_cfg = default_config(root);
    end
    if nargin < 2 || isempty(mode), mode = 'smoke'; end
    mode = lower(char(mode));
    if ~ismember(mode, {'smoke','pilot','tier2'})
        error('stage4a7_2_r1:InvalidMode','Unknown mode: %s.',mode);
    end
    sc = struct();
    sc.stage_name = 'Stage 4A.7.2-R.1';
    sc.version = '4a7_2_r1_data_driven_v1';
    sc.mode = mode;
    sc.frequency_grid_id = 'A_stage4a1_quick61';
    sc.frequency_hz = linspace(2e6,30e6,61);
    sc.measurement_kind = 'siso_forward';
    sc.feature = 'complex_raw';
    sc.alpha = 0.05;
    sc.use_parallel = false;
    sc.num_workers = 1;
    sc.prior_source = 'ENWL_LVNS_processed_OpenDSS_derived_controlled_uncertain_prior';
    sc.prior_source_label = 'public_processed_network_plus_controlled_uncertainty_not_raw_GIS';
    sc.derived_subnetwork = fullfile(base_cfg.root_dir,'data','derived', ...
        'enwl_uncertain_prior','stage4a7_2_r1_selected_public_subnetwork.csv');
    sc.results_data = fullfile(base_cfg.root_dir,'results','data','stage4a7_2_r1');
    sc.results_logs = fullfile(base_cfg.root_dir,'results','logs','stage4a7_2_r1');
    sc.source_network_id = 'network_13';
    sc.source_feeder_id = 'Feeder_3';
    sc.source_node_id = '32';
    sc.receiver_node_id = '39';
    sc.node_ids = {'32','33','34','35','36','37','38','39'};
    sc.required_edge_keys = {'32--33','37--39'};
    sc.synthetic_ambiguity_edges = {'33','35';'34','36';'35','37';'35','38'; ...
        '36','39';'37','38'};
    sc.maximum_degree = 3;
    sc.maximum_candidate_count = 2000;
    sc.top_k = 7;
    sc.topk_scaling = struct('node_count',8,'top_k_values',[1 5 10 20], ...
        'maximum_candidate_count',20000);
    sc.round_trip_tolerance = 1e-12;
    sc.profile = struct('distance','complex_raw','template_mode','frozen_243_parameter_grid', ...
        'batch_size',64,'resolution_floor',NaN);
    sc.method_selection = struct('candidate_coverage_gate',0.80, ...
        'target_truth_set_coverage',0.80,'resolution_quantile',0.95, ...
        'method_ids',{{'absolute','scaled','ratio','margin','absolute_I'}});
    sc.seeds = struct('development',20262761,'calibration',20262771, ...
        'pilot',20262781,'nonunique',20262791,'near_symmetry',20262801, ...
        'final_reserved',20262811);
    sc.scenario_design = struct('development_per_candidate',2, ...
        'calibration_per_candidate',2,'pilot_per_candidate',1, ...
        'nonunique_count',100,'near_symmetry_count',50);
    if strcmp(mode,'smoke')
        sc.top_k = 4;
        sc.scenario_design.development_per_candidate = 1;
        sc.scenario_design.calibration_per_candidate = 1;
        sc.scenario_design.pilot_per_candidate = 1;
        sc.scenario_design.nonunique_count = 10;
        sc.scenario_design.near_symmetry_count = 10;
    elseif strcmp(mode,'tier2')
        sc.scenario_design.development_per_candidate = 3;
        sc.scenario_design.calibration_per_candidate = 3;
        sc.scenario_design.pilot_per_candidate = 2;
    end
    if strcmp(mode,'pilot')
        sc.results_data = fullfile(base_cfg.root_dir,'results','data','stage4a7_2_r1','pilot');
    end
    sc.final_reserved = struct('status','manifest_only_not_materialized', ...
        'seed',sc.seeds.final_reserved,'scenario_count',0);
    sc.objective_definition = ['shared observed engineering ledger; constrained ', ...
        'candidate enumeration; independent discrete profile distance; empirical ', ...
        'candidate-set confirmation'];
    sc.parameter_search = base_cfg.stage2_2.search;
end
