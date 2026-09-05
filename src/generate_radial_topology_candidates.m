function candidates = generate_radial_topology_candidates(grammar)
%GENERATE_RADIAL_TOPOLOGY_CANDIDATES Enumerate bounded main-path branch trees.
%   Candidate IDs and canonical keys are deterministic.  Canonicalization
%   fixes TX--RX direction and represents each allowed attachment by its
%   branch count, so branch creation order and local labels cannot duplicate
%   a physical graph in this restricted grammar.

    grammar = normalize_grammar(grammar);
    slots = grammar.allowed_branch_main_nodes(:).';
    vectors = cell(1,numel(slots));
    for k=1:numel(slots), vectors{k}=0:grammar.max_side_branches_per_node; end
    grids=cell(1,numel(slots)); [grids{:}]=ndgrid(vectors{:});
    count_matrix=cellfun(@(x)x(:),grids,'UniformOutput',false);
    patterns=[count_matrix{:}];
    patterns=patterns(sum(patterns,2)<=grammar.max_branches,:);
    if size(patterns,1)>grammar.max_candidates
        error('generate_radial_topology_candidates:MaxCandidatesExceeded', ...
            'Grammar produces %d candidates, above max_candidates=%d.',size(patterns,1),grammar.max_candidates);
    end
    keys=cell(size(patterns,1),1);
    for q=1:size(patterns,1), keys{q}=canonical_key(grammar,slots,patterns(q,:)); end
    [keys,order]=sort(keys); patterns=patterns(order,:);
    if numel(unique(keys))~=numel(keys)
        error('generate_radial_topology_candidates:CanonicalCollision', ...
            'Canonicalization did not remove all structural duplicates.');
    end
    candidates=repmat(empty_candidate(),1,numel(keys));
    for q=1:numel(keys)
        candidates(q)=make_candidate(q,keys{q},grammar,slots,patterns(q,:));
        candidates(q).validation=validate_radial_topology_candidate(candidates(q),grammar);
    end
end

function grammar=normalize_grammar(grammar)
    names={'source_node_id','receiver_node_id','max_nodes','max_branches', ...
        'main_path_segments','allowed_branch_main_nodes','max_side_branches_per_node', ...
        'max_branch_depth','radial_only','main_edge_length_m','branch_edge_length_m', ...
        'main_cable_type','branch_cable_type','branch_load_ohm', ...
        'fixed_siso_endpoint_protocol','max_candidates'};
    for k=1:numel(names)
        if ~isfield(grammar,names{k}) || isempty(grammar.(names{k}))
            error('generate_radial_topology_candidates:MissingGrammarField','grammar.%s is required.',names{k});
        end
    end
    if ~grammar.radial_only || grammar.max_branch_depth~=1 || grammar.main_path_segments<2 || ...
            any(grammar.allowed_branch_main_nodes<1) || ...
            any(grammar.allowed_branch_main_nodes>=grammar.main_path_segments) || ...
            any(grammar.allowed_branch_main_nodes~=fix(grammar.allowed_branch_main_nodes)) || ...
            ~isscalar(grammar.main_edge_length_m) || grammar.main_edge_length_m<=0 || ...
            ~isscalar(grammar.branch_edge_length_m) || grammar.branch_edge_length_m<=0 || ...
            grammar.max_side_branches_per_node<0 || grammar.max_branches<0 || grammar.max_candidates<1
        error('generate_radial_topology_candidates:InvalidGrammar', ...
            'Grammar must describe a positive-length one-level radial main-path tree.');
    end
    grammar.allowed_branch_main_nodes=unique(sort(grammar.allowed_branch_main_nodes(:).'),'stable');
end

function candidate=make_candidate(index,key,g,slots,counts)
    main_ids=cell(1,g.main_path_segments+1); main_ids{1}=g.source_node_id;
    for k=1:g.main_path_segments-1, main_ids{k+1}=sprintf('M%d',k); end
    main_ids{end}=g.receiver_node_id;
    node=struct('id',{},'role',{});
    for k=1:numel(main_ids)
        role='main';if k==1,role='source';elseif k==numel(main_ids),role='receiver';end
        node(end+1)=struct('id',main_ids{k},'role',role); %#ok<AGROW>
    end
    edge=struct('id',{},'from',{},'to',{},'kind',{},'length_m',{},'cable_type',{},'load',{});
    main_edge_ids=cell(1,g.main_path_segments);
    for k=1:g.main_path_segments
        id=sprintf('M_%d_%d',k-1,k);main_edge_ids{k}=id;
        edge(end+1)=struct('id',id,'from',main_ids{k},'to',main_ids{k+1}, ...
            'kind','main','length_m',g.main_edge_length_m,'cable_type',g.main_cable_type,'load',NaN); %#ok<AGROW>
    end
    branch_edge_ids={}; branch=struct('node',{},'length',{},'cable_type',{},'load',{}); b=0;
    for s=1:numel(slots)
        for c=1:counts(s)
            b=b+1; terminal=sprintf('B%d_LOAD',b);node(end+1)=struct('id',terminal,'role','branch_load'); %#ok<AGROW>
            id=sprintf('B_%d_%d',slots(s),b);branch_edge_ids{end+1}=id; %#ok<AGROW>
            edge(end+1)=struct('id',id,'from',main_ids{slots(s)+1},'to',terminal, ...
                'kind','branch','length_m',g.branch_edge_length_m,'cable_type',g.branch_cable_type,'load',g.branch_load_ohm); %#ok<AGROW>
            branch(end+1)=struct('node',slots(s),'length',g.branch_edge_length_m, ...
                'cable_type',g.branch_cable_type,'load',g.branch_load_ohm); %#ok<AGROW>
        end
    end
    network=struct('main_lengths',repmat(g.main_edge_length_m,1,g.main_path_segments), ...
        'main_cable_type',repmat(g.main_cable_type,1,g.main_path_segments),'branches',branch);
    candidate=struct('topology_id',sprintf('G%03d',index),'nodes',node,'edges',edge, ...
        'source_node',g.source_node_id,'receiver_node',g.receiver_node_id, ...
        'main_path_edges',{main_edge_ids},'branch_edges',{branch_edge_ids}, ...
        'canonical_key',key,'network',network,'node_count',numel(node), ...
        'edge_count',numel(edge),'generation_config',g,'validation',struct());
end

function key=canonical_key(g,slots,counts)
    pieces=arrayfun(@(s,c)sprintf('%d:%d',s,c),slots,counts,'UniformOutput',false);
    key=sprintf('TX=%s|RX=%s|P=%d|%s',g.source_node_id,g.receiver_node_id, ...
        g.main_path_segments,strjoin(pieces,','));
end

function x=empty_candidate()
    x=struct('topology_id','','nodes',struct([]),'edges',struct([]),'source_node','', ...
        'receiver_node','','main_path_edges',{{}},'branch_edges',{{}},'canonical_key','', ...
        'network',struct(),'node_count',0,'edge_count',0,'generation_config',struct(),'validation',struct());
end
