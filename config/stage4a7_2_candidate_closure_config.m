function sc = stage4a7_2_candidate_closure_config(base_cfg, mode)
%STAGE4A7_2_CANDIDATE_CLOSURE_CONFIG Stage 4A.7.2 controlled closure.
    if nargin<1||isempty(base_cfg),root=fileparts(fileparts(mfilename('fullpath')));base_cfg=default_config(root);end
    if nargin<2||isempty(mode),mode='smoke';end
    mode=lower(char(mode));if ~ismember(mode,{'smoke','smoke_v2','pilot','tier2','tier2_v2','tier2_v3'}),error('stage4a7_2:InvalidMode','Unknown mode.');end
    sc=struct();sc.stage_name='Stage 4A.7.2';sc.version='4a7_2_candidate_closure_v1';sc.mode=mode;sc.grid_id='A_stage4a1_quick61';sc.frequency_hz=linspace(2e6,30e6,61);sc.measurement_kind='siso_forward';sc.alpha=0.05;sc.use_parallel=false;sc.num_workers=1;
    sc.prior_source='synthetic_demo_prior_not_field_data';sc.radial_only=true;sc.connected_required=true;sc.maximum_degree=Inf;sc.maximum_candidate_count=128;sc.top_k=3;sc.indistinguishability_resolution=1e-12;
    sc.seeds=struct('development',20262711,'calibration',20262721,'pilot',20262731,'nonunique',20262741,'final_reserved',20262751);
    sc.nonunique=struct('requested_count',100,'tau_exact',1e-10,'profile_tolerance',1e-8);
    sc.scenario_design=struct('development_per_candidate',10,'calibration_per_candidate',20,'pilot_in_domain_per_candidate',3,'pilot_parameter_ood_per_candidate',3,'pilot_structure_ool_count',7);
    if ismember(mode,{'smoke','smoke_v2'}),sc.nonunique.requested_count=10;sc.scenario_design.development_per_candidate=2;sc.scenario_design.calibration_per_candidate=3;sc.scenario_design.pilot_in_domain_per_candidate=1;sc.scenario_design.pilot_parameter_ood_per_candidate=1;sc.scenario_design.pilot_structure_ool_count=1;end
    if strcmp(mode,'pilot'),sc.nonunique.requested_count=60;end
    sc.results_data=fullfile(base_cfg.results_data,['stage4a7_2_' mode]);sc.results_logs=fullfile(base_cfg.root_dir,'results','logs',['stage4a7_2_' mode]);sc.final_reserved=struct('status','manifest_only_not_materialized','seed',sc.seeds.final_reserved,'scenario_count',0);
    sc.objective_definition='engineering prior-cost candidate generation, frozen SISO CFR residual, empirical calibrated nonconformity families';
end
