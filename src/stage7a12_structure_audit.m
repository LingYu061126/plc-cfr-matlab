function out=stage7a12_structure_audit(truth_network,candidates)
%STAGE7A12_STRUCTURE_AUDIT Evaluation-only branch-edge/junction mismatch.
%   Main-root path coordinates are metres. This function accepts truth and
%   must never be called by generation or confirmation APIs.
    truth=positions(truth_network);n=numel(truth);
    wrong=Inf(1,numel(candidates));recovered=zeros(1,numel(candidates));
    for k=1:numel(candidates)
        candidate=positions(candidates(k).network);
        remaining=candidate;matches=0;
        for j=1:n
            p=find(abs(remaining-truth(j))<1e-9,1);
            if ~isempty(p)
                matches=matches+1;remaining(p)=[];
            end
        end
        wrong(k)=n+numel(candidate)-2*matches;
        recovered(k)=nnz(arrayfun(@(v)any(abs(candidate-v)<1e-9), ...
            unique(truth)));
    end
    if isempty(wrong),minimum=NaN;maximum=0;
    else,minimum=min(wrong);maximum=max(recovered);end
    out=struct('truth_hidden_junction_count',numel(unique(truth)), ...
        'min_wrong_branch_edges',minimum, ...
        'max_recovered_hidden_junctions',maximum, ...
        'per_candidate_wrong_branch_edges',wrong);
end
function p=positions(net)
    p=zeros(1,numel(net.branches));
    for k=1:numel(p)
        p(k)=sum(net.main_lengths(1:net.branches(k).node));
    end
end
