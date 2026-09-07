function out=stage4a6_3_1_r_profile_all_accepted_members(observed_views,frequency_hz,confirmation,candidates,cfg,domain,profile_options,parameter_model)
%STAGE4A6_3_1_R_PROFILE_ALL_ACCEPTED_MEMBERS Profile every accepted member.
    expected_hash=getfield_default(confirmation,'compatibility_hash','');
    model_hash=getfield_default(parameter_model,'compatibility_hash','');
    if isempty(expected_hash)||isempty(model_hash)||~strcmp(expected_hash,model_hash)
        error('stage4a6_3_1_r:ParameterCalibrationCompatibility', ...
            'Parameter calibration model compatibility hash mismatch.');
    end
    out=run_stage4a6_3_1_member_profiles(observed_views,frequency_hz,confirmation,candidates,cfg,domain,profile_options,parameter_model);if getfield_default(out,'accepted_member_count',0)~=getfield_default(out,'evaluated_member_count',0),out.parameter_domain_status='parameter_domain_indeterminate';out.parameter_evidence='accepted/evaluated member count mismatch';end
end
function v=getfield_default(s,n,d),if isstruct(s)&&isfield(s,n),v=s.(n);else,v=d;end,end
