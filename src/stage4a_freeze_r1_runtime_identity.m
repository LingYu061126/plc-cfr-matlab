function id=stage4a_freeze_r1_runtime_identity(root,sc,mode,start_time_utc,run_command)
%STAGE4A_FREEZE_R1_RUNTIME_IDENTITY Capture reproducible run identity.
    if nargin<5||isempty(run_command),run_command=sprintf('run_stage4_freeze_r1(pwd,''%s'')',mode);end
    id=struct();id.stage='Stage 4A Freeze-R.1';id.mode=char(mode);
    id.git_head_at_run=git_value(root,'rev-parse HEAD');id.git_branch_at_run=git_value(root,'branch --show-current');
    [~,dirty]=system(sprintf('git -C %s status --porcelain',shell_quote(root)));id.git_dirty_at_run=~isempty(strtrim(dirty));
    id.source_tree_hash=stage4a_freeze_r1_source_tree_hash(root);
    id.configuration_hash=stage4a4_scientific_config_hash(strip_runtime(sc));
    id.matlab_version=version;id.platform=computer;id.computer_arch=computer('arch');
    id.use_parallel=false;id.worker_count=1;id.run_command=run_command;id.start_time_utc=start_time_utc;
    id.runtime_environment_hash=stage4a4_scientific_config_hash(struct('matlab_version',id.matlab_version,'platform',id.platform,'computer_arch',id.computer_arch,'parallel_available',exist('parpool','file')==2));
end
function v=git_value(root,arg),[st,out]=system(sprintf('git -C %s %s',shell_quote(root),arg));if st==0,v=strtrim(out);else,v='unavailable';end,end
function q=shell_quote(x),sq=char(39);q=[sq strrep(char(x),sq,[sq '"' sq '"' sq]) sq];end
function x=strip_runtime(sc)
    x=sc;for n={'output_root','results_logs','source_formal_dir','root_dir'},if isfield(x,n{1}),x=rmfield(x,n{1});end,end
end
