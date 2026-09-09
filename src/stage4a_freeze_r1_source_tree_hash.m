function hash=stage4a_freeze_r1_source_tree_hash(root)
%STAGE4A_FREEZE_R1_SOURCE_TREE_HASH Hash scientific MATLAB sources only.
%   The manifest is path-independent and excludes results, logs, reports,
%   timestamps, caches, and machine-local paths. Missing source roots fail
%   loudly instead of being represented by a placeholder.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    inventory=stage4a_freeze_r1_source_inventory(root);
    rel=inventory.relative_paths;payload=repmat(struct('relative_path','','content',''),numel(rel),1);
    for k=1:numel(rel)
        p=fullfile(root,strrep(rel{k},'/',filesep));
        if exist(p,'file')~=2,error('stage4a_freeze_r1:MissingSourceFile','Missing %s.',rel{k});end
        payload(k).relative_path=rel{k};payload(k).content=fileread(p);
    end
    hash=stage4a4_scientific_config_hash(payload);
end
