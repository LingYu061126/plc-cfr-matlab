function bank = generate_stage4a3_1_trial_bank(sc)
%GENERATE_STAGE4A3_1_TRIAL_BANK Make one shared calibration/test truth bank.
%   The bank is generated once and reused by both frequency grids and all
%   prior scenarios. Truth fields are retained for offline scoring only; they
%   are never passed to the observation-only matcher.

    if nargin < 1 || isempty(sc)
        error('generate_stage4a3_1_trial_bank:MissingConfig', 'sc is required.');
    end
    base = generate_radial_topology_candidates(sc.generator);
    bank = empty_bank();
    cursor = 0;

    rng(sc.calibration_seed, 'twister');
    for g = 1:numel(base)
        for k = 1:sc.per_graph_calibration
            cursor = cursor + 1;
            bank(cursor) = make_row(sprintf('cal_G%03d_%02d',g,k), ...
                'calibration', 'in_library_continuous', base(g), ...
                random_continuous_theta(sc.parameter_search), sc.source_tag, '', '');
        end
    end
    rng(sc.test_seed, 'twister');
    for g = 1:numel(base)
        for k = 1:sc.per_graph_test
            cursor = cursor + 1;
            bank(cursor) = make_row(sprintf('test_G%03d_%02d',g,k), ...
                'test', 'in_library_continuous', base(g), ...
                random_continuous_theta(sc.parameter_search), sc.source_tag, '', '');
        end
    end

    % The current generator supports a one-level radial tree. Increasing the
    % number of first-level branches creates legal structures outside P0
    % without introducing loops, multi-phase networks or unsupported models.
    out_grammar = sc.generator;
    out_grammar.max_branches = max(2, sc.generator.max_branches);
    out_grammar.max_side_branches_per_node = max(2, sc.generator.max_side_branches_per_node);
    out_grammar.max_nodes = max(sc.generator.max_nodes, 12);
    out_grammar.max_candidates = max(sc.generator.max_candidates, 64);
    out_candidates = generate_radial_topology_candidates(out_grammar);
    base_keys = {base.canonical_key};
    keep = ~ismember({out_candidates.canonical_key}, base_keys);
    out_candidates = out_candidates(keep);
    if numel(out_candidates) < 3
        error('generate_stage4a3_1_trial_bank:InsufficientStructureDiversity', ...
            'Only %d independent structure-out canonical keys were generated.', ...
            numel(out_candidates));
    end
    out_candidates = out_candidates(1:3);
    for k = 1:sc.structure_out_sample_count
        g = out_candidates(1 + mod(k-1, numel(out_candidates)));
        cursor = cursor + 1;
        bank(cursor) = make_row(sprintf('test_structure_out_%02d',k), 'test', ...
            'structure_out', g, random_continuous_theta(sc.parameter_search), ...
            sc.source_tag, sprintf('structure_key_%02d',1 + mod(k-1, numel(out_candidates))), ...
            'legal_one_level_tree_outside_P0');
    end

    dimensions = {'main_length_scale','branch_length_scale','branch_load_scale', ...
        'source_impedance_ohm','receiver_impedance_ohm','joint_parameter_set'};
    for k = 1:sc.parameter_out_sample_count
        g = base(1 + mod(k-1, numel(base)));
        theta = parameter_out_theta(sc.parameter_search, dimensions{1 + mod(k-1,numel(dimensions))}, k);
        cursor = cursor + 1;
        bank(cursor) = make_row(sprintf('test_parameter_out_%02d',k), 'test', ...
            'parameter_out', g, theta, sc.source_tag, theta.outlier_dimension, ...
            theta.outlier_direction);
    end
    bank = bank(:);
end

function row = empty_bank()
    row = struct('sample_id','','split','','category','','truth_topology_id','', ...
        'canonical_key','','truth_network',struct(),'truth_theta',struct(), ...
        'source_tag','','outlier_dimension','','outlier_direction','');
    row = repmat(row, 0, 1);
end

function row = make_row(sample_id, split, category, candidate, theta, source_tag, dimension, direction)
    row = struct('sample_id',sample_id,'split',split,'category',category, ...
        'truth_topology_id',candidate.topology_id, ...
        'canonical_key',candidate.canonical_key,'truth_network',candidate.network, ...
        'truth_theta',theta,'source_tag',source_tag, ...
        'outlier_dimension',dimension,'outlier_direction',direction);
end

function theta = random_continuous_theta(search)
    theta = struct('main_length_scale',draw_off_grid(search.main_length_scale), ...
        'branch_length_scale',draw_off_grid(search.branch_length_scale), ...
        'branch_load_scale',draw_off_grid(search.branch_load_scale), ...
        'source_impedance_ohm',draw_off_grid(search.source_impedance_ohm), ...
        'receiver_impedance_ohm',draw_off_grid(search.receiver_impedance_ohm), ...
        'regularization',NaN,'outlier_dimension','','outlier_direction','');
end

function value = draw_off_grid(points)
    points = points(:).';
    lo = min(points); hi = max(points);
    if hi == lo, value = lo; return; end
    value = lo + (hi-lo) * rand;
    if any(abs(value-points) < 1e-8*max(1,abs(hi-lo)))
        value = lo + (hi-lo) * 0.371;
        if any(abs(value-points) < 1e-8*max(1,abs(hi-lo))), value = lo + (hi-lo)*0.629; end
    end
end

function theta = parameter_out_theta(search, dimension, sample_index)
    theta = random_continuous_theta(search);
    switch dimension
        case 'main_length_scale'
            theta.main_length_scale = max(search.main_length_scale) + 0.07 + 0.002*mod(sample_index,3);
            direction = 'above_max';
        case 'branch_length_scale'
            theta.branch_length_scale = min(search.branch_length_scale) - 0.07 - 0.002*mod(sample_index,3);
            direction = 'below_min';
        case 'branch_load_scale'
            theta.branch_load_scale = max(search.branch_load_scale) + 0.25 + 0.01*mod(sample_index,3);
            direction = 'above_max';
        case 'source_impedance_ohm'
            theta.source_impedance_ohm = max(search.source_impedance_ohm) + 10 + mod(sample_index,3);
            direction = 'above_max';
        case 'receiver_impedance_ohm'
            theta.receiver_impedance_ohm = min(search.receiver_impedance_ohm) - 10 - mod(sample_index,3);
            direction = 'below_min';
        otherwise
            theta.main_length_scale = max(search.main_length_scale) + 0.06;
            theta.branch_length_scale = min(search.branch_length_scale) - 0.06;
            theta.branch_load_scale = max(search.branch_load_scale) + 0.20;
            theta.source_impedance_ohm = max(search.source_impedance_ohm) + 8;
            theta.receiver_impedance_ohm = min(search.receiver_impedance_ohm) - 8;
            direction = 'joint_above_below';
            dimension = 'joint_parameter_set';
    end
    theta.regularization = NaN;
    theta.outlier_dimension = dimension;
    theta.outlier_direction = direction;
end
