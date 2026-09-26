function out=stage7a4_continuous_profile_zin(y,pair,bank,base,cfg,sigma)
%STAGE7A4_CONTINUOUS_PROFILE_ZIN Fit each candidate's bounded nuisance.
%   y is 1-by-F complex Zin in ohm. The scorer receives neither truth nor
%   the generating nuisance parameters. It starts from the 45-point grid,
%   then refines main-length and branch-load scales in their fixed bounds.
    assert(isrow(y)&&numel(y)==numel(cfg.frequency_hz)&&all(isfinite(y)));
    assert(numel(pair)==2&&numel(bank.candidate_ids)==2&& ...
        isscalar(sigma)&&isfinite(sigma)&&sigma>0);
    g=stage7a4_profile_views({y},bank,[1 2],1,sigma);
    opts=optimset('TolX',cfg.optimizer_tol_x, ...
        'MaxFunEvals',cfg.optimizer_max_fun_evals,'Display','off');
    mgrid=unique(bank.params(:,1));
    d=g.distances;params=zeros(2,2);exitflag=zeros(1,2);
    evaluations=zeros(1,2);boundary_hit=false(1,2);
    for k=1:2
        initial=bank.params(g.best_template_indices(k),1:2);
        ix=find(abs(mgrid-initial(1))<1e-12,1);
        assert(~isempty(ix));
        lo=mgrid(max(1,ix-1));hi=mgrid(min(numel(mgrid),ix+1));
        objective=@(m,l) residual_sq(m,l,y,pair(k).network,base,cfg);
        [m1,~,e1,o1]=fminbnd(@(m)objective(m,initial(2)),lo,hi,opts);
        [l1,~,e2,o2]=fminbnd(@(l)objective(m1,l), ...
            cfg.load_scale_bounds(1),cfg.load_scale_bounds(2),opts);
        [m2,f2,e3,o3]=fminbnd(@(m)objective(m,l1),lo,hi,opts);
        initial_sq=(sigma*g.distances(k))^2;
        evaluations(k)=o1.funcCount+o2.funcCount+o3.funcCount;
        exitflag(k)=min([e1 e2 e3]);
        if f2<initial_sq
            d(k)=sqrt(max(f2,0))/sigma;params(k,:)=[m2 l1];
        else
            params(k,:)=initial;
        end
        boundary_hit(k)=any(abs(params(k,:)- ...
            [cfg.main_scale_bounds(1) cfg.load_scale_bounds(1)])<1e-6) || ...
            any(abs(params(k,:)- ...
            [cfg.main_scale_bounds(2) cfg.load_scale_bounds(2)])<1e-6);
        assert(isfinite(d(k))&&d(k)<=g.distances(k)+1e-10, ...
            'stage7a4r2:ContinuousScoreWorse');
    end
    out=struct('grid_distances',g.distances,'continuous_distances',d, ...
        'grid_params',bank.params(g.best_template_indices,1:2), ...
        'continuous_params',params,'exitflag',exitflag, ...
        'evaluations',evaluations,'boundary_hit',boundary_hit, ...
        'candidate_ids',{bank.candidate_ids},'bank_identity',bank.identity);
end

function value=residual_sq(main,load,y,network,base,cfg)
    theta=struct('main_length_scale',main,'branch_length_scale',1, ...
        'branch_load_scale',load,'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
    z=stage7a4_forward_state(network,theta,base,cfg.frequency_hz,cfg.state);
    value=mean(abs(z.Zin-y).^2);
end
