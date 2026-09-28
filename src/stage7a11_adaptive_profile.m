function out=stage7a11_adaptive_profile(observed,bank,indices,sigma,selector,first_threshold)
%STAGE7A11_ADAPTIVE_PROFILE Select one extra CFR state without truth labels.
%   observed{v} is a complex 1-by-F spectrum; distances are dimensionless.
    if ~strcmp(bank.identity,selector.bank_identity) || ...
            ~isequal(bank.candidate_ids,selector.candidate_ids)
        error('stage7a11:BankIdentity','Selector and bank differ.');
    end
    if ~strcmp(selector.algorithm,'joint_h50_conditioned_grid_v1') || ...
            ~isequal(sigma,selector.sigma)
        error('stage7a11:SelectorIdentity','Selector and scale differ.');
    end
    first=stage7a4_profile_views(observed,bank,indices,5,sigma);
    d0=first.distances;keep=d0<=first_threshold;
    out=struct('distances',Inf(1,numel(indices)),'selected_view',0, ...
        'first_set',keep,'first_distances',d0,'separation',NaN, ...
        'view_scores',NaN(1,numel(selector.extra_views)), ...
        'competition_indices',[],'quality_reason','empty_first_set');
    if ~any(keep),return;end
    [~,order]=sort(d0);local=find(keep);
    if numel(local)==1,local=unique([local order(2)]);end
    global_ix=indices(local);plausible=cell(1,numel(local));
    for a=1:numel(local)
        k=global_ix(a);h=bank.templates{k,5};y=observed{5}(:).';
        residual=sqrt(mean(abs(h-y).^2,2))/sigma(5);
        mask=residual<=first_threshold(local(a));
        if ~any(mask),[~,best]=min(residual);mask(best)=true;end
        plausible{a}=mask;
    end
    scores=zeros(1,numel(selector.extra_views));
    for v=1:numel(scores)
        worst=Inf;
        for a=1:numel(local)-1
            for b=a+1:numel(local)
                i=global_ix(a);j=global_ix(b);
                if i<j
                    surface=selector.surfaces{i,j,v};
                    x=surface(plausible{a},plausible{b});
                else
                    surface=selector.surfaces{j,i,v};
                    x=surface(plausible{b},plausible{a});
                end
                worst=min(worst,min(x(:)));
            end
        end
        scores(v)=worst;
    end
    [sep,v]=max(scores);selected=selector.extra_views(v);
    if selected>=12,views=[selected-1 selected];else,views=[5 selected];end
    profile=stage7a4_profile_views(observed,bank,indices,views,sigma);
    out.distances=profile.distances;out.selected_view=selected;
    out.separation=sep;out.view_scores=scores;
    out.competition_indices=global_ix;out.quality_reason='selected';
end
