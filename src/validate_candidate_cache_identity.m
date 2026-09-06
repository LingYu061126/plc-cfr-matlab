function [ok,reason] = validate_candidate_cache_identity(cache,expected)
%VALIDATE_CANDIDATE_CACHE_IDENTITY Validate every model-relevant identity.
    ok=false;reason='missing cache';if isempty(cache)||~isstruct(cache),return;end
    required={'cache_schema_version','cache_configuration_hash','forward_model_source_hash','frequency_hz','candidates','parameter_grid','parameter_template_count','measurement_kind','source_impedance_ohm','receiver_impedance_ohm','distance_feature','distance_weights'};
    for k=1:numel(required),if ~isfield(cache,required{k}),reason=['missing field ' required{k}];return;end,end
    if ~strcmp(cache.cache_schema_version,expected.cache_schema_version),reason='schema mismatch';return;end
    if ~strcmp(cache.cache_configuration_hash,expected.cache_configuration_hash),reason='cache hash mismatch';return;end
    if ~strcmp(cache.forward_model_source_hash,expected.forward_model_source_hash),reason='forward source hash mismatch';return;end
    if ~isequal(cache.frequency_hz(:),expected.frequency_hz(:)),reason='frequency array mismatch';return;end
    if ~isequal({cache.candidates.topology_id},{expected.candidates.topology_id}),reason='topology ID mismatch';return;end
    if ~isequal({cache.candidates.canonical_key},{expected.candidates.canonical_key}),reason='canonical key mismatch';return;end
    if ~isequal(cache.parameter_grid,expected.parameter_grid),reason='parameter grid mismatch';return;end
    if cache.parameter_template_count~=numel(expected.parameter_grid),reason='parameter count mismatch';return;end
    if ~strcmp(cache.measurement_kind,expected.measurement_kind)||cache.source_impedance_ohm~=expected.source_impedance_ohm||cache.receiver_impedance_ohm~=expected.receiver_impedance_ohm,reason='observation/termination mismatch';return;end
    if ~strcmp(cache.distance_feature,expected.distance_feature)||~isequal(cache.distance_weights,expected.distance_weights),reason='distance mismatch';return;end
    ok=true;reason='compatible';
end
