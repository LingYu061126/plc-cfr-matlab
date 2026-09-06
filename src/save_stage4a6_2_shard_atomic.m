function path_out = save_stage4a6_2_shard_atomic(shard, path_out, expected)
%SAVE_STAGE4A6_2_SHARD_ATOMIC Save a validated shard through a temp file.
    if nargin < 3, expected = struct(); end
    folder=fileparts(path_out);if ~isempty(folder)&&~exist(folder,'dir'),mkdir(folder);end
    copy=shard;copy.checksum='';copy.checksum=stage4a6_2_checksum(copy);
    [ok,reason]=validate_stage4a6_2_shard(copy,expected,'allow_failed',true);
    if ~ok,error('stage4a6_2:InvalidShard','Cannot save shard: %s',reason);end
    tmp=[tempname(folder) '.tmp.mat'];
    shard=copy; %#ok<NASGU>
    save(tmp,'shard','-v7');
    movefile(tmp,path_out,'f');
end
function h=stage4a6_2_checksum(v),[h,~]=stage4a4_scientific_config_hash(v);end
