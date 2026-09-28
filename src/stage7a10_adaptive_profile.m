function out=stage7a10_adaptive_profile(observed,bank,indices,sigma,selector,first_threshold)
%STAGE7A10_ADAPTIVE_PROFILE Truth-free candidate-dependent CFR view choice.
%   Complex spectra are 1-by-F. Node receiver templates include their load.
    if ~strcmp(selector.bank_identity,bank.identity)
        error('stage7a10:BankIdentity','Selector bank identity differs.');
    end
    if ~isequal(selector.candidate_ids,bank.candidate_ids)
        error('stage7a10:CandidateIdentity','Selector candidate order differs.');
    end
    first=stage7a4_profile_views(observed,bank,indices,5,sigma);
    [~,order]=sort(first.distances);keep=first.distances<=first_threshold;
    if ~any(keep)
        out=struct('distances',Inf(1,numel(indices)),'selected_view',0, ...
            'first_set',false(1,numel(indices)),'separation',NaN, ...
            'quality_reason','empty_first_set');return;
    end
    local=find(keep);
    if numel(local)==1
        local=unique([local order(1) order(2)]);
    end
    global_ix=indices(local);scores=zeros(1,numel(selector.extra_views));
    for v=1:numel(scores)
        pair=zeros(1,nchoosek(numel(global_ix),2));cursor=0;
        for i=1:numel(global_ix)-1
            for j=i+1:numel(global_ix)
                cursor=cursor+1;
                pair(cursor)=selector.separation(global_ix(i),global_ix(j),v);
            end
        end
        scores(v)=min(pair);
    end
    [sep,k]=max(scores);selected=selector.extra_views(k);
    if selected>=12 % loaded node port: include its loaded endpoint, not H50
        views=[selected-1 selected];
    else
        views=[5 selected];
    end
    p=stage7a4_profile_views(observed,bank,indices,views,sigma);
    out=struct('distances',p.distances,'selected_view',selected, ...
        'first_set',keep,'separation',sep,'quality_reason','selected');
end
