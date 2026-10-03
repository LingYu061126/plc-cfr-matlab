function out=stage7a13_structure_audit(truth_network,candidates)
%STAGE7A13_STRUCTURE_AUDIT Evaluation-only physical graph distinctions.
%   Truth is permitted here only. Attachment coordinates/edge lengths use m.
%   B1..Bn and intermediate M1..Mm are physical node labels for this audit;
%   equal attachment positions alone do not establish graph recovery.
    n=numel(candidates);
    prototype=struct('candidate_id',"",'wrong_attachment_count',NaN, ...
        'attachment_positions_match',false, ...
        'labelled_connectivity_match',false, ...
        'edge_attributes_match',false,'signature_match',false, ...
        'complete_physical_match',false);
    rows=repmat(prototype,n,1);
    true_positions=attachment_positions(truth_network);
    [true_keys,true_attributes]=labelled_edges(truth_network);
    true_signature=stage6b_network_signature(truth_network);
    for i=1:n
        network=candidates(i).network;
        positions=attachment_positions(network);
        wrong=multiset_difference(true_positions,positions);
        [keys,attributes]=labelled_edges(network);
        connections=isequal(true_keys,keys);
        attributes_match=connections && ...
            isequaln(true_attributes,attributes);
        signature_match=strcmp(true_signature, ...
            stage6b_network_signature(network));
        rows(i)=struct('candidate_id',string(candidates(i).topology_id), ...
            'wrong_attachment_count',wrong, ...
            'attachment_positions_match',wrong==0, ...
            'labelled_connectivity_match',connections, ...
            'edge_attributes_match',attributes_match, ...
            'signature_match',signature_match, ...
            'complete_physical_match',attributes_match && signature_match);
    end
    if isempty(rows)
        minimum=NaN;
    else
        minimum=min([rows.wrong_attachment_count]);
    end
    out=struct('candidates',rows, ...
        'min_wrong_attachment_count',minimum, ...
        'any_attachment_positions_match',any([rows.attachment_positions_match]), ...
        'any_labelled_connectivity_match',any([rows.labelled_connectivity_match]), ...
        'any_edge_attributes_match',any([rows.edge_attributes_match]), ...
        'any_complete_physical_match',any([rows.complete_physical_match]));
end

function positions=attachment_positions(network)
    positions=zeros(1,numel(network.branches));
    for i=1:numel(positions)
        positions(i)=sum(network.main_lengths(1:network.branches(i).node));
    end
    positions=sort(positions);
end

function wrong=multiset_difference(a,b)
    remaining=b;matches=0;
    for i=1:numel(a)
        j=find(abs(remaining-a(i))<1e-9,1);
        if ~isempty(j)
            matches=matches+1;
            remaining(j)=[];
        end
    end
    wrong=numel(a)+numel(b)-2*matches;
end

function [keys,attributes]=labelled_edges(network)
    m=numel(network.main_lengths);
    n=numel(network.branches);
    keys=strings(m+n,1);
    attributes=cell(m+n,1);
    for i=1:m
        keys(i)=sprintf('M%d>M%d:main',i-1,i);
        attributes{i}={network.main_lengths(i), ...
            network.main_cable_type(i),NaN};
    end
    for i=1:n
        branch=network.branches(i);
        keys(m+i)=sprintf('M%d>B%d:branch',branch.node,i);
        attributes{m+i}={branch.length,branch.cable_type,branch.load};
    end
    [keys,order]=sort(keys);
    attributes=attributes(order);
end
