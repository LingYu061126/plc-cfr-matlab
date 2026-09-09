function summary=exp_stage4a_freeze_r1(root,mode)
%EXP_STAGE4A_FREEZE_R1 Generate independent canonical Freeze-R.1 outputs.
%   Historical R2.1.1 inputs are read-only.  New R2.1.2 archive, Stage
%   4A.7.3 smoke/formal outputs, identity manifests and sensitivity rows are
%   written below results/data/stage4a_freeze_r1 only.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    base=default_config(root);sc=stage4a_freeze_r1_config(base,mode);ensure_dir(sc.freeze_root);ensure_dir(sc.results_logs);
    r2out=fullfile(sc.freeze_root,'r2_1_2');r2=exp_stage4a7_2_r2_1_2_statistics_archive(root,r2out); %#ok<NASGU>
    r73=exp_stage4a7_3_domain_rejection_and_nonunique_validation(root,mode,sc.output_root); %#ok<NASGU>
    formal_dir=fullfile(sc.output_root,'formal');smoke_dir=fullfile(sc.output_root,'smoke');
    if strcmpi(mode,'formal'),canonical_dir=formal_dir;else,canonical_dir=smoke_dir;end
    z=load(fullfile(canonical_dir,'stage4a7_3_summary.mat'),'identity','summary');id=z.identity;
    hist=historical_status(root);write_rows(fullfile(sc.freeze_root,'historical_artifact_status.csv'),hist);
    s=struct('stage','Stage 4A Freeze-R.1','status',ternary(strcmpi(mode,'formal'),'canonical_formal_completed','smoke_completed'),'mode',mode,'canonical_output_dir',relative(root,canonical_dir),'r2_archive_dir',relative(root,r2out),'experiment_hash',id.experiment_hash,'source_tree_hash',id.source_tree_hash,'configuration_hash',id.configuration_hash,'runtime_environment_hash',id.runtime_environment_hash,'windows_native_tested',false,'final_reserved_status','manifest_only_not_materialized','stage4b_started',false);
    write_rows(fullfile(sc.freeze_root,sprintf('freeze_summary_%s.csv',lower(mode))),s);
    write_canonical_manifest(root,sc,id,mode);summary=s;
end
function write_canonical_manifest(root,sc,id,mode)
    listing=recursive_files(sc.freeze_root);rows=repmat(manifest_row(),0,1);
    for k=1:numel(listing)
        p=listing{k};rel=relative(root,p);if strcmp(rel,'results/data/stage4a_freeze_r1/canonical_manifest.csv'),continue;end
        artifact_id=resolve_artifact_identity(root,rel,id);
        r=manifest_row();r.stage='Stage 4A Freeze-R.1';r.artifact_role=artifact_role(rel);r.relative_path=rel;r.file_size_bytes=dir(p).bytes;r.sha256=stage4a7_2_r2_sha256_file(p);r.source_tree_hash=artifact_id.source_tree_hash;r.configuration_hash=artifact_id.configuration_hash;r.experiment_hash=artifact_id.experiment_hash;r.git_head_at_run=artifact_id.git_head_at_run;r.canonical_status=canonical_status(rel,mode);r.used_for_formal_report=strcmp(r.canonical_status,'canonical');r.notes=manifest_note(rel);rows(end+1)=r; %#ok<AGROW>
    end
    write_rows(fullfile(sc.freeze_root,'canonical_manifest.csv'),rows);
end
function out=resolve_artifact_identity(root,rel,default_id)
    out=default_id;
    if contains(rel,'stage4a7_3/smoke/')
        p=fullfile(root,'results','data','stage4a_freeze_r1','stage4a7_3','smoke','stage4a7_3_summary.mat');
        if exist(p,'file')==2
            z=load(p,'identity');if isfield(z,'identity'),out=z.identity;end
        end
    end
end
function rows=historical_status(root)
    p={'results/data/stage4a7_3/formal','results/data/stage4a7_3/formal_preselection_semantic_fix','results/data/stage4a7_3/smoke','results/data/stage4a7_2_r2_1_2'};rows=repmat(struct('relative_path','','status','','notes',''),numel(p),1);
    for k=1:numel(p),rows(k)=struct('relative_path',p{k},'status','historical_read_only','notes','Preserved historical evidence; not overwritten by Freeze-R.1.');end
end
function v=artifact_role(rel)
    if contains(rel,'r2_1_2'),v='r2_1_2_archive';elseif contains(rel,'selection_rule_sensitivity'),v='method_selection_sensitivity';elseif contains(rel,'stage4a7_3/formal'),v='stage4a7_3_formal';elseif contains(rel,'stage4a7_3/smoke'),v='stage4a7_3_smoke';else,v='freeze_identity_or_summary';end
end
function v=canonical_status(rel,mode)
    if contains(rel,'selection_rule_sensitivity'),v='sensitivity';elseif contains(rel,'stage4a7_3/formal')&&strcmpi(mode,'formal'),v='canonical';elseif contains(rel,'r2_1_2')&&strcmpi(mode,'formal'),v='canonical';else,v='history_or_smoke';end
end
function v=manifest_note(rel),if contains(rel,'summary.mat'),v='Compact summary; frozen inputs are referenced read-only.';elseif contains(rel,'sensitivity'),v='Rule B audit only; not used for canonical selection.';else,v='Freeze-R.1 generated artifact.';end,end
function files=recursive_files(root)
    files={};d=dir(root);for k=1:numel(d),if d(k).isdir&&~ismember(d(k).name,{'.','..'}),files=[files recursive_files(fullfile(root,d(k).name))];elseif ~d(k).isdir,files{end+1}=fullfile(d(k).folder,d(k).name);end,end
end
function r=manifest_row(),r=struct('stage','','artifact_role','','relative_path','','file_size_bytes',0,'sha256','','source_tree_hash','','configuration_hash','','experiment_hash','','git_head_at_run','','canonical_status','','used_for_formal_report',false,'notes','');end
function p=relative(root,path),p=strrep(path,[root filesep],'');p=strrep(p,filesep,'/');end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
function ensure_dir(p),if exist(p,'dir')~=7,mkdir(p);end,end
function write_rows(p,x),writetable(struct2table(x),p);end
