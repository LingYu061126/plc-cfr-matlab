function [candidates, audit] = generate_topk_topology_candidates(spec, top_k)
%GENERATE_TOPK_TOPOLOGY_CANDIDATES Route-B deterministic Top-K prototype.
%   The prototype uses the exact constrained-tree oracle, ranks feasible
%   graphs by configured soft edge cost, and applies deterministic no-good
%   keys to prevent duplicate outputs.  It is intentionally not advertised
%   as a MILP/MIQP solver; that dependency remains a future implementation.
    if nargin<2||isempty(top_k),top_k=10;end
    if ~isscalar(top_k)||top_k<1,error('stage4a7_1:InvalidTopK','top_k must be positive.');end
    [all_candidates, full_audit]=generate_engineering_topology_candidates(spec);
    if isempty(all_candidates)
        candidates=all_candidates; audit=full_audit; audit.top_k=top_k; audit.returned_count=0;
        audit.no_good_cut_count=0; audit.prototype_status='no_feasible_engineering_candidate';
        audit.exact_key_set={}; audit.topk_key_set={}; return;
    end
    costs=[all_candidates.prior_cost]; keys={all_candidates.canonical_graph_key};
    [~,ord]=sortrows([costs(:),(1:numel(costs)).'],[1 2]);
    chosen=repmat(all_candidates(1),1,0); seen={}; no_good=0;
    for q=1:numel(ord)
        c=all_candidates(ord(q));
        if any(strcmp(seen,c.canonical_graph_key)),no_good=no_good+1;continue;end
        seen{end+1}=c.canonical_graph_key; %#ok<AGROW>
        c.generation_route='optimization_topk_prototype';
        c.generation_trace=struct('solver','exact_oracle_ranked_prototype','no_good_cut_count',no_good, ...
            'prototype_status','no_milp_dependency','source_route','route_A_exact_feasible_set');
        chosen(end+1)=c; %#ok<AGROW>
        if numel(chosen)>=top_k,break;end
    end
    candidates=chosen;
    audit=full_audit;audit.top_k=top_k;audit.returned_count=numel(candidates);audit.no_good_cut_count=no_good;
    audit.prototype_status='no_milp_dependency_exact_oracle_ranked';
    audit.exact_key_set={all_candidates.canonical_graph_key};audit.topk_key_set={candidates.canonical_graph_key};
end
