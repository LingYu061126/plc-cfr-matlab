function output = run_stage4a2_prior_constrained_matching()
%RUN_STAGE4A2_PRIOR_CONSTRAINED_MATCHING Reproducible Stage-4A.2 entry point.
    root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'src')); addpath(fullfile(root,'config')); addpath(fullfile(root,'experiments'));
    cfg=default_config(root); sc=stage4a2_prior_config(cfg); output=exp_stage4a2_prior_constrained_matching(cfg,sc);
end
