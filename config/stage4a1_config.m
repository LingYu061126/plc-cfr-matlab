function sc = stage4a1_config(base_cfg)
%STAGE4A1_CONFIG Frozen small-scale candidate-library audit configuration.
%   This configuration is independent of stages 1--3.  Its parameter grid
%   is explicitly derived from the existing stage-2.3 search definition,
%   narrowed to its nominal point for a bounded model-internal audit.

    if nargin < 1 || isempty(base_cfg)
        root = fileparts(fileparts(mfilename('fullpath')));
        base_cfg = default_config(root);
    end
    search = base_cfg.stage2_3.search;
    search.main_length_scale = 1;
    search.branch_length_scale = 1;
    search.branch_load_scale = 1;
    search.source_impedance_ohm = search.nominal_source_impedance_ohm;
    search.receiver_impedance_ohm = search.nominal_receiver_impedance_ohm;

    sc = struct();
    sc.stage_name = 'Stage 4A.1';
    sc.version = '4a1_candidate_library_audit_v1';
    sc.random_seed = 20260905;
    sc.frequency_hz = linspace(2e6,30e6,61);
    sc.measurement_kind = 'siso_forward';
    sc.tie_tolerance = base_cfg.stage2_3.tie_tolerance;
    sc.max_composite_templates = 32;
    sc.output_prefix = 'stage4a1';
    sc.parameter_search_source = 'default_config.stage2_3.search (nominal subset)';
    sc.parameter_search = search;
    sc.generator = struct( ...
        'source_node_id','TX', 'receiver_node_id','RX', ...
        'max_nodes',8, 'max_branches',2, 'main_path_segments',4, ...
        'allowed_branch_main_nodes',[1 2 3], ...
        'max_side_branches_per_node',1, 'max_branch_depth',1, ...
        'radial_only',true, 'main_edge_length_m',20, ...
        'branch_edge_length_m',15, 'main_cable_type',0, ...
        'branch_cable_type',1, 'branch_load_ohm',50, ...
        'fixed_siso_endpoint_protocol',true, 'max_candidates',16);
end
