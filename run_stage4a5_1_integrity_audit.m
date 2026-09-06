function out=run_stage4a5_1_integrity_audit(mode)
%RUN_STAGE4A5_1_INTEGRITY_AUDIT Run collision/cache/resampling correction.
    if nargin<1,mode='formal';end;root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'),fullfile(root,'tests'));
    cfg=default_config(root);sc=stage4a5_1_integrity_config(cfg,mode);ensure_result_dirs(cfg);log_path=fullfile(sc.results_logs,[sc.output_prefix '_run.log']);diary(log_path);c=onCleanup(@()diary('off')); %#ok<NASGU>
    fprintf('Stage 4A.5.1 started: %s\nMATLAB version: %s\nEntry: run_stage4a5_1_integrity_audit(%s)\n',datestr(now,31),version,mode);t=tic;out=exp_stage4a5_1_integrity_audit(cfg,sc);out.log_path=log_path;fprintf('Exit status: 0\nTotal runner time: %.3f s\n',toc(t));
end
