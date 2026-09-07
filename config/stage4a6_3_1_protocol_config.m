function sc = stage4a6_3_1_protocol_config(base_cfg, mode)
%STAGE4A6_3_1_PROTOCOL_CONFIG Controlled A-grid protocol-correction pilot.
% Truth labels are retained in the offline trial bank only.
    if nargin < 1 || isempty(base_cfg)
        root=fileparts(fileparts(mfilename('fullpath')));base_cfg=default_config(root);
    end
    if nargin < 2 || isempty(mode), mode='pilot'; end
    mode=lower(char(mode));
    if ~ismember(mode,{'pilot','audit'}),error('stage4a6_3_1:Mode','Only pilot and audit are allowed.');end
    parent=stage4a5_multiscale_confirmation_config(base_cfg,'formal');
    sc=parent;sc.stage_name='Stage 4A.6.3.1';sc.version='4a6_3_1_protocol_pilot_v1';
    sc.code_version=sc.version;sc.mode=mode;sc.output_prefix='stage4a6_3_1_pilot';
    sc.results_data=fullfile(base_cfg.results_data,'stage4a6_3_1');
    sc.results_figures=fullfile(base_cfg.results_figures,'stage4a6_3_1');
    sc.results_logs=fullfile(base_cfg.root_dir,'results','logs','stage4a6_3_1');
    sc.cache_dir=fullfile(sc.results_data,'cache');sc.grids=sc.grids(1);
    sc.termination=struct('Zs',base_cfg.Zs,'Zr',base_cfg.Zr);
    sc.grid_id='A_stage4a1_quick61';sc.source_tag='synthetic_demo_prior_not_field_data';
    sc.candidate_generation_mode='prior_constrained_radial_enumeration';
    sc.edge_universe_source='synthetic_demo_graph_grammar';
    sc.prior_source='synthetic_demo_prior_not_field_data';
    sc.known_edge_status_source='synthetic_demo_prior_not_field_data';
    sc.candidate_generator_version='generate_radial_topology_candidates_v1';
    sc.confirmation=struct('method_id','Stage4A5_1_M3_frozen','family','M3','M',8, ...
        'q',0.75,'K',3,'stability_threshold',0.70,'stability_repetitions',6, ...
        'block_count',2,'block_fraction',0.25);
    sc.profile=stage4a6_2_profile_config(base_cfg,'smoke').profile;
    sc.profile.enabled=true;sc.profile.initial_grid_points=3;sc.profile.refinement_points=0;
    sc.profile.max_refinement_rounds=0;sc.profile.use_adaptive_refinement=false;
    sc.profile.profile_multi_start_count=1;sc.profile.multistart_single_start_policy='not_applicable';
    sc.profile.profile_max_iterations=20;sc.profile.profile_max_function_evaluations=60;
    sc.profile.minimum_valid_fraction=0.80;sc.profile.critical_points_required=true;
    sc.optimization=stage4a6_2_profile_config(base_cfg,'smoke').optimization;
    sc.optimization.multi_start_count=1;sc.optimization.max_iterations=20;sc.optimization.max_function_evaluations=60;
    sc.execution=struct('use_parallel',false,'num_workers',1,'resume',true,'overwrite_completed',false,'batch_size',1);
    sc.seeds=struct('calibration',20264631,'pilot',20264632);
    sc.trial_design=struct('calibration_per_graph',2,'pilot_in_domain_per_graph',1, ...
        'pilot_out_per_active_parameter',4,'parameter_jitter_fraction',0.08, ...
        'severity_names',{{'near','medium','far'}},'direction_names',{{'lower','upper'}});
    sc.extended_domain_eta=0.5;
    sc.parameter_calibration=stage4a6_2_profile_config(base_cfg,'smoke').parameter_calibration;
    sc.parameter_calibration.minimum_samples=2;sc.parameter_calibration.minimum_profile_reliable_samples=2;
    sc.pilot_profile_case_limit=0;
    sc.calibration.minimum_samples=2;
    sc.protocol_note=['A-grid only; Stage 4A.5.1 confirmation is frozen before ' ...
        'parameter profiling. Full Stage 4A.6.3 final is not rerun.'];
end
