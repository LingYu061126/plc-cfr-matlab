function sc = stage4a6_parameter_domain_config(base_cfg,mode)
%STAGE4A6_PARAMETER_DOMAIN_CONFIG Frozen joint topology/parameter protocol.
    if nargin<1||isempty(base_cfg),root=fileparts(fileparts(mfilename('fullpath')));base_cfg=default_config(root);end
    if nargin<2,mode='formal';end;mode=lower(char(mode));if ~ismember(mode,{'smoke','development','formal','formal_a','formal_b'}),error('stage4a6:Mode','Invalid mode.');end
    a5=stage4a5_1_integrity_config(base_cfg,'formal');sc=a5;sc.stage_name='Stage 4A.6';sc.version='4a6_joint_parameter_domain_v1';sc.mode=mode;sc.output_prefix='stage4a6';
    sc.development_seeds=[20261601 20261602];sc.final_seeds=20261701:20261705;sc.parameter_calibration_seed=20261620;
    sc.extended_domain_eta_candidates=[0.5 1.0];sc.optimization=struct('algorithm','fminsearch_logistic_bounded','multi_start_count',2,'max_iterations',60,'max_function_evaluations',180,'tolerance_x',1e-5,'tolerance_fun',1e-7,'boundary_fraction',0.05,'finite_difference_step',1e-3);
    sc.parameter_calibration=struct('improvement_quantile',0.95,'relative_improvement_quantile',0.95,'sensitivity_floor_quantile',0.05,'minimum_samples',8,'indeterminate_band',0.10);
    sc.sample_design=struct('calibration_per_graph',2,'in_domain_per_replicate',7,'ood_per_dimension_per_replicate',1,'dimensions',{{'main_length_scale','branch_length_scale','branch_load_scale','source_impedance_ohm','receiver_impedance_ohm','joint_parameter_set'}},'severities',{{'near','medium','far'}});
    sc.diagnostic_methods={'A6_M0_topology_only','A6_M1_boundary','A6_M2_extended_profile','A6_M3_joint_diagnostic'};
    sc.cache_dir=fullfile(base_cfg.results_data,'stage4a5_1_cache');sc.results_data=base_cfg.results_data;sc.results_figures=base_cfg.results_figures;sc.results_logs=fullfile(base_cfg.root_dir,'results','logs');
    if strcmp(mode,'formal_a'),sc.output_prefix='stage4a6_final_A';sc.grids=sc.grids(1);sc.development_seeds=[];end
    if strcmp(mode,'formal_b'),sc.output_prefix='stage4a6_final_B';sc.grids=sc.grids(2);sc.development_seeds=[];end
    if strcmp(mode,'smoke'),sc.output_prefix='stage4a6_smoke';sc.development_seeds=sc.development_seeds(1);sc.final_seeds=sc.final_seeds(1);sc.grids=sc.grids(1);sc.optimization.max_iterations=20;sc.optimization.max_function_evaluations=60;sc.sample_design.calibration_per_graph=1;sc.sample_design.in_domain_per_replicate=2;sc.sample_design.dimensions=sc.sample_design.dimensions(1:2);sc.calibration.minimum_samples=1;sc.parameter_calibration.minimum_samples=1;end
    if strcmp(mode,'development'),sc.output_prefix='stage4a6_development';sc.final_seeds=[];end
    sc.protocol_note='Truth labels are offline only; topology and parameter-domain decisions receive observations, caches, calibration models and candidate definitions.';
end
