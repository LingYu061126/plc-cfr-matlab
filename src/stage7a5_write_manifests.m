function stage7a5_write_manifests(root,outdir,source_commit)
%STAGE7A5_WRITE_MANIFESTS Write byte-level source and artifact inventories.
    source_files={'docs/stage7a5_protocol.md','config/stage7a5_config.m', ...
        'src/stage7a5_candidate_pool.m','src/stage7a5_template_bank.m', ...
        'src/stage7a5_profile.m','src/stage7a5_graph_edit_neighbors.m', ...
        'src/stage7a5_expand_candidates.m','src/stage7a5_generate_split.m', ...
        'src/stage7a5_holdout_stat.m','src/stage7a5_score_observation.m', ...
        'src/stage7a5_calibrate_legacy.m','src/stage7a5_calibrate_split.m', ...
        'src/stage7a5_decide.m','src/stage7a5_nonunique_controls.m', ...
        'src/stage7a5_write_manifests.m','experiments/exp_stage7a5_candidate_extension.m', ...
        'run_stage7a5.m','tests/test_stage7a5_candidate_extension.m', ...
        'tests/test_stage7a5_result_integrity.m','docs/stage7a5_report.md'};
    source_files=source_files(cellfun(@(x)exist(fullfile(root,x),'file')==2,source_files));
    sr=repmat(struct('relative_path','','sha256','','size_bytes',0, ...
        'git_tracked',false,'source_commit','','category',''),numel(source_files),1);
    for k=1:numel(source_files)
        p=fullfile(root,source_files{k});info=dir(p);
        cmd=sprintf('git -C "%s" ls-files --error-unmatch -- "%s" >/dev/null 2>&1', ...
            root,source_files{k});
        [status,~]=system(cmd);
        sr(k)=struct('relative_path',source_files{k},'sha256',sha256_file(p), ...
            'size_bytes',info.bytes,'git_tracked',status==0, ...
            'source_commit',source_commit,'category',category(source_files{k}));
    end
    writetable(struct2table(sr),fullfile(outdir,'source_inventory.csv'));
    listing=dir(fullfile(outdir,'*'));listing=listing(~[listing.isdir]);
    names={listing.name};names(strcmp(names,'artifact_manifest.csv'))=[];
    ar=repmat(struct('relative_path','','sha256','','size_bytes',0, ...
        'artifact_type','','stage','','canonical_status','','source_commit',''),numel(names),1);
    for k=1:numel(names)
        p=fullfile(outdir,names{k});info=dir(p);[~,~,ext]=fileparts(names{k});
        rel=fullfile('results','data','stage7a_5',basename(outdir),names{k});
        ar(k)=struct('relative_path',strrep(rel,'\','/'), ...
            'sha256',sha256_file(p),'size_bytes',info.bytes, ...
            'artifact_type',lower(ext(2:end)),'stage','Stage 7A.5', ...
            'canonical_status','new_stage7a5_noncanonical','source_commit',source_commit);
    end
    writetable(struct2table(ar),fullfile(outdir,'artifact_manifest.csv'));
end

function h=sha256_file(path)
    [status,out]=system(sprintf('sha256sum "%s"',path));
    if status~=0,error('stage7a5:ManifestHash','Could not hash %s.',path);end
    h=regexp(strtrim(out),'^[0-9a-f]{64}','match','once');
    if isempty(h),error('stage7a5:ManifestHashMalformed');end
end
function c=category(path)
    if startsWith(path,'config/'),c='config';
    elseif startsWith(path,'src/'),c='source';
    elseif startsWith(path,'tests/'),c='test';
    elseif startsWith(path,'experiments/'),c='experiment';
    elseif startsWith(path,'docs/'),c='document';
    else,c='entrypoint';end
end
function n=basename(p)
    [~,n]=fileparts(p);
end
