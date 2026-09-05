function [digest, canonical_text] = stage4a3_1_config_hash(value)
%STAGE4A3_1_CONFIG_HASH SHA-256 for the complete Stage-4A.3.1 payload.
%   The existing stage4a2_config_hash canonicalizer retains complete numeric
%   arrays and sorted structure fields.  This wrapper makes SHA-256 a hard
%   requirement for the new stage instead of accepting its legacy fallback.

    [digest, canonical_text] = stage4a2_config_hash(value);
    if numel(digest) ~= 64 || ~all(isstrprop(digest, 'xdigit'))
        error('stage4a3_1_config_hash:SHA256Unavailable', ...
            'Stage 4A.3.1 requires the SHA-256 implementation used by stage4a2_config_hash.');
    end
end
