function rows=stage4a7_2_r1_topk_scaling_audit(sc)
%STAGE4A7_2_R1_TOPK_SCALING_AUDIT Medium shared edge-universe benchmark.
%   The implementation is a constrained best-first branch-and-bound prior-
%   cost prototype, not an Eppstein implementation.
    nodes=arrayfun(@(k)sprintf('N%d',k),1:sc.topk_scaling.node_count,'UniformOutput',false);
    pairs=[1 2;2 3;3 4;4 5;5 6;6 7;7 8;1 3;2 4;3 5;4 6;5 7;6 8;1 5;2 6;3 7;4 8;1 8];
    edge0=struct('id','','from','','to','','kind','line','length_m',1,'cable_type',0,'load',50,'prior_cost',1);
    e=repmat(edge0,size(pairs,1),1);cost=zeros(size(pairs,1),1);
    for k=1:size(pairs,1)
        e(k).id=sprintf('M%02d',k);e(k).from=nodes{pairs(k,1)};e(k).to=nodes{pairs(k,2)};e(k).prior_cost=1+0.01*k;cost(k)=e(k).prior_cost;
    end
    spec=struct('node_ids',{nodes},'source_node_id','N1','receiver_node_id','N8', ...
        'allowed_edges',e,'required_edges',e(1),'forbidden_edges',e(end), ...
        'edge_prior_cost',cost,'maximum_degree',4,'maximum_candidate_count',sc.topk_scaling.maximum_candidate_count, ...
        'radial_only',true,'require_connected',true,'prior_source','stage4a7_2_r1_medium_control');
    t0=tic;[allc,full_audit]=generate_engineering_topology_candidates(spec);exact_runtime=toc(t0);
    rows=repmat(struct('top_k',0,'total_feasible_candidates',numel(allc), ...
        'states_pushed',0,'states_popped',0,'states_expanded',0,'complete_candidates',0, ...
        'cycle_pruned',0,'degree_pruned',0,'connectivity_pruned',0,'bound_pruned',0, ...
        'peak_queue_size',0,'runtime_seconds',NaN,'exhaustive_runtime_seconds',exact_runtime, ...
        'speedup',NaN,'returned_count',0,'key_consistent_with_exhaustive',false, ...
        'prototype_status',''),1,numel(sc.topk_scaling.top_k_values));
    exact_keys={allc.canonical_graph_key};
    for q=1:numel(rows)
        k=sc.topk_scaling.top_k_values(q);t=tic;[top,a]=generate_topk_topology_candidates(spec,k);rt=toc(t);rows(q).top_k=k;rows(q).states_pushed=a.states_pushed;rows(q).states_popped=a.states_popped;rows(q).states_expanded=a.states_expanded;rows(q).complete_candidates=a.complete_candidates;rows(q).cycle_pruned=a.cycle_pruned;rows(q).degree_pruned=a.degree_pruned;rows(q).connectivity_pruned=a.connectivity_pruned;rows(q).bound_pruned=a.bound_pruned;rows(q).peak_queue_size=a.peak_queue_size;rows(q).runtime_seconds=rt;rows(q).returned_count=numel(top);rows(q).speedup=exact_runtime/max(rt,eps);rows(q).key_consistent_with_exhaustive=all(ismember({top.canonical_graph_key},exact_keys))&&numel(unique({top.canonical_graph_key}))==numel(top);rows(q).prototype_status=a.prototype_status;
    end
    if any(sc.topk_scaling.top_k_values==numel(allc))
        q=find(sc.topk_scaling.top_k_values==numel(allc),1);
        [alltop,~]=generate_topk_topology_candidates(spec,numel(allc));
        rows(q).key_consistent_with_exhaustive=isequal({alltop.canonical_graph_key},exact_keys);
    end
end
