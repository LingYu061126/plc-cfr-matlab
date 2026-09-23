function [accepted, audit, rejected] = apply_topology_constraints(candidates, partial_prior)
%APPLY_TOPOLOGY_CONSTRAINTS Audit generated graphs against explicit rules.
%   The routine is independent of CFR evidence. It checks graph structure,
%   edge/node/switch rules, declared length intervals, total length, degree,
%   and the number of edges outside the source-to-receiver path.

    if isempty(candidates)
        accepted=candidates; rejected=candidates;
        audit=empty_audit(); return;
    end
    accepted_rows={}; rejected_rows={};
    reason_counts=struct();
    for k=1:numel(candidates)
        c=candidates(k); reasons={};
        nodes=stage4a7_1_cellstr(c.node_ids); edges=c.edges;
        node_range=get_field(partial_prior,'node_count_range',[numel(nodes) numel(nodes)]);
        if numel(nodes)<min(node_range)||numel(nodes)>max(node_range), reasons{end+1}='node_count'; end %#ok<AGROW>
        if get_field(partial_prior,'require_connected',true) && ~is_connected(nodes,edges), reasons{end+1}='connectivity'; end %#ok<AGROW>
        if get_field(partial_prior,'radial_only',true) && ...
                (numel(edges)~=max(0,numel(nodes)-1)||~is_acyclic(nodes,edges))
            reasons{end+1}='radial_acyclic'; %#ok<AGROW>
        end
        degrees=node_degrees(nodes,edges);
        if any(degrees>get_field(partial_prior,'maximum_degree',Inf)), reasons{end+1}='maximum_degree'; end %#ok<AGROW>
        edge_keys=canonical_keys(edges);
        if ~all(ismember(constraint_keys(get_field(partial_prior,'required_edges',struct([]))),edge_keys))
            reasons{end+1}='required_edges'; %#ok<AGROW>
        end
        if any(ismember(constraint_keys(get_field(partial_prior,'forbidden_edges',struct([]))),edge_keys))
            reasons{end+1}='forbidden_edges'; %#ok<AGROW>
        end
        [switch_ok,switch_reason]=check_switches(edge_keys,get_field(partial_prior,'switch_state',struct([])));
        if ~switch_ok, reasons{end+1}=switch_reason; end %#ok<AGROW>
        [length_ok,intervals]=check_length_intervals(edges,get_field(partial_prior,'allowed_edges',struct([])));
        if ~length_ok, reasons{end+1}='edge_length_range'; end %#ok<AGROW>
        total_length=sum([edges.length_m]);
        total_range=get_field(partial_prior,'total_length_range_m',[-Inf Inf]);
        if ~isfinite(total_length)||total_length<total_range(1)||total_length>total_range(2)
            reasons{end+1}='total_length_range'; %#ok<AGROW>
        end
        branch_count=count_off_path_edges(nodes,edges,get_text(partial_prior,'source_node_id',''), ...
            get_text(partial_prior,'receiver_node_id',''));
        if ~isfinite(branch_count)||branch_count>get_field(partial_prior,'maximum_branch_count',Inf)
            reasons{end+1}='maximum_branch_count'; %#ok<AGROW>
        end
        c.length_interval_per_edge=intervals;
        c.total_length_m=total_length;
        c.branch_count=branch_count;
        c.constraint_valid=isempty(reasons);
        c.constraint_reasons=reasons;
        if isempty(reasons)
            c.satisfied_constraints=unique([c.satisfied_constraints, ...
                {'node_count','radial','connected','acyclic','required_edges','forbidden_edges', ...
                 'switch_state','maximum_degree','edge_length_range','total_length_range','maximum_branch_count'}],'stable');
            accepted_rows{end+1}=c; %#ok<AGROW>
        else
            rejected_rows{end+1}=c; %#ok<AGROW>
            for q=1:numel(reasons)
                field=matlab.lang.makeValidName(reasons{q});
                if ~isfield(reason_counts,field),reason_counts.(field)=0;end
                reason_counts.(field)=reason_counts.(field)+1;
            end
        end
    end
    accepted=pack_rows(accepted_rows,candidates);rejected=pack_rows(rejected_rows,candidates);
    audit=struct('input_candidate_count',numel(candidates),'accepted_candidate_count',numel(accepted), ...
        'rejected_candidate_count',numel(rejected),'rejection_reason_counts',reason_counts, ...
        'constraint_names',{{'node_count','radial','connected','acyclic','required_edges', ...
        'forbidden_edges','switch_state','maximum_degree','edge_length_range', ...
        'total_length_range','maximum_branch_count'}});
end

function out=pack_rows(rows,prototype)
    if isempty(rows),out=prototype([]);else,out=[rows{:}];end
end

function [ok,intervals]=check_length_intervals(edges,allowed)
    intervals=repmat(struct('edge_key','','minimum_m',-Inf,'maximum_m',Inf, ...
        'nominal_m',NaN,'within_range',false),1,numel(edges));
    ok=true; allowed_keys=constraint_keys(allowed);
    for k=1:numel(edges)
        key=canonical_key(edges(k).from,edges(k).to);
        j=find(strcmp(allowed_keys,key),1); lo=-Inf; hi=Inf;
        if ~isempty(j)&&isstruct(allowed)
            lo=get_field(allowed(j),'length_min_m',-Inf);
            hi=get_field(allowed(j),'length_max_m',Inf);
        end
        valid=isfinite(edges(k).length_m)&&edges(k).length_m>0&&edges(k).length_m>=lo&&edges(k).length_m<=hi;
        intervals(k)=struct('edge_key',key,'minimum_m',lo,'maximum_m',hi, ...
            'nominal_m',edges(k).length_m,'within_range',valid);
        ok=ok&&valid;
    end
end

function n=count_off_path_edges(nodes,edges,source,receiver)
    if isempty(source)||isempty(receiver),n=Inf;return;end
    si=find(strcmp(nodes,source),1);ri=find(strcmp(nodes,receiver),1);
    if isempty(si)||isempty(ri),n=Inf;return;end
    adj=repmat({zeros(0,2)},1,numel(nodes));
    for k=1:numel(edges)
        i=find(strcmp(nodes,edges(k).from),1);j=find(strcmp(nodes,edges(k).to),1);
        adj{i}(end+1,:)=[j k];adj{j}(end+1,:)=[i k];
    end
    previous=zeros(1,numel(nodes));previous_edge=zeros(1,numel(nodes));queue=si;previous(si)=-1;head=1;
    while head<=numel(queue)
        u=queue(head);head=head+1;
        for q=1:size(adj{u},1)
            v=adj{u}(q,1);
            if previous(v)==0,previous(v)=u;previous_edge(v)=adj{u}(q,2);queue(end+1)=v;end %#ok<AGROW>
        end
    end
    if previous(ri)==0,n=Inf;return;end
    path_edge_count=0;u=ri;
    while previous(u)~=-1,path_edge_count=path_edge_count+1;u=previous(u);end
    n=numel(edges)-path_edge_count;
end

function [ok,reason]=check_switches(edge_keys,rows)
    ok=true;reason='switch_state';if isempty(rows),return;end
    if iscell(rows)
        for k=1:size(rows,1)
            key=canonical_key(char(rows{k,1}),char(rows{k,2}));state=lower(char(rows{k,3}));
            if ismember(state,{'closed','must-on','on','required'})&&~ismember(key,edge_keys),ok=false;return;end
            if ismember(state,{'open','must-off','off','forbidden'})&&ismember(key,edge_keys),ok=false;return;end
        end
    else
        for k=1:numel(rows)
            key=canonical_key(char(rows(k).from),char(rows(k).to));state=lower(char(rows(k).state));
            if ismember(state,{'closed','must-on','on','required'})&&~ismember(key,edge_keys),ok=false;return;end
            if ismember(state,{'open','must-off','off','forbidden'})&&ismember(key,edge_keys),ok=false;return;end
        end
    end
end

function d=node_degrees(nodes,edges)
    d=zeros(1,numel(nodes));
    for k=1:numel(edges)
        i=find(strcmp(nodes,edges(k).from),1);j=find(strcmp(nodes,edges(k).to),1);
        if ~isempty(i),d(i)=d(i)+1;end;if ~isempty(j),d(j)=d(j)+1;end
    end
end
function tf=is_connected(nodes,edges)
    if numel(nodes)<=1,tf=true;return;end
    seen=false(1,numel(nodes));seen(1)=true;changed=true;
    while changed
        changed=false;
        for k=1:numel(edges)
            i=find(strcmp(nodes,edges(k).from),1);j=find(strcmp(nodes,edges(k).to),1);
            if seen(i)&&~seen(j),seen(j)=true;changed=true;elseif seen(j)&&~seen(i),seen(i)=true;changed=true;end
        end
    end
    tf=all(seen);
end
function tf=is_acyclic(nodes,edges)
    parent=1:numel(nodes);tf=true;
    for k=1:numel(edges)
        i=find(strcmp(nodes,edges(k).from),1);j=find(strcmp(nodes,edges(k).to),1);
        ri=root(parent,i);rj=root(parent,j);if ri==rj,tf=false;return;end;parent(ri)=rj;
    end
end
function r=root(parent,i),r=i;while parent(r)~=r,r=parent(r);end,end
function keys=canonical_keys(edges),keys=cell(1,numel(edges));for k=1:numel(edges),keys{k}=canonical_key(edges(k).from,edges(k).to);end,end
function keys=constraint_keys(edges)
    if isempty(edges),keys={};elseif iscell(edges),keys=cell(1,size(edges,1));for k=1:size(edges,1),keys{k}=canonical_key(edges{k,1},edges{k,2});end
    else,keys=canonical_keys(edges);end
end
function key=canonical_key(a,b),p=sort({char(a),char(b)});key=[p{1} '--' p{2}];end
function a=empty_audit(),a=struct('input_candidate_count',0,'accepted_candidate_count',0,'rejected_candidate_count',0,'rejection_reason_counts',struct(),'constraint_names',{{}});end
function x=get_field(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=get_text(s,n,d),x=get_field(s,n,d);if isstring(x),x=char(x);end,end
