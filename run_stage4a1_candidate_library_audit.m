function output = run_stage4a1_candidate_library_audit()
%RUN_STAGE4A1_CANDIDATE_LIBRARY_AUDIT Run regression tests and Stage 4A.1.
    root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));
    addpath(fullfile(root,'experiments'));addpath(fullfile(root,'tests'));
    cfg=default_config(root);rng(cfg.random_seed,'twister');run_tests();
    output=exp12_stage4a1_candidate_library_audit(cfg,stage4a1_config(cfg));
end
