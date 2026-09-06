function out=run_stage4a6_parameter_domain_diagnostic(mode)
%RUN_STAGE4A6_PARAMETER_DOMAIN_DIAGNOSTIC Run Stage 4A.6.
    if nargin<1,mode='formal';end;root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'),fullfile(root,'tests'));cfg=default_config(root);sc=stage4a6_parameter_domain_config(cfg,mode);ensure_result_dirs(cfg);log=fullfile(sc.results_logs,[sc.output_prefix '_run.log']);diary(log);c=onCleanup(@()diary('off')); %#ok<NASGU>
    fprintf('Stage 4A.6 started: %s\nMATLAB version: %s\nEntry: run_stage4a6_parameter_domain_diagnostic(%s)\nDevelopment seeds: %s\nFinal seeds: %s\n',datestr(now,31),version,mode,mat2str(sc.development_seeds),mat2str(sc.final_seeds));t=tic;out=exp_stage4a6_parameter_domain_diagnostic(cfg,sc);out.log_path=log;fprintf('Exit status: 0\nTotal runner time: %.3f s\n',toc(t));
end
