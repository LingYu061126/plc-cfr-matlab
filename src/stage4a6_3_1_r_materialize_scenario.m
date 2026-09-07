function [scenario, observed_views] = stage4a6_3_1_r_materialize_scenario(scenario,cfg,frequency_hz)
%STAGE4A6_3_1_R_MATERIALIZE_SCENARIO Run one truth-bearing scenario offline.
% The returned observation is for experiment generation/scoring only; it is
% never passed to the truth-free confirmer together with scenario labels.
    if nargin<3||isempty(frequency_hz),error('stage4a6_3_1_r:MissingFrequency','frequency_hz is required.');end
    scenario.parameter_vector_hash=stage4a4_scientific_config_hash(scenario.truth_theta);
    [network,local_cfg]=topology_apply_parameters(scenario.truth_network,cfg,scenario.truth_theta);
    [measurement,~]=plc_measurement_bundle('siso_forward',network,scenario.truth_theta,local_cfg);
    [observed_views,~]=plc_multiview_response(frequency_hz(:).',network,measurement,local_cfg);
    if isempty(observed_views)||any(cellfun(@(x)any(~isfinite(x(:))),observed_views))
        error('stage4a6_3_1_r:NonfiniteObservation','Scenario CFR contains nonfinite values.');
    end
    payload=struct('real',{cellfun(@real,observed_views,'UniformOutput',false)}, ...
        'imag',{cellfun(@imag,observed_views,'UniformOutput',false)});
    scenario.noiseless_cfr_hash=stage4a4_scientific_config_hash(payload);
    scenario.observation_hash=scenario.noiseless_cfr_hash;
end
