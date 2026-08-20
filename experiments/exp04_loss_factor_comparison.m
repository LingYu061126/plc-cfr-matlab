function exp04_loss_factor_comparison(cfg)
%EXP04_LOSS_FACTOR_COMPARISON Compare ideal, kG=1 and kG=5 networks.
    ensure_result_dirs(cfg);
    f = cfg.frequency_hz;
    series = struct('name', {}, 'H_V', {}, 'H_port', {});
    settings = [0, 1, 5];
    labels = {'ideal_R0G0', 'lossy_kG1', 'lossy_kG5'};
    figure('Visible', 'off');
    for k = 1:3
        local_cfg = cfg;
        if settings(k) == 0
            local_cfg.lossless = true; local_cfg.kG = 0;
        else
            local_cfg.lossless = false; local_cfg.kG = settings(k);
        end
        net = cfg.default_network;
        [H, ~] = cascade_network(f, net, local_cfg);
        series(k) = struct('name', labels{k}, 'H_V', H.H_V, 'H_port', H.H_port);
    end
    subplot(2,1,1);
    plot(f/1e6, 20*log10(abs(series(1).H_port)), 'LineWidth', 1.0); hold on;
    plot(f/1e6, 20*log10(abs(series(2).H_port)), '--', 'LineWidth', 1.0);
    plot(f/1e6, 20*log10(abs(series(3).H_port)), '-.', 'LineWidth', 1.0); hold off;
    grid on; ylabel('|H_{port}| (dB)');
    title('实验四 损耗因子比较：幅值 / loss-factor comparison');
    legend('理想 R=G=0', '正常 k_G=1', '经验修正 k_G=5', 'Location', 'best');
    subplot(2,1,2);
    plot(f/1e6, unwrap(angle(series(1).H_port))*180/pi, 'LineWidth', 1.0); hold on;
    plot(f/1e6, unwrap(angle(series(2).H_port))*180/pi, '--', 'LineWidth', 1.0);
    plot(f/1e6, unwrap(angle(series(3).H_port))*180/pi, '-.', 'LineWidth', 1.0); hold off;
    grid on; xlabel('频率 Frequency (MHz)'); ylabel('展开相位 Unwrapped phase (deg)');
    print(gcf, fullfile(cfg.results_figures, 'exp04_loss_factor_comparison.png'), '-dpng', '-r150');
    close(gcf);
    save_cfr_data(fullfile(cfg.results_data, 'exp04_loss_factor_comparison'), f, series);
end
