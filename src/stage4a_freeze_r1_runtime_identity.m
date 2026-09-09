function id=stage4a_freeze_r1_runtime_identity(root,sc,mode,start_time_utc,run_command)
%STAGE4A_FREEZE_R1_RUNTIME_IDENTITY Capture reproducible run identity.
    if nargin<5||isempty(run_command),run_command=sprintf('run_stage4_freeze_r1(pwd,''%s'')',mode);end
    id=struct();
    if isfield(sc,'stage_name'),id.stage=sc.stage_name;else,id.stage='Stage 4A Freeze-R.1';end
    id.git_head_at_run=git_value(root,'rev-parse HEAD');
    id.git_branch_at_run=git_value(root,'branch --show-current');
    if isempty(id.git_branch_at_run),id.git_branch_at_run='(detached)';end
    [status,dirty]=run_git(root,'status --porcelain');
    if status~=0,error('stage4a_freeze_r1:GitStatusFailed','Unable to read Git working-tree status.');end
    id.git_dirty_at_run=~isempty(strtrim(dirty));
    id.canonical_eligible=strcmpi(char(mode),'formal') && ~id.git_dirty_at_run;
    if strcmpi(char(mode),'formal') && id.git_dirty_at_run
        error('stage4a_freeze_r1:DirtyCanonicalSource','Canonical formal requires a clean Git worktree.');
    end
    inventory=stage4a_freeze_r1_source_inventory(root);
    id.source_inventory_count=inventory.file_count;
    id.source_inventory_tracked_only=inventory.tracked_only;
    id.source_tree_hash=stage4a_freeze_r1_source_tree_hash(root);
    id.configuration_hash=stage4a4_scientific_config_hash(strip_runtime(sc));
    id.matlab_version=version;id.platform=computer;id.computer_arch=computer('arch');
    id.use_parallel=false;id.worker_count=1;id.run_command=run_command;id.start_time_utc=start_time_utc;
    id.runtime_environment_hash=stage4a4_scientific_config_hash(struct('matlab_version',id.matlab_version,'platform',id.platform,'computer_arch',id.computer_arch,'parallel_available',exist('parpool','file')==2));
end
function v=git_value(root,arg)
    [st,out]=run_git(root,arg);
    if st~=0 || isempty(strtrim(out))
        error('stage4a_freeze_r1:GitIdentityFailed','Git identity command failed: git %s',arg);
    end
    v=strtrim(out);
end
function [status,out]=run_git(root,args)
    old=pwd;cleanup=onCleanup(@()cd(old)); %#ok<NASGU>
    if exist(root,'dir')~=7,status=1;out='';return;end
    cd(root);[status,out]=system(['git ' args]);
end
function x=strip_runtime(sc)
    x=sc;for n={'output_root','results_logs','source_formal_dir','root_dir','freeze_root','sensitivity_root'},if isfield(x,n{1}),x=rmfield(x,n{1});end,end
end
