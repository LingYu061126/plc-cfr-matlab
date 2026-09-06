function result = optimize_topology_parameters_bounded(observed_views,frequency_hz,candidate,cfg,bounds,initial_thetas,options)
%OPTIMIZE_TOPOLOGY_PARAMETERS_BOUNDED Deterministic logistic fminsearch.
%   No truth parameter is accepted. Bounds and initial templates are frozen.
    if ~iscell(observed_views),observed_views={observed_views};end
    names=bounds.names;lo=bounds.lower(:).';hi=bounds.upper(:).';n=numel(names);
    if any(~isfinite(lo))||any(~isfinite(hi))||any(hi<=lo),error('stage4a6:Bounds','Finite ordered bounds are required.');end
    starts=initial_matrix(initial_thetas,names,lo,hi);maxs=getopt(options,'multi_start_count',2);starts=starts(1:min(maxs,size(starts,1)),:);
    opt=optimset('Display','off','MaxIter',getopt(options,'max_iterations',60),'MaxFunEvals',getopt(options,'max_function_evaluations',180),'TolX',getopt(options,'tolerance_x',1e-5),'TolFun',getopt(options,'tolerance_fun',1e-7));
    runs=repmat(run_template(n),size(starts,1),1);best=Inf;besttheta=[];t0=tic;
    for s=1:size(starts,1)
        x0=min(max(starts(s,:),lo+1e-3*(hi-lo)),hi-1e-3*(hi-lo));u0=log((x0-lo)./(hi-x0));d0=objective(u0);
        [u,d,exitflag,out]=fminsearch(@objective,u0,opt);x=transform(u);runs(s)=struct('start_index',s,'initial_parameters',starts(s,:),'final_parameters',x,'initial_distance',d0,'final_distance',d,'iterations',out.iterations,'function_evaluations',out.funcCount,'exitflag',exitflag,'runtime_s',NaN);
        if d<best,best=d;besttheta=x;beststart=s;end
    end
    for s=1:numel(runs),runs(s).runtime_s=toc(t0)/numel(runs);end
    final_dist=[runs.final_distance];stable_multistart=max(final_dist)-min(final_dist)<=1e-4*max(1,best);normpos=(besttheta-lo)./(hi-lo);result=struct('distance',best,'theta',vector_to_theta(besttheta,names),'theta_vector',besttheta,'normalized_position',normpos,'near_lower',normpos<=getopt(options,'boundary_fraction',0.05),'near_upper',normpos>=1-getopt(options,'boundary_fraction',0.05),'minimum_boundary_distance',min(min(normpos,1-normpos)),'best_start_index',beststart,'runs',runs,'converged',runs(beststart).exitflag>0||stable_multistart,'stable_multistart',stable_multistart,'runtime_s',toc(t0),'bounds',bounds);
    function d=objective(u),x=transform(u);th=vector_to_theta(x,names);[net,lc]=topology_apply_parameters(candidate.network,cfg,th);[meas,~]=plc_measurement_bundle('siso_forward',net,th,lc);[views,~]=plc_multiview_response(frequency_hz,net,meas,lc);e=0;count=0;for v=1:numel(views),z=views{v}(:).'-observed_views{v}(:).';e=e+sum(abs(z).^2);count=count+numel(z);end;d=sqrt(e/count);if ~isfinite(d),d=realmax('double')/1e100;end,end
    function x=transform(u),sig=1./(1+exp(-max(min(u,40),-40)));x=lo+(hi-lo).*sig;end
end
function x=initial_matrix(t,names,lo,hi),if isempty(t),x=(lo+hi)/2;elseif isstruct(t),x=zeros(numel(t),numel(names));for i=1:numel(t),for k=1:numel(names),x(i,k)=t(i).(names{k});end,end;else,x=t;end;x=[x;(lo+hi)/2];[~,ia]=unique(round(x,12),'rows','stable');x=x(sort(ia),:);end
function t=vector_to_theta(x,n),t=struct();for k=1:numel(n),t.(n{k})=x(k);end;t.regularization=NaN;end
function x=getopt(s,n,d),if isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function r=run_template(n),r=struct('start_index',0,'initial_parameters',NaN(1,n),'final_parameters',NaN(1,n),'initial_distance',NaN,'final_distance',NaN,'iterations',0,'function_evaluations',0,'exitflag',0,'runtime_s',NaN);end
