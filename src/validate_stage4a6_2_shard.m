function [ok, reason] = validate_stage4a6_2_shard(shard, expected, varargin)
%VALIDATE_STAGE4A6_2_SHARD Validate completed or failed diagnostic shards.
    p=inputParser;p.addParameter('allow_failed',true);p.parse(varargin{:});
    ok=false;reason='';
    required={'case_id','scientific_hash','source_tree_hash','parameter_name', ...
        'exit_status','status','started_at','finished_at','runtime_s', ...
        'error_identifier','error_message','attempt_count','checksum'};
    for k=1:numel(required)
        if ~isfield(shard,required{k})
            reason=['missing_' required{k}];return;
        end
    end
    required_nonempty={'case_id','scientific_hash','source_tree_hash','parameter_name','status','checksum'};
    for k=1:numel(required_nonempty)
        f=required_nonempty{k};
        if isempty(shard.(f)),reason=['empty_' f];return;end
    end
    if ~ismember(char(shard.status),{'completed','failed'}),reason='invalid_status';return;end
    if strcmp(shard.status,'completed')
        if shard.exit_status~=0,reason='completed_nonzero_exit_status';return;end
        if ~isfield(shard,'profile_summary'),reason='missing_profile_summary';return;end
    elseif ~p.Results.allow_failed
        reason='failed_not_allowed';return;
    elseif shard.exit_status==0
        reason='failed_zero_exit_status';return;
    end
    fields={'case_id','scientific_hash','source_tree_hash','parameter_name'};
    for k=1:numel(fields)
        if isfield(expected,fields{k}) && ~strcmp(char(shard.(fields{k})),char(expected.(fields{k})))
            reason=['identity_mismatch_' fields{k}];return;
        end
    end
    copy=shard;copy.checksum='';checksum=stage4a6_2_checksum(copy);
    if ~strcmp(char(shard.checksum),checksum),reason='checksum_mismatch';return;end
    ok=true;
end

function h = stage4a6_2_checksum(value)
    [h,~] = stage4a4_scientific_config_hash(value);
end
