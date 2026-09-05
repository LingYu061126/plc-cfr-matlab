function summary = validate_radial_topology_candidate(candidate, grammar)
%VALIDATE_RADIAL_TOPOLOGY_CANDIDATE Check the restricted current-model tree.
%   The supported grammar is one ordered TX--RX main path and direct side
%   branches.  All lengths are in metres and every graph edge is explicit.

    required = {'topology_id','nodes','edges','source_node','receiver_node', ...
        'main_path_edges','branch_edges','canonical_key','network'};
    for k=1:numel(required)
        if ~isfield(candidate,required{k})
            error('validate_radial_topology_candidate:MissingField', ...
                'candidate.%s is required.',required{k});
        end
    end
    nodes = candidate.nodes; edges = candidate.edges;
    n = numel(nodes); m = numel(edges);
    if n < 2 || m ~= n-1
        error('validate_radial_topology_candidate:TreeEdgeCount', ...
            'A connected tree must have exactly node_count-1 edges.');
    end
    labels = {nodes.id};
    if numel(unique(labels)) ~= n || ~any(strcmp(labels,candidate.source_node)) || ...
            ~any(strcmp(labels,candidate.receiver_node))
        error('validate_radial_topology_candidate:InvalidNodes', ...
            'Node IDs must be unique and include source and receiver.');
    end
    adjacency = false(n); degree = zeros(1,n);
    for e=1:m
        a=find(strcmp(labels,edges(e).from),1); b=find(strcmp(labels,edges(e).to),1);
        if isempty(a)||isempty(b)||a==b||~isfinite(edges(e).length_m)||edges(e).length_m<=0
            error('validate_radial_topology_candidate:InvalidEdge', ...
                'Edges must join two different known nodes with positive finite metres.');
        end
        adjacency(a,b)=true; adjacency(b,a)=true; degree([a b])=degree([a b])+1;
    end
    visited=false(1,n); stack=find(strcmp(labels,candidate.source_node),1); visited(stack)=true;
    while ~isempty(stack)
        a=stack(end); stack(end)=[]; next=find(adjacency(a,:) & ~visited);
        visited(next)=true; stack=[stack next]; %#ok<AGROW>
    end
    if ~all(visited), error('validate_radial_topology_candidate:Disconnected','Candidate is disconnected.'); end
    if ~grammar.radial_only, error('validate_radial_topology_candidate:NonRadialUnsupported', ...
            'This current-model generator only supports radial trees.'); end
    main_count=numel(candidate.main_path_edges); branch_count=numel(candidate.branch_edges);
    if main_count~=grammar.main_path_segments || branch_count>grammar.max_branches || ...
            n>grammar.max_nodes || any(degree>grammar.max_side_branches_per_node+2)
        error('validate_radial_topology_candidate:GrammarViolation', ...
            'Candidate violates configured path, branch, node or degree bounds.');
    end
    if grammar.max_branch_depth~=1
        error('validate_radial_topology_candidate:UnsupportedBranchDepth', ...
            'The existing forward model supports one direct branch level only.');
    end
    summary=struct('node_count',n,'edge_count',m,'branch_count',branch_count, ...
        'connected',true,'acyclic',true,'degree',degree,'unit','m');
end
