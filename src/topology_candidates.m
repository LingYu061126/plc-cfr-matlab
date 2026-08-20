function candidates = topology_candidates(cfg)
%TOPOLOGY_CANDIDATES Define six small tree-topology baseline candidates.
%   All candidates share an 80 m main path split at 20/40/60 m. This keeps
%   main-line length and edge labels common while changing only the branch
%   pattern. Branch locations/counts are topology variables; cable lengths,
%   RLGC types, and nominal loads are explicit separate parameters.
%   The returned structs contain a network accepted by
%   cascade_network_stable, plus node/edge graph metadata.

    if nargin < 1 || isempty(cfg)
        cfg = default_config(fileparts(fileparts(mfilename('fullpath'))));
    end
    if ~isfield(cfg, 'topology')
        cfg.topology = struct('main_segment_length_m', 20, ...
            'branch_length_m', 15, 'branch_load_ohm', 50, ...
            'branch_cable_type', 1, 'main_cable_type', 0);
    end
    tcfg = cfg.topology;
    main_d = tcfg.main_segment_length_m;
    positions = [main_d, 2*main_d, 3*main_d];
    pattern_positions = {[], positions(2), positions(3), ...
        [positions(1), positions(3)], positions(1), positions};
    ids = {'T1', 'T2', 'T3', 'T4', 'T5', 'T6'};
    names = {'无支路主线', '中部单支路', '近末端单支路', ...
        '两支路', '改变连接位置单支路', '三支路'};
    observability_groups = {'T1', 'T2', 'T3_T5_mirror_equivalent', ...
        'T4', 'T3_T5_mirror_equivalent', 'T6'};
    main_lengths = repmat(main_d, 1, 4);
    candidates = repmat(empty_candidate(), 1, numel(ids));
    for k = 1:numel(ids)
        branch_positions = pattern_positions{k};
        branches = make_branches(branch_positions, tcfg);
        net = struct('main_lengths', main_lengths, ...
            'main_cable_type', repmat(tcfg.main_cable_type, 1, 4), ...
            'branches', branches);
        [nodes, edges] = make_graph(branch_positions, main_d, tcfg);
        candidates(k).id = ids{k};
        candidates(k).name = names{k};
        candidates(k).observability_group = observability_groups{k};
        candidates(k).network = net;
        candidates(k).nodes = nodes;
        candidates(k).edges = edges;
        candidates(k).edge_labels = arrayfun(@(x) x.id, edges, ...
            'UniformOutput', false);
        candidates(k).branch_positions_m = branch_positions;
        candidates(k).branch_count = numel(branch_positions);
        candidates(k).main_total_length_m = sum(main_lengths);
        candidates(k).tx_node = 'TX';
        candidates(k).rx_node = 'RX';
        candidates(k).parameter_class = struct('topology_variable', ...
            'branch positions and count', 'main_lengths_m', main_lengths, ...
            'branch_length_m', tcfg.branch_length_m, ...
            'main_cable_type', tcfg.main_cable_type, ...
            'branch_cable_type', tcfg.branch_cable_type, ...
            'branch_load_ohm', tcfg.branch_load_ohm, ...
            'Zs_ohm', cfg.Zs, 'Zr_ohm', cfg.Zr, 'kG', cfg.kG);
        candidates(k).reference_H = [];
        candidates(k).reference_details = [];
    end
end

function candidate = empty_candidate()
    candidate = struct('id', '', 'name', '', 'network', [], 'nodes', [], ...
        'edges', [], 'edge_labels', {{}}, 'branch_positions_m', [], ...
        'branch_count', 0, 'main_total_length_m', 0, 'tx_node', '', ...
        'rx_node', '', 'observability_group', '', 'parameter_class', [], 'reference_H', [], ...
        'reference_details', []);
end

function branches = make_branches(branch_positions, tcfg)
    branches = struct('node', {}, 'length', {}, 'cable_type', {}, 'load', {});
    for k = 1:numel(branch_positions)
        branches(k) = struct('node', branch_positions(k)/tcfg.main_segment_length_m, ...
            'length', tcfg.branch_length_m, ...
            'cable_type', tcfg.branch_cable_type, ...
            'load', tcfg.branch_load_ohm);
    end
end

function [nodes, edges] = make_graph(branch_positions, main_d, tcfg)
    node_ids = {'TX', sprintf('N%d', main_d), sprintf('N%d', 2*main_d), ...
        sprintf('N%d', 3*main_d), 'RX'};
    node_pos = [0, main_d, 2*main_d, 3*main_d, 4*main_d];
    nodes = repmat(struct('id', '', 'position_m', 0, 'role', ''), 1, 5);
    for k = 1:numel(node_ids)
        role = 'junction';
        if k == 1, role = 'tx'; end
        if k == numel(node_ids), role = 'rx'; end
        nodes(k) = struct('id', node_ids{k}, 'position_m', node_pos(k), ...
            'role', role);
    end
    edge_template = struct('id', '', 'from', '', 'to', '', 'kind', '', ...
        'length_m', 0, 'cable_type', 0, 'load', NaN);
    edges = repmat(edge_template, 1, 4);
    for k = 1:4
        edges(k) = struct('id', sprintf('M_%g_%g', node_pos(k), node_pos(k+1)), ...
            'from', node_ids{k}, 'to', node_ids{k+1}, 'kind', 'main', ...
            'length_m', main_d, 'cable_type', tcfg.main_cable_type, 'load', NaN);
    end
    for k = 1:numel(branch_positions)
        node_idx = round(branch_positions(k)/main_d) + 1;
        terminal_id = sprintf('%s_LOAD', node_ids{node_idx});
        nodes(end+1) = struct('id', terminal_id, ...
            'position_m', branch_positions(k), 'role', 'branch_load'); %#ok<AGROW>
        edges(end+1) = struct('id', sprintf('B_%g_%g', branch_positions(k), ...
            tcfg.branch_length_m), 'from', node_ids{node_idx}, ...
            'to', terminal_id, 'kind', 'branch', ...
            'length_m', tcfg.branch_length_m, ...
            'cable_type', tcfg.branch_cable_type, ...
            'load', tcfg.branch_load_ohm); %#ok<AGROW>
    end
end
