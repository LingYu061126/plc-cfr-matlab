function graph = canonicalize_asset_graph(nodes, edges, metadata)
%CANONICALIZE_ASSET_GRAPH Create a deterministic labelled graph record.
%   The canonical key is based on sorted node IDs and endpoint-labelled
%   edges.  It is deliberately an engineering identity, not a claim of
%   physical observability or graph-isomorphism under relabelling.
    if nargin < 3 || isempty(metadata), metadata = struct(); end
    node_ids = normalize_nodes(nodes);
    if numel(unique(node_ids)) ~= numel(node_ids)
        error('stage4a7_1:DuplicateNodeId','Asset graph node IDs must be unique.');
    end
    edge_rows = normalize_edges(edges);
    for k = 1:numel(edge_rows)
        if ~any(strcmp(node_ids,edge_rows(k).from)) || ~any(strcmp(node_ids,edge_rows(k).to))
            error('stage4a7_1:UnknownEdgeNode','Edge endpoint is not in node_ids.');
        end
        if strcmp(edge_rows(k).from,edge_rows(k).to)
            error('stage4a7_1:SelfLoop','Self-loops are not valid asset edges.');
        end
    end
    node_ids = sort(node_ids);
    edge_keys = cell(1,numel(edge_rows));
    for k = 1:numel(edge_rows)
        a = edge_rows(k).from; b = edge_rows(k).to;
        pair = sort({a,b}); lo = pair{1}; hi = pair{2};
        kind = get_text(edge_rows(k),'kind','line');
        edge_keys{k} = sprintf('%s--%s[%s]',lo,hi,kind);
    end
    [~, order] = sort(edge_keys);
    edge_rows = edge_rows(order);
    edge_keys = edge_keys(order);
    topology_edges=cell(1,numel(edge_rows)); asset_edges=cell(1,numel(edge_rows));
    for k=1:numel(edge_rows)
        pair=sort({char(edge_rows(k).from),char(edge_rows(k).to)});
        topology_edges{k}=sprintf('%s--%s',pair{1},pair{2});
        asset_edges{k}=sprintf('%s--%s[%s]|L=%.17g|C=%s|Z=%s',pair{1},pair{2}, ...
            get_text(edge_rows(k),'kind','line'),get_number(edge_rows(k),'length_m',NaN), ...
            value_text(get_field(edge_rows(k),'cable_type',[])),value_text(get_field(edge_rows(k),'load',NaN)));
    end
    topology_key=sprintf('V=%s|E=%s',strjoin(node_ids,','),strjoin(sort(topology_edges),','));
    asset_state_key=sprintf('V=%s|E=%s',strjoin(node_ids,','),strjoin(sort(asset_edges),','));
    key = sprintf('V=%s|E=%s',strjoin(node_ids,','),strjoin(edge_keys,','));
    graph = struct();
    graph.node_ids = node_ids;
    graph.edges = edge_rows;
    graph.sorted_edge_set = edge_keys;
    graph.canonical_graph_key = key;
    graph.topology_key = topology_key;
    graph.asset_state_key = asset_state_key;
    graph.graph_candidate_id = get_text(metadata,'graph_candidate_id','');
    graph.generation_route = get_text(metadata,'generation_route','');
    graph.generation_trace = get_field(metadata,'generation_trace',struct());
    graph.satisfied_constraints = get_field(metadata,'satisfied_constraints',{});
    graph.prior_cost = get_number(metadata,'prior_cost',0);
    graph.prior_source = get_text(metadata,'prior_source','');
    graph.prior_config_hash = get_text(metadata,'prior_config_hash','');
end

function ids = normalize_nodes(nodes)
    if iscell(nodes), ids = cellfun(@char,nodes,'UniformOutput',false);
    elseif isstruct(nodes), ids = {nodes.id};
    else, ids = stage4a7_1_cellstr(nodes);
    end
    ids = ids(:).';
end

function rows = normalize_edges(edges)
    if isempty(edges)
        rows = struct('id',{},'from',{},'to',{},'kind',{},'length_m',{},'cable_type',{},'load',{});
        return;
    end
    if iscell(edges)
        if size(edges,2) ~= 2, error('stage4a7_1:InvalidEdges','Cell edges must be N-by-2.'); end
        rows = repmat(edge_template(),1,size(edges,1));
        for k=1:size(edges,1)
            rows(k).id = sprintf('E%04d',k); rows(k).from=char(edges{k,1}); rows(k).to=char(edges{k,2});
        end
    elseif isstruct(edges)
        rows = repmat(edge_template(),1,numel(edges));
        for k=1:numel(edges)
            if ~isfield(edges(k),'from') || ~isfield(edges(k),'to')
                error('stage4a7_1:InvalidEdges','Each edge needs from and to.');
            end
            rows(k).id = get_text(edges(k),'id',sprintf('E%04d',k));
            rows(k).from=char(edges(k).from); rows(k).to=char(edges(k).to);
            rows(k).kind=get_text(edges(k),'kind','line');
            rows(k).length_m=get_number(edges(k),'length_m',NaN);
            rows(k).cable_type=get_field(edges(k),'cable_type',[]);
            rows(k).load=get_field(edges(k),'load',NaN);
        end
    else
        error('stage4a7_1:InvalidEdges','edges must be a cell or struct array.');
    end
end

function x=edge_template()
    x=struct('id','','from','','to','','kind','line','length_m',NaN,'cable_type',[],'load',NaN);
end
function x=get_field(s,n,d), if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=get_text(s,n,d),x=get_field(s,n,d);if ~ischar(x),x=char(x);end;if isempty(x),x=d;end,end
function x=get_number(s,n,d),x=get_field(s,n,d);if ~isnumeric(x)||~isscalar(x),x=d;end,end
function x=value_text(v)
    if isempty(v),x='[]';return;end
    if ischar(v),x=v;elseif isstring(v),x=char(v);elseif isnumeric(v)&&isscalar(v),x=sprintf('%.17g',v);else,x=mat2str(v);end
end
