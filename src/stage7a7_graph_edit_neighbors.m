function neighbors=stage7a7_graph_edit_neighbors(pool,index)
%STAGE7A7_GRAPH_EDIT_NEIGHBORS Physical one-step branch or junction edits.
%   Does not inspect truth labels, observations, or candidate ID substrings.
    a=features(pool(index).network);neighbors=[];
    for j=1:numel(pool)
        if j==index,continue;end
        b=features(pool(j).network);
        if a.junction_m==b.junction_m
            delta=b.old_counts-a.old_counts;
            one_branch=sum(abs(delta))==1;
            moved=sum(delta)==0&&sum(abs(delta))==2&&nnz(delta)==2;
            adjacent=one_branch||moved;
        else
            adjacent=(a.junction_m==0||b.junction_m==0)&& ...
                isequal(a.old_counts,b.old_counts);
        end
        if adjacent,neighbors(end+1)=j;end %#ok<AGROW>
    end
end
function f=features(net)
    if numel(net.main_lengths)==4
        f.junction_m=0;nodes=[1 2 3];junction_node=0;
    else
        assert(numel(net.main_lengths)==5,'stage7a7:MainPath');
        if isequal(net.main_lengths,[20 10 10 20 20])
            f.junction_m=30;nodes=[1 3 4];junction_node=2;
        elseif isequal(net.main_lengths,[20 20 10 10 20])
            f.junction_m=50;nodes=[1 2 4];junction_node=3;
        else
            error('stage7a7:UnknownJunction');
        end
    end
    f.old_counts=zeros(1,3);count_junction=0;
    for k=1:numel(net.branches)
        node=net.branches(k).node;
        if node==junction_node,count_junction=count_junction+1;continue;end
        p=find(nodes==node,1);
        assert(~isempty(p),'stage7a7:UnknownBranchNode');
        f.old_counts(p)=f.old_counts(p)+1;
    end
    assert((f.junction_m==0&&count_junction==0)|| ...
        (f.junction_m~=0&&count_junction==1),'stage7a7:JunctionBranch');
end
