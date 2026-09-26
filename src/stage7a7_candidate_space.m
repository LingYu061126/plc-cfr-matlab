function [pool,base_indices,grammar,catalog,groups,steps]= ...
        stage7a7_candidate_space(base,cfg)
%STAGE7A7_CANDIDATE_SPACE Finite 37-graph search pool with generic junction edit.
%   OUT10/OUT70 remain truth-only to test topology grammar-out rejection.
    [old,base_indices,grammar]=stage7a6_candidate_space(base);
    assert(numel(old)==17,'stage7a7:OldPool');
    branch=struct('node',0,'length',grammar.branch_edge_length_m, ...
        'cable_type',grammar.branch_cable_type,'load',grammar.branch_load_ohm);
    pool=old;
    for k=1:numel(old)
        if numel(old(k).network.branches)>=cfg.maximum_branches,continue;end
        for edge=cfg.insert_edges
            net=stage7a7_split_main_edit(old(k).network,edge,cfg,branch);
            counts=branch_counts(old(k).network);
            id=sprintf('J%02d_%d%d%d',sum(old(k).network.main_lengths(1:edge-1))+ ...
                old(k).network.main_lengths(edge)*cfg.insert_fraction,counts);
            pool(end+1)=make_candidate(net,id,old(k),grammar,cfg); %#ok<AGROW>
        end
    end
    sigs=arrayfun(@(x)stage6b_network_signature(x.network),pool, ...
        'UniformOutput',false);
    assert(numel(pool)==37&&numel(unique(sigs))==37&& ...
        numel(unique({pool.topology_id}))==37,'stage7a7:PoolIdentity');
    catalog=repmat(struct('topology_id','','network',struct()),numel(pool)+2,1);
    for k=1:numel(pool)
        catalog(k)=struct('topology_id',pool(k).topology_id, ...
            'network',pool(k).network);
    end
    catalog(end-1)=struct('topology_id','OUT10','network', ...
        truth_only_network([10 10 20 20 20],1,branch));
    catalog(end)=struct('topology_id','OUT70','network', ...
        truth_only_network([20 20 20 10 10],4,branch));
    truth_sigs=arrayfun(@(x)stage6b_network_signature(x.network),catalog, ...
        'UniformOutput',false);
    assert(numel(unique(truth_sigs))==numel(catalog), ...
        'stage7a7:TruthSignatureCollision');
    ids={pool.topology_id};
    groups=struct('inlib',base_indices, ...
        'old_out',indices(ids,{'MIRROR_M3','EXT_111'}), ...
        'reachable',indices(ids,{'J30_000','J50_000'}), ...
        'grammar_out',numel(pool)+(1:2), ...
        'domain',indices(ids,{'G002','G003'}));
    steps=inf(1,numel(catalog));steps(base_indices)=0;
    queue=base_indices(:).';
    while ~isempty(queue)
        parent=queue(1);queue(1)=[];
        near=stage7a7_graph_edit_neighbors(pool,parent);
        for child=near
            if steps(child)>steps(parent)+1
                steps(child)=steps(parent)+1;queue(end+1)=child; %#ok<AGROW>
            end
        end
    end
    assert(all(isfinite(steps(1:numel(pool))))&& ...
        all(steps(groups.reachable)==1)&& ...
        all(isinf(steps(groups.grammar_out))), ...
        'stage7a7:EditReachability');
    grammar.stage7a7_insert_edges=cfg.insert_edges;
    grammar.stage7a7_minimum_segment_m=cfg.minimum_main_segment_m;
    grammar.stage7a7_maximum_total_nodes=cfg.maximum_total_nodes;
end

function counts=branch_counts(net)
    counts=zeros(1,3);
    for b=1:numel(net.branches)
        counts(net.branches(b).node)=counts(net.branches(b).node)+1;
    end
end
function out=indices(ids,requested)
    out=zeros(1,numel(requested));
    for k=1:numel(requested)
        out(k)=find(strcmp(ids,requested{k}),1);
        assert(~isempty(out(k)),'stage7a7:MissingId');
    end
end
function net=truth_only_network(lengths,node,branch)
    branch.node=node;
    net=struct('main_lengths',lengths, ...
        'main_cable_type',zeros(1,numel(lengths)),'branches',branch);
end
function candidate=make_candidate(net,id,prototype,g,cfg)
    candidate=prototype;candidate.topology_id=id;candidate.network=net;
    candidate.canonical_key=stage6b_network_signature(net);
    nmain=numel(net.main_lengths)+1;
    labels=cell(1,nmain);labels{1}=candidate.source_node;
    for k=2:nmain-1,labels{k}=sprintf('M%d',k-1);end
    labels{end}=candidate.receiver_node;
    nodes=struct('id',{},'role',{});
    for k=1:nmain
        role='main';
        if k==1,role='source';end
        if k==nmain,role='receiver';end
        nodes(end+1)=struct('id',labels{k},'role',role); %#ok<AGROW>
    end
    edges=struct('id',{},'from',{},'to',{},'kind',{}, ...
        'length_m',{},'cable_type',{},'load',{});
    main_ids=cell(1,nmain-1);branch_ids=cell(1,numel(net.branches));
    for k=1:nmain-1
        eid=sprintf('M_%d_%d',k-1,k);main_ids{k}=eid;
        edges(end+1)=struct('id',eid,'from',labels{k}, ...
            'to',labels{k+1},'kind','main', ...
            'length_m',net.main_lengths(k), ...
            'cable_type',net.main_cable_type(k),'load',NaN); %#ok<AGROW>
    end
    for k=1:numel(net.branches)
        b=net.branches(k);terminal=sprintf('B%d_LOAD',k);
        nodes(end+1)=struct('id',terminal,'role','branch_load'); %#ok<AGROW>
        eid=sprintf('B_%d_%d',b.node,k);branch_ids{k}=eid;
        edges(end+1)=struct('id',eid,'from',labels{b.node+1}, ...
            'to',terminal,'kind','branch','length_m',b.length, ...
            'cable_type',b.cable_type,'load',b.load); %#ok<AGROW>
    end
    candidate.nodes=nodes;candidate.edges=edges;
    candidate.main_path_edges=main_ids;candidate.branch_edges=branch_ids;
    candidate.node_count=numel(nodes);candidate.edge_count=numel(edges);
    g.main_path_segments=5;g.max_nodes=cfg.maximum_total_nodes;
    g.max_branches=cfg.maximum_branches;
    candidate.generation_config=g;
    candidate.validation=validate_radial_topology_candidate(candidate,g);
end
