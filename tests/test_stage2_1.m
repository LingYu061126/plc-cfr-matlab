function test_stage2_1()
%TEST_STAGE2_1 Boundary, equivalence and audit-interface tests.
    fprintf('Running stage-2.1 audit tests...\n');
    root_dir = fileparts(fileparts(mfilename('fullpath')));
    cfg = default_config(root_dir);
    pilot = ofdm_generate_pilot(cfg.ofdm);
    H = (0.6 + 0.1i) * ones(size(pilot.X));

    [Y, noise, d] = ofdm_apply_channel(pilot.X, H, +Inf, 11);
    assert(max(abs(Y-pilot.X.*H)) == 0 && max(abs(noise)) == 0 && ...
        d.noise_variance == 0 && strcmp(d.noise_mode,'fixed_received_snr'), ...
        '+Inf SNR did not produce the explicitly noiseless result.');
    assert_throws(@() ofdm_apply_channel(pilot.X,H,-Inf,11), ...
        'ofdm_apply_channel:InvalidSNR');
    assert_throws(@() ofdm_apply_channel(pilot.X,H,NaN,11), ...
        'ofdm_apply_channel:InvalidSNR');
    assert_throws(@() ofdm_apply_channel(pilot.X,H,20+1i,11), ...
        'ofdm_apply_channel:InvalidSNR');
    fprintf('  PASS +Inf/-Inf/NaN/complex SNR boundaries\n');

    reference_power = mean(abs(pilot.X .* H).^2);
    [~,~,fixed] = ofdm_apply_channel(pilot.X,H,10,11,'fixed_noise_power',reference_power);
    [~,~,fixed2] = ofdm_apply_channel(pilot.X,2*H,10,11,'fixed_noise_power',reference_power);
    assert(fixed.noise_variance == fixed2.noise_variance && ...
        strcmp(fixed.noise_mode,'fixed_noise_power'), ...
        'Fixed-noise-power mode did not keep one reference variance.');
    assert_throws(@() ofdm_apply_channel(pilot.X,H,10,11,'fixed_noise_power'), ...
        'ofdm_apply_channel:MissingNoiseReference');
    fprintf('  PASS fixed received-SNR and fixed-noise-power modes\n');

    [Y_repeat_1, ~] = ofdm_apply_channel(pilot.X, H, 20, 12345);
    [Y_repeat_2, ~] = ofdm_apply_channel(pilot.X, H, 20, 12345);
    assert(max(abs(Y_repeat_1-Y_repeat_2)) == 0 && ...
        cfg.stage2_1.monte_carlo_trials >= 50 && numel(cfg.stage2_1.noise_modes) == 2, ...
        'Fixed random seeds or statistical configuration are not reproducible.');
    fprintf('  PASS fixed-seed repeatability and 50-trial audit configuration\n');

    Hweak = H; Hweak(1:200) = 1e-14 * exp(1i*(1:200));
    phase = cfr_phase_error_metrics(Hweak, H, struct('mask_threshold_db', -40));
    assert(all(isfinite([phase.raw_unwrapped_rmse_deg, phase.masked_unwrapped_rmse_deg, ...
        phase.weighted_circular_rmse_deg, phase.valid_fraction])) && ...
        phase.valid_fraction > 0 && phase.valid_fraction < 1, ...
        'Amplitude-aware phase metrics are not finite or not masked.');
    fprintf('  PASS raw/masked/weighted phase metrics and valid fraction\n');

    [cir, time_s, Hfull, cir_details] = ofdm_cfr_to_cir(H, cfg.ofdm);
    assert(numel(cir)==cfg.ofdm.nfft && numel(time_s)==cfg.ofdm.nfft && ...
        numel(Hfull)==cfg.ofdm.nfft && strcmp(cir_details.name,'circular band-limited CIR') && ...
        ~cir_details.has_cyclic_prefix && ~cir_details.peak_is_physical_toa, ...
        'Circular band-limited CIR metadata or dimensions are incorrect.');
    fprintf('  PASS circular band-limited CIR naming, metadata and dimensions\n');

    candidates = topology_candidates(cfg);
    references = topology_reference_cfr(cfg.ofdm.pilot_frequency_hz,candidates,cfg);
    m = topology_nearest_match(references(3).reference_H,references,'complex', ...
        cfg.ofdm,[.5 .5],cfg.stage2.tie_tolerance);
    assert(strcmp(candidates(3).observability_group,candidates(5).observability_group) && ...
        numel(m.group_best_distances)==5 && m.ambiguous && ...
        m.group_distance_gap >= 0, ...
        'Structural T3/T5 group or numeric tie metadata is missing.');
    e = topology_evaluation_metrics([3 5],[3 3],candidates,[true false],{m m});
    assert(e.accuracy == .5 && e.group_accuracy == 1 && ...
        e.structurally_indistinguishable_group_count == 1 && ...
        e.numeric_tie_rate == .5, ...
        'Structural equivalence and numeric tie statistics were conflated.');
    fprintf('  PASS structural T3/T5 equivalence versus numeric tie separation\n');

    refs_views = cell(1,numel(candidates));
    for k=1:numel(candidates), refs_views{k}={references(k).reference_H,references(k).reference_H}; end
    mv = topology_multiview_match({references(3).reference_H,references(3).reference_H}, ...
        refs_views,'complex',cfg.ofdm,[.5 .5],cfg.stage2.tie_tolerance,{candidates.observability_group});
    assert(mv.predicted_index==3 || mv.predicted_index==5, ...
        'Repeated-view multiview matcher returned an invalid candidate.');
    fprintf('  PASS multiview matcher interface\n');
    assert_throws(@() topology_prefix_network(candidates(2).network, 0), ...
        'topology_prefix_network:InvalidSegmentCount');
    bad_net = candidates(2).network; bad_net.main_lengths(1) = -1;
    assert_throws(@() cascade_network_stable(cfg.ofdm.pilot_frequency_hz, bad_net, cfg), ...
        'cascade_network_stable:InvalidLengths');
    fprintf('  PASS invalid length and extra-measurement input validation\n');
    fprintf('ALL STAGE-2.1 AUDIT TESTS PASSED\n');
end

function assert_throws(fun, expected_identifier)
    threw = false;
    try
        fun();
    catch ME
        threw = true;
        assert(strcmp(ME.identifier, expected_identifier), ...
            'Expected %s but received %s.', expected_identifier, ME.identifier);
    end
    assert(threw, 'Expected error %s was not thrown.', expected_identifier);
end
