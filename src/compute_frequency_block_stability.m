function out = compute_frequency_block_stability(observed_views, cache, topk, options, seed)
%COMPUTE_FREQUENCY_BLOCK_STABILITY Estimate selection stability without refitting.
%   Contiguous frequency blocks are resampled.  Only the cached Kmax
%   neighborhood templates are rescored; no forward model is called.
    if nargin<5||isempty(seed), seed=1; end
    if nargin<4||isempty(options), options=struct(); end
    B=get_option(options,'repetitions',30); nblock=get_option(options,'block_count',4); frac=get_option(options,'block_fraction',0.25);
    if ~iscell(observed_views),observed_views={observed_views};end
    nfreq=numel(cache.frequency_hz); block_len=max(1,min(nfreq,round(nfreq*frac)));
    ids=topk.topology_labels; n_top=numel(ids); classes=topk.class_labels; n_class=numel(classes);
    class_index=zeros(1,n_top); for g=1:n_top, class_index(g)=find(cellfun(@(x)any(strcmp(x,ids{g})),topk.class_members),1); end
    topo_counts=zeros(1,n_top); class_counts=zeros(1,n_class); selected_top=cell(1,B); selected_class=cell(1,B);
    old=rng;cleanup=onCleanup(@()rng(old));rng(seed,'twister');
    for b=1:B
        keep=false(1,nfreq);
        for j=1:nblock
            start=1+floor(rand*max(1,nfreq-block_len+1)); keep(start:min(nfreq,start+block_len-1))=true;
        end
        if ~any(keep),keep(1:min(nfreq,block_len))=true;end
        topo_score=Inf(1,n_top);
        for g=1:n_top
            ix=topk.topK_template_indices{g};best=Inf;
            for t=1:numel(ix)
                e2=0;count=0;
                for v=1:numel(observed_views)
                    obs=observed_views{v}(:).';ref=cache.cfr_views{v}(ix(t),:);e2=e2+sum(abs(ref(keep)-obs(keep)).^2);count=count+sum(keep);
                end
                best=min(best,sqrt(e2/count));
            end
            topo_score(g)=best;
        end
        class_score=Inf(1,n_class);
        for c=1:n_class,class_score(c)=min(topo_score(class_index==c));end
        [~,g]=min(topo_score);[~,c]=min(class_score);topo_counts(g)=topo_counts(g)+1;class_counts(c)=class_counts(c)+1;
        selected_top{b}=ids{g};selected_class{b}=classes{c};
    end
    [~,g0]=min(topk.best_distance);[~,c0]=min(topk.class_scores);
    out=struct('repetitions',B,'block_count',nblock,'block_length',block_len, ...
        'topology_selection_stability',topo_counts/B,'class_selection_stability',class_counts/B, ...
        'best_topology_stability',topo_counts(g0)/B,'best_class_stability',class_counts(c0)/B, ...
        'bootstrap_best_topology',ids{g0},'bootstrap_best_class',classes{c0}, ...
        'selected_topology_ids',{selected_top},'selected_class_ids',{selected_class}, ...
        'seed',seed,'uses_topK_cache',true);
end
function x=get_option(s,n,d),if isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
