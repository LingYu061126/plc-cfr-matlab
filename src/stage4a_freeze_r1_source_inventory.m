function inventory=stage4a_freeze_r1_source_inventory(root)
%STAGE4A_FREEZE_R1_SOURCE_INVENTORY Return the tracked scientific source set.
%   The inventory is obtained from Git, not from a directory scan.  This
%   prevents an untracked MATLAB file in a developer worktree from entering
%   the source identity of a canonical run.
    if nargin<1||isempty(root)
        root=fileparts(fileparts(mfilename('fullpath')));
    end
    root=char(root);
    [status,is_repo]=run_git(root,'rev-parse --is-inside-work-tree');
    if status~=0 || ~strcmp(strtrim(is_repo),'true')
        error('stage4a_freeze_r1:NotGitRepository','The source root is not a Git worktree: %s',root);
    end
    [status,listing]=run_git(root,'ls-files');
    if status~=0
        error('stage4a_freeze_r1:GitInventoryFailed','git ls-files failed for the source root.');
    end
    lines=strsplit(strrep(listing,char(13),''),char(10));
    rel={};
    for k=1:numel(lines)
        p=strtrim(lines{k});
        if isempty(p),continue;end
        p=strrep(p,char(92),'/');
        is_scientific=(starts_with_any(p,{'config/','src/','experiments/','tests/'}) && ends_with(p,'.m')) || ...
            (~contains(p,'/') && starts_with(p,'run_stage4') && ends_with(p,'.m'));
        if is_scientific,rel{end+1}=p;end %#ok<AGROW>
    end
    rel=sort(unique(rel));
    if isempty(rel)
        error('stage4a_freeze_r1:EmptySourceInventory','No tracked scientific MATLAB sources were found.');
    end
    missing=false(size(rel));
    for k=1:numel(rel)
        missing(k)=exist(fullfile(root,strrep(rel{k},'/',filesep)),'file')~=2;
    end
    if any(missing)
        error('stage4a_freeze_r1:MissingTrackedSource','Tracked source is missing from the worktree: %s',rel{find(missing,1)});
    end
    inventory=struct('relative_paths',{rel},'tracked_only',true,'git_root',root,'file_count',numel(rel));
end

function [status,out]=run_git(root,args)
    old=pwd;
    cleanup=onCleanup(@()cd(old)); %#ok<NASGU>
    if exist(root,'dir')~=7
        status=1;out='';return;
    end
    cd(root);
    [status,out]=system(['git ' args]);
end

function tf=starts_with_any(value,prefixes)
    tf=false;
    for k=1:numel(prefixes)
        if strncmp(value,prefixes{k},numel(prefixes{k})),tf=true;return;end
    end
end

function tf=starts_with(value,prefix)
    tf=strncmp(value,prefix,numel(prefix));
end

function tf=ends_with(value,suffix)
    tf=numel(value)>=numel(suffix) && strcmp(value(end-numel(suffix)+1:end),suffix);
end
