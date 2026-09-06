function out = run_stage4a5_multiscale_confirmation(mode)
%RUN_STAGE4A5_MULTISCALE_CONFIRMATION Run the Stage 4A.5 audit.
%   Usage from the repository root:
%       out = run_stage4a5_multiscale_confirmation('smoke');
%       out = run_stage4a5_multiscale_confirmation('formal');
%   The default is formal.  Results use a Stage 4A.5-specific prefix.
    if nargin < 1 || isempty(mode), mode = 'formal'; end
    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'src'));
    addpath(fullfile(root,'config'));
    addpath(fullfile(root,'experiments'));
    cfg = default_config(root);
    sc = stage4a5_multiscale_confirmation_config(cfg,mode);
    ensure_result_dirs(cfg);
    log_path = fullfile(sc.results_logs,[sc.output_prefix '_run.log']);
    if ~exist(sc.results_logs,'dir'), mkdir(sc.results_logs); end
    diary(log_path);
    cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
    fprintf('Stage 4A.5 run started: %s\n',datestr(now,31));
    fprintf('MATLAB version: %s\n',version);
    fprintf('Entry: run_stage4a5_multiscale_confirmation(%s)\n',mode);
    fprintf('Git HEAD and worktree are recorded by the caller; source hash is computed by the experiment.\n');
    fprintf('Development seeds: %s\n',mat2str(sc.development_seeds));
    fprintf('Final seeds: %s\n',mat2str(sc.final_seeds));
    fprintf('Output prefix: %s\n',sc.output_prefix);
    started = tic;
    out = exp_stage4a5_multiscale_confirmation(cfg,sc);
    out.log_path = log_path;
    fprintf('Stage 4A.5 run exit status: 0\n');
    fprintf('Total runner time: %.3f s\n',toc(started));
end
