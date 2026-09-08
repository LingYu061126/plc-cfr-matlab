function sc = stage4a7_1_candidate_confirmation_config(base_cfg, mode)
%STAGE4A7_1_CANDIDATE_CONFIRMATION_CONFIG Stage 4A.7.1 frozen scope.
%   This is a model-internal, A-grid, serial pilot configuration.  The
%   engineering prior is explicitly synthetic and is not field GIS.
    if nargin<1||isempty(base_cfg)
        root=fileparts(fileparts(mfilename('fullpath')));base_cfg=default_config(root);
    end
    if nargin<2||isempty(mode),mode='pilot';end
    mode=lower(char(mode));if ~ismember(mode,{'smoke','pilot','calibration','extended_pilot'}),error('stage4a7_1:InvalidMode','Unknown mode.');end
    a=stage4a1_config(base_cfg);a5=stage4a5_1_integrity_config(base_cfg,'formal');
    sc=struct();sc.stage_name='Stage 4A.7.1';sc.version='4a7_1_candidate_confirmation_v1';
    sc.mode=mode;sc.grid_id='A_stage4a1_quick61';sc.frequency_hz=linspace(2e6,30e6,61);
    sc.measurement_kind='siso_forward';sc.use_parallel=false;sc.num_workers=1;
    sc.prior_source='synthetic_demo_prior_not_field_data';sc.radial_only=true;sc.connected_required=true;
    sc.maximum_candidate_count=128;sc.maximum_degree=Inf;sc.top_k=7;sc.alpha=0.05;
    sc.seeds=struct('calibration',20261711,'pilot',20261721,'final_reserved',20261731,'noise',20261741);
    sc.confirmation=struct('residual_threshold',Inf,'margin_threshold',0,'rho_threshold',1, ...
        'indistinguishability_resolution',1e-9,'minimum_calibration_per_candidate',20, ...
        'definition_version','stage4a7_1_objective_confirmation_v1');
    sc.noise=struct('source','frozen explicit synthetic sigma2 configuration', ...
        'model_interpretation','weighted_residual_only_without_Gaussian_assumptions','sigma2',1e-6, ...
        'weighted_residual_quantile',0.95,'threshold_safety_factor',1.10);
    sc.routes=struct('route_A','engineering_edge_universe_enumeration','route_B','deterministic_exact_oracle_topk_prototype', ...
        'route_C','multi_node_tomography_capability_gate');
    sc.legacy_grammar=a.generator;sc.legacy_candidate_count=7;sc.parameter_search=a5.parameter_search;
    sc.stage4a5_1_config=a5;sc.frozen_m3_method_id='M3_M4_q750_K3_qs70';
    sc.results_data=fullfile(base_cfg.results_data,'stage4a7_1');
    sc.results_logs=fullfile(base_cfg.root_dir,'results','logs','stage4a7_1');
    sc.scenario_design=struct('calibration_count_per_candidate',20, ...
        'pilot_continuous_per_candidate',2,'pilot_nominal_per_candidate',1, ...
        'parameter_out_count',9,'structure_out_count',3, ...
        'symmetry_preserving_minimum',2,'final_reserved_is_manifest_only',true, ...
        'require_active_outlier_dimension',false);
    if strcmp(mode,'extended_pilot')
        sc.version='4a7_1_candidate_confirmation_extended_pilot_v1';
        sc.seeds=struct('calibration',20261811,'pilot',20261821,'final_reserved',20261831,'noise',20261841);
        sc.results_data=fullfile(base_cfg.results_data,'stage4a7_1_extended_pilot_v2');
        sc.results_logs=fullfile(base_cfg.root_dir,'results','logs','stage4a7_1_extended_pilot_v2');
        sc.scenario_design.calibration_count_per_candidate=100;
        sc.scenario_design.pilot_continuous_per_candidate=30;
        sc.scenario_design.pilot_nominal_per_candidate=1;
        sc.scenario_design.parameter_out_count=221;
        sc.scenario_design.structure_out_count=73;
        sc.scenario_design.require_active_outlier_dimension=true;
    end
    sc.candidate_generation=struct('maximum_candidate_count',sc.maximum_candidate_count, ...
        'required_edges',[],'forbidden_edges',[],'edge_prior_cost',[],'prior_source',sc.prior_source, ...
        'radial_only',true,'connected_required',true,'maximum_degree',Inf);
    sc.compatibility_definition='stable single-path first-level-branch adapter; unsupported engineering graphs retained but excluded from scored library';
end
