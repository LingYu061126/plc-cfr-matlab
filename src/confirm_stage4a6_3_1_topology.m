function result = confirm_stage4a6_3_1_topology(observed_views,cache,subband_sets,calibration_model,spec,expected_hash)
%CONFIRM_STAGE4A6_3_1_TOPOLOGY Frozen Stage-4A.5.1 truth-free confirmer.
% The interface accepts observations, cache and calibration only.
    if nargin<6||isempty(expected_hash),expected_hash=getfield_default(calibration_model,'compatibility_hash','');end
    if isempty(expected_hash),error('stage4a6_3_1:MissingCompatibilityHash','Compatibility hash is required.');end
    if ~strcmp(getfield_default(calibration_model,'compatibility_hash',''),expected_hash)
        error('stage4a6_3_1:CalibrationCompatibility','Calibration compatibility hash mismatch.');
    end
    if ~strcmp(getfield_default(cache,'compatibility_hash',''),expected_hash)
        error('stage4a6_3_1:CacheCompatibility','Cache compatibility hash mismatch.');
    end
    opts=struct('candidate_count_before_prior',cache.candidate_count, ...
        'repetitions',getfield_default(spec,'stability_repetitions',6), ...
        'block_count',getfield_default(spec,'block_count',2), ...
        'block_fraction',getfield_default(spec,'block_fraction',0.25), ...
        'stability_seed',getfield_default(spec,'stability_seed',1));
    raw=score_stage4a5_observation(observed_views,cache,subband_sets,opts);
    r=apply_stage4a5_confirmation(raw,calibration_model,spec);
    r.confirmation_method_id=getfield_default(spec,'method_id','Stage4A5_1_M3_frozen');
    r.compatibility_hash=expected_hash;r.calibration_hash=getfield_default(calibration_model,'calibration_hash','');
    if isfield(r,'accepted_topology_set')&&~isempty(r.accepted_topology_set),r.accepted_member_ids=strsplit(r.accepted_topology_set,',');else,r.accepted_member_ids={};end
    r.accepted_member_count=numel(r.accepted_member_ids);r.evaluated_member_ids={};r.evaluated_member_count=0;result=r;
end
function v=getfield_default(s,n,d),if isstruct(s)&&isfield(s,n),v=s.(n);else,v=d;end,end
