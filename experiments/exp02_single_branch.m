function exp02_single_branch(cfg)
%EXP02_SINGLE_BRANCH Compare one branch with the no-branch baseline.
    ensure_result_dirs(cfg);
    f = cfg.frequency_hz;
    branch_net = cfg.default_network;
    base_net = branch_net;
    base_net.branches = struct('node', {}, 'length', {}, 'cable_type', {}, 'load', {});
    series = struct('name', {}, 'H_V', {}, 'H_port', {});
    figure('Visible', 'off', 'Position', [100, 100, 1200, 760]);
    kg_values = [1, 5];
    for p = 1:2
        local_cfg = cfg;
        local_cfg.kG = kg_values(p);
        [Hb, ~] = cascade_network(f, branch_net, local_cfg);
        [H0, ~] = cascade_network(f, base_net, local_cfg);
        series(end+1) = struct('name', sprintf('branch_kG%d', local_cfg.kG), ...
            'H_V', Hb.H_V, 'H_port', Hb.H_port); %#ok<AGROW>
        series(end+1) = struct('name', sprintf('baseline_kG%d', local_cfg.kG), ...
            'H_V', H0.H_V, 'H_port', H0.H_port); %#ok<AGROW>
        subplot(2,2,2*p-1);
        plot(f/1e6, 20*log10(abs(Hb.H_port)), 'LineWidth', 1.1); hold on;
        plot(f/1e6, 20*log10(abs(H0.H_port)), '--', 'LineWidth', 1.0); hold off;
        grid on; ylabel('|H_{port}| (dB)');
        if p == 2, xlabel('频率 Frequency (MHz)'); end
        title(sprintf('幅值 Magnitude, k_G = %d', local_cfg.kG));
        legend('单分支 branch', '无支路 baseline', 'Location', 'best');
        subplot(2,2,2*p);
        plot(f/1e6, unwrap(angle(Hb.H_port))*180/pi, 'LineWidth', 1.1); hold on;
        plot(f/1e6, unwrap(angle(H0.H_port))*180/pi, '--', 'LineWidth', 1.0); hold off;
        grid on; ylabel('展开相位 Unwrapped phase (deg)');
        if p == 2, xlabel('频率 Frequency (MHz)'); end
        title(sprintf('相位 Phase, k_G = %d', local_cfg.kG));
        legend('单分支 branch', '无支路 baseline', 'Location', 'best');
    end
    print(gcf, fullfile(cfg.results_figures, 'exp02_single_branch.png'), '-dpng', '-r150');
    close(gcf);
    save_cfr_data(fullfile(cfg.results_data, 'exp02_single_branch'), f, series);
end
