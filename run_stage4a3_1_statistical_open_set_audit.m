function out = run_stage4a3_1_statistical_open_set_audit(mode)
%RUN_STAGE4A3_1_STATISTICAL_OPEN_SET_AUDIT Logged Stage-4A.3.1 entry point.

    if nargin < 1 || isempty(mode), mode = 'formal'; end
    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'src'));
    addpath(fullfile(root, 'config'));
    addpath(fullfile(root, 'experiments'));
    cfg = default_config(root);
    if ~isfield(cfg, 'results_logs')
        cfg.results_logs = fullfile(root, 'results', 'logs');
    end
    sc = stage4a3_1_statistical_config(cfg, mode);
    if strcmp(sc.mode, 'formal')
        log_name = 'stage4a3_1_formal_run.log';
    else
        log_name = 'stage4a3_1_smoke_run.log';
    end
    log_file = fullfile(cfg.results_logs, log_name);
    if ~exist(cfg.results_logs, 'dir'), mkdir(cfg.results_logs); end
    diary('off');
    fid = fopen(log_file, 'w');
    if fid < 0, error('run_stage4a3_1:LogOpenFailed', 'Cannot initialize log file %s.', log_file); end
    fclose(fid);
    diary(log_file);
    cleanup = onCleanup(@()diary('off')); %#ok<NASGU>
    fprintf('MATLAB version: %s\n', version);
    fprintf('Stage 4A.3.1 mode: %s\n', sc.mode);
    fprintf('Run entry: run_stage4a3_1_statistical_open_set_audit(%s)\n', sc.mode);
    fprintf('Log file: %s\n', log_file);
    [status, git_head] = system(sprintf('git -C "%s" rev-parse HEAD', root));
    fprintf('Git HEAD status=%d, commit=%s\n', status, strtrim(git_head));
    fprintf('Calibration seed=%d, test seed=%d, per-graph calibration=%d, per-graph test=%d\n', ...
        sc.calibration_seed, sc.test_seed, sc.per_graph_calibration, sc.per_graph_test);
    out = exp_stage4a3_1_statistical_open_set_audit(cfg, sc);
    fprintf('Exit status: 0\n');
    fprintf('Generated result prefix: %s\n', sc.output_prefix);
end
