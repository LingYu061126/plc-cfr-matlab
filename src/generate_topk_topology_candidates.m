function [candidates, audit] = generate_topk_topology_candidates(spec, top_k)
%GENERATE_TOPK_TOPOLOGY_CANDIDATES Lazy constrained prior-cost Top-K trees.
%   Deterministic best-first branch-and-bound.  The objective is the
%   configured nonnegative engineering prior cost, not a CFR ranking.
    if nargin<2 || isempty(top_k), top_k=10; end
    if ~isscalar(top_k) || top_k<1 || top_k~=fix(top_k)
        error('stage4a7_2:InvalidTopK','top_k must be a positive integer.');
    end
    spec=normalize_engineering_candidate_spec(spec);
    n=numel(spec.node_ids); target=n-1;
    forbidden=spec.forbidden_edge_keys; req=spec.required_edges;
    optional=spec.allowed_edges(~ismember(endpoint_keys(spec.allowed_edges),forbidden));
    req_keys=endpoint_keys(req); opt_keys=endpoint_keys(optional);
    optional=optional(~ismember(opt_keys,req_keys)); opt_keys=opt_keys(~ismember(opt_keys,req_keys));
    [opt_keys,ord]=sort(opt_keys); optional=optional(ord);
    all_keys=endpoint_keys(spec.allowed_edges); [~,loc]=ismember(opt_keys,all_keys);
    costs=spec.edge_prior_cost(loc);
    [selected,parent,degree,req_cost]=required_state(req,spec);
    if numel(selected)>target
        candidates=repmat(make_empty_candidate(),1,0); audit=base_audit(spec,top_k); audit.required_forbidden_pruned=1; audit.exhausted=true; return;
    end
    initial=state_template(); initial.pos=1; initial.selected=selected; initial.parent=parent; initial.degree=degree;
    initial.cost=req_cost; initial.lower_bound=lower_bound(initial,optional,costs,target); initial.state_key=state_key(initial);
    queue=initial; candidates=repmat(make_empty_candidate(),1,0); seen_complete={}; stats=stats_template(); stats.states_pushed=1; stats.peak_queue_size=1;
    while ~isempty(queue)
        [s,queue]=pop_queue(queue); stats.states_popped=stats.states_popped+1;
        if numel(candidates)>=top_k && s.lower_bound>candidates(end).prior_cost
            stats.bound_pruned=stats.bound_pruned+1; break;
        end
        stats.states_expanded=stats.states_expanded+1;
        need=target-numel(s.selected); remaining=numel(optional)-s.pos+1;
        if need<0 || need>remaining, stats.edge_count_pruned=stats.edge_count_pruned+1; continue; end
        if need==0
            if spec.require_connected && ~is_connected(s.selected,spec.node_ids), stats.connectivity_pruned=stats.connectivity_pruned+1; continue; end
            c=pack_candidate(s.selected,s,spec); key=c.canonical_graph_key;
            if any(strcmp(seen_complete,key)), stats.duplicate_pruned=stats.duplicate_pruned+1; continue; end
            seen_complete{end+1}=key; candidates(end+1)=c; %#ok<AGROW>
            stats.complete_candidates=stats.complete_candidates+1; candidates=candidate_order(candidates);
            if numel(candidates)>top_k, candidates=candidates(1:top_k); end
            continue;
        end
        if s.pos>numel(optional), stats.edge_count_pruned=stats.edge_count_pruned+1; continue; end
        e=optional(s.pos); [ok,p2,d2,reason]=try_add(e,s.selected,s.parent,s.degree,spec);
        if ok
            inc=s; inc.pos=s.pos+1; inc.selected=[s.selected e]; inc.parent=p2; inc.degree=d2; inc.cost=s.cost+costs(s.pos); inc.lower_bound=lower_bound(inc,optional,costs,target); inc.state_key=state_key(inc);
            queue(end+1)=inc; stats.states_pushed=stats.states_pushed+1; %#ok<AGROW>
        elseif strcmp(reason,'degree')
            stats.degree_pruned=stats.degree_pruned+1;
        else
            stats.cycle_pruned=stats.cycle_pruned+1;
        end
        exc=s; exc.pos=s.pos+1; exc.lower_bound=lower_bound(exc,optional,costs,target); exc.state_key=state_key(exc);
        if target-numel(exc.selected)<=numel(optional)-exc.pos+1
            queue(end+1)=exc; stats.states_pushed=stats.states_pushed+1; %#ok<AGROW>
        else
            stats.edge_count_pruned=stats.edge_count_pruned+1;
        end
        stats.peak_queue_size=max(stats.peak_queue_size,numel(queue));
    end
    exhausted=isempty(queue) || (numel(candidates)>=top_k && queue_min_bound(queue)>candidates(end).prior_cost);
    audit=base_audit(spec,top_k); audit=merge_audit(audit,stats); audit.returned_count=numel(candidates); audit.exhausted=exhausted; audit.topk_key_set={candidates.canonical_graph_key}; audit.prototype_status='lazy_best_first_branch_and_bound_prior_cost_v1';
end

function [selected,p,d,cost]=required_state(req,spec)
    selected=repmat(edge_template(),1,0); p=1:numel(spec.node_ids); d=zeros(1,numel(p)); cost=0;
    for k=1:numel(req)
        [ok,p,d]=try_add(req(k),selected,p,d,spec); if ~ok,error('stage4a7_2:RequiredCycle','Required edges form a cycle or violate degree.');end
        selected(end+1)=req(k); j=find(strcmp(endpoint_keys(spec.allowed_edges),endpoint_keys(req(k))),1); cost=cost+spec.edge_prior_cost(j);
    end
end
function lb=lower_bound(s,edges,costs,target)
    need=target-numel(s.selected); if need<=0,lb=s.cost;return;end
    if s.pos>numel(edges),lb=Inf;return;end
    z=sort(costs(s.pos:end)); if numel(z)<need,lb=Inf;else,lb=s.cost+sum(z(1:need));end
end
function s=state_template(),s=struct('pos',1,'selected',repmat(edge_template(),1,0),'parent',[],'degree',[],'cost',0,'lower_bound',0,'state_key','');end
function [state,q]=pop_queue(q)
    order=1:numel(q); for i=2:numel(order),x=order(i);j=i-1;while j>=1&&(q(x).lower_bound<q(order(j)).lower_bound||(q(x).lower_bound==q(order(j)).lower_bound&&strcmp(q(x).state_key,q(order(j)).state_key)<0)),order(j+1)=order(j);j=j-1;end;order(j+1)=x;end
    state=q(order(1)); q=q(order(2:end));
end
function x=queue_min_bound(q),x=min([q.lower_bound]);end
function key=state_key(s),if isempty(s.selected),e='';else,e=strjoin(endpoint_keys(s.selected),',');end;key=sprintf('%06d|%s',s.pos,e);end
function [ok,p2,d2,reason]=try_add(e,selected,p,d,spec)
    i=find(strcmp(spec.node_ids,e.from),1);j=find(strcmp(spec.node_ids,e.to),1);p2=p;d2=d;ok=false;reason='cycle';
    if isempty(i)||isempty(j)||i==j,reason='invalid';return;end
    if d(i)>=spec.maximum_degree||d(j)>=spec.maximum_degree,reason='degree';return;end
    if any(strcmp(endpoint_keys(selected),endpoint_keys(e))),reason='duplicate';return;end
    ri=find_root(p,i);rj=find_root(p,j);if ri==rj,reason='cycle';return;end
    p2(ri)=rj;d2(i)=d2(i)+1;d2(j)=d2(j)+1;ok=true;reason='ok';
end
function r=find_root(p,i),r=i;while p(r)~=r,r=p(r);end,end
function tf=is_connected(edges,ids)
    if numel(ids)<=1,tf=true;return;end;seen=false(1,numel(ids));seen(1)=true;changed=true;
    while changed,changed=false;for k=1:numel(edges),i=find(strcmp(ids,edges(k).from),1);j=find(strcmp(ids,edges(k).to),1);if seen(i)&&~seen(j),seen(j)=true;changed=true;elseif seen(j)&&~seen(i),seen(i)=true;changed=true;end,end,end;tf=all(seen);
end
function c=pack_candidate(edges,s,spec)
    meta=struct('generation_route','optimization_topk_lazy_best_first','generation_trace',struct('state_key',s.state_key,'lower_bound',s.lower_bound), 'satisfied_constraints',{{'radial','connected','required_edges','degree_bound'}},'prior_cost',s.cost,'prior_source',spec.prior_source,'prior_config_hash',spec.prior_config_hash);
    c=canonicalize_asset_graph(spec.node_ids,edges,meta);c.edges=edges;c.graph_candidate_id='';c.source_node_id=getf(spec,'source_node_id','');c.receiver_node_id=getf(spec,'receiver_node_id','');c.generation_route='optimization_topk_lazy_best_first';c.generation_trace=meta.generation_trace;c.satisfied_constraints=meta.satisfied_constraints;c.prior_cost=s.cost;c.prior_source=spec.prior_source;c.prior_config_hash=spec.prior_config_hash;c.forward_model_compatible=NaN;c.compatibility_reason='not_checked';c.adapter_hash='';c.scored_library_included=false;
end
function c=make_empty_candidate(),c=struct('node_ids',{{}},'edges',repmat(edge_template(),1,0),'sorted_edge_set',{{}},'canonical_graph_key','','graph_candidate_id','','source_node_id','','receiver_node_id','','generation_route','','generation_trace',struct(),'satisfied_constraints',{{}},'prior_cost',NaN,'prior_source','','prior_config_hash','','forward_model_compatible',NaN,'compatibility_reason','','adapter_hash','','scored_library_included',false);end
function c=candidate_order(c)
    if numel(c)<2,return;end;order=1:numel(c);for i=2:numel(order),x=order(i);j=i-1;while j>=1&&(c(x).prior_cost<c(order(j)).prior_cost||(c(x).prior_cost==c(order(j)).prior_cost&&strcmp(c(x).canonical_graph_key,c(order(j)).canonical_graph_key)<0)),order(j+1)=order(j);j=j-1;end;order(j+1)=x;end;c=c(order);
end
function a=base_audit(spec,k),a=struct('allowed_edge_count',numel(spec.allowed_edges),'theoretical_edge_subset_count',safe_nchoosek(numel(spec.allowed_edges),numel(spec.node_ids)-1),'candidate_count',0,'duplicate_count',spec.duplicate_count,'top_k',k,'returned_count',0,'no_good_cut_count',0,'states_pushed',0,'states_popped',0,'states_expanded',0,'complete_candidates',0,'cycle_pruned',0,'degree_pruned',0,'required_forbidden_pruned',0,'connectivity_pruned',0,'bound_pruned',0,'duplicate_pruned',0,'edge_count_pruned',0,'peak_queue_size',0,'runtime_seconds',NaN,'exhausted',false,'exact_key_set',{{}},'topk_key_set',{{}},'prototype_status','');end
function a=merge_audit(a,s),names=fieldnames(s);for k=1:numel(names),a.(names{k})=s.(names{k});end,end
function s=stats_template(),s=struct('states_pushed',0,'states_popped',0,'states_expanded',0,'complete_candidates',0,'cycle_pruned',0,'degree_pruned',0,'required_forbidden_pruned',0,'connectivity_pruned',0,'bound_pruned',0,'duplicate_pruned',0,'edge_count_pruned',0,'peak_queue_size',0);end
function k=endpoint_keys(e),k=cell(1,numel(e));for i=1:numel(e),p=sort({e(i).from,e(i).to});k{i}=[p{1} '--' p{2}];end,end
function n=safe_nchoosek(m,k),if k<0||k>m,n=0;elseif m>60,n=Inf;else,n=nchoosek(m,k);end,end
function e=edge_template(),e=struct('id','','from','','to','','kind','line','length_m',NaN,'cable_type',[],'load',NaN,'prior_cost',NaN);end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
