function out=stage7a4_15m_profile(observed,candidates,bank,base,cfg,indices,views,sigma,nstarts)
%STAGE7A4_15M_PROFILE Shared-nuisance complex multiview grid/continuous fit.
%   Each observation is a 1-by-F complex spectrum (CFR or ohm Zin). No
%   truth label or generating nuisance enters this scoring interface.
    if nargin<9,nstarts=1;end
    assert(nstarts>=1&&nstarts<=3&&all(ismember(views,[3 4 5 6 13 14])));
    grid=stage7a4_profile_views(observed,bank,indices,views,sigma);
    nc=numel(indices);out=struct('grid_distances',grid.distances, ...
        'continuous_distances',grid.distances,'grid_params', ...
        bank.params(grid.best_template_indices,1:2), ...
        'continuous_params',bank.params(grid.best_template_indices,1:2), ...
        'evaluations',zeros(1,nc),'exitflag',ones(1,nc), ...
        'candidate_ids',{bank.candidate_ids(indices)});
    opts=optimset('TolX',cfg.optimizer_tol_x, ...
        'MaxFunEvals',cfg.optimizer_max_fun_evals,'Display','off');
    mgrid=unique(bank.params(:,1));
    for q=1:nc
        k=indices(q);start_rows=grid.best_template_indices(q);
        if nstarts>1
            all_scores=zeros(size(bank.params,1),1);
            for v=views
                h=bank.templates{k,v};y=observed{v}(:).';
                all_scores=all_scores+mean(abs(h-y).^2,2)/sigma(v)^2;
            end
            [~,ord]=sort(all_scores);chosen=start_rows;
            for j=1:numel(ord)
                if all(abs(bank.params(ord(j),1)-bank.params(chosen,1))>0.012)
                    chosen(end+1)=ord(j); %#ok<AGROW>
                end
                if numel(chosen)>=nstarts,break;end
            end
            start_rows=chosen;
        end
        best_sq=out.grid_distances(q)^2;best_par=out.grid_params(q,:);
        for row=start_rows
            initial=bank.params(row,1:2);mi=find(abs(mgrid-initial(1))<1e-12,1);
            lo=mgrid(max(1,mi-1));hi=mgrid(min(numel(mgrid),mi+1));
            fun=@(m,l) objective(m,l,observed,views,sigma, ...
                candidates(k).network,base,cfg);
            [m1,~,e1,o1]=fminbnd(@(m)fun(m,initial(2)),lo,hi,opts);
            [l1,~,e2,o2]=fminbnd(@(l)fun(m1,l), ...
                cfg.load_scale_bounds(1),cfg.load_scale_bounds(2),opts);
            [m2,f2,e3,o3]=fminbnd(@(m)fun(m,l1),lo,hi,opts);
            out.evaluations(q)=out.evaluations(q)+ ...
                o1.funcCount+o2.funcCount+o3.funcCount;
            out.exitflag(q)=min(out.exitflag(q),min([e1 e2 e3]));
            if f2<best_sq,best_sq=f2;best_par=[m2 l1];end
        end
        out.continuous_distances(q)=sqrt(max(best_sq,0));
        out.continuous_params(q,:)=best_par;
        assert(isfinite(out.continuous_distances(q))&& ...
            out.continuous_distances(q)<=out.grid_distances(q)+1e-9);
    end
end

function value=objective(main,load,observed,views,sigma,network,base,cfg)
    theta=struct('main_length_scale',main,'branch_length_scale',1, ...
        'branch_load_scale',load,'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
    states=unique(ceil(views/2));outputs=cell(1,numel(cfg.states));
    for s=states
        outputs{s}=stage7a4_forward_state(network,theta,base,cfg.frequency_hz,cfg.states(s));
    end
    value=0;
    for v=views
        s=ceil(v/2);z=outputs{s};
        if v<=10
            if mod(v,2),pred=z.H_endpoint;else,pred=z.Zin;end
        else
            if mod(v,2),pred=z.H_endpoint;else,pred=z.H_node;end
        end
        value=value+mean(abs(pred-observed{v}).^2)/sigma(v)^2;
    end
    value=value/numel(views);
end
