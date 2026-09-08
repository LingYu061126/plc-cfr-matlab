function [candidate, report] = adapt_engineering_candidate_to_forward_model(candidate, cfg)
%ADAPT_ENGINEERING_CANDIDATE_TO_FORWARD_MODEL Convert an asset tree to the
% stable single-path/first-level-branch network representation.
%   The adapter is intentionally conservative.  A graph that cannot be
%   represented is returned with a reason code and is never silently scored.
    report=struct('forward_model_compatible',false,'reason_code','','reason','','adapter_hash','','round_trip_ok',false);
    candidate.forward_model_compatible=false; candidate.scored_library_included=false;
    [nodes,edges,source_id,receiver_id]=graph_fields(candidate);
    if isempty(edges), report=fail(report,'missing_edge_representation','Candidate has no engineering edges.'); return; end
    if isempty(source_id)||isempty(receiver_id), report=fail(report,'source_or_receiver_missing','Source or receiver node is missing.'); return; end
    if ~is_tree(nodes,edges), report=fail(report,'not_a_tree','Engineering graph is not a connected tree.'); return; end
    [path_edges,path_nodes]=unique_path(edges,source_id,receiver_id);
    if isempty(path_edges), report=fail(report,'path_orientation_error','Source-to-receiver path cannot be recovered.'); return; end
    used=false(1,numel(edges));
    for k=1:numel(path_edges), used(path_edges(k))=true; end
    main_lengths=zeros(1,numel(path_edges)); main_types=zeros(1,numel(path_edges));
    for k=1:numel(path_edges)
        e=edges(path_edges(k));
        if ~isfinite(e.length_m)||e.length_m<=0, report=fail(report,'missing_edge_length','A path edge lacks a positive finite length.'); return; end
        if isempty(e.cable_type)||~isscalar(e.cable_type)||~isfinite(e.cable_type), report=fail(report,'missing_cable_type','A path edge lacks a valid cable type.'); return; end
        main_lengths(k)=e.length_m; main_types(k)=e.cable_type;
    end
    branches=struct('node',{},'length',{},'cable_type',{},'load',{});
    path_index=containers.Map(path_nodes,1:numel(path_nodes));
    for q=find(~used)
        e=edges(q); [attach,leaf]=off_path_edge(e,path_nodes);
        if isempty(attach), report=fail(report,'nested_branch_not_supported','A non-path component is not a single leaf branch.'); return; end
        if ~isKey(path_index,attach)||~isfinite(e.length_m)||e.length_m<=0, report=fail(report,'missing_edge_length','A branch edge lacks a positive finite length.'); return; end
        if isempty(e.cable_type)||~isscalar(e.cable_type)||~isfinite(e.cable_type), report=fail(report,'missing_cable_type','A branch edge lacks a valid cable type.'); return; end
        if isempty(e.load)||~isscalar(e.load)||~(isfinite(e.load)||isinf(e.load)), report=fail(report,'missing_terminal_load','A branch terminal load is missing.'); return; end
        p=path_index(attach); if p<=1 || p>=numel(path_nodes), report=fail(report,'unsupported_component','A branch must attach to an internal main-path node.'); return; end
        branches(end+1)=struct('node',p-1,'length',e.length_m,'cable_type',e.cable_type,'load',e.load); %#ok<AGROW>
        if ~any(strcmp(nodes,leaf)), report=fail(report,'unsupported_component','Branch leaf is not in the graph node set.'); return; end
    end
    net=struct('main_lengths',main_lengths,'main_cable_type',main_types,'branches',branches);
    candidate.network=net; candidate.forward_model_compatible=true; candidate.compatibility_reason='stable_single_path_first_level_branch'; candidate.scored_library_included=true;
    report.forward_model_compatible=true; report.reason_code='compatible'; report.reason='stable single-path with first-level leaf branches';
    report.adapter_hash=stage4a4_scientific_config_hash(struct('adapter','stage4a7_2_engineering_adapter_v1','cfg',safe_cfg(cfg))); candidate.adapter_hash=report.adapter_hash;
    [round_trip,rt_report]=round_trip_audit(candidate,nodes,path_nodes,source_id,receiver_id); report.round_trip_ok=round_trip; report.round_trip_report=rt_report;
    if ~round_trip, candidate.forward_model_compatible=false; candidate.scored_library_included=false; report=fail(report,'path_orientation_error','Engineering round-trip changed graph structure.'); end
end

function [nodes,edges,s,r]=graph_fields(c)
    if isfield(c,'node_ids'),nodes=cellstr(c.node_ids);elseif isfield(c,'nodes')&&isstruct(c.nodes),nodes={c.nodes.id};else,nodes={};end
    if isfield(c,'edges'),edges=c.edges;else,edges=struct([]);end
    if isfield(c,'source_node_id'),s=char(c.source_node_id);elseif isfield(c,'source_node'),s=char(c.source_node);elseif isfield(c,'tx_node'),s=char(c.tx_node);else,s='';end
    if isfield(c,'receiver_node_id'),r=char(c.receiver_node_id);elseif isfield(c,'receiver_node'),r=char(c.receiver_node);elseif isfield(c,'rx_node'),r=char(c.rx_node);else,r='';end
    if isempty(nodes)&&~isempty(edges),nodes=unique([ {edges.from} {edges.to} ]);end
end
function tf=is_tree(nodes,e),tf=~isempty(nodes)&&numel(e)==numel(nodes)-1&&is_connected(e,nodes)&&acyclic(e,nodes);end
function tf=is_connected(e,nodes)
    if numel(nodes)<=1,tf=true;return;end
    seen=false(1,numel(nodes));seen(1)=true;changed=true;
    while changed
        changed=false;
        for k=1:numel(e)
            i=find(strcmp(nodes,e(k).from),1);j=find(strcmp(nodes,e(k).to),1);
            if seen(i)&&~seen(j),seen(j)=true;changed=true;elseif seen(j)&&~seen(i),seen(i)=true;changed=true;end
        end
    end
    tf=all(seen);
end
function tf=acyclic(e,nodes),p=1:numel(nodes);tf=true;for k=1:numel(e),i=find(strcmp(nodes,e(k).from),1);j=find(strcmp(nodes,e(k).to),1);ri=find_root(p,i);rj=find_root(p,j);if ri==rj,tf=false;return;end;p(ri)=rj;end,end
function [idx,path_nodes]=unique_path(edges,s,r)
    adj=cell(1,0);nodes=unique([{edges.from} {edges.to}]);adj=repmat({{}},1,numel(nodes));
    for k=1:numel(edges),i=find(strcmp(nodes,edges(k).from),1);j=find(strcmp(nodes,edges(k).to),1);adj{i}{end+1}=[j k];adj{j}{end+1}=[i k];end
    si=find(strcmp(nodes,s),1);ri=find(strcmp(nodes,r),1);prev=zeros(1,numel(nodes));pe=zeros(1,numel(nodes));q=si;prev(si)=-1;
    h=1; while h<=numel(q), u=q(h); for z=1:numel(adj{u}), v=adj{u}{z}(1); if prev(v)==0, prev(v)=u; pe(v)=adj{u}{z}(2); q(end+1)=v; end, end, h=h+1; end
    if ri>numel(prev)||prev(ri)==0,idx=[];path_nodes={};return;end
    seq=ri;while prev(seq(1))~=-1,seq=[prev(seq(1)) seq];end;idx=pe(seq(2:end));path_nodes=nodes(seq);
end
function [attach,leaf]=off_path_edge(e,path_nodes)
    a=ismember(e.from,path_nodes);b=ismember(e.to,path_nodes);attach='';leaf='';if xor(a,b),if a,attach=e.from;leaf=e.to;else,attach=e.to;leaf=e.from;end,end
end
function [ok,rep]=round_trip_audit(c,nodes,path_nodes,s,r)
    rep=struct('path_nodes',{path_nodes},'source_node',s,'receiver_node',r,'edge_count',numel(c.edges));
    [~,e2,~,~]=graph_fields(c); % The adapter retains the original engineering graph.
    rep.recovered_edge_count=numel(e2);ok=numel(e2)==numel(c.edges)&&is_tree(nodes,e2);
end
function r=fail(r,code,msg),r.forward_model_compatible=false;r.reason_code=code;r.reason=msg;end
function x=safe_cfg(cfg),x=struct('kG',getf(cfg,'kG',1),'Zs',getf(cfg,'Zs',50),'Zr',getf(cfg,'Zr',50),'port_reference_ohm',getf(cfg,'port_reference_ohm',50));end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n),x=s.(n);else,x=d;end,end
function r=find_root(p,i),r=i;while p(r)~=r,r=p(r);end,end
