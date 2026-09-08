function spec = normalize_engineering_candidate_spec(spec)
%NORMALIZE_ENGINEERING_CANDIDATE_SPEC Canonicalize an engineering edge spec.
%   Edge attributes and prior costs are normalized together.  The routine is
%   deliberately deterministic: undirected endpoints are ordered, duplicate
%   edges are collapsed using the lowest finite cost, and all validation is
%   performed before a search starts.

    required = {'node_ids','allowed_edges'};
    for k = 1:numel(required)
        if ~isfield(spec,required{k})
            error('stage4a7_2:MissingSpec','Missing %s.',required{k});
        end
    end
    spec.node_ids = stage4a7_1_cellstr(spec.node_ids);
    if isempty(spec.node_ids) || numel(unique(spec.node_ids)) ~= numel(spec.node_ids)
        error('stage4a7_2:InvalidNodeIds','node_ids must be nonempty and unique.');
    end
    raw_edges = normalize_edges(spec.allowed_edges);
    raw_cost = raw_edge_cost(spec,raw_edges);
    [spec.allowed_edges,spec.edge_prior_cost,duplicate_count] = canonical_edges(raw_edges,raw_cost,spec.node_ids);
    spec.duplicate_count = duplicate_count;
    spec.required_edges = normalize_edges(get_field(spec,'required_edges',[]));
    spec.forbidden_edges = normalize_edges(get_field(spec,'forbidden_edges',[]));
    spec.required_edges = canonical_constraint_edges(spec.required_edges,spec.node_ids);
    spec.forbidden_edges = canonical_constraint_edges(spec.forbidden_edges,spec.node_ids);
    spec.edge_prior_cost = spec.edge_prior_cost(:);
    if any(~isfinite(spec.edge_prior_cost)) || any(spec.edge_prior_cost < 0)
        error('stage4a7_2:InvalidEdgeCost','edge_prior_cost must be finite and nonnegative.');
    end
    if ~isfield(spec,'maximum_degree') || isempty(spec.maximum_degree), spec.maximum_degree = Inf; end
    if ~isscalar(spec.maximum_degree) || isnan(spec.maximum_degree) || spec.maximum_degree < 0
        error('stage4a7_2:InvalidMaximumDegree','maximum_degree must be nonnegative or Inf.');
    end
    if ~isfield(spec,'radial_only') || isempty(spec.radial_only), spec.radial_only = true; end
    if ~isfield(spec,'require_connected') || isempty(spec.require_connected), spec.require_connected = true; end
    if ~spec.radial_only
        error('stage4a7_2:NonRadialUnsupported','This generator only constructs radial trees.');
    end
    if ~isfield(spec,'maximum_candidate_count') || isempty(spec.maximum_candidate_count), spec.maximum_candidate_count = 1e5; end
    if ~isscalar(spec.maximum_candidate_count) || ~isfinite(spec.maximum_candidate_count) || spec.maximum_candidate_count < 1
        error('stage4a7_2:InvalidCandidateLimit','maximum_candidate_count must be a positive finite scalar.');
    end
    if ~isfield(spec,'prior_source') || isempty(spec.prior_source), spec.prior_source = 'synthetic_demo_prior_not_field_data'; end
    if ~isfield(spec,'prior_config_hash') || isempty(spec.prior_config_hash)
        spec.prior_config_hash = stage4a4_scientific_config_hash(struct('node_ids',{spec.node_ids},'edges',spec.allowed_edges,'cost',spec.edge_prior_cost));
    end
    if isfield(spec,'switch_state') && ~isempty(spec.switch_state)
        [sw_req,sw_forb] = switch_constraints(spec.switch_state,spec.allowed_edges,spec.node_ids);
        spec.required_edges = merge_constraint_edges(spec.required_edges,sw_req,spec.node_ids);
        spec.forbidden_edges = merge_constraint_edges(spec.forbidden_edges,sw_forb,spec.node_ids);
    end
    req = endpoint_keys(spec.required_edges); forb = endpoint_keys(spec.forbidden_edges);
    if ~isempty(intersect(req,forb))
        error('stage4a7_1:RequiredForbiddenConflict','Required and forbidden edges overlap.');
    end
    allowed = endpoint_keys(spec.allowed_edges);
    if any(~ismember(req,allowed))
        error('stage4a7_2:RequiredEdgeUnavailable','A required edge is absent from allowed_edges.');
    end
    spec.required_edge_keys = req;
    spec.forbidden_edge_keys = forb;
end

function [edges,costs,duplicate_count] = canonical_edges(raw,cost,node_ids)
    if isempty(raw), edges=raw; costs=zeros(0,1); duplicate_count=0; return; end
    for k=1:numel(raw)
        if strcmp(raw(k).from,raw(k).to), error('stage4a7_2:SelfLoop','Self-loops are not valid asset edges.'); end
        if ~any(strcmp(node_ids,raw(k).from)) || ~any(strcmp(node_ids,raw(k).to))
            error('stage4a7_2:UnknownEdgeNode','Edge endpoint is not in node_ids.');
        end
        pair=sort({raw(k).from,raw(k).to}); raw(k).from=pair{1}; raw(k).to=pair{2};
    end
    keys=endpoint_keys(raw); [keys,order]=sort(keys); raw=raw(order); cost=cost(order);
    edges=repmat(edge_template(),1,0); costs=zeros(0,1); duplicate_count=0; k=1;
    while k<=numel(raw)
        j=k; group=[]; while j<=numel(raw) && strcmp(keys{j},keys{k}), group(end+1)=j; j=j+1; end %#ok<AGROW>
        [~,q]=min(cost(group)); pick=group(q); edges(end+1)=raw(pick); costs(end+1,1)=cost(pick); %#ok<AGROW>
        duplicate_count=duplicate_count+numel(group)-1; k=j;
    end
end

function costs=raw_edge_cost(spec,edges)
    if isfield(spec,'edge_prior_cost') && ~isempty(spec.edge_prior_cost)
        costs=double(spec.edge_prior_cost(:));
        if numel(costs)~=numel(edges), error('stage4a7_2:CostLength','edge_prior_cost length mismatch.'); end
    else
        costs=zeros(numel(edges),1);
        for k=1:numel(edges)
            if isfield(edges(k),'prior_cost') && ~isempty(edges(k).prior_cost) && isfinite(edges(k).prior_cost), costs(k)=double(edges(k).prior_cost); end
        end
    end
    if any(~isfinite(costs)) || any(costs<0), error('stage4a7_2:InvalidEdgeCost','edge_prior_cost must be finite and nonnegative.'); end
end

function e=canonical_constraint_edges(e,node_ids)
    if isempty(e), return; end
    for k=1:numel(e)
        if strcmp(e(k).from,e(k).to), error('stage4a7_2:SelfLoop','Constraint self-loop is invalid.'); end
        if ~any(strcmp(node_ids,e(k).from)) || ~any(strcmp(node_ids,e(k).to)), error('stage4a7_2:UnknownEdgeNode','Constraint endpoint is unknown.'); end
        p=sort({e(k).from,e(k).to}); e(k).from=p{1}; e(k).to=p{2};
    end
    [keys,o]=sort(endpoint_keys(e)); e=e(o); [~,u]=unique(keys,'stable'); e=e(u);
end

function [r,f]=switch_constraints(switch_state,allowed,node_ids)
    r=repmat(edge_template(),1,0); f=r;
    if isstruct(switch_state)
        rows=switch_state;
    elseif iscell(switch_state)
        rows=repmat(struct('from','','to','','state',''),size(switch_state,1),1);
        for k=1:size(switch_state,1), rows(k)=struct('from',char(switch_state{k,1}),'to',char(switch_state{k,2}),'state',char(switch_state{k,3})); end
    else
        error('stage4a7_2:InvalidSwitchState','switch_state must be a struct array or cell array.');
    end
    for k=1:numel(rows)
        if isfield(rows(k),'edge_id') && ~isempty(rows(k).edge_id)
            j=find(strcmp({allowed.id},char(rows(k).edge_id)),1); if isempty(j), error('stage4a7_2:UnknownSwitchEdge','Switch edge is unknown.'); end; e=allowed(j);
        else
            e=edge_template(); e.from=char(rows(k).from); e.to=char(rows(k).to);
        end
        state=lower(char(rows(k).state));
        if ismember(state,{'closed','must-on','on','required'}), r(end+1)=e; elseif ismember(state,{'open','must-off','off','forbidden'}), f(end+1)=e; elseif ~ismember(state,{'unknown','optional'}), error('stage4a7_2:InvalidSwitchState','Unknown switch state %s.',state); end
    end
    r=canonical_constraint_edges(r,node_ids); f=canonical_constraint_edges(f,node_ids);
end

function e=merge_constraint_edges(a,b,node_ids), e=canonical_constraint_edges([a b],node_ids); end
function k=endpoint_keys(edges), k=cell(1,numel(edges)); for i=1:numel(edges), k{i}=[edges(i).from '--' edges(i).to]; end, end
function e=normalize_edges(edges)
    if isempty(edges), e=repmat(edge_template(),1,0); return; end
    if iscell(edges)
        if size(edges,2)<2, error('stage4a7_2:InvalidEdges','Cell edges must have at least two columns.'); end
        e=repmat(edge_template(),1,size(edges,1)); for k=1:size(edges,1), e(k).id=sprintf('E%04d',k); e(k).from=char(edges{k,1}); e(k).to=char(edges{k,2}); end
    elseif isstruct(edges)
        e=repmat(edge_template(),1,numel(edges));
        for k=1:numel(edges), e(k).id=get_text(edges(k),'id',sprintf('E%04d',k)); e(k).from=char(edges(k).from); e(k).to=char(edges(k).to); e(k).kind=get_text(edges(k),'kind','line'); e(k).length_m=get_num(edges(k),'length_m',NaN); e(k).cable_type=get_field(edges(k),'cable_type',[]); e(k).load=get_field(edges(k),'load',NaN); if isfield(edges(k),'prior_cost'),e(k).prior_cost=edges(k).prior_cost;end,end
    else, error('stage4a7_2:InvalidEdges','Edges must be a cell or struct array.'); end
end
function x=edge_template(), x=struct('id','','from','','to','','kind','line','length_m',NaN,'cable_type',[],'load',NaN,'prior_cost',NaN); end
function x=get_field(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=get_text(s,n,d),x=get_field(s,n,d);if isstring(x),x=char(x);end;if isempty(x),x=d;end,end
function x=get_num(s,n,d),x=get_field(s,n,d);if ~isnumeric(x)||~isscalar(x),x=d;end,end
