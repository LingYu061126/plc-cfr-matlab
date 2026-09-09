function test_stage4_freeze_r1()
%TEST_STAGE4_FREEZE_R1 Reproducibility, semantics and manifest checks.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));
    tmp=fullfile(tempdir,'stage4 freeze r1 中文 (sha)');if exist(tmp,'dir')~=7,mkdir(tmp);end
    p=fullfile(tmp,'a file (中文).bin');fid=fopen(p,'wb');fwrite(fid,uint8('abc'),'uint8');fclose(fid);cleanup=onCleanup(@()delete_if_exists(p));
    assert(strcmp(stage4a7_2_r2_sha256_file(p),'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'),'Cross-platform path SHA vector failed.');
    m=stage4a7_3_calibrate_domain_model((1:40)','x',struct('minimum_count',20,'quantile',.95,'near_boundary_quantile',.80));
    assert(strcmp(stage4a7_3_apply_domain_model(m.near_boundary_threshold+.01,m).parameter_domain_status,'borderline_domain_score'),'Physical boundary name leaked into score status.');
    assert(strcmp(stage4a7_3_apply_domain_model(NaN,m).parameter_domain_status,'undetermined'),'Nonfinite score must be undetermined.');
    cfg=stage4a7_3_domain_validation_config(default_config(root),'smoke');assert(strcmp(cfg.parameter_domain.selection_rule_id,'domain_gate_then_ood_v1'));assert(~cfg.parameter_domain.pilot_used_for_selection);
    assert(strcmp(stage4a_freeze_r1_source_tree_hash(root),stage4a_freeze_r1_source_tree_hash(root)),'Source hash is not deterministic.');
    out=fullfile(root,'results','data','stage4a_freeze_r1','stage4a7_3','formal');
    if exist(out,'dir')==7 && exist(fullfile(out,'source_identity_manifest.csv'),'file')==2
        z=readtable(fullfile(out,'source_identity_manifest.csv'));assert(all(strlength(string(z.source_tree_hash))==64),'Source identity manifest is incomplete.');
        manifest=readtable(fullfile(root,'results','data','stage4a_freeze_r1','canonical_manifest.csv'),'TextType','string');
        for ii=1:height(manifest)
            artifact=fullfile(root,char(manifest.relative_path(ii)));
            assert(exist(artifact,'file')==2,'Canonical manifest points to a missing artifact: %s',artifact);
            assert(strcmp(stage4a7_2_r2_sha256_file(artifact),char(manifest.sha256(ii))),'Canonical manifest SHA mismatch: %s',artifact);
        end
        c=readtable(fullfile(root,'results','data','stage4a_freeze_r1','canonical_manifest.csv'));assert(all(c.file_size_bytes>=0)&&all(cellfun(@(x)exist(fullfile(root,strrep(x,'/',filesep)),'file')==2,c.relative_path)),'Canonical manifest contains a missing artifact.');
    end
    fprintf('  PASS Stage 4A Freeze-R.1 SHA, score semantics, selection identity and manifest checks\n');
end
function delete_if_exists(p),if exist(p,'file'),delete(p);end,end
