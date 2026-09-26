function neighbors=stage7a5_graph_edit_neighbors(pool,index)
%STAGE7A5_GRAPH_EDIT_NEIGHBORS Return valid one-branch add/delete/move graphs.
%   The graph is represented by branch counts at M1/M2/M3 in this grammar.
    counts=branch_counts(pool(index).network);neighbors=[];
    for j=1:numel(pool)
        if j==index,continue;end
        delta=branch_counts(pool(j).network)-counts;
        add_or_delete=sum(abs(delta))==1;
        moved=sum(delta)==0&&sum(abs(delta))==2&&nnz(delta)==2;
        if add_or_delete||moved,neighbors(end+1)=j;end %#ok<AGROW>
    end
end

function counts=branch_counts(network)
    counts=zeros(1,3);
    for k=1:numel(network.branches)
        counts(network.branches(k).node)=counts(network.branches(k).node)+1;
    end
end
