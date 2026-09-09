function sc=stage4a7_2_r2_1_protocol_config(base,mode)
%STAGE4A7_2_R2_1_PROTOCOL_CONFIG Independent off-grid/noisy validation.
    if nargin<1||isempty(base),base=default_config(fileparts(fileparts(mfilename('fullpath'))));end
    if nargin<2||isempty(mode),mode='smoke';end
    mode=lower(char(mode));if ~ismember(mode,{'smoke','formal'}),error('stage4a7_2_r2_1:Mode','Mode must be smoke or formal.');end
    sc=stage4a7_2_r2_candidate_coverage_config(base,mode);sc.stage_name='Stage 4A.7.2-R.2.1';sc.version='4a7_2_r2_1_independent_validation_v1';sc.mode=mode;
    sc.results_data=fullfile(base.root_dir,'results','data','stage4a7_2_r2_1',mode);sc.results_logs=fullfile(base.root_dir,'results','logs','stage4a7_2_r2_1');
    sc.use_parallel=false;sc.num_workers=1;sc.noise=struct('enabled',true,'snr_db',20,'kind','frequency_domain_circular_complex_gaussian');
    % ENWL-derived line records do not provide the terminal load needed by
    % the controlled first-level-branch forward adapter.  This value is an
    % explicit model-side default, not a measurement or an ENWL parameter.
    sc.forward_model_default_terminal_load_ohm=50;
    sc.forward_model_load_mapping_status='controlled_model_default_not_ENWL_measurement';
    sc.case_sampling=struct('kind','off_grid_uniform_in_domain','exact_grid_control',false,'seed_rule','stable_case_seed(master_seed,sample_id)');
    sc.corruptions={'nominal','missing_edge','false_edge','confidence_inversion','incorrect_required_edge','missing_switch_state','mixed_corruption'};
    sc.add_controlled_ambiguity_edges=true;
    sc.observed_default_prior_cost=1.0;
    sc.synthetic_ambiguity_prior_cost=1.0;
    sc.scenario_design.development_per_candidate=2;sc.scenario_design.calibration_per_candidate=10;sc.scenario_design.pilot_per_candidate=1;
    if strcmp(mode,'formal'),sc.scenario_design.development_per_candidate=3;sc.scenario_design.calibration_per_candidate=40;sc.scenario_design.pilot_per_candidate=2;end
    sc.seeds=struct('development',20262901,'calibration',20262911,'pilot',20262921,'final_reserved',20262931);
    sc.method_selection.method_ids={'absolute','scaled','ratio','margin','absolute_I'};sc.method_selection.coverage_gate=.80;sc.method_selection.development_set_size=3;
    sc.profile.resolution_floor=1e-10;sc.profile.equivalence_tolerance=1e-10;
    sc.final_reserved=struct('status','manifest_only_not_materialized','seed',sc.seeds.final_reserved,'scenario_count',0);
end
