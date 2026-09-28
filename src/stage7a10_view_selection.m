function out=stage7a10_view_selection(bank,sigma,extra_views)
%STAGE7A10_VIEW_SELECTION Precompute pair separation without test data.
%   Uses all template parameter rows and candidate identities. Output
%   separation(i,j,v) is minimum normalized complex RMS across both graphs'
%   allowed parameter rows; it is not a physical-global identifiability proof.
    n=numel(bank.candidate_ids);nv=numel(extra_views);
    sep=zeros(n,n,nv);
    for v=1:nv
        ix=extra_views(v);assert(sigma(ix)>0);
        for i=1:n-1
            ai=bank.templates{i,ix};
            for j=i+1:n
                bj=bank.templates{j,ix};best=Inf;
                for p=1:size(ai,1)
                    d=sqrt(mean(abs(bj-ai(p,:)).^2,2))/sigma(ix);
                    best=min(best,min(d));
                end
                sep(i,j,v)=best;sep(j,i,v)=best;
            end
        end
    end
    out=struct('separation',sep,'extra_views',extra_views, ...
        'bank_identity',bank.identity,'candidate_ids',{bank.candidate_ids});
end
