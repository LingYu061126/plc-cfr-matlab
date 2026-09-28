function selector=stage7a11_view_selector(bank,sigma,extra_views)
%STAGE7A11_VIEW_SELECTOR Precompute finite-grid joint CFR pair distances.
%   Each surface is parameter-row-by-parameter-row; a row fixes one graph's
%   physical nuisance parameters across all views. CFR and sigma share units.
    assert(numel(sigma)==numel(bank.view_names) && all(sigma>0) && ...
        all(isfinite(sigma)),'stage7a11:ScaleIdentity');
    n=numel(bank.candidate_ids);nv=numel(extra_views);
    surfaces=cell(n,n,nv);separation=zeros(n,n,nv);
    for v=1:nv
        view=extra_views(v);
        assert(ismember(view,[3 7 12 14 16]),'stage7a11:ViewBudget');
        if view>=12,views=[5 view-1 view];else,views=[5 view];end
        for i=1:n-1
            nr=size(bank.templates{i,5},1);
            for j=i+1:n
                ns=size(bank.templates{j,5},1);accum=zeros(nr,ns);
                for u=views
                    a=bank.templates{i,u};b=bank.templates{j,u};
                    assert(size(a,1)==nr && size(b,1)==ns, ...
                        'stage7a11:ParameterRowIdentity');
                    for r=1:nr
                        accum(r,:)=accum(r,:)+ ...
                            mean(abs(b-a(r,:)).^2,2)'/sigma(u)^2;
                    end
                end
                surface=sqrt(accum/numel(views));
                surfaces{i,j,v}=surface;
                separation(i,j,v)=min(surface(:));
                separation(j,i,v)=separation(i,j,v);
            end
        end
    end
    payload=struct('algorithm','joint_h50_conditioned_grid_v1', ...
        'bank_identity',bank.identity,'sigma',sigma,'extra_views',extra_views, ...
        'separation',separation);
    selector=struct('algorithm',payload.algorithm,'bank_identity',bank.identity, ...
        'candidate_ids',{bank.candidate_ids},'sigma',sigma, ...
        'extra_views',extra_views,'surfaces',{surfaces}, ...
        'separation',separation,'identity',stage4a4_scientific_config_hash(payload));
end
