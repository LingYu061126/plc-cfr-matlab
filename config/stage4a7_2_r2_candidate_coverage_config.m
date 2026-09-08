function sc = stage4a7_2_r2_candidate_coverage_config(base_cfg, mode)
%STAGE4A7_2_R2_CANDIDATE_COVERAGE_CONFIG R.2 frozen audit settings.
%   This configuration deliberately separates engineering, compatible and
%   scored candidate spaces.  It does not alter the stable forward model.
    if nargin < 1 || isempty(base_cfg)
        root = fileparts(fileparts(mfilename('fullpath')));
        base_cfg = default_config(root);
    end
    if nargin < 2 || isempty(mode), mode = 'smoke'; end
    mode = lower(char(mode));
    if ~ismember(mode, {'smoke','formal'})
        error('stage4a7_2_r2:InvalidMode','Mode must be smoke or formal.');
    end
    sc = struct();
    sc.stage_name = 'Stage 4A.7.2-R.2';
    sc.version = '4a7_2_r2_candidate_coverage_v1';
    sc.mode = mode;
    sc.frequency_grid_id = 'A_stage4a1_quick61';
    sc.frequency_hz = linspace(2e6,30e6,61);
    sc.measurement_kind = 'siso_forward';
    sc.feature = 'complex_raw';
    sc.alpha = 0.05;
    sc.use_parallel = false;
    sc.num_workers = 1;
    sc.top_k_values = [1 3 5 6 10 20 30 53];
    sc.maximum_candidate_count = 2000;
    sc.prior_source = 'ENWL_LVNS_processed_OpenDSS_derived_controlled_uncertain_prior';
    sc.derived_subnetwork = fullfile(base_cfg.root_dir,'data','derived', ...
        'enwl_uncertain_prior','stage4a7_2_r1_selected_public_subnetwork.csv');
    sc.results_data = fullfile(base_cfg.root_dir,'results','data','stage4a7_2_r2');
    sc.results_logs = fullfile(base_cfg.root_dir,'results','logs','stage4a7_2_r2');
    sc.source_network_id = 'network_13';
    sc.source_feeder_id = 'Feeder_3';
    sc.source_node_id = '32';
    sc.receiver_node_id = '39';
    sc.maximum_degree = 3;
    sc.required_edge_keys = {'32--33','37--39'};
    sc.synthetic_ambiguity_edges = {'33','35';'34','36';'35','37'; ...
        '35','38';'36','39';'37','38'};
    sc.profile = struct('template_grid_id','stage4a1_243_parameter_grid', ...
        'resolution_floor',NaN,'equivalence_tolerance',1e-10);
    sc.method_selection = struct('method_ids',{{'absolute','scaled','ratio', ...
        'margin','absolute_I'}},'development_set_size',3, ...
        'coverage_gate',0.80,'tie_tolerance',1e-12);
    sc.k_audit = struct('include_oracle_reference',false);
    sc.seeds = struct('development',20262761,'calibration',20262771, ...
        'pilot',20262781,'nonunique',20262791,'near_symmetry',20262801, ...
        'final_reserved',20262811);
    sc.scenario_design = struct('development_per_candidate',5, ...
        'calibration_per_candidate',40,'pilot_per_candidate',2, ...
        'scenario_equivalence_count',20,'near_symmetry_levels', ...
        [0 1e-4 5e-4 1e-3 2e-3 5e-3 1e-2 2e-2 5e-2]);
    if strcmp(mode,'smoke')
        sc.scenario_design.development_per_candidate = 5;
        sc.scenario_design.calibration_per_candidate = 5;
        sc.scenario_design.pilot_per_candidate = 1;
        sc.scenario_design.scenario_equivalence_count = 8;
    else
        sc.results_data = fullfile(sc.results_data,'formal');
    end
    sc.final_reserved = struct('status','manifest_only_not_materialized', ...
        'seed',sc.seeds.final_reserved,'scenario_count',0);
    sc.execution = struct('resume',false,'write_intermediate',true, ...
        'deterministic_order',true,'worker_write_policy','main_process_only');
    sc.parameter_search = base_cfg.stage2_2.search;
    sc.objective_definition = ['R.2 coverage and set-validity audit: ', ...
        'full compatible baseline, candidate-specific profile distance, ', ...
        'calibration resolution and scenario-level equivalence.'];
end
