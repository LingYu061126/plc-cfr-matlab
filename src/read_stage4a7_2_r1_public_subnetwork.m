function [reference, audit] = read_stage4a7_2_r1_public_subnetwork(csv_path)
%READ_STAGE4A7_2_R1_PUBLIC_SUBNETWORK Read the committed ENWL-derived rows.
%   The rows are a derived, auditable subnetwork.  They contain no raw ZIP
%   contents and are not treated as an uncertain ledger until the separate
%   uncertainty builder has generated that ledger.
    if ~(ischar(csv_path)||isstring(csv_path)) || ~exist(csv_path,'file')
        error('stage4a7_2_r1:MissingSubnetwork','Derived subnetwork CSV is missing.');
    end
    required={'source_dataset','source_network_id','source_feeder_id', ...
        'source_record_id','from_node','to_node','length_m','source_cable_type', ...
        'model_cable_type','reference_edge_status'};
    text=fileread(csv_path);lines=regexp(text,'\r?\n','split');lines=lines(~cellfun(@isempty,lines));
    headers=strsplit(strtrim(lines{1}),',');
    if ~all(ismember(required,headers))
        error('stage4a7_2_r1:SubnetworkFields','Derived subnetwork fields are incomplete.');
    end
    idx=zeros(1,numel(required));for k=1:numel(required),idx(k)=find(strcmp(headers,required{k}),1);end
    raw=repmat(struct('source_dataset','','source_network_id','','source_feeder_id','', ...
        'source_record_id','','from_node','','to_node','','length_m',NaN, ...
        'source_cable_type','','model_cable_type',NaN,'reference_edge_status',''),max(numel(lines)-1,0),1);
    for k=2:numel(lines)
        f=strsplit(strtrim(lines{k}),',');
        raw(k-1)=struct('source_dataset',f{idx(1)},'source_network_id',f{idx(2)}, ...
            'source_feeder_id',f{idx(3)},'source_record_id',f{idx(4)}, ...
            'from_node',f{idx(5)},'to_node',f{idx(6)},'length_m',str2double(f{idx(7)}), ...
            'source_cable_type',f{idx(8)},'model_cable_type',str2double(f{idx(9)}), ...
            'reference_edge_status',f{idx(10)});
    end
    nodes=unique([{raw.from_node},{raw.to_node}],'stable');
    % Line records do not carry a terminal load.  Keep this as NaN so the
    % adapter round-trip does not mistake a bookkeeping default for a
    % physical edge attribute.
    edge0=struct('id','','from','','to','','kind','line','length_m',NaN, ...
        'cable_type',NaN,'load',NaN,'prior_cost',NaN);
    edges=repmat(edge0,numel(raw),1);
    for k=1:numel(raw)
        edges(k).id=char(raw(k).source_record_id);
        edges(k).from=char(raw(k).from_node);edges(k).to=char(raw(k).to_node);
        edges(k).length_m=double(raw(k).length_m);
        edges(k).cable_type=double(raw(k).model_cable_type);
        edges(k).load=NaN;
    end
    reference=struct('node_ids',{nodes(:).'},'source_node_id','32', ...
        'receiver_node_id','39','edges',edges,'source_table',raw);
    audit=struct('row_count',numel(raw),'node_count',numel(nodes), ...
        'edge_count',numel(edges),'source_dataset',char(raw(1).source_dataset), ...
        'source_network_id',char(raw(1).source_network_id), ...
        'source_feeder_id',char(raw(1).source_feeder_id), ...
        'status','read_derived_public_subnetwork');
end
