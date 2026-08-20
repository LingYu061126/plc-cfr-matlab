function run_stage2_3(run_mode)
%RUN_STAGE2_3 Run all regression tests then the stage-2.3 audit.
    if nargin < 1 || isempty(run_mode), run_mode='formal'; end
    root=fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));
    addpath(fullfile(root,'experiments'));addpath(fullfile(root,'tests'));
    cfg=default_config(root);ensure_result_dirs(cfg);rng(cfg.random_seed,'twister');
    run_tests();
    batch_count=1;if strcmpi(run_mode,'formal'),batch_count=2;end
    trials_per_batch=cfg.stage2_3.formal_trials/batch_count;
    for k=1:numel(cfg.stage2_3.measurement_kinds)
        for b=1:batch_count
            local_cfg=cfg;kind=cfg.stage2_3.measurement_kinds{k};
            local_cfg.stage2_3.measurement_kinds={kind};
            local_cfg.stage2_3.formal_trials=trials_per_batch;
            local_cfg.stage2_3.trial_offset=(b-1)*trials_per_batch;
            local_cfg.stage2_3.output_prefix=sprintf('stage2_3_partial_%s_b%d',kind,b);
            exp11_stage2_3_observability(local_cfg,run_mode);
        end
    end
    compile_stage2_3_results(cfg);
end
