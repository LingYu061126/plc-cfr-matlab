function exp08_topology_baseline(cfg)
%EXP08_TOPOLOGY_BASELINE Explainable nearest-reference topology baseline.
%   Experiments A-E use stable stage-1.5 CFR references, LS pilot estimates,
%   normalized amplitude/phase/complex/CIR features, and nearest-neighbor
%   matching. No machine learning, waveform optimization, or fault locating
%   is used. All perturbation magnitudes are simulation assumptions pending
%   confirmation against a real communication waveform and measurements.

    ensure_result_dirs(cfg);
    tic_total = tic;
    ocfg = cfg.ofdm;
    f_hz = ocfg.pilot_frequency_hz;
    pilot = ofdm_generate_pilot(ocfg);
    candidates = topology_candidates(cfg);
    references = topology_reference_cfr(f_hz, candidates, cfg);
    features = {'amplitude', 'phase', 'complex', 'cir', 'amp_phase_joint'};
    feature_labels = {'CFR幅值', 'CFR相位', '复数CFR', 'CIR', '幅相联合'};
    nfeature = numel(features);
    ntopology = numel(references);
    weights = cfg.stage2.joint_distance_weights;

    % Experiment A: direct ideal CFR matching and class-interdistance.
    ideal_observed = cell(1, ntopology);
    ideal_true = 1:ntopology;
    for k = 1:ntopology, ideal_observed{k} = references(k).reference_H; end
    [ideal_pred, ideal_eval] = classify_many(ideal_observed, ideal_true, ...
        references, features, ocfg, weights);
    ideal_pairwise = pairwise_distances(references, features, ocfg, weights);

    % Experiment B: no-noise OFDM pilot estimate matching.
    noiseless_observed = cell(1, ntopology);
    for k = 1:ntopology
        [Y, ~] = ofdm_apply_channel(pilot.X, references(k).reference_H, Inf, ...
            cfg.random_seed + 1000 + k);
        [noiseless_observed{k}, ~] = ofdm_channel_estimate_ls(pilot.X, Y);
    end
    [noiseless_pred, noiseless_eval] = classify_many(noiseless_observed, ...
        ideal_true, references, features, ocfg, weights);

    % Experiment C: AWGN SNR robustness.
    snr_values = cfg.stage2.snr_db(:).';
    nsnr = numel(snr_values);
    snr_accuracy = zeros(nsnr, nfeature);
    snr_group_accuracy = zeros(nsnr, nfeature);
    snr_ambiguous_rate = zeros(nsnr, nfeature);
    snr_estimation = zeros(nsnr, 3); % NMSE, magnitude RMSE dB, phase RMSE deg
    snr_edge_micro = zeros(nsnr, nfeature, 3);
    snr_eval = cell(nsnr, nfeature);
    snr_confusion = zeros(ntopology, ntopology, nfeature, nsnr);
    snr_measurement_count = zeros(1, nsnr);
    for s = 1:nsnr
        nobs = ntopology * cfg.stage2.monte_carlo_trials;
        observations = cell(1, nobs);
        true_indices = zeros(1, nobs);
        cursor = 0;
        for t = 1:ntopology
            for trial = 1:cfg.stage2.monte_carlo_trials
                cursor = cursor + 1;
                seed = cfg.random_seed + 100000*s + 1000*t + trial;
                [Y, ~] = ofdm_apply_channel(pilot.X, references(t).reference_H, ...
                    snr_values(s), seed);
                [observations{cursor}, ~] = ofdm_channel_estimate_ls(pilot.X, Y);
                estimation = estimation_error_metrics(observations{cursor}, ...
                    references(t).reference_H);
                snr_estimation(s,1) = snr_estimation(s,1) + estimation.nmse;
                snr_estimation(s,2) = snr_estimation(s,2) + estimation.amplitude_rmse_db;
                snr_estimation(s,3) = snr_estimation(s,3) + estimation.phase_rmse_deg;
                true_indices(cursor) = t;
            end
        end
        snr_measurement_count(s) = nobs;
        snr_estimation(s,:) = snr_estimation(s,:) / nobs;
        [~, current_eval] = classify_many(observations, true_indices, ...
            references, features, ocfg, weights);
        for j = 1:nfeature
            snr_eval{s,j} = current_eval{j};
            snr_accuracy(s,j) = current_eval{j}.accuracy;
            snr_group_accuracy(s,j) = current_eval{j}.group_accuracy;
            snr_ambiguous_rate(s,j) = current_eval{j}.ambiguous_rate;
            snr_confusion(:,:,j,s) = current_eval{j}.confusion_matrix;
            snr_edge_micro(s,j,1) = current_eval{j}.edge_micro.precision;
            snr_edge_micro(s,j,2) = current_eval{j}.edge_micro.recall;
            snr_edge_micro(s,j,3) = current_eval{j}.edge_micro.f1;
        end
    end

    % Experiment D: load-only variation. The topology is held fixed while
    % scalar loads or the literature-model RLC load are changed.
    load_scales = cfg.stage2.load_scales(:).';
    load_names = {'load_-20pct', 'load_-10pct', 'load_+10pct', ...
        'load_+20pct', 'parallel_RLC_model'};
    nload = numel(load_names);
    load_accuracy_all = zeros(nload, nfeature);
    load_accuracy_branch = zeros(nload, nfeature);
    load_intra = NaN(nload, nfeature);
    load_inter = NaN(nload, nfeature);
    load_eval_all = cell(nload, nfeature);
    load_eval_branch = cell(nload, nfeature);
    load_observed = cell(nload*ntopology, 1);
    load_true = zeros(1, nload*ntopology);
    load_applicable = false(1, nload*ntopology);
    cursor = 0;
    for c = 1:nload
        for t = 1:ntopology
            cursor = cursor + 1;
            net = candidates(t).network;
            applicable = ~isempty(net.branches);
            if c <= numel(load_scales)
                if applicable
                    for b = 1:numel(net.branches)
                        net.branches(b).load = cfg.topology.branch_load_ohm * load_scales(c);
                    end
                end
            elseif applicable
                Zrlc = parallel_rlc_load(f_hz, cfg.topology.branch_load_ohm, 5, 15e6);
                for b = 1:numel(net.branches), net.branches(b).load = Zrlc; end
            end
            [H, ~] = cascade_network_stable(f_hz, net, cfg);
            load_observed{cursor} = H.H_port;
            load_true(cursor) = t;
            load_applicable(cursor) = applicable;
        end
    end
    for c = 1:nload
        range = (c-1)*ntopology + (1:ntopology);
        branch_range = range(load_applicable(range));
        [~, load_eval_all_current] = classify_many(load_observed(range), ...
            load_true(range), references, features, ocfg, weights);
        for j = 1:nfeature
            load_eval_all{c,j} = load_eval_all_current{j};
            load_accuracy_all(c,j) = load_eval_all_current{j}.accuracy;
            if ~isempty(branch_range)
                [~, branch_eval] = classify_many(load_observed(branch_range), ...
                    load_true(branch_range), references, features(j), ocfg, weights);
                load_eval_branch{c,j} = branch_eval{1};
                load_accuracy_branch(c,j) = branch_eval{1}.accuracy;
                [load_intra(c,j), load_inter(c,j)] = mean_intra_inter( ...
                    load_observed(branch_range), load_true(branch_range), ...
                    references, features{j}, ocfg, weights);
            end
        end
    end

    % Experiment E: line-length and kG perturbations with nominal references.
    parameter_names = {'length_-5pct', 'length_-2pct', 'length_+2pct', ...
        'length_+5pct', 'kG_-5pct', 'kG_+5pct'};
    parameter_kind = {'length', 'length', 'length', 'length', 'kG', 'kG'};
    parameter_scale = [cfg.stage2.length_scales(:).', cfg.stage2.loss_scales(:).'];
    nparameter = numel(parameter_names);
    parameter_accuracy = zeros(nparameter, nfeature);
    parameter_intra = zeros(nparameter, nfeature);
    parameter_inter = zeros(nparameter, nfeature);
    parameter_eval = cell(nparameter, nfeature);
    parameter_observed = cell(nparameter*ntopology, 1);
    parameter_true = zeros(1, nparameter*ntopology);
    cursor = 0;
    for c = 1:nparameter
        for t = 1:ntopology
            cursor = cursor + 1;
            local_cfg = cfg;
            net = candidates(t).network;
            if strcmp(parameter_kind{c}, 'length')
                net.main_lengths = net.main_lengths * parameter_scale(c);
                for b = 1:numel(net.branches)
                    net.branches(b).length = net.branches(b).length * parameter_scale(c);
                end
            else
                local_cfg.kG = cfg.kG * parameter_scale(c);
            end
            [H, ~] = cascade_network_stable(f_hz, net, local_cfg);
            parameter_observed{cursor} = H.H_port;
            parameter_true(cursor) = t;
        end
    end
    for c = 1:nparameter
        range = (c-1)*ntopology + (1:ntopology);
        [~, parameter_eval_current] = classify_many(parameter_observed(range), ...
            parameter_true(range), references, features, ocfg, weights);
        for j = 1:nfeature
            parameter_eval{c,j} = parameter_eval_current{j};
            parameter_accuracy(c,j) = parameter_eval_current{j}.accuracy;
            [parameter_intra(c,j), parameter_inter(c,j)] = mean_intra_inter( ...
                parameter_observed(range), parameter_true(range), references, ...
                features{j}, ocfg, weights);
        end
    end

    % Console summary is deliberately explicit about recognition versus
    % channel-estimation measurements.
    fprintf('EXP08 topology baseline: %d candidates, %d pilot bins\n', ...
        ntopology, ocfg.num_pilots);
    fprintf('  Experiment A ideal accuracy by feature:');
    for j = 1:nfeature
        fprintf(' %s=%.3f(group %.3f)', features{j}, ideal_eval{j}.accuracy, ...
            ideal_eval{j}.group_accuracy);
    end
    fprintf('\n');
    for s = 1:nsnr
        fprintf('  SNR=%g dB joint accuracy=%.3f edge F1=%.3f (%d measurements)\n', ...
            snr_values(s), snr_accuracy(s,5), snr_edge_micro(s,5,3), ...
            snr_measurement_count(s));
        fprintf('    group accuracy=%.3f ambiguous rate=%.3f\n', ...
            snr_group_accuracy(s,5), snr_ambiguous_rate(s,5));
        fprintf('    CFR estimate NMSE=%.5g amplitude RMSE=%.5g dB phase RMSE=%.5g deg\n', ...
            snr_estimation(s,1), snr_estimation(s,2), snr_estimation(s,3));
    end
    fprintf('  Load robustness: joint branch-only accuracy [');
    fprintf('%.3f ', load_accuracy_branch(:,5)); fprintf(']\n');
    fprintf('  Parameter robustness: joint accuracy [');
    fprintf('%.3f ', parameter_accuracy(:,5)); fprintf(']\n');

    % Figures: ideal class distances, SNR accuracy/confusion, and robustness.
    plot_pairwise_distances(ideal_pairwise, references, features, cfg);
    plot_snr_accuracy(snr_values, snr_accuracy, feature_labels, cfg);
    plot_snr_confusion(snr_confusion, snr_values, references, cfg);
    plot_robustness(load_names, load_intra, load_inter, parameter_names, ...
        parameter_intra, parameter_inter, cfg);

    write_ideal_csv(fullfile(cfg.results_data, ...
        'exp08_ideal_topology_matching.csv'), features, ideal_eval);
    write_snr_csv(fullfile(cfg.results_data, 'exp08_snr_summary.csv'), ...
        snr_values, features, snr_accuracy, snr_group_accuracy, ...
        snr_ambiguous_rate, snr_edge_micro, snr_estimation);
    write_robustness_csv(fullfile(cfg.results_data, 'exp08_load_summary.csv'), ...
        load_names, features, load_accuracy_all, load_accuracy_branch, ...
        load_intra, load_inter);
    write_robustness_csv(fullfile(cfg.results_data, ...
        'exp08_parameter_summary.csv'), parameter_names, features, ...
        parameter_accuracy, parameter_accuracy, parameter_intra, parameter_inter);
    write_edge_summary_csv(fullfile(cfg.results_data, ...
        'exp08_edge_metrics.csv'), features, ideal_eval, noiseless_eval, ...
        snr_values, snr_eval, load_names, load_eval_branch, ...
        parameter_names, parameter_eval);
    for s = 1:nsnr
        write_confusion_csv(fullfile(cfg.results_data, sprintf( ...
            'exp08_confusion_SNR_%g_joint.csv', snr_values(s))), ...
            snr_confusion(:,:,5,s), references);
    end

    measurement_count_summary = struct('ideal_cfr', ntopology, ...
        'noiseless_ofdm', ntopology, 'snr_total', sum(snr_measurement_count), ...
        'load_total', nload*ntopology, 'parameter_total', nparameter*ntopology, ...
        'total', ntopology + ntopology + sum(snr_measurement_count) + ...
        nload*ntopology + nparameter*ntopology);
    summary_file = fullfile(cfg.results_data, 'exp08_topology_baseline_summary.txt');
    write_text_summary(summary_file, candidates, ocfg, features, ideal_eval, ...
        noiseless_eval, snr_values, snr_accuracy, snr_group_accuracy, ...
        snr_ambiguous_rate, snr_estimation, load_names, ...
        load_accuracy_branch, load_intra, load_inter, parameter_names, ...
        parameter_accuracy, parameter_intra, parameter_inter, ...
        measurement_count_summary, toc(tic_total));
    save(fullfile(cfg.results_data, 'exp08_topology_baseline.mat'), ...
        'cfg', 'ocfg', 'pilot', 'candidates', 'references', 'features', ...
        'feature_labels', 'ideal_eval', 'ideal_pred', 'ideal_pairwise', ...
        'noiseless_eval', 'noiseless_pred', 'snr_values', 'snr_accuracy', ...
        'snr_group_accuracy', 'snr_ambiguous_rate', 'snr_estimation', ...
        'snr_edge_micro', 'snr_eval', 'snr_confusion', 'snr_measurement_count', ...
        'load_names', 'load_accuracy_all', 'load_accuracy_branch', ...
        'load_intra', 'load_inter', 'load_eval_all', 'load_eval_branch', ...
        'parameter_names', 'parameter_kind', 'parameter_scale', ...
        'parameter_accuracy', 'parameter_intra', 'parameter_inter', ...
        'parameter_eval', 'measurement_count_summary');
end

function [predicted, evaluation] = classify_many(observed, true_indices, ...
        references, features, ocfg, weights)
    nobs = numel(observed);
    nfeature = numel(features);
    predicted = zeros(nfeature, nobs);
    ambiguous = false(nfeature, nobs);
    evaluation = cell(1, nfeature);
    for j = 1:nfeature
        for k = 1:nobs
            result = topology_nearest_match(observed{k}, references, ...
                features{j}, ocfg, weights);
            predicted(j,k) = result.predicted_index;
            ambiguous(j,k) = result.ambiguous;
        end
        evaluation{j} = topology_evaluation_metrics(true_indices, ...
            predicted(j,:), references);
        evaluation{j}.ambiguous_count = sum(ambiguous(j,:));
        evaluation{j}.ambiguous_rate = mean(ambiguous(j,:));
    end
end

function metrics = estimation_error_metrics(H_hat, H_true)
    H_hat = H_hat(:).'; H_true = H_true(:).';
    mag_hat = 20*log10(max(abs(H_hat), realmin));
    mag_true = 20*log10(max(abs(H_true), realmin));
    phase_hat = unwrap(angle(H_hat));
    phase_true = unwrap(angle(H_true));
    phase_hat = phase_hat - phase_hat(1);
    phase_true = phase_true - phase_true(1);
    metrics = struct('nmse', sum(abs(H_hat-H_true).^2) / ...
        sum(abs(H_true).^2), 'amplitude_rmse_db', ...
        sqrt(mean((mag_hat-mag_true).^2)), 'phase_rmse_deg', ...
        sqrt(mean((phase_hat-phase_true).^2))*180/pi);
end

function distances = pairwise_distances(references, features, ocfg, weights)
    n = numel(references); m = numel(features);
    distances = zeros(n, n, m);
    for j = 1:m
        for a = 1:n
            for b = 1:n
                distances(a,b,j) = topology_feature_distance( ...
                    references(a).reference_H, references(b).reference_H, ...
                    features{j}, ocfg, weights);
            end
        end
    end
end

function [intra_mean, inter_mean] = mean_intra_inter(observed, true_indices, ...
        references, feature, ocfg, weights)
    intra = zeros(1, numel(observed)); inter = zeros(1, numel(observed));
    for k = 1:numel(observed)
        truth = true_indices(k);
        intra(k) = topology_feature_distance(observed{k}, ...
            references(truth).reference_H, feature, ocfg, weights);
        scores = zeros(1, numel(references));
        for q = 1:numel(references)
            scores(q) = topology_feature_distance(observed{k}, ...
                references(q).reference_H, feature, ocfg, weights);
        end
        scores(truth) = Inf;
        inter(k) = min(scores);
    end
    intra_mean = mean(intra); inter_mean = mean(inter);
end

function plot_pairwise_distances(distances, references, features, cfg)
    figure('Visible', 'off', 'Position', [100, 100, 1150, 760]);
    ids = {references.id};
    for j = 1:numel(features)
        subplot(2,3,j);
        imagesc(distances(:,:,j)); axis square; colorbar;
        title(sprintf('理想类间距离 / %s', features{j}));
        set(gca, 'XTick', 1:numel(ids), 'XTickLabel', ids, ...
            'YTick', 1:numel(ids), 'YTickLabel', ids);
        xlabel('参考拓扑'); ylabel('真实拓扑');
    end
    print(gcf, fullfile(cfg.results_figures, ...
        'exp08_ideal_pairwise_distances.png'), '-dpng', '-r150');
    close(gcf);
end

function plot_snr_accuracy(snr_values, accuracy, labels, cfg)
    figure('Visible', 'off'); hold on;
    styles = {'-o', '--s', '-.^', ':d', '-x'};
    for j = 1:size(accuracy,2)
        plot(snr_values, accuracy(:,j), styles{j}, 'LineWidth', 1.1);
    end
    hold off; grid on; ylim([0, 1.05]);
    xlabel('SNR (dB)'); ylabel('完整拓扑识别率 Accuracy');
    title('不同SNR下的拓扑识别基线 / topology baseline by SNR');
    legend(labels, 'Location', 'best');
    print(gcf, fullfile(cfg.results_figures, ...
        'exp08_topology_accuracy_snr.png'), '-dpng', '-r150');
    close(gcf);
end

function plot_snr_confusion(confusion, snr_values, references, cfg)
    figure('Visible', 'off', 'Position', [100, 100, 1150, 760]);
    ids = {references.id};
    for s = 1:numel(snr_values)
        subplot(2,2,s);
        imagesc(confusion(:,:,5,s)); axis square; colorbar;
        title(sprintf('幅相联合混淆矩阵，SNR=%g dB', snr_values(s)));
        set(gca, 'XTick', 1:numel(ids), 'XTickLabel', ids, ...
            'YTick', 1:numel(ids), 'YTickLabel', ids);
        xlabel('预测拓扑'); ylabel('真实拓扑');
    end
    print(gcf, fullfile(cfg.results_figures, ...
        'exp08_topology_confusion_snr.png'), '-dpng', '-r150');
    close(gcf);
end

function plot_robustness(load_names, load_intra, load_inter, parameter_names, ...
        parameter_intra, parameter_inter, cfg)
    figure('Visible', 'off', 'Position', [100, 100, 1100, 760]);
    subplot(2,1,1);
    plot(1:numel(load_names), load_intra(:,5), '-o', 'LineWidth', 1.1); hold on;
    plot(1:numel(load_names), load_inter(:,5), '--s', 'LineWidth', 1.1); hold off;
    grid on; ylabel('幅相联合距离');
    set(gca, 'XTick', 1:numel(load_names), 'XTickLabel', load_names);
    title('负载变化：类内距离与最近类间距离');
    legend('类内距离', '最近类间距离', 'Location', 'best');
    subplot(2,1,2);
    plot(1:numel(parameter_names), parameter_intra(:,5), '-o', 'LineWidth', 1.1); hold on;
    plot(1:numel(parameter_names), parameter_inter(:,5), '--s', 'LineWidth', 1.1); hold off;
    grid on; ylabel('幅相联合距离'); xlabel('扰动场景');
    set(gca, 'XTick', 1:numel(parameter_names), 'XTickLabel', parameter_names);
    title('线路参数扰动：类内距离与最近类间距离');
    legend('类内距离', '最近类间距离', 'Location', 'best');
    print(gcf, fullfile(cfg.results_figures, ...
        'exp08_topology_robustness.png'), '-dpng', '-r150');
    close(gcf);
end

function write_ideal_csv(filename, features, evaluation)
    fid = fopen(filename, 'w');
    if fid < 0, error('exp08:OpenFailed', 'Cannot open %s.', filename); end
    fprintf(fid, 'feature,accuracy,group_accuracy,ambiguous_rate,edge_precision,edge_recall,edge_f1\n');
    for j = 1:numel(features)
        e = evaluation{j};
        fprintf(fid, '%s,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g\n', features{j}, ...
            e.accuracy, e.group_accuracy, e.ambiguous_rate, ...
            e.edge_micro.precision, e.edge_micro.recall, e.edge_micro.f1);
    end
    fclose(fid);
end

function write_snr_csv(filename, snr_values, features, accuracy, group_accuracy, ...
        ambiguous_rate, edge_micro, estimation)
    fid = fopen(filename, 'w');
    if fid < 0, error('exp08:OpenFailed', 'Cannot open %s.', filename); end
    fprintf(fid, ['snr_db,feature,accuracy,group_accuracy,ambiguous_rate,' ...
        'edge_precision,edge_recall,edge_f1,' ...
        'estimate_nmse,estimate_amplitude_rmse_db,estimate_phase_rmse_deg\n']);
    for s = 1:numel(snr_values)
        for j = 1:numel(features)
            fprintf(fid, '%.17g,%s,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g\n', ...
                snr_values(s), features{j}, accuracy(s,j), group_accuracy(s,j), ...
                ambiguous_rate(s,j), edge_micro(s,j,1), edge_micro(s,j,2), ...
                edge_micro(s,j,3), estimation(s,1), estimation(s,2), estimation(s,3));
        end
    end
    fclose(fid);
end

function write_robustness_csv(filename, names, features, accuracy_all, ...
        accuracy_branch, intra, inter)
    fid = fopen(filename, 'w');
    if fid < 0, error('exp08:OpenFailed', 'Cannot open %s.', filename); end
    fprintf(fid, 'scenario,feature,accuracy_all,accuracy_branch_or_primary,intra_distance,inter_distance\n');
    for c = 1:numel(names)
        for j = 1:numel(features)
            fprintf(fid, '%s,%s,%.17g,%.17g,%.17g,%.17g\n', names{c}, ...
                features{j}, accuracy_all(c,j), accuracy_branch(c,j), ...
                intra(c,j), inter(c,j));
        end
    end
    fclose(fid);
end

function write_edge_summary_csv(filename, features, ideal_eval, noiseless_eval, ...
        snr_values, snr_eval, load_names, load_eval, parameter_names, parameter_eval)
    fid = fopen(filename, 'w');
    if fid < 0, error('exp08:OpenFailed', 'Cannot open %s.', filename); end
    fprintf(fid, 'scenario,feature,accuracy,edge_precision,edge_recall,edge_f1\n');
    for j = 1:numel(features)
        write_edge_row(fid, 'ideal', features{j}, ideal_eval{j});
        write_edge_row(fid, 'noiseless_ofdm', features{j}, noiseless_eval{j});
    end
    for s = 1:numel(snr_values)
        for j = 1:numel(features)
            write_edge_row(fid, sprintf('SNR_%g_dB', snr_values(s)), ...
                features{j}, snr_eval{s,j});
        end
    end
    for c = 1:numel(load_names)
        for j = 1:numel(features)
            if ~isempty(load_eval{c,j})
                write_edge_row(fid, load_names{c}, features{j}, load_eval{c,j});
            end
        end
    end
    for c = 1:numel(parameter_names)
        for j = 1:numel(features)
            write_edge_row(fid, parameter_names{c}, features{j}, parameter_eval{c,j});
        end
    end
    fclose(fid);
end

function write_edge_row(fid, scenario, feature, evaluation)
    fprintf(fid, '%s,%s,%.17g,%.17g,%.17g,%.17g\n', scenario, feature, ...
        evaluation.accuracy, evaluation.edge_micro.precision, ...
        evaluation.edge_micro.recall, evaluation.edge_micro.f1);
end

function write_confusion_csv(filename, confusion, references)
    fid = fopen(filename, 'w');
    if fid < 0, error('exp08:OpenFailed', 'Cannot open %s.', filename); end
    ids = {references.id};
    fprintf(fid, 'true_or_pred');
    for k = 1:numel(ids), fprintf(fid, ',%s', ids{k}); end
    fprintf(fid, '\n');
    for r = 1:numel(ids)
        fprintf(fid, '%s', ids{r});
        fprintf(fid, ',%g', confusion(r,:));
        fprintf(fid, '\n');
    end
    fclose(fid);
end

function write_text_summary(filename, candidates, ocfg, features, ideal_eval, ...
        noiseless_eval, snr_values, snr_accuracy, snr_group_accuracy, ...
        snr_ambiguous_rate, snr_estimation, load_names, ...
        load_accuracy, load_intra, load_inter, parameter_names, ...
        parameter_accuracy, parameter_intra, parameter_inter, ...
        measurement_counts, elapsed_s)
    fid = fopen(filename, 'w');
    if fid < 0, error('exp08:OpenFailed', 'Cannot open %s.', filename); end
    fprintf(fid, '阶段2 OFDM信道估计与拓扑识别基线摘要\n');
    fprintf(fid, '模型：复基带频域等效观测 Y=XH+N，LS估计 H_hat=Y/X；不是完整PLC收发机。\n');
    fprintf(fid, 'OFDM：NFFT=%d Fs=%.17g Hz DeltaF=%.17g Hz band=[%.17g, %.17g] Hz pilots=%d spacing=%d。\n', ...
        ocfg.nfft, ocfg.sample_rate_hz, ocfg.subcarrier_spacing_hz, ...
        ocfg.frequency_band_hz(1), ocfg.frequency_band_hz(2), ...
        ocfg.num_pilots, ocfg.pilot_spacing);
    fprintf(fid, '候选拓扑：\n');
    for k = 1:numel(candidates)
        fprintf(fid, '%s %s branches=%d positions_m=', candidates(k).id, ...
            candidates(k).name, candidates(k).branch_count);
        fprintf(fid, '%.17g ', candidates(k).branch_positions_m);
        fprintf(fid, '\n');
    end
    fprintf(fid, '\nExperiment A ideal accuracy:\n');
    for j = 1:numel(features)
        fprintf(fid, '%s %.17g edgeP %.17g edgeR %.17g edgeF1 %.17g\n', ...
            features{j}, ideal_eval{j}.accuracy, ideal_eval{j}.edge_micro.precision, ...
            ideal_eval{j}.edge_micro.recall, ideal_eval{j}.edge_micro.f1);
    end
    fprintf(fid, 'Experiment B noiseless OFDM accuracy:\n');
    for j = 1:numel(features)
        fprintf(fid, '%s %.17g\n', features{j}, noiseless_eval{j}.accuracy);
    end
    fprintf(fid, 'Experiment C SNR accuracy rows are feature order: amplitude phase complex cir amp_phase_joint\n');
    for s = 1:numel(snr_values)
        fprintf(fid, 'SNR %.17g dB: ', snr_values(s));
        fprintf(fid, '%.17g ', snr_accuracy(s,:)); fprintf(fid, '\n');
        fprintf(fid, '  group_accuracy %.17g ambiguous_rate %.17g\n', ...
            snr_group_accuracy(s,5), snr_ambiguous_rate(s,5));
        fprintf(fid, '  estimate NMSE %.17g amplitude_RMSE_dB %.17g phase_RMSE_deg %.17g\n', ...
            snr_estimation(s,1), snr_estimation(s,2), snr_estimation(s,3));
    end
    fprintf(fid, 'Experiment D load branch-only joint accuracy/intra/inter:\n');
    for c = 1:numel(load_names)
        fprintf(fid, '%s %.17g %.17g %.17g\n', load_names{c}, ...
            load_accuracy(c,5), load_intra(c,5), load_inter(c,5));
    end
    fprintf(fid, 'Experiment E parameter perturbation joint accuracy/intra/inter:\n');
    for c = 1:numel(parameter_names)
        fprintf(fid, '%s %.17g %.17g %.17g\n', parameter_names{c}, ...
            parameter_accuracy(c,5), parameter_intra(c,5), parameter_inter(c,5));
    end
    fprintf(fid, 'Measurement counts ideal=%d noiseless_ofdm=%d SNR=%d load=%d parameter=%d total=%d\n', ...
        measurement_counts.ideal_cfr, measurement_counts.noiseless_ofdm, ...
        measurement_counts.snr_total, measurement_counts.load_total, ...
        measurement_counts.parameter_total, measurement_counts.total);
    fprintf(fid, 'Elapsed_seconds %.17g\n', elapsed_s);
    fclose(fid);
end
