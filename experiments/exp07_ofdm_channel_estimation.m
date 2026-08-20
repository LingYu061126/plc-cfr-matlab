function exp07_ofdm_channel_estimation(cfg)
%EXP07_OFDM_CHANNEL_ESTIMATION OFDM-equivalent LS CFR/CIR estimation.
%   Experiment A's ideal matching is completed in exp08. This experiment
%   focuses on the measurement chain for one representative topology:
%   X -> H -> Y -> H_hat, plus CFR phase and circular CIR diagnostics.
%   It is a frequency-domain equivalent model, not a complete PLC modem.

    ensure_result_dirs(cfg);
    ocfg = cfg.ofdm;
    pilot = ofdm_generate_pilot(ocfg);
    candidates = topology_candidates(cfg);
    references = topology_reference_cfr(ocfg.pilot_frequency_hz, candidates, cfg);
    representative_index = 2; % T2: one middle branch
    H_true = references(representative_index).reference_H;
    [Y, noise, channel_details] = ofdm_apply_channel( ...
        pilot.X, H_true, Inf, cfg.random_seed + 700);
    [H_hat, estimate_details] = ofdm_channel_estimate_ls(pilot.X, Y);
    [cir, time_s, H_full, cir_details] = ofdm_cfr_to_cir(H_hat, ocfg);
    [cir_true, ~, H_full_true] = ofdm_cfr_to_cir(H_true, ocfg);

    true_mag_db = 20*log10(max(abs(H_true), realmin));
    est_mag_db = 20*log10(max(abs(H_hat), realmin));
    true_phase = unwrap(angle(H_true));
    est_phase = unwrap(angle(H_hat));
    phase_difference = (est_phase-est_phase(1)) - (true_phase-true_phase(1)); %#ok<NASGU>
    estimate_metrics = cfr_estimation_metrics(H_hat, H_true, ...
        struct('mask_threshold_db', -40));
    metrics = struct();
    metrics.nmse_complex = estimate_metrics.nmse;
    metrics.amplitude_rmse_db = estimate_metrics.amplitude_rmse_db;
    metrics.phase_rmse_deg = estimate_metrics.raw_phase_rmse_deg;
    metrics.masked_phase_rmse_deg = estimate_metrics.masked_phase_rmse_deg;
    metrics.weighted_phase_rmse_deg = estimate_metrics.weighted_phase_rmse_deg;
    metrics.valid_phase_fraction = estimate_metrics.valid_phase_fraction;
    metrics.max_complex_error = max(abs(H_hat-H_true));
    metrics.cir_peak_index = find(abs(cir) == max(abs(cir)), 1, 'first') - 1;
    metrics.circular_delay_metric_us = time_s(metrics.cir_peak_index+1)*1e6;
    metrics.cir_peak_toa_us = metrics.circular_delay_metric_us; % legacy field name
    metrics.measurement_count = numel(pilot.X);

    figure('Visible', 'off', 'Position', [100, 100, 1100, 820]);
    subplot(2,2,1);
    plot(ocfg.pilot_frequency_hz/1e6, true_mag_db, 'LineWidth', 1.0); hold on;
    plot(ocfg.pilot_frequency_hz/1e6, est_mag_db, '--', 'LineWidth', 1.0); hold off;
    grid on; xlabel('频率 Frequency (MHz)'); ylabel('幅值 Magnitude (dB)');
    title('OFDM导频LS CFR估计：幅值 / LS CFR magnitude');
    legend('真实 H', '估计 H_{hat}', 'Location', 'best');
    subplot(2,2,2);
    plot(ocfg.pilot_frequency_hz/1e6, true_phase*180/pi, 'LineWidth', 1.0); hold on;
    plot(ocfg.pilot_frequency_hz/1e6, est_phase*180/pi, '--', 'LineWidth', 1.0); hold off;
    grid on; xlabel('频率 Frequency (MHz)'); ylabel('展开相位 Phase (deg)');
    title('OFDM导频LS CFR估计：相位 / LS CFR phase');
    legend('真实 H', '估计 H_{hat}', 'Location', 'best');
    subplot(2,2,3);
    plot(ocfg.pilot_frequency_hz/1e6, abs(H_hat-H_true), ...
        'LineWidth', 1.0);
    grid on; xlabel('频率 Frequency (MHz)'); ylabel('|H_{hat}-H| (linear)');
    title(sprintf('复数CFR误差（线性）/ complex CFR error, NMSE=%.3g', ...
        metrics.nmse_complex));
    subplot(2,2,4);
    plot(time_s*1e6, 20*log10(max(abs(cir), realmin)), 'LineWidth', 1.0); hold on;
    plot(time_s*1e6, 20*log10(max(abs(cir_true), realmin)), '--', 'LineWidth', 1.0); hold off;
    grid on; xlabel('循环时间 Circular time (us)'); ylabel('|CIR| (dB)');
    title(sprintf('循环带限CIR：循环峰 %.3f us / circular peak %.3f us', ...
        metrics.circular_delay_metric_us, metrics.circular_delay_metric_us));
    legend('估计 CIR', '真实 CIR', 'Location', 'best');
    print(gcf, fullfile(cfg.results_figures, ...
        'exp07_ofdm_channel_estimation.png'), '-dpng', '-r150');
    close(gcf);

    write_complex_csv(fullfile(cfg.results_data, ...
        'exp07_ofdm_channel_estimation.csv'), ocfg.pilot_frequency_hz, ...
        pilot.X, H_true, Y, H_hat);
    save(fullfile(cfg.results_data, 'exp07_ofdm_channel_estimation.mat'), ...
        'ocfg', 'pilot', 'candidates', 'representative_index', 'H_true', ...
        'Y', 'noise', 'H_hat', 'H_full', 'H_full_true', 'cir', 'cir_true', ...
        'time_s', 'channel_details', 'estimate_details', 'cir_details', ...
        'estimate_metrics', 'metrics');
end

function write_complex_csv(filename, f_hz, X, H_true, Y, H_hat)
    fid = fopen(filename, 'w');
    if fid < 0, error('exp07:OpenFailed', 'Cannot open %s.', filename); end
    H_true_mag_db = 20*log10(max(abs(H_true), realmin));
    H_hat_mag_db = 20*log10(max(abs(H_hat), realmin));
    H_true_phase_deg = unwrap(angle(H_true))*180/pi;
    H_hat_phase_deg = unwrap(angle(H_hat))*180/pi;
    fprintf(fid, ['frequency_hz,X_real,X_imag,H_true_real,H_true_imag,' ...
        'H_true_mag_db,H_true_phase_unwrapped_deg,Y_real,Y_imag,' ...
        'H_hat_real,H_hat_imag,H_hat_mag_db,H_hat_phase_unwrapped_deg\n']);
    for k = 1:numel(f_hz)
        fprintf(fid, '%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g\n', ...
            f_hz(k), real(X(k)), imag(X(k)), real(H_true(k)), imag(H_true(k)), ...
            H_true_mag_db(k), H_true_phase_deg(k), real(Y(k)), imag(Y(k)), ...
            real(H_hat(k)), imag(H_hat(k)), H_hat_mag_db(k), H_hat_phase_deg(k));
    end
    fclose(fid);
end
