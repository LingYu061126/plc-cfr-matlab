function exp03_load_sweep(cfg)
%EXP03_LOAD_SWEEP Compare the prescribed branch loads.
    ensure_result_dirs(cfg);
    f = cfg.frequency_hz;
    loads = [5, 50, 150, 1000, Inf];
    names = {'load5', 'load50', 'load150', 'load1000', 'loadInf'};
    series = struct('name', {}, 'H_V', {}, 'H_port', {});
    figure('Visible', 'off'); hold on;
    styles = {'-', '--', '-.', ':', '-'};
    for k = 1:numel(loads)
        net = cfg.default_network;
        net.branches.load = loads(k);
        [H, ~] = cascade_network(f, net, cfg);
        series(k) = struct('name', names{k}, 'H_V', H.H_V, 'H_port', H.H_port);
        plot(f/1e6, 20*log10(abs(H.H_port)), styles{k}, 'LineWidth', 1.0);
    end
    hold off; grid on; xlabel('频率 Frequency (MHz)'); ylabel('|H_{port}| (dB)');
    title('实验三 支路负载扫描 / branch-load sweep (H_{port})');
    legend('5 \Omega', '50 \Omega', '150 \Omega', '1000 \Omega', '\infty', 'Location', 'best');
    print(gcf, fullfile(cfg.results_figures, 'exp03_load_sweep.png'), '-dpng', '-r150');
    close(gcf);
    save_cfr_data(fullfile(cfg.results_data, 'exp03_load_sweep'), f, series);
end
