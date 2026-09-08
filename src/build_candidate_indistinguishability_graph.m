function graph = build_candidate_indistinguishability_graph(candidate_ids, scores, resolution)
%BUILD_CANDIDATE_INDISTINGUISHABILITY_GRAPH Build calibrated score graph.
%   Connected components are calibrated indistinguishability sets, not
%   strict physical equivalence classes.
    if nargin<3||isempty(resolution),resolution=0;end
    ids=stage4a7_1_cellstr(candidate_ids);s=double(scores(:));n=numel(ids);
    if numel(s)~=n,error('stage4a7_1:ScoreLength','candidate_ids and scores differ.');end
    adj=false(n);for i=1:n,for j=i+1:n,if isfinite(s(i))&&isfinite(s(j))&&abs(s(i)-s(j))<=resolution,adj(i,j)=true;adj(j,i)=true;end,end,end
    comp=zeros(n,1);cc=0;
    for i=1:n
        if comp(i)~=0,continue;end
        cc=cc+1;queue=i;comp(i)=cc;
        while ~isempty(queue),q=queue(1);queue(1)=[];next=find(adj(q,:)&comp.'==0);comp(next)=cc;queue=[queue next];end %#ok<AGROW>
    end
    members=cell(1,cc);for k=1:cc,members{k}=ids(comp==k);end
    graph=struct('candidate_ids',{ids},'scores',s,'adjacency',adj,'component_index',comp, ...
        'components',{members},'resolution',resolution,'definition','calibrated_indistinguishability_not_physical_equivalence');
end
