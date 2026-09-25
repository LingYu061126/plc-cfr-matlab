function out=stage7a4_profile_views(observed,bank,candidate_indices,view_indices,sigma)
%STAGE7A4_PROFILE_VIEWS Jointly fit all views with one shared theta row.
%   observed is a cell array of complex row vectors. Sigma is calibrated
%   complex RMS error per view, in the natural units of that view. Scoring
%   never receives the observation's generating topology or nuisance theta.
    assert(numel(observed)==numel(bank.view_names) && ...
        numel(sigma)==numel(bank.view_names),'stage7a4:ViewIdentity');
    assert(all(isfinite(sigma(view_indices)))&&all(sigma(view_indices)>0), ...
        'stage7a4:InvalidScale');
    n=numel(candidate_indices);d=Inf(1,n);best=zeros(1,n);
    for q=1:n
        k=candidate_indices(q);nt=size(bank.templates{k,view_indices(1)},1);
        accum=zeros(nt,1);
        for j=1:numel(view_indices)
            v=view_indices(j);y=observed{v}(:).';
            h=bank.templates{k,v};
            assert(numel(y)==size(h,2)&&all(isfinite(y)), ...
                'stage7a4:ObservationShape');
            residual=sqrt(mean(abs(h-y).^2,2))/sigma(v);
            accum=accum+residual.^2;
        end
        [d(q),best(q)]=min(sqrt(accum/numel(view_indices)));
    end
    out=struct('distances',d,'best_template_indices',best, ...
        'candidate_ids',{bank.candidate_ids(candidate_indices)}, ...
        'template_params',bank.params(best,:),'view_indices',view_indices, ...
        'view_names',{bank.view_names(view_indices)});
end
