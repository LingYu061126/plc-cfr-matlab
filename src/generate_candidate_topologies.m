function [candidates, audit] = generate_candidate_topologies(partial_prior)
%GENERATE_CANDIDATE_TOPOLOGIES Enumerate radial graphs from a partial prior.
%   Required nodes are always present. Optional-node subsets are enumerated
%   within node_count_range, then the existing engineering spanning-tree
%   generator is called for each subset. This function does not evaluate a
%   CFR and does not infer topology from measurement evidence.

    validate_prior(partial_prior);
    all_nodes = stage4a7_1_cellstr(partial_prior.node_ids);
    optional = get_cellstr(partial_prior,'optional_node_ids',{});
    required = get_cellstr(partial_prior,'required_node_ids',setdiff(all_nodes,optional,'stable'));
    source = get_text(partial_prior,'source_node_id','');
    receiver = get_text(partial_prior,'receiver_node_id','');
    required = unique([required {source} {receiver} required_switch_nodes(partial_prior)],'stable');
    required = required(~cellfun('isempty',required));
    unclassified = setdiff(all_nodes,[required optional],'stable');
    required = unique([required unclassified],'stable');
    optional = setdiff(optional,required,'stable');
    assert(all(ismember([required optional],all_nodes)),'stage6a:UnknownNodeClass', ...
        'Required/optional nodes must be members of node_ids.');
    assert(isempty(intersect(required,optional)),'stage6a:NodeClassOverlap', ...
        'Required and optional node sets must be disjoint.');

    count_range = get_field(partial_prior,'node_count_range',[numel(required) numel(all_nodes)]);
    validateattributes(count_range,{'numeric'},{'vector','numel',2,'integer','nonnegative'});
    count_range = sort(double(count_range(:).'));
    assert(count_range(1)<=numel(all_nodes) && count_range(2)>=numel(required) && count_range(2)<=numel(all_nodes), ...
        'stage6a:InvalidNodeCountRange','node_count_range is inconsistent with the node classes.');
    max_subsets = get_field(partial_prior,'maximum_node_subsets',1e5);
    validateattributes(max_subsets,{'numeric'},{'scalar','integer','positive','finite'});
    if numel(optional)>20
        error('stage6a:OptionalNodeLimit','At most 20 optional nodes are supported by exhaustive subset enumeration.');
    end
    possible_subset_count = 2^numel(optional);
    if possible_subset_count>max_subsets
        error('stage6a:MaxNodeSubsetsExceeded', ...
            'Optional-node subset count %d exceeds maximum_node_subsets %d.',possible_subset_count,max_subsets);
    end

    prior_hash = get_text(partial_prior,'prior_config_hash','');
    if isempty(prior_hash), prior_hash=stage4a4_scientific_config_hash(partial_prior); end
    collected = {};
    subset_audits = repmat(struct('active_node_ids',{{}},'candidate_count',0, ...
        'status','','engineering_audit',struct()),1,0);
    evaluated=0; skipped=0; raw_count=0;
    for mask=0:possible_subset_count-1
        keep = logical(bitget(mask,1:numel(optional)));
        active = [required optional(keep)];
        active = all_nodes(ismember(all_nodes,active));
        if numel(active)<count_range(1) || numel(active)>count_range(2)
            skipped=skipped+1; continue;
        end
        if ~constraint_endpoints_available(partial_prior,active)
            skipped=skipped+1; continue;
        end
        subset_spec = subset_prior(partial_prior,active,prior_hash);
        evaluated=evaluated+1;
        [rows,eng_audit]=generate_engineering_topology_candidates(subset_spec);
        raw_count=raw_count+numel(rows);
        for k=1:numel(rows)
            rows(k).generation_route='stage6a_partial_prior_node_subset';
            rows(k).generation_trace.stage6a_active_node_ids=active;
            rows(k).generation_trace.stage6a_optional_mask=mask;
            collected{end+1}=rows(k); %#ok<AGROW>
        end
        subset_audits(end+1)=struct('active_node_ids',{active}, ...
            'candidate_count',numel(rows),'status','evaluated', ...
            'engineering_audit',eng_audit); %#ok<AGROW>
    end

    if isempty(collected)
        candidates=empty_candidates();
    else
        candidates=[collected{:}];
        keys={candidates.canonical_graph_key};
        [~,order]=sort(keys); candidates=candidates(order); keys=keys(order);
        [~,unique_idx]=unique(keys,'stable'); candidates=candidates(unique_idx);
        for k=1:numel(candidates)
            candidates(k).graph_candidate_id=sprintf('S6E%04d',k);
            candidates(k).prior_config_hash=prior_hash;
        end
    end
    maximum_candidates=get_field(partial_prior,'maximum_candidate_count',1e5);
    if numel(candidates)>maximum_candidates
        error('stage6a:MaxCandidatesExceeded','Candidate cap %d exceeded after node-subset aggregation.',maximum_candidates);
    end
    audit=struct('prior_source',get_text(partial_prior,'prior_source',''), ...
        'prior_config_hash',prior_hash,'required_node_ids',{required}, ...
        'optional_node_ids',{optional},'possible_node_subset_count',possible_subset_count, ...
        'evaluated_node_subset_count',evaluated,'skipped_node_subset_count',skipped, ...
        'raw_candidate_count',raw_count,'duplicate_candidate_count',raw_count-numel(candidates), ...
        'candidate_count',numel(candidates),'subset_audits',subset_audits);
end

function spec=subset_prior(prior,active,prior_hash)
    spec=prior;
    spec.node_ids=active;
    [spec.allowed_edges,idx]=filter_edges(get_field(prior,'allowed_edges',struct([])),active);
    cost=get_field(prior,'edge_prior_cost',[]);
    if ~isempty(cost), spec.edge_prior_cost=cost(idx); end
    spec.required_edges=filter_edges(get_field(prior,'required_edges',struct([])),active);
    spec.forbidden_edges=filter_edges(get_field(prior,'forbidden_edges',struct([])),active);
    if isfield(prior,'switch_state')
        spec.switch_state=filter_switches(prior.switch_state,active);
    end
    spec.prior_config_hash=prior_hash;
end

function tf=constraint_endpoints_available(prior,active)
    tf=all_edges_inside(get_field(prior,'required_edges',struct([])),active);
    if ~tf, return; end
    switches=get_field(prior,'switch_state',struct([]));
    if isempty(switches), return; end
    if iscell(switches)
        for k=1:size(switches,1)
            state=lower(char(switches{k,3}));
            if ismember(state,{'closed','must-on','on','required'}) && ...
                    ~all(ismember({char(switches{k,1}),char(switches{k,2})},active))
                tf=false; return;
            end
        end
    else
        for k=1:numel(switches)
            state=lower(char(switches(k).state));
            if ismember(state,{'closed','must-on','on','required'}) && ...
                    ~all(ismember({char(switches(k).from),char(switches(k).to)},active))
                tf=false; return;
            end
        end
    end
end

function nodes=required_switch_nodes(prior)
    nodes={}; switches=get_field(prior,'switch_state',struct([]));
    if isempty(switches), return; end
    if iscell(switches)
        for k=1:size(switches,1)
            if ismember(lower(char(switches{k,3})),{'closed','must-on','on','required'})
                nodes=[nodes {char(switches{k,1}) char(switches{k,2})}]; %#ok<AGROW>
            end
        end
    else
        for k=1:numel(switches)
            if ismember(lower(char(switches(k).state)),{'closed','must-on','on','required'})
                nodes=[nodes {char(switches(k).from) char(switches(k).to)}]; %#ok<AGROW>
            end
        end
    end
end

function [out,idx]=filter_edges(edges,active)
    if isempty(edges), out=edges; idx=[]; return; end
    if iscell(edges)
        keep=false(size(edges,1),1);
        for k=1:size(edges,1), keep(k)=all(ismember({char(edges{k,1}),char(edges{k,2})},active)); end
        idx=find(keep); out=edges(keep,:);
    else
        keep=false(1,numel(edges));
        for k=1:numel(edges), keep(k)=all(ismember({char(edges(k).from),char(edges(k).to)},active)); end
        idx=find(keep); out=edges(keep);
    end
end

function out=filter_switches(rows,active)
    if isempty(rows), out=rows; return; end
    if iscell(rows)
        keep=false(size(rows,1),1);
        for k=1:size(rows,1), keep(k)=all(ismember({char(rows{k,1}),char(rows{k,2})},active)); end
        out=rows(keep,:);
    else
        keep=false(1,numel(rows));
        for k=1:numel(rows), keep(k)=all(ismember({char(rows(k).from),char(rows(k).to)},active)); end
        out=rows(keep);
    end
end

function tf=all_edges_inside(edges,active)
    if isempty(edges),tf=true;return;end
    if iscell(edges)
        tf=true;
        for k=1:size(edges,1),tf=tf&&all(ismember({char(edges{k,1}),char(edges{k,2})},active));end
    else
        tf=true;
        for k=1:numel(edges),tf=tf&&all(ismember({char(edges(k).from),char(edges(k).to)},active));end
    end
end

function validate_prior(p)
    assert(isstruct(p)&&isscalar(p),'stage6a:InvalidPrior','partial_prior must be a scalar struct.');
    assert(isfield(p,'node_ids')&&isfield(p,'allowed_edges'),'stage6a:MissingPriorField', ...
        'partial_prior requires node_ids and allowed_edges.');
end
function x=get_field(s,n,d),if isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=get_text(s,n,d),x=get_field(s,n,d);if isstring(x),x=char(x);end,end
function x=get_cellstr(s,n,d),x=get_field(s,n,d);if isempty(x),x={};else,x=stage4a7_1_cellstr(x);end,end
function c=empty_candidates(),c=repmat(struct(),1,0);end
