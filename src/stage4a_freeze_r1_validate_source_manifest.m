function audit=stage4a_freeze_r1_validate_source_manifest(root,manifest_path,expected_source_tree_hash)
%STAGE4A_FREEZE_R1_VALIDATE_SOURCE_MANIFEST Validate every source reference.
    if nargin<3,expected_source_tree_hash='';end
    assert(exist(manifest_path,'file')==2,'stage4a_freeze_r1:MissingSourceManifest','Missing source manifest: %s',manifest_path);
    t=readtable(manifest_path,'TextType','string');
    required={'relative_path','file_sha256','source_tree_hash'};
    for k=1:numel(required),assert(ismember(required{k},t.Properties.VariableNames),'stage4a_freeze_r1:SourceManifestSchema','Missing source manifest field %s.',required{k});end
    inv=stage4a_freeze_r1_source_inventory(root);tracked=string(inv.relative_paths);
    missing=0;untracked=0;hash_mismatch=0;tree_mismatch=0;
    for k=1:height(t)
        rel=char(t.relative_path(k));p=fullfile(root,strrep(rel,'/',filesep));
        if exist(p,'file')~=2,missing=missing+1;continue;end
        if ~any(strcmp(tracked,string(rel))),untracked=untracked+1;end
        if ~strcmp(stage4a7_2_r2_sha256_file(p),char(t.file_sha256(k))),hash_mismatch=hash_mismatch+1;end
        if ~isempty(expected_source_tree_hash) && ~strcmp(char(t.source_tree_hash(k)),expected_source_tree_hash),tree_mismatch=tree_mismatch+1;end
    end
    if missing>0,error('stage4a_freeze_r1:SourceManifestMissingFile','Source manifest references %d missing file(s).',missing);end
    if untracked>0,error('stage4a_freeze_r1:SourceManifestUntrackedFile','Source manifest references %d untracked file(s).',untracked);end
    if hash_mismatch>0,error('stage4a_freeze_r1:SourceManifestHashMismatch','Source manifest has %d file hash mismatch(es).',hash_mismatch);end
    if tree_mismatch>0,error('stage4a_freeze_r1:SourceManifestTreeHashMismatch','Source manifest has %d source-tree hash mismatch(es).',tree_mismatch);end
    audit=struct('manifest_row_count',height(t),'missing_file_count',missing,'untracked_file_count',untracked,'hash_mismatch_count',hash_mismatch,'source_tree_hash_mismatch_count',tree_mismatch,'tracked_inventory_count',inv.file_count);
end
