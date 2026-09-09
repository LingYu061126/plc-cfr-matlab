function test_stage4_freeze_r1_1()
%TEST_STAGE4_FREEZE_R1_1 Clean-source identity, stamping and archive checks.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    tmp=fullfile(tempdir,'stage4 freeze r1 1 中文 (vectors)');if exist(tmp,'dir')~=7,mkdir(tmp);end
    empty_path=fullfile(tmp,'empty file (中文).bin');fid=fopen(empty_path,'wb');fclose(fid);
    abc_path=fullfile(tmp,'abc file (括号).bin');fid=fopen(abc_path,'wb');fwrite(fid,uint8('abc'),'uint8');fclose(fid);
    cleanup=onCleanup(@()cleanup_files({empty_path,abc_path})); %#ok<NASGU>
    assert(strcmp(stage4a7_2_r2_sha256_file(empty_path),'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'),'Empty-file SHA256 vector failed.');
    assert(strcmp(stage4a7_2_r2_sha256_file(abc_path),'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'),'ABC SHA256 vector failed.');
    inv=stage4a_freeze_r1_source_inventory(root);assert(inv.tracked_only&&inv.file_count>0,'Tracked source inventory is empty.');
    assert(all(cellfun(@(p)exist(fullfile(root,strrep(p,'/',filesep)),'file')==2,inv.relative_paths)),'Source inventory contains a missing file.');
    h1=stage4a_freeze_r1_source_tree_hash(root);h2=stage4a_freeze_r1_source_tree_hash(root);assert(strcmp(h1,h2)&&numel(h1)==64,'Source tree hash is not deterministic.');
    row=struct('rule_id','rule_B_strict_lexicographic_sensitivity','selected_method','profile_min_distance','threshold',0.0564853173821596,'experiment_hash','eh');
    id=struct('selected_method','profile_relative_distance','experiment_hash','eh','stage','Stage 4A Freeze-R.1.1');
    stamped=stage4a_freeze_r1_stamp_identity(row,id);assert(strcmp(stamped.selected_method,'profile_min_distance'),'Scientific selected_method was overwritten.');assert(strcmp(stamped.canonical_execution_method,'profile_relative_distance'),'Canonical execution method was not separated.');
    assert_throws(@()stage4a_freeze_r1_stamp_identity(row,struct('experiment_hash','different')),'stage4a_freeze_r1:IdentityFieldCollision');
    assert_throws(@()stage4a_freeze_r1_runtime_identity(root,default_config(root),'formal','now','test'),'stage4a_freeze_r1:DirtyCanonicalSource');
    smoke_id=stage4a_freeze_r1_runtime_identity(root,default_config(root),'smoke','now','test');assert(smoke_id.git_dirty_at_run&&~smoke_id.canonical_eligible,'Dirty smoke identity was not recorded.');
    manifest_path=fullfile(tmp,'source_manifest.csv');t=table(string(inv.relative_paths{1}),string(stage4a7_2_r2_sha256_file(fullfile(root,strrep(inv.relative_paths{1},'/',filesep)))),string(h1),true,true,0, ...
        'VariableNames',{'relative_path','file_sha256','source_tree_hash','git_tracked','file_exists','file_size_bytes'});writetable(t,manifest_path);a=stage4a_freeze_r1_validate_source_manifest(root,manifest_path,h1);assert(a.manifest_row_count==1&&a.hash_mismatch_count==0,'Valid source manifest was rejected.');
    t.relative_path(1)="src/this_file_does_not_exist.m";writetable(t,manifest_path);assert_throws(@()stage4a_freeze_r1_validate_source_manifest(root,manifest_path,h1),'stage4a_freeze_r1:SourceManifestMissingFile');
    fprintf('  PASS Stage 4A Freeze-R.1.1 clean identity, hash, stamping and manifest checks\n');
end
function assert_throws(fun,id),ok=false;try,fun();catch e,ok=strcmp(e.identifier,id);end;assert(ok,'Expected error %s.',id);end
function cleanup_files(paths),for k=1:numel(paths),if exist(paths{k},'file'),delete(paths{k});end,end,end
