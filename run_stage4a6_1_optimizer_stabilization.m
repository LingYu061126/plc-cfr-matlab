function out=run_stage4a6_1_optimizer_stabilization(mode)
%RUN_STAGE4A6_1_OPTIMIZER_STABILIZATION Run the isolated Stage 4A.6.1 audit.
    if nargin<1,mode='development';end
    root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    cfg=default_config(root);sc=stage4a6_1_optimizer_config(cfg,mode);if ~exist(sc.results_logs,'dir'),mkdir(sc.results_logs);end
    log=fullfile(sc.results_logs,[sc.output_prefix '_run.log']);
    if exist(log,'file'),delete(log);end
    diary(log);cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
    fprintf('Stage 4A.6.1 started: %s\nMATLAB version: %s\nEntry: run_stage4a6_1_optimizer_stabilization(%s)\nDevelopment seeds: %s\nFinal seeds: %s\n',datestr(now,31),version,mode,mat2str(sc.development_seeds),mat2str(sc.final_seeds));t=tic;out=exp_stage4a6_1_optimizer_stabilization(cfg,sc);out.log_path=log;fprintf('Exit status: 0\nTotal runner time: %.3f s\n',toc(t));
end
