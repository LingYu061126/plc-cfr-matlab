function out = compute_topk_template_evidence(distances, subband_distances, cache, k_values)
%COMPUTE_TOPK_TEMPLATE_EVIDENCE Summarize equally sized template neighborhoods.
%   Every topology contributes the same K values from its own parameter grid;
%   no topology receives an advantage from having more templates.
    if nargin<4||isempty(k_values), k_values=[3,5,10]; end
    ids={cache.templates.topology_id}; labels=stable_unique(ids); n_top=numel(labels);
    k_values=unique(k_values(:).'); kmax=max(k_values); nband=size(subband_distances,2);
    best_dist=Inf(1,n_top); best_template=zeros(1,n_top); best_sub=zeros(n_top,nband);
    top_idx=cell(1,n_top); top_dist=cell(1,n_top); neigh=zeros(n_top,numel(k_values)); neigh_std=zeros(n_top,numel(k_values));
    for g=1:n_top
        ix=find(strcmp(ids,labels{g})); [s,ord]=sort(distances(ix),'ascend');
        kk=min(kmax,numel(s)); ord=ord(1:kk); chosen=ix(ord);
        best_dist(g)=s(1); best_template(g)=chosen(1); best_sub(g,:)=subband_distances(chosen(1),:);
        top_idx{g}=chosen; top_dist{g}=s(1:kk);
        for q=1:numel(k_values)
            k=min(k_values(q),kk); vals=s(1:k); neigh(g,q)=mean(vals); neigh_std(g,q)=std(vals,1);
        end
    end
    class_ids={cache.templates.equivalence_class}; class_labels=stable_unique(class_ids);
    class_members=cell(1,numel(class_labels)); class_topology_indices=cell(1,numel(class_labels)); class_score=zeros(1,numel(class_labels)); class_best_top=zeros(1,numel(class_labels));
    for c=1:numel(class_labels)
        gi=find(strcmp(class_ids,class_labels{c})); gi=unique(cellfun(@(x)find(strcmp(labels,x),1),ids(gi)));
        class_topology_indices{c}=gi; class_members{c}=stable_unique(labels(gi)); class_score(c)=min(best_dist(gi)); [~,j]=min(best_dist(gi)); class_best_top(c)=gi(j);
    end
    [d1,bi]=min(class_score); tmp=class_score;tmp(bi)=Inf;[d2,si]=min(tmp);
    raw_best=class_best_top(bi); best_class=class_labels{bi};
    neigh_class=zeros(1,numel(class_labels),numel(k_values));
    neigh_margin=zeros(1,numel(k_values)); best_neigh=zeros(1,numel(k_values)); second_neigh=zeros(1,numel(k_values));
    for q=1:numel(k_values)
        for c=1:numel(class_labels)
            gi=class_topology_indices{c};
            neigh_class(1,c,q)=min(neigh(gi,q));
        end
        [best_neigh(q),bc]=min(neigh_class(1,:,q)); z=neigh_class(1,:,q);z(bc)=Inf;second_neigh(q)=min(z);neigh_margin(q)=second_neigh(q)-best_neigh(q);
    end
    selected_neigh=zeros(1,numel(k_values)); selected_second=Inf(1,numel(k_values)); selected_margin=zeros(1,numel(k_values));
    for q=1:numel(k_values)
        selected_neigh(q)=neigh_class(1,bi,q); z=neigh_class(1,:,q);z(bi)=Inf;selected_second(q)=min(z);selected_margin(q)=selected_second(q)-selected_neigh(q);
    end
    out=struct('topology_labels',{labels},'best_distance',best_dist,'best_template',best_template, ...
        'best_subband_distance',best_sub,'topK_template_indices',{top_idx},'topK_template_distances',{top_dist}, ...
        'neighborhood_scores',neigh,'neighborhood_std',neigh_std,'class_labels',{class_labels}, ...
        'class_members',{class_members},'class_scores',class_score,'class_best_topology',class_best_top, ...
        'best_class_index',bi,'second_class_index',si,'best_class',best_class, ...
        'best_class_members',strjoin(class_members{bi},','),'best_topology',labels{raw_best}, ...
        'best_topology_index',raw_best,'best_template_index',best_template(raw_best), ...
        'best_distance_value',d1,'second_distance_value',d2,'margin',d2-d1, ...
        'neighborhood_class_scores',neigh_class,'best_neighborhood_scores',best_neigh, ...
        'second_neighborhood_scores',second_neigh,'neighborhood_margins',neigh_margin, ...
        'selected_neighborhood_scores',selected_neigh,'selected_second_neighborhood_scores',selected_second, ...
        'selected_neighborhood_margins',selected_margin, ...
        'k_values',k_values);
end
function y=stable_unique(x),y={};for k=1:numel(x),if ~any(strcmp(y,x{k})),y{end+1}=x{k};end,end,end
