function out=stage4a7_3_apply_domain_model(score,model)
%STAGE4A7_3_APPLY_DOMAIN_MODEL Apply a frozen high-score rejection rule.
    assert(isstruct(model)&&strcmp(model.status,'calibrated'), ...
        'stage4a7_3:UncalibratedDomainModel','A calibrated domain model is required.');
    if ~isfinite(score), status='undetermined';accepted=false;
    elseif score>model.threshold,status='out_of_parameter_domain';accepted=false;
    elseif score>model.near_boundary_threshold,status='near_parameter_boundary';accepted=true;
    else,status='in_parameter_domain';accepted=true;end
    out=struct('score',score,'parameter_domain_status',status,'domain_accepted',accepted, ...
        'threshold',model.threshold,'near_boundary_threshold',model.near_boundary_threshold, ...
        'domain_calibration_hash',model.calibration_hash,'definition_version',model.definition_version);
end
