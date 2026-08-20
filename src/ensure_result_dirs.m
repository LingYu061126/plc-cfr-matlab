function ensure_result_dirs(cfg)
%ENSURE_RESULT_DIRS Create the configured result directories if absent.
    if ~exist(cfg.results_figures, 'dir'), mkdir(cfg.results_figures); end
    if ~exist(cfg.results_data, 'dir'), mkdir(cfg.results_data); end
end
