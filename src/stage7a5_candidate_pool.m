function [pool,base_indices,grammar]=stage7a5_candidate_pool(base)
%STAGE7A5_CANDIDATE_POOL Enumerate the predeclared one-level branch grammar.
%   IDs are names only; physical identity is stage6b_network_signature.
    sc=stage7a_profile_search_config(base,'formal');
    grammar=sc.stage6b.scale.grammars(1);
    grammar.allowed_branch_main_nodes=[1 2 3];
    grammar.max_side_branches_per_node=2;grammar.max_branches=2;
    grammar.max_nodes=7;grammar.max_candidates=10;
    pool=generate_radial_topology_candidates(grammar);
    for k=1:numel(pool)
        counts=zeros(1,3);
        for b=1:numel(pool(k).network.branches)
            counts(pool(k).network.branches(b).node)= ...
                counts(pool(k).network.branches(b).node)+1;
        end
        pool(k).topology_id=pattern_id(counts);
    end
    ids={pool.topology_id};
    assert(numel(pool)==10&&numel(unique(ids))==10,'stage7a5:GrammarSize');
    base_ids={'G001','G002','G003'};
    base_indices=zeros(1,3);
    for k=1:3
        base_indices(k)=find(strcmp(ids,base_ids{k}),1);
        assert(~isempty(base_indices(k)),'stage7a5:MissingBaselineCandidate');
    end
    sigs=arrayfun(@(x)stage6b_network_signature(x.network),pool,'UniformOutput',false);
    assert(numel(unique(sigs))==10,'stage7a5:SignatureCollision');
    assert(all(arrayfun(@(x)x.validation.connected&&x.validation.acyclic,pool)), ...
        'stage7a5:InvalidGeneratedTopology');
end

function id=pattern_id(counts)
    if isequal(counts,[0 0 0]),id='G001';
    elseif isequal(counts,[0 1 0]),id='G002';
    elseif isequal(counts,[1 0 0]),id='G003';
    elseif isequal(counts,[0 0 1]),id='MIRROR_M3';
    elseif isequal(counts,[1 1 0]),id='ADD_M1_M2';
    elseif isequal(counts,[1 0 1]),id='ADD_M1_M3';
    elseif isequal(counts,[0 1 1]),id='ADD_M2_M3';
    elseif isequal(counts,[2 0 0]),id='DOUBLE_M1';
    elseif isequal(counts,[0 2 0]),id='DOUBLE_M2';
    elseif isequal(counts,[0 0 2]),id='DOUBLE_M3';
    else,error('stage7a5:UnknownPattern');end
end
