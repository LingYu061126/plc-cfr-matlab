function result = stage3a_match_toa(observed_views,reference_views,ofdm_cfg,labels,tie_tolerance)
%STAGE3A_MATCH_TOA Match only circular-delay proxies across views.
    if nargin<5||isempty(tie_tolerance),tie_tolerance=1e-10;end
    n=numel(reference_views); nv=numel(observed_views); scores=zeros(1,n);
    observed=zeros(1,nv); ref=zeros(n,nv);
    for v=1:nv, [observed(v),~]=stage3a_toa_feature(observed_views{v},ofdm_cfg); end
    for k=1:n, for v=1:nv, [ref(k,v),~]=stage3a_toa_feature(reference_views{k}{v},ofdm_cfg); end,end
    period=1/ofdm_cfg.sample_rate_hz;
    for k=1:n
        delta=abs(observed-ref(k,:)); delta=min(delta,period-delta);
        scores(k)=sqrt(mean(delta.^2));
    end
    [best,idx]=min(scores); order=sort(scores); second=order(min(2,n));
    tied=find(scores<=best+tie_tolerance*max(period,best));
    labels=labels(:).'; groups=unique(labels,'stable'); group_best=zeros(1,numel(groups));
    for g=1:numel(groups), group_best(g)=min(scores(strcmp(labels,groups{g})));end
    pg=find(strcmp(groups,labels{idx}),1); other=group_best;other(pg)=Inf;
    result=struct('predicted_index',idx,'scores',scores,'best_distance',best, ...
        'second_best_distance',second,'distance_gap',second-best,'tied_indices',tied, ...
        'ambiguous',numel(tied)>1,'predicted_group_index',pg, ...
        'predicted_group',groups{pg},'observability_group_labels',{groups}, ...
        'group_best_distances',group_best,'group_inter_best_distance',min(other), ...
        'view_count',nv,'observed_delay_s',observed,'reference_delay_s',ref, ...
        'selected_feature','toa');
end
