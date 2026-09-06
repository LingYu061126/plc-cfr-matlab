function [ok, reason] = validate_stage4a6_2_shard(shard, expected)
%VALIDATE_STAGE4A6_2_SHARD Check compact shard identity and completion.
    ok = false; reason = '';
    required = {'case_id','scientific_hash','source_tree_hash','exit_status','status','profile_summary'};
    for k=1:numel(required)
        if ~isfield(shard,required{k}), reason=['missing_' required{k}]; return; end
    end
    if ~strcmp(shard.status,'completed') || shard.exit_status ~= 0
        reason='not_completed'; return;
    end
    fields={'case_id','scientific_hash','source_tree_hash'};
    for k=1:numel(fields)
        if isfield(expected,fields{k}) && ~strcmp(char(shard.(fields{k})),char(expected.(fields{k})))
            reason=['identity_mismatch_' fields{k}]; return;
        end
    end
    if isfield(expected,'parameter_name') && isfield(shard,'parameter_name') && ...
            ~strcmp(char(shard.parameter_name),char(expected.parameter_name))
        reason='identity_mismatch_parameter_name'; return;
    end
    if isfield(shard,'checksum') && ~isempty(shard.checksum)
        copy = shard; copy.checksum='';
        checksum = stage4a6_2_checksum(copy);
        if ~strcmp(shard.checksum,checksum), reason='checksum_mismatch'; return; end
    end
    ok = true;
end

function h = stage4a6_2_checksum(value)
    [h,~] = stage4a4_scientific_config_hash(value);
end
