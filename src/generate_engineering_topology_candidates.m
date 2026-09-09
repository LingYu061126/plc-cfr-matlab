function [candidates, audit] = generate_engineering_topology_candidates(spec)
%GENERATE_ENGINEERING_TOPOLOGY_CANDIDATES Enumerate constrained asset trees.
%   This is Route A of Stage 4A.7.1.  It searches combinations of eligible
%   edges with early cycle, degree, connectivity, required-edge and
%   remaining-edge pruning; it never enumerates the full edge power set.
%   The output is an engineering candidate layer.  Forward-model support is
%   assessed separately by check_forward_model_compatibility.
    spec = normalize_engineering_candidate_spec(spec);
    n = numel(spec.node_ids); m = numel(spec.allowed_edges); target = n-1;
    if n < 1, error('stage4a7_1:EmptyNodeSet','At least one node is required.'); end
    if target == 0
        candidates = make_candidates(spec,{},struct('index',1));
        audit = finalize_audit(spec,0,0,stats_template(),candidates); return;
    end
    keys = endpoint_keys(spec.allowed_edges);
    [~,ord] = sort(keys); spec.allowed_edges = spec.allowed_edges(ord); spec.edge_prior_cost = spec.edge_prior_cost(ord); keys=keys(ord);
    req_keys = endpoint_keys(spec.required_edges); forb_keys=endpoint_keys(spec.forbidden_edges);
    if ~isempty(intersect(req_keys,forb_keys))
        error('stage4a7_1:RequiredForbiddenConflict','Required and forbidden edges overlap.');
    end
    allowed_keys = keys;
    if any(~ismember(req_keys,allowed_keys))
        error('stage4a7_1:RequiredEdgeUnavailable','A required edge is absent from allowed_edges.');
    end
    eligible = spec.allowed_edges(~ismember(keys,forb_keys));
    ekeys = endpoint_keys(eligible);
    req_mask = ismember(ekeys,req_keys);
    required = eligible(req_mask); optional = eligible(~req_mask);
    [selected, parent, degree] = add_required(required,spec);
    if numel(selected) > target
        error('stage4a7_1:TooManyRequiredEdges','Required edges exceed spanning-tree size.');
    end
    stats = stats_template(); stats.theoretical_edge_subset_count = safe_nchoosek(m,target); stats.duplicate_count=spec.duplicate_count;
    candidates = repmat(empty_candidate(),1,0);
    walk(1,selected,parent,degree);
    if isempty(candidates) && spec.require_connected
        % Keep a deterministic empty result; the audit explains why.
    end
    if ~isempty(candidates)
        candidates=candidate_order(candidates);
        for k=1:numel(candidates), candidates(k).graph_candidate_id=sprintf('EC%04d',k); end
    end
    audit = finalize_audit(spec,m,target,stats,candidates);

    function walk(pos, selected_edges, p, deg)
        stats.search_node_count=stats.search_node_count+1;
        need = target-numel(selected_edges); remaining = numel(optional)-pos+1;
        if need < 0 || need > remaining, stats.remaining_edge_pruned=stats.remaining_edge_pruned+1; return; end
        if any(deg>spec.maximum_degree), stats.degree_pruned=stats.degree_pruned+1; return; end
        if ~potentially_connected(selected_edges,optional(pos:end),spec.node_ids)
            stats.connectivity_pruned=stats.connectivity_pruned+1; return;
        end
        if need==0
            if spec.require_connected && ~is_connected(selected_edges,spec.node_ids)
                stats.connectivity_pruned=stats.connectivity_pruned+1; return;
            end
            stats.feasible_tree_count=stats.feasible_tree_count+1;
            meta=struct('graph_candidate_id','','source_node_id',getf(spec,'source_node_id',''),'receiver_node_id',getf(spec,'receiver_node_id',''),'generation_route','engineering_edge_universe', ...
                'generation_trace',stats,'satisfied_constraints',{{'radial','connected','required_edges','degree_bound'}}, ...
                'prior_cost',edge_cost(selected_edges,spec),'prior_source',spec.prior_source, ...
                'prior_config_hash',spec.prior_config_hash);
            graph=canonicalize_asset_graph(spec.node_ids,selected_edges,meta);
            candidates(end+1)=pack_candidate(graph,selected_edges,meta); %#ok<AGROW>
            if numel(candidates)>spec.maximum_candidate_count
                error('stage4a7_1:MaxCandidatesExceeded','Candidate cap %d exceeded.',spec.maximum_candidate_count);
            end
            return;
        end
        if pos>numel(optional), return; end
        e=optional(pos);
        [can,p2,d2,reason]=try_add(e,selected_edges,p,deg,spec);
        if can
            walk(pos+1,[selected_edges e],p2,d2);
        elseif strcmp(reason,'degree')
            stats.degree_pruned=stats.degree_pruned+1;
        else
            stats.cycle_pruned=stats.cycle_pruned+1;
        end
        walk(pos+1,selected_edges,p,deg);
    end
end

function spec=normalize_spec(spec)
    required={'node_ids','allowed_edges'};
    for k=1:numel(required),if ~isfield(spec,required{k}),error('stage4a7_1:MissingSpec','Missing %s.',required{k});end,end
    spec.node_ids=stage4a7_1_cellstr(spec.node_ids);
    spec.allowed_edges=normalize_edges(spec.allowed_edges);
    if ~isfield(spec,'required_edges')||isempty(spec.required_edges),spec.required_edges=normalize_edges([]);else,spec.required_edges=normalize_edges(spec.required_edges);end
    if ~isfield(spec,'forbidden_edges')||isempty(spec.forbidden_edges),spec.forbidden_edges=normalize_edges([]);else,spec.forbidden_edges=normalize_edges(spec.forbidden_edges);end
    if ~isfield(spec,'maximum_degree')||isempty(spec.maximum_degree),spec.maximum_degree=Inf;end
    if ~isfield(spec,'radial_only'),spec.radial_only=true;end
    if ~isfield(spec,'require_connected'),spec.require_connected=true;end
    if ~isfield(spec,'maximum_candidate_count')||isempty(spec.maximum_candidate_count),spec.maximum_candidate_count=1e5;end
    if ~isfield(spec,'prior_source'),spec.prior_source='synthetic_demo_prior_not_field_data';end
    if ~isfield(spec,'prior_config_hash')||isempty(spec.prior_config_hash),spec.prior_config_hash=stage4a4_scientific_config_hash(spec);end
    if isfield(spec,'edge_prior_cost')&&~isempty(spec.edge_prior_cost)
        spec.edge_prior_cost=spec.edge_prior_cost(:);
    else
        spec.edge_prior_cost=zeros(numel(spec.allowed_edges),1);
    end
    if numel(spec.edge_prior_cost)~=numel(spec.allowed_edges),error('stage4a7_1:CostLength','edge_prior_cost length mismatch.');end
end

function [selected,parent,degree]=add_required(required,spec)
    selected=repmat(edge_template(),1,0); parent=1:numel(spec.node_ids); degree=zeros(1,numel(parent)); ids=spec.node_ids;
    for k=1:numel(required)
        [ok,parent,degree]=try_add(required(k),selected,parent,degree,spec);
        if ~ok,error('stage4a7_1:RequiredCycle','Required edges form a cycle.');end
        selected(end+1)=required(k); %#ok<AGROW>
    end
    %#ok<NASGU>
end
function [ok,p2,d2,reason]=try_add(e,selected,p,d,spec)
    ids=spec.node_ids; i=find(strcmp(ids,e.from),1);j=find(strcmp(ids,e.to),1);p2=p;d2=d;ok=false;reason='cycle';
    if isempty(i)||isempty(j)||i==j,reason='invalid';return;end
    if d(i)>=spec.maximum_degree||d(j)>=spec.maximum_degree,reason='degree';return;end
    ri=find_root(p,i);rj=find_root(p,j);if ri==rj,reason='cycle';return;end
    p2(ri)=rj;d2(i)=d2(i)+1;d2(j)=d2(j)+1;ok=true;reason='ok';
end
function r=find_root(p,i),r=i;while p(r)~=r,r=p(r);end,end
function tf=is_connected(edges,ids)
    if numel(ids)<=1,tf=true;return;end
    seen=false(1,numel(ids));seen(1)=true;changed=true;
    while changed,changed=false;for k=1:numel(edges),i=find(strcmp(ids,edges(k).from),1);j=find(strcmp(ids,edges(k).to),1);if seen(i)&&~seen(j),seen(j)=true;changed=true;elseif seen(j)&&~seen(i),seen(i)=true;changed=true;end,end,end
    tf=all(seen);
end
function tf=potentially_connected(selected,remaining,ids),tf=is_connected([selected remaining],ids);end
function candidates=make_candidates(spec,edges,trace)
    meta=struct('source_node_id',getf(spec,'source_node_id',''),'receiver_node_id',getf(spec,'receiver_node_id',''),'generation_route','engineering_edge_universe','generation_trace',trace,'prior_cost',0,'prior_source',spec.prior_source,'prior_config_hash',spec.prior_config_hash);
    g=canonicalize_asset_graph(spec.node_ids,edges,meta); candidates=pack_candidate(g,edges,meta); candidates.graph_candidate_id='EC0001';
end
function c=pack_candidate(g,edges,meta)
    c=g;c.edges=edges;c.graph_candidate_id=g.graph_candidate_id;c.source_node_id=getf(meta,'source_node_id','');c.receiver_node_id=getf(meta,'receiver_node_id','');c.generation_route=meta.generation_route;c.generation_trace=meta.generation_trace;c.satisfied_constraints=meta.satisfied_constraints;c.prior_cost=meta.prior_cost;c.prior_source=meta.prior_source;c.prior_config_hash=meta.prior_config_hash;c.forward_model_compatible=NaN;c.compatibility_reason='not_checked';c.adapter_hash='';c.scored_library_included=false;
    c.node_count=numel(g.node_ids); c.edge_count=numel(edges);
end
function a=finalize_audit(spec,m,target,stats,candidates)
    if isstruct(m), stats0=m; else, stats0=stats; end
    a=struct('allowed_edge_count',numel(spec.allowed_edges),'theoretical_edge_subset_count',getf(stats0,'theoretical_edge_subset_count',safe_nchoosek(numel(spec.allowed_edges),target)), ...
        'feasible_radial_candidate_count',getf(stats0,'feasible_tree_count',numel(candidates)), ...
        'candidate_count',numel(candidates),'duplicate_count',getf(stats0,'duplicate_count',getf(spec,'duplicate_count',0)),'search_node_count',getf(stats0,'search_node_count',0),'cycle_pruned_branch_count',getf(stats0,'cycle_pruned',0), ...
        'degree_pruned_branch_count',getf(stats0,'degree_pruned',0),'connectivity_pruned_branch_count',getf(stats0,'connectivity_pruned',0), ...
        'required_edge_pruned_count',getf(stats0,'required_edge_pruned',0),'remaining_edge_pruned_count',getf(stats0,'remaining_edge_pruned',0), ...
        'maximum_candidate_count',spec.maximum_candidate_count,'prior_source',spec.prior_source,'prior_config_hash',spec.prior_config_hash);
end
function s=stats_template(),s=struct('theoretical_edge_subset_count',0,'feasible_tree_count',0,'cycle_pruned',0,'degree_pruned',0,'connectivity_pruned',0,'required_edge_pruned',0,'remaining_edge_pruned',0,'search_node_count',0,'duplicate_count',0);end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n),x=s.(n);else,x=d;end,end
function k=endpoint_keys(edges)
    k=cell(1,numel(edges));for i=1:numel(edges),pair=sort({edges(i).from,edges(i).to});k{i}=sprintf('%s--%s',pair{1},pair{2});end
end
function n=safe_nchoosek(m,k),if k<0||k>m,n=0;elseif m>60,n=Inf;else,n=nchoosek(m,k);end,end
function c=edge_template(),c=struct('id','','from','','to','','kind','line','length_m',NaN,'cable_type',[],'load',NaN,'prior_cost',NaN);end
function c=empty_candidate()
    c=struct('node_ids',{{}},'edges',repmat(edge_template(),1,0),'sorted_edge_set',{{}},'node_count',0,'edge_count',0,'source_node_id','','receiver_node_id','', ...
        'canonical_graph_key','','graph_candidate_id','','generation_route','','generation_trace',struct(), ...
        'satisfied_constraints',{{}},'prior_cost',NaN,'prior_source','','prior_config_hash','', ...
        'topology_key','','asset_state_key','','forward_model_compatible',NaN,'compatibility_reason','','adapter_hash','','scored_library_included',false);
end
function c=candidate_order(c)
    c=stage4a7_2_r2_sort_candidates(c);
end
function e=normalize_edges(edges)
    if isempty(edges),e=repmat(edge_template(),1,0);return;end
    if iscell(edges),e=repmat(edge_template(),1,size(edges,1));for k=1:size(edges,1),e(k).id=sprintf('E%04d',k);e(k).from=char(edges{k,1});e(k).to=char(edges{k,2});end
    elseif isstruct(edges),e=repmat(edge_template(),1,numel(edges));for k=1:numel(edges),e(k)=edge_template();e(k).id=get_text(edges(k),'id',sprintf('E%04d',k));e(k).from=char(edges(k).from);e(k).to=char(edges(k).to);e(k).kind=get_text(edges(k),'kind','line');e(k).length_m=get_num(edges(k),'length_m',NaN);e(k).cable_type=get_field(edges(k),'cable_type',[]);e(k).load=get_field(edges(k),'load',NaN);end
    else,error('stage4a7_1:InvalidEdges','Edges must be cell or struct.');end
end
function x=get_field(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=get_text(s,n,d),x=get_field(s,n,d);if isstring(x),x=char(x);end;if isempty(x),x=d;end,end
function x=get_num(s,n,d),x=get_field(s,n,d);if ~isnumeric(x)||~isscalar(x),x=d;end,end
function c=edge_cost(edges,spec),c=0;for k=1:numel(edges),ix=find(strcmp(endpoint_keys(spec.allowed_edges),endpoint_keys(edges(k))),1);if ~isempty(ix),c=c+spec.edge_prior_cost(ix);end,end,end
