function out=stage7a5_profile(observed,pool,bank,base,cfg,candidate_indices, ...
        views,sigma,frequency_indices,use_continuous)
%STAGE7A5_PROFILE Truth-free shared-parameter CFR/Zin profile distance.
%   observed contains {H50,Zin50}; views selects 1, 2, or both. Frequencies
%   are row indices. Continuous fitting starts from the best cached grid
%   point and searches only inside its adjacent main-scale grid interval.
    if nargin<11,use_continuous=true;end
    if ~isequal(bank.search_identity,expected_search_identity(cfg))
        error('stage7a5:SearchIdentityMismatch', ...
            'Template bank and requested parameter search domain differ.');
    end
    assert(numel(observed)==2&&all(ismember(views,[1 2]))&&~isempty(views));
    assert(numel(sigma)==2&&all(isfinite(sigma(views)))&&all(sigma(views)>0));
    assert(all(frequency_indices>=1&frequency_indices<=numel(cfg.frequency_hz)));
    n=numel(candidate_indices);d=inf(1,n);gridrow=zeros(1,n);
    params=zeros(n,2);evals=zeros(1,n);exitflag=ones(1,n);
    for q=1:n
        k=candidate_indices(q);nt=size(bank.params,1);accum=zeros(nt,1);
        for v=views
            y=observed{v}(:).';h=bank.templates{k,v};
            residual=sqrt(mean(abs(h(:,frequency_indices)-y(frequency_indices)).^2,2))/sigma(v);
            accum=accum+residual.^2;
        end
        [d(q),gridrow(q)]=min(sqrt(accum/numel(views)));
        params(q,:)=bank.params(gridrow(q),:);
    end
    grid_d=d;
    if use_continuous
        main_grid=unique(bank.params(:,1));
        opts=optimset('TolX',1e-6,'MaxFunEvals',35,'Display','off');
        for q=1:n
            k=candidate_indices(q);initial=params(q,:);
            im=find(abs(main_grid-initial(1))<1e-12,1);
            lo=main_grid(max(1,im-1));hi=main_grid(min(numel(main_grid),im+1));
            fun=@(m,l)objective(m,l,observed,views,sigma,frequency_indices, ...
                pool(k).network,base,cfg);
            [m1,~,e1,o1]=fminbnd(@(m)fun(m,initial(2)),lo,hi,opts);
            [l1,~,e2,o2]=fminbnd(@(l)fun(m1,l),cfg.load_scale_bounds(1), ...
                cfg.load_scale_bounds(2),opts);
            [m2,f2,e3,o3]=fminbnd(@(m)fun(m,l1),lo,hi,opts);
            evals(q)=o1.funcCount+o2.funcCount+o3.funcCount;
            exitflag(q)=min([e1 e2 e3]);
            if f2<d(q)^2,d(q)=sqrt(max(f2,0));params(q,:)=[m2 l1];end
        end
    end
    assert(all(isfinite(d))&&all(d<=grid_d+1e-9),'stage7a5:ProfileIncrease');
    out=struct('candidate_indices',candidate_indices,'candidate_ids', ...
        {bank.candidate_ids(candidate_indices)},'distances',d, ...
        'grid_distances',grid_d,'params',params,'grid_rows',gridrow, ...
        'evaluations',evals,'exitflag',exitflag,'views',views, ...
        'frequency_indices',frequency_indices);
end

function value=objective(main,load,observed,views,sigma,frequency_indices,network,base,cfg)
    theta=struct('main_length_scale',main,'branch_length_scale',1, ...
        'branch_load_scale',load,'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
    z=stage7a4_forward_state(network,theta,base,cfg.frequency_hz,cfg.state_50);
    pred={z.H_endpoint,z.Zin};value=0;
    for v=views
        ix=frequency_indices;
        r=sqrt(mean(abs(pred{v}(ix)-observed{v}(ix)).^2))/sigma(v);
        value=value+r^2/numel(views);
    end
end

function identity=expected_search_identity(cfg)
    identity=stage4a4_scientific_config_hash(struct( ...
        'main_bounds',cfg.main_scale_bounds,'load_bounds',cfg.load_scale_bounds, ...
        'main_grid',cfg.main_scale_grid,'load_grid',cfg.load_scale_grid, ...
        'frequency_hz',cfg.frequency_hz,'state',cfg.state_50));
end
