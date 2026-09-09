function summary=exp_stage4a_freeze_r1_1(root,mode,freeze_root_override,source_override)
%EXP_STAGE4A_FREEZE_R1_1 Generate the clean-source canonical archive.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    base=default_config(root);sc=stage4a_freeze_r1_1_config(base,mode,freeze_root_override,source_override);
    ensure_dir(sc.freeze_root);ensure_dir(sc.results_logs);
    run_command=sprintf('run_stage4_freeze_r1_1(pwd,''%s'')',mode);
    pre_id=stage4a_freeze_r1_runtime_identity(root,sc,mode,utc_now(),run_command); %#ok<NASGU>
    if nargin>=4&&~isempty(source_override),source_dir=char(source_override);else,source_dir=sc.source_formal_dir;end
    r2out=fullfile(sc.freeze_root,'r2_1_2');
    exp_stage4a7_2_r2_1_2_statistics_archive(root,r2out,source_dir);
    domain_source=fullfile(source_dir,'formal');
    exp_stage4a7_3_domain_rejection_and_nonunique_validation(root,mode,sc.output_root,domain_source,run_command,sc.results_logs);
    stage_dir=fullfile(sc.output_root,mode);z=load(fullfile(stage_dir,'stage4a7_3_summary.mat'),'identity','summary');id=z.identity;
    assert(strcmp(id.git_head_at_run,pre_id.git_head_at_run),'stage4a_freeze_r1_1:IdentityChanged','Git HEAD changed during the canonical run.');
    if strcmpi(mode,'formal'),assert(id.canonical_eligible && ~id.git_dirty_at_run,'stage4a_freeze_r1_1:FormalNotCanonical','Formal run did not meet clean-source eligibility.');end
    source_manifest=fullfile(stage_dir,'source_identity_manifest.csv');audit=stage4a_freeze_r1_validate_source_manifest(root,source_manifest,id.source_tree_hash);
    source_inventory=readtable(source_manifest,'TextType','string');writetable(source_inventory,fullfile(sc.freeze_root,'source_inventory.csv'));
    hist=historical_status();write_rows(fullfile(sc.freeze_root,'historical_artifact_status.csv'),hist);
    status=ternary(strcmpi(mode,'formal'),'formal_completed','smoke_completed');
    s=struct('stage','Stage 4A Freeze-R.1.1','status',status,'mode',mode,'canonical_output_dir',relative(root,stage_dir), ...
        'r2_archive_dir',relative(root,r2out),'experiment_hash',id.experiment_hash,'source_tree_hash',id.source_tree_hash, ...
        'configuration_hash',id.configuration_hash,'runtime_environment_hash',id.runtime_environment_hash, ...
        'git_head_at_run',id.git_head_at_run,'git_branch_at_run',id.git_branch_at_run,'git_dirty_at_run',id.git_dirty_at_run, ...
        'canonical_eligible',id.canonical_eligible,'source_inventory_count',audit.manifest_row_count, ...
        'source_manifest_missing_count',audit.missing_file_count,'source_manifest_untracked_count',audit.untracked_file_count, ...
        'source_manifest_hash_mismatch_count',audit.hash_mismatch_count,'windows_native_tested',false, ...
        'final_reserved_status','manifest_only_not_materialized','stage4b_started',false);
    write_rows(fullfile(sc.freeze_root,sprintf('freeze_summary_%s.csv',lower(mode))),s);
    write_canonical_manifest(root,sc,id,mode);
    validate_canonical_manifest(root,sc.freeze_root);
    summary=s;
end

function write_canonical_manifest(root,sc,id,mode)
    listing=recursive_files(sc.freeze_root);rows=repmat(manifest_row(),0,1);
    for k=1:numel(listing)
        p=listing{k};rel=relative(root,p);
        if strcmp(rel,'results/data/stage4a_freeze_r1_1/canonical_manifest.csv'),continue;end
        info=dir(p);r=manifest_row();r.stage='Stage 4A Freeze-R.1.1';r.artifact_role=artifact_role(rel);r.relative_path=rel;
        r.file_size_bytes=info.bytes;r.sha256=stage4a7_2_r2_sha256_file(p);r.source_tree_hash=id.source_tree_hash;r.configuration_hash=id.configuration_hash;
        r.experiment_hash=id.experiment_hash;r.git_head_at_run=id.git_head_at_run;r.git_dirty_at_run=id.git_dirty_at_run;
        r.canonical_eligible=id.canonical_eligible;r.canonical_status=canonical_status(rel,mode);r.used_for_formal_report=strcmp(r.canonical_status,'canonical');r.notes=manifest_note(rel);
        rows(end+1)=r; %#ok<AGROW>
    end
    write_rows(fullfile(sc.freeze_root,'canonical_manifest.csv'),rows);
end

function validate_canonical_manifest(root,freeze_root)
    path=fullfile(freeze_root,'canonical_manifest.csv');t=readtable(path,'TextType','string');
    for k=1:height(t)
        p=fullfile(root,strrep(char(t.relative_path(k)),'/',filesep));
        assert(exist(p,'file')==2,'stage4a_freeze_r1_1:MissingArtifact','Canonical manifest references a missing artifact: %s',char(t.relative_path(k)));
        assert(dir(p).bytes==t.file_size_bytes(k),'stage4a_freeze_r1_1:ArtifactSizeMismatch','Canonical artifact size mismatch: %s',p);
        assert(strcmp(stage4a7_2_r2_sha256_file(p),char(t.sha256(k))),'stage4a_freeze_r1_1:ArtifactHashMismatch','Canonical artifact hash mismatch: %s',p);
        assert(strlength(string(t.source_tree_hash(k)))==64 && strlength(string(t.configuration_hash(k)))==64 && strlength(string(t.experiment_hash(k)))==64,'stage4a_freeze_r1_1:ArtifactIdentityIncomplete','Canonical artifact identity is incomplete: %s',p);
    end
end

function rows=historical_status()
    p={'results/data/stage4a_freeze_r1','results/data/stage4a7_3/formal','results/data/stage4a7_3/formal_preselection_semantic_fix','results/data/stage4a7_3/smoke'};
    rows=repmat(struct('relative_path','','status','historical_superseded_by_clean_source_r1_1','notes','Preserved historical evidence; not overwritten.'),numel(p),1);
    for k=1:numel(p),rows(k).relative_path=p{k};end
end

function v=artifact_role(rel)
    if contains(rel,'source_identity_manifest')||contains(rel,'source_inventory'),v='source_identity';
    elseif contains(rel,'selection_rule_sensitivity'),v='sensitivity';
    elseif contains(rel,'stage4a7_3/formal'),v='stage4a7_3_formal';
    elseif contains(rel,'stage4a7_3/smoke'),v='stage4a7_3_smoke';
    elseif contains(rel,'r2_1_2'),v='r2_1_2_archive';
    else,v='freeze_identity_or_summary';end
end
function v=canonical_status(rel,mode)
    if contains(rel,'selection_rule_sensitivity'),v='sensitivity';
    elseif contains(rel,'stage4a7_3/formal')&&strcmpi(mode,'formal'),v='canonical';
    elseif contains(rel,'r2_1_2')&&strcmpi(mode,'formal'),v='canonical';
    else,v='history_or_smoke';end
end
function v=manifest_note(rel)
    if contains(rel,'canonical_manifest'),v='Manifest excludes itself to avoid a hash cycle.';
    elseif contains(rel,'selection_rule_sensitivity'),v='Rule B sensitivity; not used for canonical selection.';
    elseif contains(rel,'summary.mat'),v='Compact summary; frozen inputs remain read-only.';
    else,v='Freeze-R.1.1 generated artifact.';end
end
function files=recursive_files(root)
    files={};d=dir(root);
    for k=1:numel(d)
        if d(k).isdir&&~ismember(d(k).name,{'.','..'}),files=[files recursive_files(fullfile(root,d(k).name))]; %#ok<AGROW>
        elseif ~d(k).isdir,files{end+1}=fullfile(d(k).folder,d(k).name);end %#ok<AGROW>
    end
end
function r=manifest_row()
    r=struct('stage','','artifact_role','','relative_path','','file_size_bytes',0,'sha256','','source_tree_hash','','configuration_hash','','experiment_hash','','git_head_at_run','','git_dirty_at_run',false,'canonical_eligible',false,'canonical_status','','used_for_formal_report',false,'notes','');
end
function p=relative(root,path),p=strrep(path,[root filesep],'');p=strrep(p,filesep,'/');end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function s=utc_now(),d=datetime('now','TimeZone','UTC');d.Format='yyyy-MM-dd''T''HH:mm:ss.SSS''Z''';s=char(d);end
function ensure_dir(p),if exist(p,'dir')~=7,mkdir(p);end,end
function write_rows(p,x),writetable(struct2table(x),p);end
