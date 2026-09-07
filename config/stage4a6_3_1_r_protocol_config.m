function sc = stage4a6_3_1_r_protocol_config(base_cfg, mode)
%STAGE4A6_3_1_R_PROTOCOL_CONFIG Reproducible independent A-grid pilot.
% Truth fields are confined to the offline scenario bank and scoring.
    if nargin < 1 || isempty(base_cfg)
        root = fileparts(fileparts(mfilename('fullpath')));
        base_cfg = default_config(root);
    end
    if nargin < 2 || isempty(mode), mode = 'pilot'; end
    mode = lower(char(mode));
    if ~ismember(mode, {'pilot','audit'})
        error('stage4a6_3_1_r:InvalidMode','mode must be pilot or audit.');
    end
    old = stage4a6_3_1_protocol_config(base_cfg,'pilot');
    sc = old;
    sc.stage_name = 'Stage 4A.6.3.1-R';
    sc.version = '4a6_3_1_r_independent_pilot_v1';
    sc.code_version = sc.version;
    sc.mode = mode;
    sc.output_prefix = 'stage4a6_3_1_r';
    sc.results_data = fullfile(base_cfg.results_data,'stage4a6_3_1_r');
    sc.results_figures = fullfile(base_cfg.results_figures,'stage4a6_3_1_r');
    sc.results_logs = fullfile(base_cfg.root_dir,'results','logs','stage4a6_3_1_r');
    sc.cache_dir = fullfile(sc.results_data,'cache');
    sc.grids = sc.grids(1);
    sc.grid_id = 'A_stage4a1_quick61';
    sc.execution = struct('use_parallel',false,'num_workers',1,'resume',true, ...
        'overwrite_completed',false,'batch_size',1);
    sc.seeds = struct('calibration',20266031,'pilot',20266032,'final_reserved',20266033);
    sc.trial_design = struct('calibration_per_graph',2, ...
        'pilot_in_domain_per_graph',1,'pilot_boundary_per_graph',1, ...
        'pilot_out_per_graph',3,'parameter_jitter_fraction',0.08, ...
        'severity_names',{{'near','medium','far'}}, ...
        'direction_names',{{'lower','upper'}}, ...
        'final_reserved_count',7);
    sc.profile = old.profile;
    sc.profile.enabled = true;
    sc.profile.grid_strategy = 'fixed_grid_with_midpoints';
    sc.profile.initial_grid_points = 3;
    sc.profile.refinement_points = 0;
    sc.profile.max_refinement_rounds = 0;
    sc.profile.use_adaptive_refinement = false;
    sc.profile.profile_multi_start_count = 1;
    sc.profile.multistart_single_start_policy = 'not_applicable';
    sc.profile.profile_max_iterations = 20;
    sc.profile.profile_max_function_evaluations = 60;
    sc.profile.minimum_valid_fraction = 0.80;
    sc.profile.critical_points_required = true;
    sc.optimization = old.optimization;
    sc.optimization.multi_start_count = 1;
    sc.optimization.max_iterations = 20;
    sc.optimization.max_function_evaluations = 60;
    sc.parameter_calibration = old.parameter_calibration;
    sc.parameter_calibration.minimum_samples = 2;
    sc.parameter_calibration.minimum_profile_reliable_samples = 2;
    sc.calibration.minimum_samples = 2;
    sc.extended_domain_eta = 0.5;
    sc.confirmation.method_id = 'Stage4A5_1_M3_frozen';
    sc.confirmation.family = 'M3';
    sc.confirmation.stability_repetitions = 6;
    sc.confirmation.block_count = 2;
    sc.confirmation.block_fraction = 0.25;
    sc.candidate_generation_mode = 'prior_constrained_radial_enumeration';
    sc.edge_universe_source = 'synthetic_demo_graph_grammar';
    sc.prior_source = 'synthetic_demo_prior_not_field_data';
    sc.known_edge_status_source = 'synthetic_demo_prior_not_field_data';
    sc.candidate_generator_version = 'generate_radial_topology_candidates_v1';
    sc.protocol = struct('scenario_design_version','independent_physical_scenarios_v1', ...
        'final_reserved_is_manifest_only',true,'profile_all_accepted_members',true, ...
        'truth_free_confirmation_adapter','stage4a6_3_1_r_confirm_with_frozen_stage4a5_1', ...
        'parameter_profile_name','constrained_residual_profile_not_likelihood', ...
        'candidate_generation_tag','synthetic_demo_prior_not_field_data');
    sc.protocol_note = ['A-grid independent pilot only. Calibration and pilot use ' ...
        'different physical scenario seeds; final_reserved is not executed.'];
end
