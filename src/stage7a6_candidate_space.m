function [pool,base_indices,grammar,truth_catalog,groups,edit_steps]= ...
        stage7a6_candidate_space(base)
%STAGE7A6_CANDIDATE_SPACE Expand one-level branch counts without truth leakage.
%   The searchable pool has 17 four-segment trees. MID30/MID50 are separate
%   truth-only five-segment trees; they are never returned in pool.
    [old,~,grammar]=stage7a5_candidate_pool(base);
    old_sigs=arrayfun(@(x)stage6b_network_signature(x.network),old, ...
        'UniformOutput',false);
    grammar.max_branches=3;
    grammar.max_nodes=8;
    grammar.max_candidates=17;
    pool=generate_radial_topology_candidates(grammar);
    assert(numel(pool)==17,'stage7a6:PoolSize');
    for k=1:numel(pool)
        sig=stage6b_network_signature(pool(k).network);
        j=find(strcmp(old_sigs,sig),1);
        if ~isempty(j)
            pool(k).topology_id=old(j).topology_id;
        else
            counts=branch_counts(pool(k).network);
            pool(k).topology_id=sprintf('EXT_%d%d%d',counts);
        end
        assert(pool(k).validation.connected&&pool(k).validation.acyclic, ...
            'stage7a6:InvalidPoolGraph');
    end
    ids={pool.topology_id};
    assert(numel(unique(ids))==17,'stage7a6:DuplicateIds');
    base_indices=indices(ids,{'G001','G002','G003'});
    assert(numel(base_indices)==3,'stage7a6:MissingBase');
    truth_catalog=repmat(struct('topology_id','','network',struct()),1,19);
    for k=1:17
        truth_catalog(k)=struct('topology_id',pool(k).topology_id, ...
            'network',pool(k).network);
    end
    % A junction at 30 or 50 m needs a main-edge subdivision edit. The
    % current count-based editor cannot create either connection location.
    truth_catalog(18)=struct('topology_id','MID30', ...
        'network',midpoint_network([20 10 10 20 20],2));
    truth_catalog(19)=struct('topology_id','MID50', ...
        'network',midpoint_network([20 20 10 10 20],3));
    all_sigs=arrayfun(@(x)stage6b_network_signature(x.network),truth_catalog, ...
        'UniformOutput',false);
    assert(numel(unique(all_sigs))==19,'stage7a6:TruthSignatureCollision');
    old_ids={old.topology_id};
    groups=struct();
    groups.inlib=base_indices;
    groups.old_out=indices(ids, ...
        {'MIRROR_M3','ADD_M1_M3','ADD_M2_M3','DOUBLE_M3'});
    groups.reachable=indices(ids,{'EXT_111','EXT_021'});
    groups.grammar_out=[18 19];
    groups.domain=indices(ids,{'G002','G003'});
    assert(all(~ismember(groups.reachable,indices(ids,old_ids)))&& ...
        all(groups.grammar_out>numel(pool)),'stage7a6:ExtrapolationIdentity');
    edit_steps=inf(1,numel(truth_catalog));
    edit_steps(base_indices)=0;
    queue=base_indices(:).';
    while ~isempty(queue)
        parent=queue(1);queue(1)=[];
        near=stage7a5_graph_edit_neighbors(pool,parent);
        for child=near
            if edit_steps(child)>edit_steps(parent)+1
                edit_steps(child)=edit_steps(parent)+1;
                queue(end+1)=child; %#ok<AGROW>
            end
        end
    end
    assert(all(isfinite(edit_steps(1:17)))&& ...
        all(edit_steps(groups.reachable)==2)&& ...
        all(isinf(edit_steps(groups.grammar_out))), ...
        'stage7a6:EditReachability');
end

function out=indices(all_ids,requested)
    out=zeros(1,numel(requested));
    for k=1:numel(requested)
        j=find(strcmp(all_ids,requested{k}),1);
        assert(~isempty(j),'stage7a6:MissingGraph','Missing %s.',requested{k});
        out(k)=j;
    end
end
function counts=branch_counts(network)
    counts=zeros(1,3);
    for b=1:numel(network.branches)
        counts(network.branches(b).node)=counts(network.branches(b).node)+1;
    end
end
function network=midpoint_network(lengths,branch_node)
    branches=struct('node',branch_node,'length',15, ...
        'cable_type',1,'load',50);
    network=struct('main_lengths',lengths,'main_cable_type', ...
        zeros(1,numel(lengths)),'branches',branches);
end
