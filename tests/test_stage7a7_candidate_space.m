function test_stage7a7_candidate_space(root)
%TEST_STAGE7A7_CANDIDATE_SPACE Generic junction, identity, reachability.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage7a7_config(base,'smoke','nominal');
    [pool,base_ix,~,catalog,groups,steps]=stage7a7_candidate_space(base,cfg);
    assert(numel(pool)==37&&numel(catalog)==39);
    assert(all(steps(groups.reachable)==1)&& ...
        all(isinf(steps(groups.grammar_out))));
    assert(isequal(sort({pool(base_ix).topology_id}), ...
        sort({'G001','G002','G003'})));
    sigs=arrayfun(@(x)stage6b_network_signature(x.network),pool, ...
        'UniformOutput',false);
    assert(numel(unique(sigs))==37);
    for j=groups.reachable
        assert(numel(pool(j).network.main_lengths)==5&& ...
            sum(pool(j).network.main_lengths)==80&& ...
            pool(j).validation.connected&&pool(j).validation.acyclic);
        near=stage7a7_graph_edit_neighbors(pool,base_ix(1));
        assert(any(near==j),'A junction target is not reachable by generic edit.');
    end
    for j=groups.grammar_out
        assert(~any(strcmp(sigs,stage6b_network_signature(catalog(j).network))));
    end
    theta=struct('main_length_scale',1,'branch_length_scale',1, ...
        'branch_load_scale',1,'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
    for j=[groups.reachable groups.grammar_out]
        z=stage7a4_forward_state(catalog(j).network,theta,base, ...
            cfg.frequency_hz,cfg.state_50);
        assert(all(isfinite(z.H_endpoint))&&all(isfinite(z.Zin)));
    end
    fprintf('PASS test_stage7a7_candidate_space\n');
end
