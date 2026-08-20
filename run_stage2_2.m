function run_stage2_2()
%RUN_STAGE2_2 Run regression tests and the stage-2.2 experiment only.
    root=fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));
    addpath(fullfile(root,'experiments'));addpath(fullfile(root,'tests'));
    cfg=default_config(root);ensure_result_dirs(cfg);rng(cfg.random_seed,'twister');
    run_tests();exp10_stage2_2_physical_multiview(cfg);
end
