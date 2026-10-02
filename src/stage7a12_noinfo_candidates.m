function indices=stage7a12_noinfo_candidates(labels,pool,cfg,count,seed)
%STAGE7A12_NOINFO_CANDIDATES Random count-matched graph control.
%   Uses only observed meter labels, requested count and independent seed.
    eligible=zeros(1,0);
    for k=1:numel(pool)
        ci=stage7a12_ci_matrix(pool(k).network,cfg);
        if isequal(ci.labels,labels),eligible(end+1)=k;end %#ok<AGROW>
    end
    assert(count<=numel(eligible),'stage7a12:ControlCount');
    if count==0,indices=[];return;end
    rs=RandStream('mt19937ar','Seed',seed);
    order=randperm(rs,numel(eligible));indices=eligible(order(1:count));
end
