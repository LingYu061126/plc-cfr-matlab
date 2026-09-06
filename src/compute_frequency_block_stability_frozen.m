function out = compute_frequency_block_stability_frozen(observed_views,cache,topk,masks)
%COMPUTE_FREQUENCY_BLOCK_STABILITY_FROZEN Rescore common frozen masks.
    if ~iscell(observed_views),observed_views={observed_views};end
    B=size(masks,1);nf=numel(cache.frequency_hz);if size(masks,2)~=nf,error('stage4a5_1:MaskSize','Mask frequency count mismatch.');end
    ids=topk.topology_labels;classes=topk.class_labels;nt=numel(ids);nc=numel(classes);ci=zeros(1,nt);
    for g=1:nt,ci(g)=find(cellfun(@(x)any(strcmp(x,ids{g})),topk.class_members),1);end
    tc=zeros(1,nt);cc=zeros(1,nc);
    for b=1:B
        keep=masks(b,:);score=Inf(1,nt);
        for g=1:nt
            ix=topk.topK_template_indices{g};
            for t=1:numel(ix)
                e2=0;n=0;for v=1:numel(observed_views),o=observed_views{v}(:).';q=cache.cfr_views{v}(ix(t),:);e2=e2+sum(abs(q(keep)-o(keep)).^2);n=n+sum(keep);end
                score(g)=min(score(g),sqrt(e2/n));
            end
        end
        cs=Inf(1,nc);for c=1:nc,cs(c)=min(score(ci==c));end
        [~,g]=min(score);[~,c]=min(cs);tc(g)=tc(g)+1;cc(c)=cc(c)+1;
    end
    [~,g0]=min(topk.best_distance);[~,c0]=min(topk.class_scores);
    out=struct('repetitions',B,'topology_selection_stability',tc/B,'class_selection_stability',cc/B,'best_topology_stability',tc(g0)/B,'best_class_stability',cc(c0)/B,'bootstrap_best_topology',ids{g0},'bootstrap_best_class',classes{c0},'uses_topK_cache',true,'uses_frozen_common_masks',true);
end
