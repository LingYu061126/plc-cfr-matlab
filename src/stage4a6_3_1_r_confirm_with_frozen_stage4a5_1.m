function result=stage4a6_3_1_r_confirm_with_frozen_stage4a5_1(observed_views,cache,subband_sets,calibration_model,spec,expected_hash)
%STAGE4A6_3_1_R_CONFIRM_WITH_FROZEN_STAGE4A5_1 Truth-free frozen adapter.
    if nargin<6||isempty(expected_hash),error('stage4a6_3_1_r:MissingHash','Expected compatibility hash is required.');end
    if ~strcmp(getfield_default(calibration_model,'compatibility_hash',''),expected_hash),error('stage4a6_3_1_r:CalibrationCompatibility','Calibration model hash mismatch.');end
    if ~strcmp(getfield_default(cache,'compatibility_hash',''),expected_hash),error('stage4a6_3_1_r:CacheCompatibility','Template cache hash mismatch.');end
    result=confirm_stage4a6_3_1_topology(observed_views,cache,subband_sets,calibration_model,spec,expected_hash);result.confirmation_method_id='Stage4A5_1_M3_frozen_adapter_R';result.compatibility_hash=expected_hash;
end
function v=getfield_default(s,n,d),if isstruct(s)&&isfield(s,n),v=s.(n);else,v=d;end,end
