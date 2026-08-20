function exp09_stage2_1_audit(cfg)
%EXP09_STAGE2_1_AUDIT Stage-2.1 statistical and observability audit.
%   This experiment keeps the stage-1.5 stable CFR evaluator unchanged and
%   audits the stage-2 estimator/matcher under independent seeds, two AWGN
%   definitions, measurement reversals/asymmetry, extra receiver position,
%   parameter uncertainty, and feature variants. It is still a frequency-
%   domain equivalent model: no OFDM waveform optimization or ML is used.

    ensure_result_dirs(cfg);
    tic_total = tic;
    ocfg = cfg.ofdm;
    pilot = ofdm_generate_pilot(ocfg);
    candidates = topology_candidates(cfg);
    references = topology_reference_cfr(ocfg.pilot_frequency_hz, candidates, cfg);
    stage = cfg.stage2_1;
    features = {'amplitude', 'amplitude_raw_db', 'amplitude_db_standardized', ...
        'phase', 'phase_masked', 'phase_weighted', 'complex', 'cir', ...
        'amp_phase_joint'};
    feature_labels = {'归一化幅值', '未归一化dB幅值', '标准化dB幅值', ...
        '原始展开相位', '掩膜相位', '加权圆周相位', '复数CFR', ...
        '循环带限CIR', '幅相联合'};
    weights = stage.joint_distance_weights;
    reference_power = mean(abs(pilot.X .* ...
        references(stage.reference_topology_index).reference_H).^2);

    fprintf('EXP09 stage 2.1 audit: %d topology candidates, %d pilots, %d trials/SNR/topology\n', ...
        numel(candidates), ocfg.num_pilots, stage.monte_carlo_trials);
    fprintf('  Structural observability groups: ');
    group_labels = unique({candidates.observability_group}, 'stable');
    fprintf('%s ', group_labels{:}); fprintf('\n');
    noise_results = repmat(empty_noise_result(), 1, numel(stage.noise_modes));
    for m = 1:numel(stage.noise_modes)
        noise_results(m) = run_noise_mode(stage.noise_modes{m}, stage, cfg, ...
            ocfg, pilot, candidates, references, features, weights, reference_power, m);
    end

    measurement = run_measurement_audit(cfg, ocfg, candidates, references, features, weights);
    uncertainty = run_uncertainty_audit(cfg, ocfg, candidates, references, features, weights);
    feature_audit = run_feature_audit(cfg, ocfg, pilot, candidates, references, features);
    pairwise = pairwise_feature_distances(references, features, ocfg, weights);

    write_noise_summary_csv(fullfile(cfg.results_data, ...
        'stage2_1_noise_summary.csv'), noise_results, features);
    write_noise_trials_csv(fullfile(cfg.results_data, ...
        'stage2_1_noise_trials.csv'), noise_results);
    write_noise_edge_csv(fullfile(cfg.results_data, ...
        'stage2_1_edge_summary.csv'), noise_results);
    write_noise_confusions(cfg.results_data, noise_results, features, references);
    write_measurement_csv(fullfile(cfg.results_data, ...
        'stage2_1_measurement_summary.csv'), measurement.rows);
    write_measurement_confusions(cfg.results_data, measurement, references);
    write_uncertainty_csv(fullfile(cfg.results_data, ...
        'stage2_1_uncertainty_summary.csv'), uncertainty.rows);
    write_uncertainty_confusions(fullfile(cfg.results_data, ...
        'stage2_1_uncertainty_confusion.csv'), uncertainty, references);
    write_feature_audit_csv(fullfile(cfg.results_data, ...
        'stage2_1_feature_audit.csv'), feature_audit.rows);
    write_pairwise_csv(fullfile(cfg.results_data, ...
        'stage2_1_class_pairwise.csv'), pairwise, features);
    write_config_csv(fullfile(cfg.results_data, 'stage2_1_config.csv'), ...
        cfg, stage, ocfg, reference_power);

    plot_noise_audit(noise_results, features, cfg);
    plot_measurement_audit(measurement.rows, cfg);
    plot_uncertainty_audit(uncertainty.rows, cfg);
    plot_feature_audit(feature_audit.rows, cfg);

    summary_file = fullfile(cfg.results_data, 'stage2_1_summary.txt');
    write_text_summary(summary_file, cfg, ocfg, candidates, noise_results, ...
        measurement, uncertainty, feature_audit, toc(tic_total));
    save(fullfile(cfg.results_data, 'stage2_1_audit.mat'), ...
        'cfg', 'ocfg', 'pilot', 'candidates', 'references', 'features', ...
        'feature_labels', 'weights', 'reference_power', 'noise_results', ...
        'measurement', 'uncertainty', 'feature_audit', 'pairwise');

    fprintf('  Noise modes complete: fixed received SNR and fixed noise power.\n');
    for m = 1:numel(noise_results)
        j = find(strcmp(features, 'amp_phase_joint'), 1);
        for s = 1:numel(stage.snr_db)
            q = noise_results(m).summary(s,j);
            fprintf('    %s SNR=%g dB: strict %.3f +/- %.3f, group %.3f, tie %.3f, NMSE %.5g\n', ...
                noise_results(m).mode, stage.snr_db(s), q.accuracy_mean, ...
                q.accuracy_std, q.group_accuracy_mean, q.numeric_tie_rate_mean, ...
                q.nmse_mean);
        end
    end
    fprintf('  Measurement scenarios: ');
    for k = 1:numel(measurement.rows)
        fprintf('%s ', measurement.rows(k).scenario);
    end
    fprintf('\n');
    fprintf('  Uncertainty rows: %d; feature-audit rows: %d.\n', ...
        numel(uncertainty.rows), numel(feature_audit.rows));
    fprintf('  Structural indistinguishable groups remain defined by candidate metadata;\n');
    fprintf('  noisy T3/T5 score differences are recorded as numeric gaps, not new topology information.\n');
    fprintf('EXP09 stage 2.1 audit completed in %.3f s.\n', toc(tic_total));
end

function result = run_noise_mode(mode, stage, cfg, ocfg, pilot, candidates, ...
        references, features, weights, reference_power, mode_index)
    snr_values = stage.snr_db(:).';
    ntrial = stage.monte_carlo_trials;
    ntop = numel(candidates);
    nfeature = numel(features);
    result = empty_noise_result();
    result.mode = mode;
    result.snr_values = snr_values;
    result.features = features;
    result.summary = repmat(empty_summary(), numel(snr_values), nfeature);
    result.confusion = zeros(ntop, ntop, nfeature, numel(snr_values));
    result.evaluations = cell(numel(snr_values), nfeature);
    result.trial_log = repmat(empty_trial_row(), 0, 1);
    result.reference_power = reference_power;
    for s = 1:numel(snr_values)
        nobs = ntrial * ntop;
        observations = cell(1, nobs);
        true_indices = zeros(1, nobs);
        estimates = repmat(empty_estimation(), 1, nobs);
        cursor = 0;
        for trial = 1:ntrial
            for t = 1:ntop
                cursor = cursor + 1;
                seed = cfg.random_seed + 2100000 + mode_index*1000000 + ...
                    s*10000 + trial*100 + t;
                if strcmp(mode, 'fixed_noise_power')
                    [Y, ~] = ofdm_apply_channel(pilot.X, references(t).reference_H, ...
                        snr_values(s), seed, mode, reference_power);
                else
                    [Y, ~] = ofdm_apply_channel(pilot.X, references(t).reference_H, ...
                        snr_values(s), seed, mode);
                end
                [observations{cursor}, ~] = ofdm_channel_estimate_ls(pilot.X, Y);
                estimates(cursor) = cfr_estimation_metrics(observations{cursor}, ...
                    references(t).reference_H, struct('mask_threshold_db', ...
                    stage.phase_mask_threshold_db));
                true_indices(cursor) = t;
            end
        end
        for j = 1:nfeature
            [predicted, meta, eval] = classify_observations(observations, ...
                true_indices, references, features{j}, ocfg, weights, ...
                cfg.stage2.tie_tolerance);
            result.evaluations{s,j} = eval;
            result.confusion(:,:,j,s) = eval.confusion_matrix;
            trial_indices = reshape(1:nobs, ntop, ntrial).';
            trial_accuracy = zeros(1,ntrial);
            trial_group_accuracy = zeros(1,ntrial);
            trial_tie = zeros(1,ntrial);
            trial_gap = zeros(1,ntrial);
            trial_intra = zeros(1,ntrial);
            trial_inter = zeros(1,ntrial);
            trial_nmse = zeros(1,ntrial);
            trial_amp = zeros(1,ntrial);
            trial_raw_phase = zeros(1,ntrial);
            trial_masked_phase = zeros(1,ntrial);
            trial_weighted_phase = zeros(1,ntrial);
            trial_valid = zeros(1,ntrial);
            for trial = 1:ntrial
                ix = trial_indices(trial,:);
                trial_accuracy(trial) = mean(predicted(ix) == true_indices(ix));
                truth_groups = arrayfun(@(x) x, true_indices(ix)); %#ok<NASGU>
                trial_group_accuracy(trial) = mean(arrayfun(@(q) ...
                    strcmp(candidates(predicted(ix(q))).observability_group, ...
                    candidates(true_indices(ix(q))).observability_group), 1:numel(ix)));
                trial_tie(trial) = mean(arrayfun(@(q) meta{ix(q)}.ambiguous, 1:numel(ix)));
                trial_gap(trial) = mean(arrayfun(@(q) meta{ix(q)}.distance_gap, 1:numel(ix)));
                trial_intra(trial) = finite_mean(eval.group_intra_distances(ix));
                trial_inter(trial) = finite_mean(eval.group_inter_distances(ix));
                trial_nmse(trial) = mean([estimates(ix).nmse]);
                trial_amp(trial) = mean([estimates(ix).amplitude_rmse_db]);
                trial_raw_phase(trial) = mean([estimates(ix).raw_phase_rmse_deg]);
                trial_masked_phase(trial) = mean([estimates(ix).masked_phase_rmse_deg]);
                trial_weighted_phase(trial) = mean([estimates(ix).weighted_phase_rmse_deg]);
                trial_valid(trial) = mean([estimates(ix).valid_phase_fraction]);
            end
            q = empty_summary();
            q.feature = features{j}; q.snr_db = snr_values(s); q.mode = mode;
            q.n = ntrial;
            q = put_summary_stat(q, 'accuracy', trial_accuracy);
            q = put_summary_stat(q, 'group_accuracy', trial_group_accuracy);
            q = put_summary_stat(q, 'numeric_tie_rate', trial_tie);
            q = put_summary_stat(q, 'distance_gap', trial_gap);
            q = put_summary_stat(q, 'group_intra_distance', trial_intra);
            q = put_summary_stat(q, 'group_inter_distance', trial_inter);
            q = put_summary_stat(q, 'nmse', trial_nmse);
            q = put_summary_stat(q, 'amplitude_rmse_db', trial_amp);
            q = put_summary_stat(q, 'raw_phase_rmse_deg', trial_raw_phase);
            q = put_summary_stat(q, 'masked_phase_rmse_deg', trial_masked_phase);
            q = put_summary_stat(q, 'weighted_phase_rmse_deg', trial_weighted_phase);
            q = put_summary_stat(q, 'valid_phase_fraction', trial_valid);
            q.group_intra_inter_ratio_mean = safe_ratio(q.group_intra_distance_mean, ...
                q.group_inter_distance_mean);
            q.d_intra_ge_inter_rate = mean(trial_intra >= trial_inter);
            result.summary(s,j) = q;
            for k = 1:nobs
                row = empty_trial_row();
                row.mode = mode; row.snr_db = snr_values(s); row.trial = ceil(k/ntop);
                row.true_id = candidates(true_indices(k)).id;
                row.feature = features{j}; row.predicted_id = candidates(predicted(k)).id;
                row.group_correct = strcmp(candidates(true_indices(k)).observability_group, ...
                    candidates(predicted(k)).observability_group);
                row.numeric_tie = meta{k}.ambiguous; row.distance_gap = meta{k}.distance_gap;
                truth_group = candidates(true_indices(k)).observability_group;
                groups = {candidates.observability_group};
                gi = find(strcmp(unique(groups, 'stable'), truth_group), 1);
                row.group_intra_distance = meta{k}.group_best_distances(gi);
                other = meta{k}.group_best_distances; other(gi) = Inf;
                row.group_inter_distance = min(other);
                row.nmse = estimates(k).nmse; row.amplitude_rmse_db = estimates(k).amplitude_rmse_db;
                row.raw_phase_rmse_deg = estimates(k).raw_phase_rmse_deg;
                row.masked_phase_rmse_deg = estimates(k).masked_phase_rmse_deg;
                row.weighted_phase_rmse_deg = estimates(k).weighted_phase_rmse_deg;
                row.valid_phase_fraction = estimates(k).valid_phase_fraction;
                result.trial_log(end+1) = row; %#ok<AGROW>
            end
        end
    end
end

function measurement = run_measurement_audit(cfg, ocfg, candidates, references, features, weights)
    f = ocfg.pilot_frequency_hz;
    symmetric_cfg = cfg;
    reverse_candidates = candidates;
    for k = 1:numel(candidates)
        reverse_candidates(k).network = reverse_network(candidates(k).network);
    end
    reverse_references = topology_reference_cfr(f, reverse_candidates, symmetric_cfg);
    asymmetric_cfg = cfg;
    asymmetric_cfg.Zs = cfg.stage2_1.asymmetric_Zs;
    asymmetric_cfg.Zr = cfg.stage2_1.asymmetric_Zr;
    asym_forward = topology_reference_cfr(f, candidates, asymmetric_cfg);
    asym_reverse = topology_reference_cfr(f, reverse_candidates, asymmetric_cfg);

    prefix_cfg = cfg;
    prefix_candidates = candidates;
    for k = 1:numel(candidates)
        prefix_candidates(k).network = topology_prefix_network( ...
            candidates(k).network, cfg.stage2_1.extra_receiver_segments);
    end
    prefix_references = topology_reference_cfr(f, prefix_candidates, prefix_cfg);
    endpoint_views = cell(1, numel(candidates));
    reverse_views = cell(1, numel(candidates));
    asym_views = cell(1, numel(candidates));
    asym_bidir_views = cell(1, numel(candidates));
    prefix_views = cell(1, numel(candidates));
    for k = 1:numel(candidates)
        endpoint_views{k} = {references(k).reference_H};
        reverse_views{k} = {reverse_references(k).reference_H};
        asym_views{k} = {asym_forward(k).reference_H};
        asym_bidir_views{k} = {asym_forward(k).reference_H, asym_reverse(k).reference_H};
        prefix_views{k} = {references(k).reference_H, prefix_references(k).reference_H};
    end
    scenarios = { ...
        make_measurement_scenario('C1_forward_symmetric', references, endpoint_views, references, 'symmetric', 'TX_to_RX', cfg.Zs, cfg.Zr), ...
        make_measurement_scenario('C1_reverse_symmetric', reverse_references, reverse_views, reverse_references, 'symmetric', 'RX_to_TX', cfg.Zs, cfg.Zr), ...
        make_measurement_scenario('C1_bidirectional_symmetric', references, ...
            combine_views(references, reverse_references), references, 'symmetric', 'both', cfg.Zs, cfg.Zr), ...
        make_measurement_scenario('C2_forward_asymmetric', asym_forward, asym_views, asym_forward, 'asymmetric', 'TX_to_RX', asymmetric_cfg.Zs, asymmetric_cfg.Zr), ...
        make_measurement_scenario('C2_bidirectional_asymmetric', asym_forward, asym_bidir_views, asym_forward, 'asymmetric', 'both', asymmetric_cfg.Zs, asymmetric_cfg.Zr), ...
        make_measurement_scenario('C3_endpoint_plus_node40', references, prefix_views, references, 'symmetric', 'TX_to_RX_plus_node40', cfg.Zs, cfg.Zr)};
    measurement.rows = repmat(empty_measurement_row(), 0, 1);
    measurement.confusions = {};
    measurement.scenarios = scenarios;
    for s = 1:numel(scenarios)
        sc = scenarios{s};
        for j = 1:numel(features)
            [pred, meta, eval, base_eval] = classify_measurement(sc.observed_views, ...
                sc.reference_views, sc.reference_candidates, features{j}, ...
                ocfg, weights, cfg.stage2.tie_tolerance, {candidates.observability_group});
            row = empty_measurement_row();
            row.scenario = sc.name; row.feature = features{j};
            row.measurement_direction = sc.direction; row.termination_type = sc.termination_type;
            row.Zs_ohm = sc.Zs; row.Zr_ohm = sc.Zr; row.view_count = numel(sc.observed_views);
            row.strict_accuracy = eval.accuracy; row.group_accuracy = eval.group_accuracy;
            row.base_group_accuracy = base_eval.group_accuracy;
            row.numeric_tie_rate = eval.numeric_tie_rate;
            row.distance_gap = eval.mean_distance_gap;
            row.group_intra_distance = eval.mean_group_intra_distance;
            row.group_inter_distance = eval.mean_group_inter_distance;
            row.intra_inter_ratio = eval.group_intra_inter_ratio;
            row.structurally_indistinguishable_group_count = ...
                base_eval.structurally_indistinguishable_group_count;
            row.effective_structural_group_count = ...
                eval.structurally_indistinguishable_group_count;
            row.d_intra_ge_inter = row.group_intra_distance >= row.group_inter_distance;
            measurement.rows(end+1) = row; %#ok<AGROW>
            measurement.confusions{end+1} = struct('scenario', sc.name, ...
                'feature', features{j}, 'matrix', eval.confusion_matrix, ...
                'evaluation', eval, 'predicted', pred, 'metadata', {meta}); %#ok<AGROW>
        end
    end
end

function sc = make_measurement_scenario(name, reference_candidates, reference_views, ...
        truth_candidates, termination_type, direction, Zs, Zr)
    sc = struct('name', name, 'reference_candidates', reference_candidates, ...
        'reference_views', {reference_views}, 'observed_views', {{}}, ...
        'truth_candidates', truth_candidates, 'termination_type', termination_type, ...
        'direction', direction, 'Zs', Zs, 'Zr', Zr);
    % In this deterministic audit, the observed view for each true candidate
    % equals its corresponding reference view.
    sc.observed_views = cell(1, numel(reference_views));
    for k = 1:numel(reference_views)
        sc.observed_views{k} = reference_views{k};
    end
end

function views = combine_views(forward, reverse)
    views = cell(1, numel(forward));
    for k = 1:numel(forward)
        views{k} = {forward(k).reference_H, reverse(k).reference_H};
    end
end

function [predicted, metadata, evaluation, base_evaluation] = classify_measurement(observed, reference_views, ...
        candidates, feature, ocfg, weights, tie_tolerance, groups)
    n = numel(observed);
    predicted = zeros(1,n); metadata = cell(1,n);
    true_indices = 1:n;
    effective_candidates = candidates;
    effective_groups = effective_measurement_groups(reference_views, candidates, ocfg);
    for k = 1:n
        effective_candidates(k).observability_group = effective_groups{k};
    end
    for k = 1:n
        if numel(observed{k}) == 1
            r = topology_nearest_match(observed{k}{1}, effective_candidates, feature, ocfg, weights, tie_tolerance);
        else
            r = topology_multiview_match(observed{k}, reference_views, feature, ...
                ocfg, weights, tie_tolerance, effective_groups);
        end
        predicted(k) = r.predicted_index;
        metadata{k} = r;
    end
    ambiguous = cellfun(@(x) x.ambiguous, metadata);
    evaluation = topology_evaluation_metrics(true_indices, predicted, ...
        effective_candidates, ambiguous, metadata);
    base_evaluation = topology_evaluation_metrics(true_indices, predicted, ...
        candidates, ambiguous);
end

function labels = effective_measurement_groups(reference_views, candidates, ocfg)
%EFFECTIVE_MEASUREMENT_GROUPS Find exact equivalence under the supplied views.
%   The base T3/T5 label is retained in candidate metadata. For C2/C3 this
%   second label set records whether the added physical measurement views
%   actually make the reference observations different at double precision.
    n = numel(reference_views);
    adjacency = false(n,n);
    tolerance = 1e-10;
    for a = 1:n
        adjacency(a,a) = true;
        for b = a+1:n
            d = zeros(1,numel(reference_views{a}));
            for v = 1:numel(reference_views{a})
                d(v) = topology_feature_distance(reference_views{a}{v}, ...
                    reference_views{b}{v}, 'complex', ocfg, [0.5 0.5]);
            end
            same = sqrt(mean(d.^2)) <= tolerance;
            adjacency(a,b) = same; adjacency(b,a) = same;
        end
    end
    labels = cell(1,n); group_index = zeros(1,n); group_count = 0;
    for a = 1:n
        if group_index(a) == 0
            group_count = group_count + 1;
            reachable = any(adjacency(a,:),1);
            group_index(reachable) = group_count;
        end
    end
    for a = 1:n
        labels{a} = sprintf('effective_group_%d', group_index(a));
    end
    %#ok<NASGU> candidates is kept in the signature to document the mapping.
end

function uncertainty = run_uncertainty_audit(cfg, ocfg, candidates, references, features, weights)
    f = ocfg.pilot_frequency_hz;
    uncertainty.rows = repmat(empty_uncertainty_row(), 0, 1);
    uncertainty.confusions = {};
    scale_values = cfg.stage2_1.length_scales(:).';
    kinds = {'main_length', 'branch_length', 'all_line_length'};
    for kind_index = 1:numel(kinds)
        for a = 1:numel(scale_values)
            observed = cell(1,numel(candidates));
            for t = 1:numel(candidates)
                net = candidates(t).network;
                if kind_index == 1 || kind_index == 3
                    net.main_lengths = net.main_lengths * scale_values(a);
                end
                if kind_index == 2 || kind_index == 3
                    for b = 1:numel(net.branches)
                        net.branches(b).length = net.branches(b).length * scale_values(a);
                    end
                end
                [H,~] = cascade_network_stable(f, net, cfg);
                observed{t} = H.H_port;
            end
            scenario = sprintf('%s_%+.0fpercent', kinds{kind_index}, (scale_values(a)-1)*100);
            [uncertainty.rows, uncertainty.confusions] = append_uncertainty_scenario( ...
                uncertainty.rows, uncertainty.confusions, scenario, ...
                observed, 1:numel(candidates), candidates, references, features, ocfg, weights, cfg);
        end
    end
    load_values = cfg.stage2_1.load_scales(:).';
    for a = 1:numel(load_values)
        observed = cell(1,numel(candidates));
        for t = 1:numel(candidates)
            net = candidates(t).network;
            for b = 1:numel(net.branches)
                net.branches(b).load = cfg.topology.branch_load_ohm * load_values(a);
            end
            [H,~] = cascade_network_stable(f, net, cfg);
            observed{t} = H.H_port;
        end
        scenario = sprintf('branch_load_%+.0fpercent', (load_values(a)-1)*100);
        [uncertainty.rows, uncertainty.confusions] = append_uncertainty_scenario( ...
            uncertainty.rows, uncertainty.confusions, scenario, observed, ...
            1:numel(candidates), candidates, references, features, ocfg, weights, cfg);
    end
    observed = cell(1,numel(candidates));
    for t = 1:numel(candidates)
        net = candidates(t).network;
        Zrlc = parallel_rlc_load(f, cfg.topology.branch_load_ohm, 5, 15e6);
        for b = 1:numel(net.branches), net.branches(b).load = Zrlc; end
        [H,~] = cascade_network_stable(f, net, cfg);
        observed{t} = H.H_port;
    end
    [uncertainty.rows, uncertainty.confusions] = append_uncertainty_scenario( ...
        uncertainty.rows, uncertainty.confusions, 'branch_load_parallel_RLC', ...
        observed, 1:numel(candidates), candidates, references, features, ocfg, weights, cfg);

    ntrial = cfg.stage2_1.joint_trials;
    for trial = 1:ntrial
        observed = cell(1, numel(candidates));
        for t = 1:numel(candidates)
            seed = cfg.random_seed + cfg.stage2_1.uncertainty_seed_offset + trial*100 + t;
            old_rng = rng; cleanup = onCleanup(@() rng(old_rng)); %#ok<NASGU>
            rng(seed, 'twister');
            main_scale = 0.95 + 0.10*rand;
            branch_scale = 0.95 + 0.10*rand;
            load_scale = 0.80 + 0.40*rand;
            kg_scale = 0.95 + 0.10*rand;
            zs_scale = 0.95 + 0.10*rand;
            zr_scale = 0.95 + 0.10*rand;
            local_cfg = cfg; local_cfg.kG = cfg.kG*kg_scale;
            local_cfg.Zs = cfg.Zs*zs_scale; local_cfg.Zr = cfg.Zr*zr_scale;
            net = candidates(t).network;
            net.main_lengths = net.main_lengths*main_scale;
            for b = 1:numel(net.branches)
                net.branches(b).length = net.branches(b).length*branch_scale;
                net.branches(b).load = net.branches(b).load*load_scale;
            end
            [H,~] = cascade_network_stable(f, net, local_cfg);
            observed{t} = H.H_port;
        end
        scenario = sprintf('joint_random_%03d', trial);
        [uncertainty.rows, uncertainty.confusions] = append_uncertainty_scenario( ...
            uncertainty.rows, uncertainty.confusions, scenario, observed, ...
            1:numel(candidates), candidates, references, features, ocfg, weights, cfg);
    end
end

function [rows, confusions] = append_uncertainty_scenario(rows, confusions, scenario, observed, ...
        true_indices, candidates, references, features, ocfg, weights, cfg)
    new_rows = repmat(empty_uncertainty_row(), 1, numel(features));
    new_confusions = cell(1, numel(features));
    for j = 1:numel(features)
        [pred, meta, eval] = classify_observations(observed, true_indices, references, ...
            features{j}, ocfg, weights, cfg.stage2.tie_tolerance);
        row = empty_uncertainty_row();
        row.scenario = scenario; row.feature = features{j}; row.sample_count = numel(observed);
        row.strict_accuracy = eval.accuracy; row.group_accuracy = eval.group_accuracy;
        row.numeric_tie_rate = eval.numeric_tie_rate; row.mean_distance_gap = eval.mean_distance_gap;
        row.group_intra_distance = eval.mean_group_intra_distance;
        row.group_inter_distance = eval.mean_group_inter_distance;
        row.intra_inter_ratio = eval.group_intra_inter_ratio;
        row.d_intra_ge_inter = row.group_intra_distance >= row.group_inter_distance;
        finite_pair = isfinite(eval.group_intra_distances) & isfinite(eval.group_inter_distances);
        if any(finite_pair)
            row.sample_d_intra_ge_inter_rate = mean(eval.group_intra_distances(finite_pair) >= ...
                eval.group_inter_distances(finite_pair));
        else
            row.sample_d_intra_ge_inter_rate = NaN;
        end
        new_rows(j) = row;
        confusion_row = struct('scenario', scenario, 'feature', features{j}, ...
            'matrix', eval.confusion_matrix, 'predicted', pred, 'metadata', {meta});
        new_confusions{j} = confusion_row;
    end
    if isempty(rows), rows = new_rows; else, rows = [rows, new_rows]; end %#ok<AGROW>
    if isempty(confusions), confusions = new_confusions; else, confusions = [confusions, new_confusions]; end %#ok<AGROW>
    fprintf('  uncertainty scenario %s: %d feature rows (stored=%d)\n', ...
        scenario, numel(features), numel(rows));
end

function feature_audit = run_feature_audit(cfg, ocfg, pilot, candidates, references, features)
    weights_list = cfg.stage2_1.feature_audit_weights;
    ntrial = cfg.stage2_1.monte_carlo_trials;
    ntop = numel(candidates);
    observations = cell(1, ntrial*ntop); true_indices = zeros(1,ntrial*ntop);
    cursor = 0;
    for trial = 1:ntrial
        for t = 1:ntop
            cursor = cursor + 1;
            seed = cfg.random_seed + 3100000 + trial*100 + t;
            [Y,~] = ofdm_apply_channel(pilot.X, references(t).reference_H, ...
                cfg.stage2_1.feature_audit_snr_db, seed, 'fixed_received_snr');
            [observations{cursor},~] = ofdm_channel_estimate_ls(pilot.X,Y);
            true_indices(cursor)=t;
        end
    end
    feature_audit.rows = repmat(empty_feature_row(), 0, 1);
    for w = 1:size(weights_list,1)
        for j = 1:numel(features)
            [~,~,eval] = classify_observations(observations, true_indices, references, ...
                features{j}, ocfg, weights_list(w,:), cfg.stage2.tie_tolerance);
            row = empty_feature_row(); row.scenario = 'fixed_received_snr_20dB';
            row.feature = features{j}; row.weight_amplitude = weights_list(w,1);
            row.weight_phase = weights_list(w,2); row.sample_count = numel(observations);
            row.strict_accuracy = eval.accuracy; row.group_accuracy = eval.group_accuracy;
            row.numeric_tie_rate = eval.numeric_tie_rate; row.mean_distance_gap = eval.mean_distance_gap;
            row.group_intra_distance = eval.mean_group_intra_distance;
            row.group_inter_distance = eval.mean_group_inter_distance;
            row.intra_inter_ratio = eval.group_intra_inter_ratio;
            feature_audit.rows(end+1)=row; %#ok<AGROW>
        end
    end
end

function [predicted, metadata, evaluation] = classify_observations(observed, true_indices, ...
        references, feature, ocfg, weights, tie_tolerance)
    n = numel(observed); predicted=zeros(1,n); metadata=cell(1,n);
    for k=1:n
        metadata{k}=topology_nearest_match(observed{k}, references, feature, ocfg, weights, tie_tolerance);
        predicted(k)=metadata{k}.predicted_index;
    end
    ambiguous=cellfun(@(x)x.ambiguous, metadata);
    evaluation=topology_evaluation_metrics(true_indices,predicted,references,ambiguous,metadata);
end

function refs = topology_reference_cfr_local(f, candidates, cfg) %#ok<DEFNU>
    refs = topology_reference_cfr(f, candidates, cfg);
end

function reverse = reverse_network(network)
    reverse = network;
    reverse.main_lengths = fliplr(network.main_lengths(:).');
    if isfield(network, 'main_cable_type')
        types=network.main_cable_type; if isscalar(types), types=types*ones(size(network.main_lengths)); end
        reverse.main_cable_type=fliplr(types(:).');
    end
    nseg=numel(reverse.main_lengths);
    if ~isfield(network,'branches') || isempty(network.branches)
        reverse.branches=struct('node',{},'length',{},'cable_type',{},'load',{});
    else
        reverse.branches=network.branches;
        for b=1:numel(reverse.branches), reverse.branches(b).node=nseg-network.branches(b).node; end
    end
end

function result = pairwise_feature_distances(references, features, ocfg, weights)
    n=numel(references); result=zeros(n,n,numel(features));
    for j=1:numel(features)
        for a=1:n
            for b=1:n
                result(a,b,j)=topology_feature_distance(references(a).reference_H, ...
                    references(b).reference_H,features{j},ocfg,weights);
            end
        end
    end
end

function s=empty_noise_result()
    s=struct('mode','','snr_values',[],'features',{{}},'summary',[], ...
        'confusion',[],'evaluations',{{}},'trial_log',empty_trial_row(), ...
        'reference_power',NaN);
    s.trial_log=s.trial_log([]);
end

function q=empty_summary()
    q=struct('mode','','snr_db',NaN,'feature','','n',0, ...
        'accuracy_mean',NaN,'accuracy_std',NaN,'accuracy_ci_low',NaN,'accuracy_ci_high',NaN, ...
        'group_accuracy_mean',NaN,'group_accuracy_std',NaN,'group_accuracy_ci_low',NaN,'group_accuracy_ci_high',NaN, ...
        'numeric_tie_rate_mean',NaN,'numeric_tie_rate_std',NaN,'numeric_tie_rate_ci_low',NaN,'numeric_tie_rate_ci_high',NaN, ...
        'distance_gap_mean',NaN,'distance_gap_std',NaN,'distance_gap_ci_low',NaN,'distance_gap_ci_high',NaN, ...
        'group_intra_distance_mean',NaN,'group_intra_distance_std',NaN,'group_intra_distance_ci_low',NaN,'group_intra_distance_ci_high',NaN, ...
        'group_inter_distance_mean',NaN,'group_inter_distance_std',NaN,'group_inter_distance_ci_low',NaN,'group_inter_distance_ci_high',NaN, ...
        'group_intra_inter_ratio_mean',NaN,'d_intra_ge_inter_rate',NaN, ...
        'nmse_mean',NaN,'nmse_std',NaN,'nmse_ci_low',NaN,'nmse_ci_high',NaN, ...
        'amplitude_rmse_db_mean',NaN,'amplitude_rmse_db_std',NaN,'amplitude_rmse_db_ci_low',NaN,'amplitude_rmse_db_ci_high',NaN, ...
        'raw_phase_rmse_deg_mean',NaN,'raw_phase_rmse_deg_std',NaN,'raw_phase_rmse_deg_ci_low',NaN,'raw_phase_rmse_deg_ci_high',NaN, ...
        'masked_phase_rmse_deg_mean',NaN,'masked_phase_rmse_deg_std',NaN,'masked_phase_rmse_deg_ci_low',NaN,'masked_phase_rmse_deg_ci_high',NaN, ...
        'weighted_phase_rmse_deg_mean',NaN,'weighted_phase_rmse_deg_std',NaN,'weighted_phase_rmse_deg_ci_low',NaN,'weighted_phase_rmse_deg_ci_high',NaN, ...
        'valid_phase_fraction_mean',NaN,'valid_phase_fraction_std',NaN,'valid_phase_fraction_ci_low',NaN,'valid_phase_fraction_ci_high',NaN);
end

function row=empty_trial_row()
    row=struct('mode','','snr_db',NaN,'trial',0,'true_id','','feature','', ...
        'predicted_id','','group_correct',false,'numeric_tie',false,'distance_gap',NaN, ...
        'group_intra_distance',NaN,'group_inter_distance',NaN,'nmse',NaN, ...
        'amplitude_rmse_db',NaN,'raw_phase_rmse_deg',NaN,'masked_phase_rmse_deg',NaN, ...
        'weighted_phase_rmse_deg',NaN,'valid_phase_fraction',NaN);
end

function row=empty_estimation()
    row=struct('nmse',NaN,'amplitude_rmse_db',NaN,'phase_rmse_deg',NaN, ...
        'raw_phase_rmse_deg',NaN,'masked_phase_rmse_deg',NaN, ...
        'weighted_phase_rmse_deg',NaN,'circular_phase_rmse_deg',NaN, ...
        'valid_phase_fraction',NaN,'phase_details',struct());
end

function row=empty_measurement_row()
    row=struct('scenario','','feature','','measurement_direction','','termination_type','', ...
        'Zs_ohm',NaN,'Zr_ohm',NaN,'view_count',0,'strict_accuracy',NaN, ...
        'group_accuracy',NaN,'base_group_accuracy',NaN,'numeric_tie_rate',NaN,'distance_gap',NaN, ...
        'group_intra_distance',NaN,'group_inter_distance',NaN,'intra_inter_ratio',NaN, ...
        'structurally_indistinguishable_group_count',NaN,'effective_structural_group_count',NaN, ...
        'd_intra_ge_inter',false);
end

function row=empty_uncertainty_row()
    row=struct('scenario','','feature','','sample_count',0,'strict_accuracy',NaN, ...
        'group_accuracy',NaN,'numeric_tie_rate',NaN,'mean_distance_gap',NaN, ...
        'group_intra_distance',NaN,'group_inter_distance',NaN,'intra_inter_ratio',NaN, ...
        'd_intra_ge_inter',false,'sample_d_intra_ge_inter_rate',NaN);
end

function row=empty_feature_row()
    row=struct('scenario','','feature','','weight_amplitude',NaN,'weight_phase',NaN, ...
        'sample_count',0,'strict_accuracy',NaN,'group_accuracy',NaN,'numeric_tie_rate',NaN, ...
        'mean_distance_gap',NaN,'group_intra_distance',NaN,'group_inter_distance',NaN, ...
        'intra_inter_ratio',NaN);
end

function q=put_summary_stat(q,name,x)
    x=x(isfinite(x)); if isempty(x), return; end
    mu=mean(x); if numel(x)>1, sd=std(x,0); else, sd=0; end
    half=1.96*sd/sqrt(numel(x));
    q.([name '_mean'])=mu; q.([name '_std'])=sd;
    q.([name '_ci_low'])=mu-half; q.([name '_ci_high'])=mu+half;
end

function value=finite_mean(x)
    x=x(isfinite(x)); if isempty(x), value=NaN; else, value=mean(x); end
end
function value=safe_ratio(a,b)
    if ~isfinite(a)||~isfinite(b)||b==0, value=NaN; else, value=a/b; end
end

function write_noise_summary_csv(filename, results, features)
    fid=fopen(filename,'w'); assert(fid>=0,'Cannot open noise summary.');
    fprintf(fid,['mode,snr_db,feature,n,accuracy_mean,accuracy_std,accuracy_ci_low,accuracy_ci_high,' ...
        'group_accuracy_mean,group_accuracy_std,group_accuracy_ci_low,group_accuracy_ci_high,' ...
        'numeric_tie_rate_mean,numeric_tie_rate_std,numeric_tie_rate_ci_low,numeric_tie_rate_ci_high,' ...
        'distance_gap_mean,distance_gap_std,group_intra_mean,group_inter_mean,intra_inter_ratio,d_intra_ge_inter_rate,' ...
        'nmse_mean,nmse_std,nmse_ci_low,nmse_ci_high,amplitude_rmse_db_mean,amplitude_rmse_db_std,' ...
        'raw_phase_rmse_deg_mean,raw_phase_rmse_deg_std,masked_phase_rmse_deg_mean,masked_phase_rmse_deg_std,' ...
        'weighted_phase_rmse_deg_mean,weighted_phase_rmse_deg_std,valid_phase_fraction_mean,valid_phase_fraction_std\n']);
    for m=1:numel(results), for s=1:numel(results(m).snr_values), for j=1:numel(features)
        q=results(m).summary(s,j);
        fprintf(fid,'%s,%.17g,%s,%d,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g\n', ...
            q.mode,q.snr_db,q.feature,q.n,q.accuracy_mean,q.accuracy_std,q.accuracy_ci_low,q.accuracy_ci_high, ...
            q.group_accuracy_mean,q.group_accuracy_std,q.group_accuracy_ci_low,q.group_accuracy_ci_high, ...
            q.numeric_tie_rate_mean,q.numeric_tie_rate_std,q.numeric_tie_rate_ci_low,q.numeric_tie_rate_ci_high, ...
            q.distance_gap_mean,q.distance_gap_std,q.group_intra_distance_mean,q.group_inter_distance_mean,q.group_intra_inter_ratio_mean,q.d_intra_ge_inter_rate, ...
            q.nmse_mean,q.nmse_std,q.nmse_ci_low,q.nmse_ci_high,q.amplitude_rmse_db_mean,q.amplitude_rmse_db_std, ...
            q.raw_phase_rmse_deg_mean,q.raw_phase_rmse_deg_std,q.masked_phase_rmse_deg_mean,q.masked_phase_rmse_deg_std, ...
            q.weighted_phase_rmse_deg_mean,q.weighted_phase_rmse_deg_std,q.valid_phase_fraction_mean,q.valid_phase_fraction_std);
    end,end,end
    fclose(fid);
end

function write_noise_trials_csv(filename, results)
    fid=fopen(filename,'w'); assert(fid>=0,'Cannot open noise trials.');
    fprintf(fid,['mode,snr_db,trial,true_id,feature,predicted_id,group_correct,numeric_tie,distance_gap,' ...
        'group_intra_distance,group_inter_distance,nmse,amplitude_rmse_db,raw_phase_rmse_deg,' ...
        'masked_phase_rmse_deg,weighted_phase_rmse_deg,valid_phase_fraction\n']);
    for m=1:numel(results), rows=results(m).trial_log; for k=1:numel(rows)
        r=rows(k); fprintf(fid,'%s,%.17g,%d,%s,%s,%s,%d,%d,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g\n', ...
            r.mode,r.snr_db,r.trial,r.true_id,r.feature,r.predicted_id,r.group_correct,r.numeric_tie,r.distance_gap, ...
            r.group_intra_distance,r.group_inter_distance,r.nmse,r.amplitude_rmse_db,r.raw_phase_rmse_deg, ...
            r.masked_phase_rmse_deg,r.weighted_phase_rmse_deg,r.valid_phase_fraction);
    end,end
    fclose(fid);
end

function write_noise_confusions(data_dir, results, features, refs)
    for m=1:numel(results), for s=1:numel(results(m).snr_values), for j=1:numel(features)
        name=sprintf('stage2_1_confusion_%s_SNR_%g_%s.csv',results(m).mode,results(m).snr_values(s),features{j});
        extension = '.csv';
        name = [strrep(strrep(name(1:end-numel(extension)),'.','p'),'-','m'), extension];
        write_matrix_csv(fullfile(data_dir,name),results(m).confusion(:,:,j,s),refs);
    end,end,end
end

function write_noise_edge_csv(filename, results)
    fid=fopen(filename,'w'); assert(fid>=0,'Cannot open stage2.1 edge summary.');
    fprintf(fid,'mode,snr_db,feature,edge_precision_micro,edge_recall_micro,edge_f1_micro\n');
    for m=1:numel(results)
        for s=1:numel(results(m).snr_values)
            for j=1:numel(results(m).features)
                e=results(m).evaluations{s,j}.edge_micro;
                fprintf(fid,'%s,%.17g,%s,%.17g,%.17g,%.17g\n',results(m).mode,results(m).snr_values(s),results(m).features{j},e.precision,e.recall,e.f1);
            end
        end
    end
    fclose(fid);
end

function write_matrix_csv(filename, matrix, refs)
    fid=fopen(filename,'w'); assert(fid>=0,'Cannot open confusion matrix.'); ids={refs.id};
    fprintf(fid,'true_or_pred'); for k=1:numel(ids), fprintf(fid,',%s',ids{k}); end; fprintf(fid,'\n');
    for r=1:numel(ids), fprintf(fid,'%s',ids{r}); fprintf(fid,',%g',matrix(r,:)); fprintf(fid,'\n'); end
    fclose(fid);
end

function write_measurement_csv(filename, rows)
    fid=fopen(filename,'w'); assert(fid>=0,'Cannot open measurement summary.');
    fprintf(fid,'scenario,feature,direction,termination_type,Zs_ohm,Zr_ohm,view_count,strict_accuracy,effective_group_accuracy,base_group_accuracy,numeric_tie_rate,distance_gap,group_intra_distance,group_inter_distance,intra_inter_ratio,base_structural_group_count,effective_structural_group_count,d_intra_ge_inter\n');
    for k=1:numel(rows), r=rows(k); fprintf(fid,'%s,%s,%s,%s,%.17g,%.17g,%d,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%d,%d,%d\n', ...
        r.scenario,r.feature,r.measurement_direction,r.termination_type,r.Zs_ohm,r.Zr_ohm,r.view_count,r.strict_accuracy,r.group_accuracy,r.base_group_accuracy,r.numeric_tie_rate,r.distance_gap,r.group_intra_distance,r.group_inter_distance,r.intra_inter_ratio,r.structurally_indistinguishable_group_count,r.effective_structural_group_count,r.d_intra_ge_inter); end
    fclose(fid);
end

function write_measurement_confusions(data_dir, measurement, refs)
    for k=1:numel(measurement.confusions)
        c=measurement.confusions{k}; name=sprintf('stage2_1_confusion_%s_%s.csv',c.scenario,c.feature); write_matrix_csv(fullfile(data_dir,name),c.matrix,refs);
    end
end

function write_uncertainty_csv(filename, rows)
    fid=fopen(filename,'w'); assert(fid>=0,'Cannot open uncertainty summary.');
    fprintf(fid,'scenario,feature,sample_count,strict_accuracy,group_accuracy,numeric_tie_rate,mean_distance_gap,group_intra_distance,group_inter_distance,intra_inter_ratio,d_intra_ge_inter,sample_d_intra_ge_inter_rate\n');
    for k=1:numel(rows), r=rows(k); fprintf(fid,'%s,%s,%d,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%d,%.17g\n',r.scenario,r.feature,r.sample_count,r.strict_accuracy,r.group_accuracy,r.numeric_tie_rate,r.mean_distance_gap,r.group_intra_distance,r.group_inter_distance,r.intra_inter_ratio,r.d_intra_ge_inter,r.sample_d_intra_ge_inter_rate); end
    fclose(fid);
end

function write_uncertainty_confusions(filename, uncertainty, refs)
    fid=fopen(filename,'w'); assert(fid>=0,'Cannot open uncertainty confusion.'); fprintf(fid,'scenario,feature,true_id,predicted_id,count\n');
    for k=1:numel(uncertainty.confusions)
        c=uncertainty.confusions{k}; ids={refs.id};
        for r=1:numel(ids), for p=1:numel(ids), fprintf(fid,'%s,%s,%s,%s,%d\n',c.scenario,c.feature,ids{r},ids{p},c.matrix(r,p)); end,end
    end
    fclose(fid);
end

function write_feature_audit_csv(filename, rows)
    fid=fopen(filename,'w'); assert(fid>=0,'Cannot open feature audit.'); fprintf(fid,'scenario,feature,weight_amplitude,weight_phase,sample_count,strict_accuracy,group_accuracy,numeric_tie_rate,mean_distance_gap,group_intra_distance,group_inter_distance,intra_inter_ratio\n');
    for k=1:numel(rows), r=rows(k); fprintf(fid,'%s,%s,%.17g,%.17g,%d,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g\n',r.scenario,r.feature,r.weight_amplitude,r.weight_phase,r.sample_count,r.strict_accuracy,r.group_accuracy,r.numeric_tie_rate,r.mean_distance_gap,r.group_intra_distance,r.group_inter_distance,r.intra_inter_ratio); end
    fclose(fid);
end

function write_pairwise_csv(filename, pairwise, features)
    fid=fopen(filename,'w'); assert(fid>=0,'Cannot open pairwise file.'); fprintf(fid,'feature,true_index,reference_index,distance\n');
    for j=1:numel(features), for a=1:size(pairwise,1), for b=1:size(pairwise,2), fprintf(fid,'%s,%d,%d,%.17g\n',features{j},a,b,pairwise(a,b,j)); end,end,end; fclose(fid);
end

function write_config_csv(filename, cfg, stage, ocfg, reference_power)
    fid=fopen(filename,'w'); assert(fid>=0,'Cannot open config file.'); fprintf(fid,'parameter,value\n');
    fprintf(fid,'matlab_model,frequency_domain_equivalent_Y=XH+N\n'); fprintf(fid,'nfft,%d\nFs_hz,%.17g\nsubcarrier_spacing_hz,%.17g\nfrequency_low_hz,%.17g\nfrequency_high_hz,%.17g\npilot_count,%d\n',ocfg.nfft,ocfg.sample_rate_hz,ocfg.subcarrier_spacing_hz,ocfg.frequency_band_hz(1),ocfg.frequency_band_hz(2),ocfg.num_pilots);
    fprintf(fid,'trials_per_snr_topology,%d\nmask_threshold_db,%.17g\nreference_topology_index,%d\nreference_signal_power,%.17g\n',stage.monte_carlo_trials,stage.phase_mask_threshold_db,stage.reference_topology_index,reference_power);
    fprintf(fid,'Zs_ohm,%.17g\nZr_ohm,%.17g\nkG,%.17g\n',cfg.Zs,cfg.Zr,cfg.kG); fclose(fid);
end

function plot_noise_audit(results, features, cfg)
    joint=find(strcmp(features,'amp_phase_joint'),1); complex=find(strcmp(features,'complex'),1);
    figure('Visible','off','Position',[100 100 1100 760]);
    subplot(2,1,1); hold on; styles={'-o','--s'};
    for m=1:numel(results), x=results(m).snr_values; q=results(m).summary(:,joint); errorbar(x,[q.accuracy_mean],[q.accuracy_std],styles{m},'LineWidth',1.1); end
    grid on; ylim([0 1.05]); xlabel('SNR (dB)'); ylabel('严格拓扑识别率'); title('阶段2.1多随机种子：幅相联合识别率（误差棒=标准差）'); legend({results.mode},'Location','best');
    subplot(2,1,2); hold on;
    for m=1:numel(results), q=results(m).summary(:,complex); errorbar(results(m).snr_values,[q.nmse_mean],[q.nmse_std],styles{m},'LineWidth',1.1); end
    grid on; set(gca,'YScale','log'); xlabel('SNR (dB)'); ylabel('CFR估计 NMSE'); title('复数CFR估计 NMSE；统计趋势而非单次单调性'); legend({results.mode},'Location','best');
    print(gcf,fullfile(cfg.results_figures,'stage2_1_noise_robustness.png'),'-dpng','-r150'); close(gcf);
end

function plot_measurement_audit(rows,cfg)
    names=unique({rows.scenario},'stable'); features={'complex','amp_phase_joint'}; figure('Visible','off','Position',[100 100 1150 760]);
    for j=1:2, subplot(1,2,j); vals=zeros(1,numel(names)); groups=vals;
        for k=1:numel(names), hit=find(strcmp({rows.scenario},names{k})&strcmp({rows.feature},features{j}),1); vals(k)=rows(hit).strict_accuracy; groups(k)=rows(hit).group_accuracy; end
        bar([vals;groups].'); ylim([0 1.05]); grid on; set(gca,'XTick',1:numel(names),'XTickLabel',names,'XTickLabelRotation',35); ylabel('识别率'); title(features{j}); legend('严格','等价组','Location','best');
    end
    print(gcf,fullfile(cfg.results_figures,'stage2_1_measurement_identifiability.png'),'-dpng','-r150'); close(gcf);
end

function plot_uncertainty_audit(rows,cfg)
    hit=strcmp({rows.feature},'amp_phase_joint'); r=rows(hit); figure('Visible','off','Position',[100 100 1200 760]);
    subplot(2,1,1); bar([r.group_intra_distance; r.group_inter_distance].'); grid on; ylabel('距离'); title('参数不确定性：类内最佳距离与最近类间距离（幅相联合）'); legend('组内','组间','Location','best');
    subplot(2,1,2); plot(1:numel(r),[r.intra_inter_ratio],'-o'); grid on; yline(1,'--'); ylabel('D_{intra}/D_{inter}'); xlabel('扰动场景（含随机联合样本）'); title('比值 >= 1 表示当前匹配器无法可靠分离');
    print(gcf,fullfile(cfg.results_figures,'stage2_1_parameter_uncertainty.png'),'-dpng','-r150'); close(gcf);
end

function plot_feature_audit(rows,cfg)
    hit=strcmp({rows.scenario},'fixed_received_snr_20dB')&abs([rows.weight_amplitude]-.5)<eps; r=rows(hit); figure('Visible','off','Position',[100 100 1200 760]);
    bar([r.strict_accuracy; r.group_accuracy].'); ylim([0 1.05]); grid on; set(gca,'XTick',1:numel(r),'XTickLabel',{r.feature},'XTickLabelRotation',35); ylabel('识别率'); title('特征审计：20 dB、0.5/0.5（非最优性声明）'); legend('严格','等价组','Location','best');
    print(gcf,fullfile(cfg.results_figures,'stage2_1_feature_audit.png'),'-dpng','-r150'); close(gcf);
end

function write_text_summary(filename,cfg,ocfg,candidates,noise,measurement,uncertainty,feature_audit,elapsed)
    fid=fopen(filename,'w'); assert(fid>=0,'Cannot open stage2.1 text summary.');
    fprintf(fid,'阶段 2.1 OFDM 拓扑识别基线审计摘要\n'); fprintf(fid,'模型：复基带频域等效 Y=XH+N；不是完整PLC收发机。\n');
    fprintf(fid,'NFFT=%d Fs=%.17g Hz band=%.17g..%.17g Hz pilots=%d\n',ocfg.nfft,ocfg.sample_rate_hz,ocfg.frequency_band_hz(1),ocfg.frequency_band_hz(2),ocfg.num_pilots);
    fprintf(fid,'候选拓扑及结构观测组：\n'); for k=1:numel(candidates), fprintf(fid,'%s,%s,%s\n',candidates(k).id,candidates(k).name,candidates(k).observability_group); end
    fprintf(fid,'结构不可辨识组数量=%d（由候选定义固定，不随噪声改变）。\n',sum(group_count(candidates)>1));
    for m=1:numel(noise), fprintf(fid,'\n噪声模式 %s：\n',noise(m).mode); for s=1:numel(noise(m).snr_values), q=noise(m).summary(s,strcmp(noise(m).features,'amp_phase_joint')); fprintf(fid,'SNR %.17g strict %.17g std %.17g CI[%.17g,%.17g] group %.17g tie %.17g NMSE %.17g maskedPhase %.17g\n',q.snr_db,q.accuracy_mean,q.accuracy_std,q.accuracy_ci_low,q.accuracy_ci_high,q.group_accuracy_mean,q.numeric_tie_rate_mean,q.nmse_mean,q.masked_phase_rmse_deg_mean); end,end
    fprintf(fid,'\n测量场景行数=%d；不确定性行数=%d；特征审计行数=%d。\n',numel(measurement.rows),numel(uncertainty.rows),numel(feature_audit.rows));
    fprintf(fid,'阶段2.1耗时 %.17g s。\n',elapsed); fclose(fid);
end

function counts=group_count(candidates)
    labels={candidates.observability_group}; u=unique(labels,'stable'); counts=zeros(size(u)); for k=1:numel(u), counts(k)=sum(strcmp(labels,u{k})); end
end
