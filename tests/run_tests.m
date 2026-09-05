function run_tests()
%RUN_TESTS Analytical, limiting-case and numerical-stability test suite.
    fprintf('Running MATLAB PLC CFR stage-1.5 tests...\n');
    tol = 1e-10;
    root_dir = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root_dir, 'src'));
    addpath(fullfile(root_dir, 'config'));
    addpath(fullfile(root_dir, 'experiments'));
    addpath(fullfile(root_dir, 'tests'));
    cfg = default_config(root_dir);
    c0 = cable_parameters(0);
    c1 = cable_parameters(1);

    f10 = 10e6;
    [R0, ~, G0] = cable_rlgc(f10, c0, 5, false);
    [R1, ~, G1] = cable_rlgc(f10, c1, 5, false);
    assert(abs(R0 - 0.379473318) < 2e-8, '10 MHz cable 0 R failed.');
    assert(abs(G0 - 9.707521e-5) < 2e-10, '10 MHz cable 0 G failed.');
    assert(abs(R1 - 0.295356733) < 2e-8, '10 MHz cable 1 R failed.');
    assert(abs(G1 - 1.09013265e-4) < 2e-10, '10 MHz cable 1 G failed.');
    fprintf('  PASS RLGC values at 10 MHz\n');

    assert_throws(@() cable_rlgc(0, c0, 1, false), ...
        'cable_rlgc:InvalidFrequency');
    assert_throws(@() cable_rlgc([-1, 1e6], c0, 1, false), ...
        'cable_rlgc:InvalidFrequency');
    assert_throws(@() cable_rlgc([1e6, NaN], c0, 1, false), ...
        'cable_rlgc:InvalidFrequency');
    fprintf('  PASS strictly-positive finite frequency validation\n');

    z0 = sqrt(c0.L_uH_per_m*1e-6/(c0.C_pF_per_m*1e-12));
    z1 = sqrt(c1.L_uH_per_m*1e-6/(c1.C_pF_per_m*1e-12));
    assert(abs(z0 - 268.3281573) < 1e-7 && abs(z1 - 234.2160175) < 1e-7, ...
        'Nominal characteristic impedance check failed.');
    fprintf('  PASS nominal sqrt(L/C) checks\n');

    f = linspace(2e6, 30e6, 17);
    [~, ~, ~, ~, gamma, Zc] = cable_rlgc(f, c0, 1, false);
    T = transmission_line_abcd(gamma, Zc, 20);
    det_error = determinant_error(T);
    assert(max(det_error) < 1e-12, 'ABCD reciprocity determinant failed.');
    fprintf('  PASS uniform-line determinant AD-BC=1 (max %.3g)\n', max(det_error));

    Twhole = transmission_line_abcd(gamma, Zc, 40);
    Thalf1 = transmission_line_abcd(gamma, Zc, 20);
    Thalf2 = transmission_line_abcd(gamma, Zc, 20);
    Tsplit = pagewise_product_for_test(Thalf1, Thalf2);
    assert(max(abs(Twhole(:) - Tsplit(:))) < 1e-10, ...
        'Line split equivalence failed.');
    fprintf('  PASS split-line ABCD cascade equivalence\n');

    cfg_small = cfg;
    cfg_small.frequency_hz = f;
    net = struct('main_lengths', 40, 'main_cable_type', 0, ...
        'branches', empty_branches());
    [~, Tnet] = cascade_network(f, net, cfg_small);
    assert(max(abs(Tnet(:) - Twhole(:))) < 1e-10, ...
        'No-branch network mismatch.');
    fprintf('  PASS no-branch network equals one uniform line\n');

    [~, ~, ~, ~, bgamma, bZc] = cable_rlgc(f, c1, 1, false);
    z_open = branch_input_impedance(bgamma, bZc, 10, Inf);
    z_short = branch_input_impedance(bgamma, bZc, 10, 0);
    z_zero = branch_input_impedance(bgamma, bZc, 0, 50+10i);
    z_finite = branch_input_impedance(bgamma, bZc, 10, 50+10i);
    assert(all(isfinite(z_open)) && all(isfinite(z_short)) && ...
        all(isfinite(z_zero)) && all(isfinite(z_finite)), ...
        'Branch special case failed.');
    assert(max(abs(z_zero - (50+10i))) == 0, ...
        'Zero-length complex branch bypass failed.');
    z_scalar = branch_input_impedance(bgamma, bZc, 10, 50);
    z_vector = branch_input_impedance(bgamma, bZc, 10, 50*ones(size(f)));
    assert(max(abs(z_scalar-z_vector)) == 0, ...
        'Scalar/vector load equivalence failed.');
    assert_throws(@() branch_input_impedance(bgamma, bZc, 10, [1, 2]), ...
        'branch_input_impedance:InvalidLoad');
    fprintf('  PASS scalar real/complex, vector, open and short branch loads\n');

    Zrlc = parallel_rlc_load(f, 500, 5, 15e6);
    z_rlc = branch_input_impedance(bgamma, bZc, 10, Zrlc);
    assert(all(isfinite(Zrlc)) && all(isfinite(z_rlc)) && ...
        max(abs(Zrlc)) <= 500*(1+1e-12), ...
        'Frequency-selective complex load failed.');
    net_rlc = cfg.default_network;
    net_rlc.branches.load = Zrlc;
    [Hrlc, drlc] = cascade_network_stable(f, net_rlc, cfg_small);
    assert(all(isfinite(Hrlc.H_port)) && all(isfinite(drlc.branch_zin{1})), ...
        'Network interface rejected frequency-selective complex load.');
    fprintf('  PASS Cañete parallel-RLC frequency-selective network load\n');

    gamma_ideal = 1i * 2*pi*f*1e-9;
    Tmatch = transmission_line_abcd(gamma_ideal, 50*ones(size(f)), 20);
    [Hv50, Hp50] = abcd_to_transfer(Tmatch, 50, 50, 50);
    assert(max(abs(Hp50 - 2*Hv50)) < tol, ...
        '50-ohm matched H_port=2*H_V failed.');
    assert(max(abs(abs(Hp50) - 1)) < 1e-10, ...
        'Matched lossless H_port magnitude failed.');
    [Hv75, Hp75] = abcd_to_transfer(Tmatch, 75, 50, 50);
    assert(max(abs(Hp75 - 2.5*Hv75)) < tol, ...
        'General reference-port normalization failed.');
    assert(max(abs(Hp75 - 2*Hv75)) > 1e-3, ...
        'Changed Zs must not retain unconditional factor two.');
    assert_throws(@() abcd_to_transfer(Tmatch, 50, 50, 0), ...
        'abcd_to_transfer:InvalidPortReference');
    fprintf('  PASS source-port normalization applicability constraints\n');

    short_net = cfg.default_network;
    vector_net = short_net;
    vector_net.branches.load = 50*ones(size(f));
    [Hscalar_net, ~] = cascade_network_stable(f, short_net, cfg_small);
    [Hvector_net, ~] = cascade_network_stable(f, vector_net, cfg_small);
    assert(max(abs(Hscalar_net.H_port-Hvector_net.H_port)) == 0, ...
        'Scalar/vector load network equivalence failed.');
    fprintf('  PASS scalar and equal frequency-vector network loads agree\n');

    for kg = [1, 5]
        cfg_short = cfg;
        cfg_short.kG = kg;
        [Habcd, ~] = cascade_network(f, short_net, cfg_short);
        [Hstable, stable_details] = cascade_network_stable(f, short_net, cfg_short);
        rel = relative_error(Habcd.H_port, Hstable.H_port);
        assert(max(rel) < 2e-12, ...
            'Stable/ABCD short-line complex CFR mismatch.');
        assert(min(real(stable_details.input_impedance)) > -1e-10, ...
            'Short passive network has negative-real input impedance.');
    end
    fprintf('  PASS stable recursion matches short-line ABCD complex CFR\n');

    [~, ~, ~, ~, gamma_long, Zc_long] = cable_rlgc(f, c0, 5, false);
    [Zin_match, ratio_match] = terminated_line_response( ...
        gamma_long, Zc_long, 1200, Zc_long);
    expected_ratio = exp(-gamma_long*1200);
    assert(max(relative_error(Zin_match, Zc_long)) < 2e-12, ...
        'Long matched line input impedance failed.');
    assert(max(relative_error(ratio_match, expected_ratio)) < 2e-12, ...
        'Long matched line propagation ratio failed.');
    fprintf('  PASS stable long matched-line analytic limit\n');

    cfg_long = cfg;
    cfg_long.kG = 5;
    one_piece = struct('main_lengths', 1200, 'main_cable_type', 0, ...
        'branches', empty_branches());
    two_pieces = struct('main_lengths', [600, 600], ...
        'main_cable_type', [0, 0], 'branches', empty_branches());
    [Hone, done] = cascade_network_stable(f, one_piece, cfg_long);
    [Htwo, dtwo] = cascade_network_stable(f, two_pieces, cfg_long);
    assert(max(relative_error(Hone.H_port, Htwo.H_port)) < 3e-12, ...
        'Stable long-line segmentation invariance failed.');
    assert(max(relative_error(done.input_impedance, dtwo.input_impedance)) < 3e-12, ...
        'Stable long-line input impedance segmentation failed.');
    fprintf('  PASS stable long-line segmentation invariance\n');

    fprintf('  Long-line legacy ABCD determinant audit:\n');
    f_audit = cfg.frequency_hz;
    lengths = [300, 500, 800, 1200];
    kg_values = [1, 5];
    audit = repmat(struct(), numel(kg_values), numel(lengths));
    for p = 1:numel(kg_values)
        cfg_audit = cfg;
        cfg_audit.kG = kg_values(p);
        cfg_audit.suppress_abcd_warning = true;
        for k = 1:numel(lengths)
            audit_net = struct('main_lengths', [lengths(k)/2, lengths(k)/2], ...
                'main_cable_type', [0, 0], ...
                'branches', struct('node', 1, 'length', 50, ...
                'cable_type', 1, 'load', 50));
            [Habcd, ~, dabcd] = cascade_network(f_audit, audit_net, cfg_audit);
            [Hstable, dstable] = cascade_network_stable(f_audit, audit_net, cfg_audit);
            audit(p,k).det_max = dabcd.determinant_error_max;
            audit(p,k).det_median = dabcd.determinant_error_median;
            audit(p,k).worst_hz = dabcd.determinant_worst_frequency_hz;
            audit(p,k).reliable = dabcd.abcd_reliable;
            audit(p,k).cfr_rel_max = max(relative_error( ...
                Habcd.H_port, Hstable.H_port));
            assert(all(isfinite(Hstable.H_port)), ...
                'Stable long-line CFR contains nonfinite values.');
            assert(min(real(dstable.input_impedance)) > -1e-8, ...
                'Stable passive long network has negative-real input impedance.');
            fprintf(['    L=%4d m kG=%d max=%.6g median=%.6g ' ...
                'worst=%.6f MHz legacyReliable=%d CFRrel=%.6g\n'], ...
                lengths(k), kg_values(p), audit(p,k).det_max, ...
                audit(p,k).det_median, audit(p,k).worst_hz/1e6, ...
                audit(p,k).reliable, audit(p,k).cfr_rel_max);
        end
    end
    assert(audit(1,1).reliable, ...
        '300 m kG=1 should remain below the determinant threshold.');
    assert(~audit(2,2).reliable && ~audit(2,3).reliable && ...
        ~audit(2,4).reliable, ...
        '500/800/1200 m kG=5 legacy ABCD must be flagged unreliable.');
    fprintf('  PASS long-line determinant diagnostics and stable physical checks\n');
    fprintf('ALL STAGE-1.5 TESTS PASSED\n');
    test_ofdm_baseline();
    test_stage2_1();
    test_stage2_2();
    test_stage2_3();
    test_stage3a();
    test_stage3a_1();
    test_stage3a_2();
    test_stage3_band_configs();
    test_stage3b_pre();
    test_stage3b_waveform();
    test_stage4a1();
    test_stage4a2_prior_constrained_library();
    test_stage4a3_open_set_audit();
    test_stage4a3_1_statistical_open_set_audit();
    test_stage4a4_candidate_confirmation();
end

function err = determinant_error(T)
    A = squeeze(T(1,1,:));
    B = squeeze(T(1,2,:));
    C = squeeze(T(2,1,:));
    D = squeeze(T(2,2,:));
    err = abs(A.*D-B.*C-1);
end

function out = pagewise_product_for_test(left, right)
    n = size(left, 3);
    out = zeros(2, 2, n);
    for k = 1:n, out(:,:,k) = left(:,:,k) * right(:,:,k); end
end

function err = relative_error(actual, expected)
    err = abs(actual-expected) ./ max(abs(expected), realmin);
end

function b = empty_branches()
    b = struct('node', {}, 'length', {}, 'cable_type', {}, 'load', {});
end

function assert_throws(fun, expected_identifier)
    threw = false;
    try
        fun();
    catch ME
        threw = true;
        assert(strcmp(ME.identifier, expected_identifier), ...
            'Expected error %s but received %s.', expected_identifier, ME.identifier);
    end
    assert(threw, 'Expected error %s was not thrown.', expected_identifier);
end
