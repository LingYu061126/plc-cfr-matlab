function exp06_frequency_selective_load(cfg)
%EXP06_FREQUENCY_SELECTIVE_LOAD Demonstrate Cañete's parallel-RLC load.
%   R=500 ohm, Q=5 and f0=15 MHz are literature-model simulation
%   parameters, not measured parameters of a field appliance.
    ensure_result_dirs(cfg);
    f = cfg.frequency_hz;
    R = 500;
    Q = 5;
    f0 = 15e6;
    Zrlc = parallel_rlc_load(f, R, Q, f0);
    net_constant = cfg.default_network;
    net_constant.branches.load = R;
    net_rlc = cfg.default_network;
    net_rlc.branches.load = Zrlc;
    [Hconstant, ~] = cascade_network_stable(f, net_constant, cfg);
    [Hrlc, details] = cascade_network_stable(f, net_rlc, cfg);
    series(1) = struct('name', 'constant_R500', ...
        'H_V', Hconstant.H_V, 'H_port', Hconstant.H_port);
    series(2) = struct('name', 'Canete_parallel_RLC_R500_Q5_f015MHz', ...
        'H_V', Hrlc.H_V, 'H_port', Hrlc.H_port);

    figure('Visible', 'off', 'Position', [100, 100, 1000, 760]);
    subplot(2,1,1);
    plot(f/1e6, 20*log10(abs(Hconstant.H_port)), '--', 'LineWidth', 1.0); hold on;
    plot(f/1e6, 20*log10(abs(Hrlc.H_port)), 'LineWidth', 1.1); hold off;
    grid on; ylabel('|H_{port}| (dB)');
    title('频率选择性支路负载 / Cañete parallel-RLC simulation load');
    legend('恒定500 \Omega', '并联RLC模型 R=500 \Omega, Q=5, f_0=15 MHz', ...
        'Location', 'best');
    subplot(2,1,2);
    plot(f/1e6, unwrap(angle(Hconstant.H_port))*180/pi, '--', 'LineWidth', 1.0); hold on;
    plot(f/1e6, unwrap(angle(Hrlc.H_port))*180/pi, 'LineWidth', 1.1); hold off;
    grid on; xlabel('频率 Frequency (MHz)');
    ylabel('展开相位 Unwrapped phase (deg)');
    legend('恒定500 \Omega', '并联RLC文献模型', 'Location', 'best');
    print(gcf, fullfile(cfg.results_figures, ...
        'exp06_frequency_selective_load.png'), '-dpng', '-r150');
    close(gcf);

    save_cfr_data(fullfile(cfg.results_data, ...
        'exp06_frequency_selective_load'), f, series);
    branch_input_impedance_ohm = details.branch_zin{1}; %#ok<NASGU>
    save(fullfile(cfg.results_data, 'exp06_frequency_selective_load_impedance.mat'), ...
        'f', 'R', 'Q', 'f0', 'Zrlc', 'branch_input_impedance_ohm');
end
