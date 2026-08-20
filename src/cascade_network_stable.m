function [H, details] = cascade_network_stable(f_hz, network, cfg)
%CASCADE_NETWORK_STABLE Stable backward recursion for a branched PLC line.
%   This function accepts the same network fields as cascade_network but
%   avoids forming a total ABCD matrix. Starting at Zr, it recursively:
%     1) translates each downstream impedance through a line using tanh;
%     2) accumulates Vright/Vleft using decaying exponentials;
%     3) combines node branches as parallel admittances.
%   It returns H_V=Vr/Vs and H_port normalized to the configured reference
%   termination. details includes total input impedance, passive voltage
%   ratio and all branch input impedances. Units are Hz, m and ohm.

    f_hz = f_hz(:).';
    if ~isstruct(network) || ~isfield(network, 'main_lengths')
        error('cascade_network_stable:InvalidNetwork', ...
            'network.main_lengths is required.');
    end
    lengths = network.main_lengths(:).';
    nseg = numel(lengths);
    if nseg < 1 || any(~isfinite(lengths)) || any(lengths < 0)
        error('cascade_network_stable:InvalidLengths', ...
            'main_lengths must be finite nonnegative metres.');
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
        error('cascade_network_stable:InvalidCableTypes', ...
            'main_cable_type must be scalar or match main_lengths.');
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
    if ~(isscalar(cfg.Zs) && isfinite(cfg.Zs) && isscalar(cfg.Zr) && ...
            (isfinite(cfg.Zr) || isinf(cfg.Zr)))
        error('cascade_network_stable:InvalidTermination', ...
            'Zs must be finite and Zr must be finite or Inf.');
    end
    if ~(isscalar(cfg.port_reference_ohm) && isreal(cfg.port_reference_ohm) && ...
            isfinite(cfg.port_reference_ohm) && cfg.port_reference_ohm > 0)
        error('cascade_network_stable:InvalidPortReference', ...
            'port_reference_ohm must be finite and positive.');
    end

    branch_zin = cell(1, numel(branches));
    branch_node = zeros(1, numel(branches));
    for ib = 1:numel(branches)
        required = {'node', 'length', 'cable_type', 'load'};
        for q = 1:numel(required)
            if ~isfield(branches(ib), required{q})
                error('cascade_network_stable:BranchField', ...
                    'Each branch needs node, length, cable_type and load.');
            end
        end
        node = branches(ib).node;
        if ~(isscalar(node) && node == fix(node) && node >= 1 && node < nseg)
            error('cascade_network_stable:BranchNode', ...
                'Branch node must be an integer from 1 to number of segments minus 1.');
        end
        bcable = cable_parameters(branches(ib).cable_type);
        [~, ~, ~, ~, bgamma, bZc] = cable_rlgc( ...
            f_hz, bcable, cfg.kG, cfg.lossless);
        branch_zin{ib} = branch_input_impedance( ...
            bgamma, bZc, branches(ib).length, branches(ib).load);
        branch_node(ib) = node;
    end

    if isinf(cfg.Zr)
        Zeq = Inf(size(f_hz));
    else
        Zeq = cfg.Zr * ones(size(f_hz));
    end
    passive_ratio = ones(size(f_hz));
    section_input_impedance = cell(1, nseg);
    section_voltage_ratio = cell(1, nseg);
    node_equivalent_impedance = cell(1, max(nseg-1, 0));

    for seg = nseg:-1:1
        cable = cable_parameters(main_types(seg));
        [~, ~, ~, ~, gamma, Zc] = cable_rlgc( ...
            f_hz, cable, cfg.kG, cfg.lossless);
        [Zeq, ratio] = terminated_line_response( ...
            gamma, Zc, lengths(seg), Zeq);
        passive_ratio = passive_ratio .* ratio;
        section_input_impedance{seg} = Zeq;
        section_voltage_ratio{seg} = ratio;
        if seg > 1
            node = seg - 1;
            Yeq = impedance_to_admittance(Zeq);
            node_branches = find(branch_node == node);
            for ib = node_branches
                Yeq = Yeq + impedance_to_admittance(branch_zin{ib});
            end
            Zeq = admittance_to_impedance(Yeq);
            node_equivalent_impedance{node} = Zeq;
        end
    end

    source_ratio = source_voltage_ratio(Zeq, cfg.Zs);
    H_V = passive_ratio .* source_ratio;
    H_port = ((cfg.Zs + cfg.port_reference_ohm) / ...
        cfg.port_reference_ohm) .* H_V;
    if any(isnan(H_V)) || any(isnan(H_port)) || any(~isfinite(H_port))
        error('cascade_network_stable:NonfiniteTransfer', ...
            'Stable recursion produced a nonfinite transfer function.');
    end
    H = struct('H_V', H_V, 'H_port', H_port);
    details = struct('frequency_hz', f_hz, 'input_impedance', Zeq, ...
        'passive_voltage_ratio', passive_ratio, 'source_voltage_ratio', source_ratio, ...
        'branch_zin', {branch_zin}, 'branch_node', branch_node, ...
        'section_input_impedance', {section_input_impedance}, ...
        'section_voltage_ratio', {section_voltage_ratio}, ...
        'node_equivalent_impedance', {node_equivalent_impedance}, ...
        'Zs', cfg.Zs, 'Zr', cfg.Zr, ...
        'port_reference_ohm', cfg.port_reference_ohm, ...
        'lossless', cfg.lossless, 'kG', cfg.kG);
end

function Y = impedance_to_admittance(Z)
    Y = zeros(size(Z));
    finite_nonzero = isfinite(Z) & (Z ~= 0);
    Y(finite_nonzero) = 1 ./ Z(finite_nonzero);
    Y(Z == 0) = Inf;
end

function Z = admittance_to_impedance(Y)
    Z = zeros(size(Y));
    finite_nonzero = isfinite(Y) & (Y ~= 0);
    Z(finite_nonzero) = 1 ./ Y(finite_nonzero);
    Z(Y == 0) = Inf;
end

function ratio = source_voltage_ratio(Zin, Zs)
    ratio = zeros(size(Zin));
    open_mask = isinf(Zin);
    ratio(open_mask) = 1;
    finite_mask = ~open_mask;
    denom = Zs + Zin(finite_mask);
    if any(denom == 0)
        error('cascade_network_stable:SourceSingularity', ...
            'Zs+Zin is zero at one or more frequencies.');
    end
    ratio(finite_mask) = Zin(finite_mask) ./ denom;
end
