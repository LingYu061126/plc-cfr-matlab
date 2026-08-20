function exp05_long_line_literature_case(cfg)
%EXP05_LONG_LINE_LITERATURE_CASE Stable long-line extrapolation and audit.
%   Official CFR curves use backward impedance/voltage recursion. Legacy
%   ABCD results are retained only for comparison and determinant audit.
%   All cases are outside Cañete's typical 0.5--50 m section range.
    ensure_result_dirs(cfg);
    f = cfg.frequency_hz;
    lengths = [300, 500, 800, 1200];
    kg_values = [1, 5];
    series = struct('name', {}, 'H_V', {}, 'H_port', {});
    diagnostic_template = struct('length_m', [], 'kG', [], ...
        'det_max', [], 'det_median', [], 'det_worst_frequency_hz', [], ...
        'legacy_abcd_reliable', [], 'cfr_relative_error_max', [], ...
        'stable_finite', [], 'stable_input_min_real_ohm', [], ...
        'stable_magnitude_min_db', [], 'stable_magnitude_max_db', [], ...
        'below_reference_floor_fraction', []);
    diagnostics = repmat(diagnostic_template, numel(kg_values), numel(lengths));
    figure('Visible', 'off', 'Position', [100, 100, 1000, 760]);
    fid = fopen(fullfile(cfg.results_data, 'exp05_long_line_summary.txt'), 'w');
    if fid < 0, error('exp05:OpenFailed', 'Cannot open long-line summary.'); end
    fprintf(fid, '实验五：文献参数外推；正式CFR采用稳定阻抗/电压比递推，原ABCD仅作诊断对照。\n');
    fprintf(fid, 'Cañete典型线段校准范围0.5--50m；全部300--1200m场景均超范围。\n');
    fprintf(fid, '参考测量门限 %.1f dB 仅用于报告低于门限的频点比例，不代表已知硬件动态范围。\n', ...
        cfg.measurement_floor_reference_db);

    for p = 1:numel(kg_values)
        local_cfg = cfg;
        local_cfg.kG = kg_values(p);
        local_cfg.suppress_abcd_warning = true;
        subplot(2,1,p); hold on;
        for k = 1:numel(lengths)
            net = struct('main_lengths', [lengths(k)/2, lengths(k)/2], ...
                'main_cable_type', [0, 0], ...
                'branches', struct('node', 1, 'length', 50, ...
                'cable_type', 1, 'load', 50));
            [Hstable, stable_details] = cascade_network_stable(f, net, local_cfg);
            [Hlegacy, ~, legacy_details] = cascade_network(f, net, local_cfg);
            stable_name = sprintf('stable_L%d_kG%d', lengths(k), local_cfg.kG);
            legacy_name = sprintf('legacyABCD_L%d_kG%d', lengths(k), local_cfg.kG);
            series(end+1) = struct('name', stable_name, ...
                'H_V', Hstable.H_V, 'H_port', Hstable.H_port); %#ok<AGROW>
            series(end+1) = struct('name', legacy_name, ...
                'H_V', Hlegacy.H_V, 'H_port', Hlegacy.H_port); %#ok<AGROW>

            scale = max(abs(Hstable.H_port), realmin);
            relative_error = abs(Hlegacy.H_port-Hstable.H_port) ./ scale;
            magnitude_db = 20*log10(abs(Hstable.H_port));
            d = struct();
            d.length_m = lengths(k);
            d.kG = local_cfg.kG;
            d.det_max = legacy_details.determinant_error_max;
            d.det_median = legacy_details.determinant_error_median;
            d.det_worst_frequency_hz = legacy_details.determinant_worst_frequency_hz;
            d.legacy_abcd_reliable = legacy_details.abcd_reliable;
            d.cfr_relative_error_max = max(relative_error);
            d.stable_finite = all(isfinite(Hstable.H_port));
            d.stable_input_min_real_ohm = min(real(stable_details.input_impedance));
            d.stable_magnitude_min_db = min(magnitude_db);
            d.stable_magnitude_max_db = max(magnitude_db);
            d.below_reference_floor_fraction = mean( ...
                magnitude_db < cfg.measurement_floor_reference_db);
            diagnostics(p,k) = d;
            fprintf(fid, ['L=%dm kG=%d det_max=%.17g det_median=%.17g ' ...
                'det_worst_MHz=%.17g legacy_ABCD_reliable=%d ' ...
                'CFR_relerr_max=%.17g stable_finite=%d minReZin=%.17g ' ...
                'stable_dB_min=%.17g stable_dB_max=%.17g below_floor_fraction=%.17g\n'], ...
                d.length_m, d.kG, d.det_max, d.det_median, ...
                d.det_worst_frequency_hz/1e6, d.legacy_abcd_reliable, ...
                d.cfr_relative_error_max, d.stable_finite, ...
                d.stable_input_min_real_ohm, d.stable_magnitude_min_db, ...
                d.stable_magnitude_max_db, d.below_reference_floor_fraction);
            plot(f/1e6, magnitude_db, 'LineWidth', 1.0);
        end
        hold off; grid on; ylabel('|H_{port}| (dB)');
        if p == 2, xlabel('频率 Frequency (MHz)'); end
        title(sprintf(['实验五 稳定递推正式结果 / stable long-line ' ...
            'extrapolation, k_G=%d'], local_cfg.kG));
        legend('300 m', '500 m', '800 m', '1200 m', 'Location', 'best');
    end
    fclose(fid);
    print(gcf, fullfile(cfg.results_figures, ...
        'exp05_long_line_literature_case.png'), '-dpng', '-r150');
    close(gcf);

    figure('Visible', 'off', 'Position', [100, 100, 1000, 760]);
    subplot(2,1,1);
    for p = 1:numel(kg_values)
        values = arrayfun(@(x) x.det_max, diagnostics(p,:));
        semilogy(lengths, values, '-o', 'LineWidth', 1.1); hold on;
    end
    yline(cfg.abcd_det_warning_threshold, '--k', 'ABCD reliability threshold');
    hold off; grid on; ylabel('max |AD-BC-1|');
    title('原ABCD长线行列式残差 / legacy ABCD determinant residual');
    legend('k_G=1', 'k_G=5', 'Location', 'northwest');
    subplot(2,1,2);
    for p = 1:numel(kg_values)
        values = arrayfun(@(x) x.cfr_relative_error_max, diagnostics(p,:));
        semilogy(lengths, values, '-o', 'LineWidth', 1.1); hold on;
    end
    hold off; grid on; xlabel('主线长度 Main-line length (m)');
    ylabel('max relative CFR difference');
    title('原ABCD与稳定递推CFR差异 / legacy versus stable CFR');
    legend('k_G=1', 'k_G=5', 'Location', 'best');
    print(gcf, fullfile(cfg.results_figures, ...
        'exp05_long_line_stability_diagnostics.png'), '-dpng', '-r150');
    close(gcf);

    save_cfr_data(fullfile(cfg.results_data, ...
        'exp05_long_line_literature_case'), f, series);
    save(fullfile(cfg.results_data, 'exp05_long_line_diagnostics.mat'), ...
        'f', 'lengths', 'kg_values', 'diagnostics');
end
