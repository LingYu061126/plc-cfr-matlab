function test_ofdm_baseline()
%TEST_OFDM_BASELINE Unit tests for stage-2 OFDM and topology baseline.
    fprintf('Running stage-2 OFDM/topology baseline tests...\n');
    root_dir = fileparts(fileparts(mfilename('fullpath')));
    cfg = default_config(root_dir);
    ocfg = cfg.ofdm;
    pilot = ofdm_generate_pilot(ocfg);
    H_known = (0.7 + 0.2i) * exp(-1i*linspace(0, 2*pi, numel(pilot.X)));
    Y = pilot.X .* H_known;
    [H_hat, ~] = ofdm_channel_estimate_ls(pilot.X, Y);
    assert(max(abs(H_hat-H_known)) < 1e-14, ...
        'Known X,H noiseless LS recovery failed.');
    fprintf('  PASS known X,H noiseless LS recovery\n');

    [Y0, ~] = ofdm_apply_channel(pilot.X, H_known, Inf, 17);
    [H0, ~] = ofdm_channel_estimate_ls(pilot.X, Y0);
    assert(max(abs(H0-H_known)) < 1e-14, ...
        'Noiseless OFDM estimate is not at numerical precision.');
    fprintf('  PASS noiseless H_hat recovery\n');

    [Y_low, ~] = ofdm_apply_channel(pilot.X, H_known, 0, 18);
    [Y_high, ~] = ofdm_apply_channel(pilot.X, H_known, 30, 19);
    [H_low, ~] = ofdm_channel_estimate_ls(pilot.X, Y_low);
    [H_high, ~] = ofdm_channel_estimate_ls(pilot.X, Y_high);
    nmse_low = sum(abs(H_low-H_known).^2) / sum(abs(H_known).^2);
    nmse_high = sum(abs(H_high-H_known).^2) / sum(abs(H_known).^2);
    assert(nmse_high < nmse_low, 'LS NMSE did not improve with SNR.');
    fprintf('  PASS noise NMSE decreases with SNR (0 dB %.4g, 30 dB %.4g)\n', ...
        nmse_low, nmse_high);

    [cir, ~, Hfull] = ofdm_cfr_to_cir(H_known, ocfg);
    assert(max(abs(fft(cir, ocfg.nfft)-Hfull)) < 1e-14, ...
        'IFFT/FFT CFR-CIR consistency failed.');
    fprintf('  PASS IFFT/FFT CFR-CIR consistency\n');

    candidates = topology_candidates(cfg);
    ids = {candidates.id};
    assert(numel(unique(ids)) == 6 && all(arrayfun(@(x) ~isempty(x.network), candidates)), ...
        'Topology IDs and network definitions are not one-to-one.');
    references = topology_reference_cfr(ocfg.pilot_frequency_hz, candidates, cfg);
    assert(all(arrayfun(@(x) all(isfinite(x.reference_H)), references)), ...
        'A topology reference CFR is nonfinite.');
    fprintf('  PASS candidate topology IDs and stable reference CFRs\n');

    match1 = topology_nearest_match(references(2).reference_H, references, ...
        'amp_phase_joint', ocfg, cfg.stage2.joint_distance_weights, ...
        cfg.stage2.tie_tolerance);
    match2 = topology_nearest_match(references(2).reference_H, references, ...
        'amp_phase_joint', ocfg, cfg.stage2.joint_distance_weights, ...
        cfg.stage2.tie_tolerance);
    assert(strcmp(match1.predicted_id, match2.predicted_id) && ...
        max(abs(match1.scores-match2.scores)) == 0, ...
        'Deterministic topology matching is not repeatable.');
    fprintf('  PASS fixed-reference topology matching repeatability\n');
    mirror_match = topology_nearest_match(references(3).reference_H, references, ...
        'amp_phase_joint', ocfg, cfg.stage2.joint_distance_weights, ...
        cfg.stage2.tie_tolerance);
    assert(mirror_match.ambiguous && numel(mirror_match.tied_indices) >= 2, ...
        'T3/T5 mirror-equivalent topology tie was not reported.');
    fprintf('  PASS mirror-equivalent T3/T5 ambiguity is reported\n');

    load_values = {[], Inf, 0, 50+10i, ...
        parallel_rlc_load(ocfg.pilot_frequency_hz, 50, 5, 15e6)};
    for k = 1:numel(load_values)
        net = candidates(2).network;
        if isempty(load_values{k})
            net.branches = struct('node', {}, 'length', {}, ...
                'cable_type', {}, 'load', {});
        else
            for b = 1:numel(net.branches)
                net.branches(b).load = load_values{k};
            end
        end
        [Hload, ~] = cascade_network_stable(ocfg.pilot_frequency_hz, net, cfg);
        assert(all(isfinite(Hload.H_port)), 'Load variation produced nonfinite CFR.');
    end
    fprintf('  PASS empty/open/short/complex/RLC load cases\n');
    fprintf('ALL STAGE-2 OFDM BASELINE TESTS PASSED\n');
end
