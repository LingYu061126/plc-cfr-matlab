function run_all()
%RUN_ALL Run tests and all PLC CFR experiments from project root.
%   Run this function from MATLAB with the current folder set to the
%   matlab_plc_cfr directory, or call it after addpath(genpath(...)).
    root_dir = fileparts(mfilename('fullpath'));
    addpath(fullfile(root_dir, 'src'));
    addpath(fullfile(root_dir, 'config'));
    addpath(fullfile(root_dir, 'experiments'));
    addpath(fullfile(root_dir, 'tests'));
    % Prefer the installed CJK font for bilingual figure labels when
    % MATLAB's graphics renderer supports it; numerical results do not
    % depend on this display setting.
    try
        set(groot, 'defaultAxesFontName', 'Noto Sans CJK SC');
        set(groot, 'defaultTextFontName', 'Noto Sans CJK SC');
    catch
        % Font selection is cosmetic and must not block numerical runs.
    end
    cfg = default_config(root_dir);
    ensure_result_dirs(cfg);
    if exist('rng', 'file')
        rng(cfg.random_seed, 'twister');
    end
    fprintf('PLC CFR project root: %s\n', root_dir);
    fprintf('Frequency grid: %.3g--%.3g Hz, %d points\n', ...
        cfg.frequency_hz(1), cfg.frequency_hz(end), numel(cfg.frequency_hz));
    run_tests();
    exp01_parameter_sanity(cfg);
    exp02_single_branch(cfg);
    exp03_load_sweep(cfg);
    exp04_loss_factor_comparison(cfg);
    exp05_long_line_literature_case(cfg);
    exp06_frequency_selective_load(cfg);
    exp07_ofdm_channel_estimation(cfg);
    exp08_topology_baseline(cfg);
    exp09_stage2_1_audit(cfg);
    exp10_stage2_2_physical_multiview(cfg);
    exp11_stage2_3_observability(cfg);
    fprintf('All tests and experiments completed.\n');
    fprintf('Figures: %s\nData: %s\n', cfg.results_figures, cfg.results_data);
end
