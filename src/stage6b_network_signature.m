function key=stage6b_network_signature(network)
%STAGE6B_NETWORK_SIGNATURE Stable physical signature for controlled studies.
    branches=network.branches;
    if isempty(branches)
        branch_text='none';
    else
        rows=zeros(numel(branches),4);
        for k=1:numel(branches)
            rows(k,:)=[branches(k).node branches(k).length branches(k).cable_type real(branches(k).load)];
        end
        rows=sortrows(rows);branch_text=sprintf('%.12g,%.12g,%.12g,%.12g;',rows.');
    end
    key=sprintf('M=%s|T=%s|B=%s',sprintf('%.12g,',network.main_lengths), ...
        sprintf('%.12g,',network.main_cable_type),branch_text);
end
