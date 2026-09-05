function prior = validate_topology_prior_consistency(prior, grammar)
%VALIDATE_TOPOLOGY_PRIOR_CONSISTENCY Validate hard/soft prior syntax safely.
%   This checks only prior consistency and current forward-model scope; it
%   does not use a truth topology, a simulated response or a match result.

    required={'node_inventory','edge_prior','network_rules','observation_prior','source_tag'};
    for k=1:numel(required), if ~isfield(prior,required{k}), error('validate_topology_prior_consistency:MissingField','asset_prior.%s is required.',required{k}); end,end
    nodes=prior.node_inventory; ids={nodes.node_id};
    if numel(unique(ids))~=numel(ids) || ~any(strcmp(ids,grammar.source_node_id)) || ~any(strcmp(ids,grammar.receiver_node_id))
        error('validate_topology_prior_consistency:NodeInventory','Node inventory must be unique and include source/receiver.');
    end
    rules=prior.network_rules;
    if ~rules.radial_only || ~strcmp(rules.root_node,grammar.source_node_id) || ~strcmp(rules.receiver_node,grammar.receiver_node_id) || ...
            rules.maximum_branch_depth>1 || rules.maximum_degree<2
        error('validate_topology_prior_consistency:UnsupportedRules','Prior rules exceed the current one-level radial forward model.');
    end
    e=prior.edge_prior;
    for k=1:numel(e)
        if ~known_or_wildcard(e(k).from,ids) || ~known_or_wildcard(e(k).to,ids) || ...
                e(k).length_min_m<0 || e(k).length_max_m<=0 || e(k).length_min_m>e(k).length_max_m || ...
                ~ismember(char(e(k).prior_kind),{'hard','soft'}) || ...
                ~ismember(char(e(k).edge_kind),{'main','branch','any'})
            error('validate_topology_prior_consistency:InvalidEdgePrior','Invalid edge prior at index %d.',k);
        end
        if e(k).required && e(k).forbidden
            error('validate_topology_prior_consistency:RequiredForbiddenConflict','An edge cannot be both required and forbidden.');
        end
    end
    for i=1:numel(e), for j=i+1:numel(e)
        if same_edge(e(i),e(j)) && ((e(i).required&&e(j).forbidden)||(e(i).forbidden&&e(j).required))
            error('validate_topology_prior_consistency:RequiredForbiddenConflict','Required and forbidden edge priors conflict.');
        end
    end,end
    required_edges=e([e.required] & strcmp({e.prior_kind},'hard'));
    if numel(required_edges)>grammar.main_path_segments+grammar.max_branches
        error('validate_topology_prior_consistency:RequiredCycleOrOverconstraint','Required edges exceed supported tree edge count.');
    end
    prior.prior_config_hash=stage4a2_config_hash(prior);
end
function ok=known_or_wildcard(id,ids),ok=strcmp(id,'*')||any(strcmp(id,ids));end
function ok=same_edge(a,b),ok=(strcmp(a.from,b.from)&&strcmp(a.to,b.to))||(strcmp(a.from,b.to)&&strcmp(a.to,b.from));end
