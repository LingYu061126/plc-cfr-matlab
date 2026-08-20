function [H, Ttotal, details] = cascade_network(f_hz, network, cfg)
%CASCADE_NETWORK Build a main-line/branch network by ABCD cascading.
%   [H,Ttotal,details] = CASCADE_NETWORK(f_hz, network, cfg) accepts a row
%   or column frequency vector in Hz. network.main_lengths is a vector of
%   main-line segment lengths in m; network.main_cable_type is scalar or a
%   vector of cable types; network.branches is a struct array with fields
%   node (1..N-1), length (m), cable_type and load (ohm). A branch is first
%   translated to its node input impedance and then inserted as a shunt.
%   The physical order is line, node shunt(s), line, ...; matrix products
%   are ordinary two-port cascade products, not a calculus chain rule.
%   cfg supplies kG, Zs, Zr and optional lossless. H is a struct containing
%   H_V and H_port; Ttotal is 2x2xN; details stores branch impedances and
%   determinant diagnostics. For numerically long lines use
%   cascade_network_stable; this legacy ABCD path warns when AD-BC drifts.

    f_hz = f_hz(:).';
    if ~isstruct(network) || ~isfield(network, 'main_lengths')
        error('cascade_network:InvalidNetwork', 'network.main_lengths is required.');
    end
    lengths = network.main_lengths(:).';
    nseg = numel(lengths);
    if nseg < 1 || any(~isfinite(lengths)) || any(lengths < 0)
        error('cascade_network:InvalidLengths', 'main_lengths must be finite nonnegative metres.');
    end
    if isfield(network, 'main_cable_type')
        main_types = network.main_cable_type;
    else
        main_types = 0;
    end
    if isscalar(main_types)
        main_types = main_types * ones(1, nseg);
    else
        main_types = main_types(:).';
    end
    if numel(main_types) ~= nseg
        error('cascade_network:InvalidCableTypes', 'main_cable_type must be scalar or match main_lengths.');
    end
    if ~isfield(network, 'branches') || isempty(network.branches)
        branches = struct('node', {}, 'length', {}, 'cable_type', {}, 'load', {});
    else
        branches = network.branches;
    end
    if ~isfield(cfg, 'kG'), cfg.kG = 1; end
    if ~isfield(cfg, 'Zs'), cfg.Zs = 50; end
    if ~isfield(cfg, 'Zr'), cfg.Zr = 50; end
    if ~isfield(cfg, 'port_reference_ohm'), cfg.port_reference_ohm = 50; end
    if ~isfield(cfg, 'lossless'), cfg.lossless = false; end
    if ~isfield(cfg, 'abcd_det_warning_threshold'), cfg.abcd_det_warning_threshold = 1e-6; end
    if ~isfield(cfg, 'suppress_abcd_warning'), cfg.suppress_abcd_warning = false; end
    n = numel(f_hz);
    Ttotal = repmat(eye(2), 1, 1, n);
    branch_zin = cell(1, numel(branches));
    branch_node = zeros(1, numel(branches));
    branch_segments = cell(1, nseg-1);

    for seg = 1:nseg
        cable = cable_parameters(main_types(seg));
        [~, ~, ~, ~, gamma, Zc] = cable_rlgc(f_hz, cable, cfg.kG, cfg.lossless);
        Tline = transmission_line_abcd(gamma, Zc, lengths(seg));
        Ttotal = pagewise_product(Ttotal, Tline);
        if seg < nseg
            node_branches = find_branch_indices(branches, seg);
            branch_segments{seg} = node_branches;
            for ib = node_branches
                b = branches(ib);
                bcable = cable_parameters(b.cable_type);
                [~, ~, ~, ~, bgamma, bZc] = cable_rlgc(f_hz, bcable, cfg.kG, cfg.lossless);
                Zin = branch_input_impedance(bgamma, bZc, b.length, b.load);
                if any(isnan(Zin))
                    error('cascade_network:BranchNaN', 'Branch %d produced NaN input impedance.', ib);
                end
                if any(Zin == 0)
                    error('cascade_network:BranchShort', ...
                        'Branch %d is a zero-ohm shunt at one or more frequencies.', ib);
                end
                Tshunt = shunt_abcd(Zin);
                Ttotal = pagewise_product(Ttotal, Tshunt);
                branch_zin{ib} = Zin;
                branch_node(ib) = b.node;
            end
        end
    end
    [H_V, H_port, denominator] = abcd_to_transfer( ...
        Ttotal, cfg.Zs, cfg.Zr, cfg.port_reference_ohm);
    A = squeeze(Ttotal(1,1,:)).';
    B = squeeze(Ttotal(1,2,:)).';
    C = squeeze(Ttotal(2,1,:)).';
    D = squeeze(Ttotal(2,2,:)).';
    det_error = abs(A.*D - B.*C - 1);
    [det_max, det_worst_index] = max(det_error);
    det_median = median(det_error);
    abcd_reliable = all(isfinite(Ttotal(:))) && ...
        isfinite(det_max) && det_max <= cfg.abcd_det_warning_threshold;
    if ~abcd_reliable && ~cfg.suppress_abcd_warning
        warning('cascade_network:IllConditionedABCD', ...
            ['ABCD determinant residual max %.6g exceeds %.6g at %.6g MHz. ' ...
             'Use cascade_network_stable for the official CFR.'], ...
            det_max, cfg.abcd_det_warning_threshold, f_hz(det_worst_index)/1e6);
    end
    H = struct('H_V', H_V, 'H_port', H_port);
    details = struct('branch_zin', {branch_zin}, ...
        'branch_node', branch_node, 'branch_segments', {branch_segments}, ...
        'frequency_hz', f_hz, 'Zs', cfg.Zs, 'Zr', cfg.Zr, ...
        'denominator', denominator, 'lossless', cfg.lossless, 'kG', cfg.kG, ...
        'port_reference_ohm', cfg.port_reference_ohm, ...
        'determinant_error', det_error, 'determinant_error_max', det_max, ...
        'determinant_error_median', det_median, ...
        'determinant_worst_frequency_hz', f_hz(det_worst_index), ...
        'abcd_reliable', abcd_reliable);
end

function indices = find_branch_indices(branches, node)
    indices = [];
    for k = 1:numel(branches)
        required = {'node', 'length', 'cable_type', 'load'};
        for q = 1:numel(required)
            if ~isfield(branches(k), required{q})
                error('cascade_network:BranchField', 'Each branch needs node, length, cable_type and load.');
            end
        end
        if branches(k).node == node
            indices(end+1) = k; %#ok<AGROW>
        end
    end
end

function out = pagewise_product(left, right)
    n = size(left, 3);
    out = zeros(2, 2, n);
    for k = 1:n
        out(:,:,k) = left(:,:,k) * right(:,:,k);
    end
end
