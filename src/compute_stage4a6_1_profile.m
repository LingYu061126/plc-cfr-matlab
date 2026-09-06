function profile = compute_stage4a6_1_profile(observed_views,frequency_hz,candidate,cfg,domain,in_result,ext_result,initial_thetas,options)
%COMPUTE_STAGE4A6_1_PROFILE Coarse single-parameter profile evidence.
%   Each fixed-parameter point refits only the remaining active parameters.
%   The output is a compact summary; full curves are not retained by default.

    names=domain.names(:).'; active=topology_active_parameter_mask(candidate,names);
    names=names(active); lo=domain.in_lower(active); hi=domain.in_upper(active);
    elo=domain.ext_lower(active); ehi=domain.ext_upper(active);
    if ~get_option(options,'enabled',true) || isempty(names)
        profile=repmat(profile_template(),0,1); return;
    end
    npoints=get_option(options,'grid_points',5);
    profile=repmat(profile_template(),numel(names),1);
    for k=1:numel(names)
        in_values=linspace(lo(k),hi(k),npoints);
        ext_values=linspace(elo(k),ehi(k),max(npoints,5));
        in_curve=scan(in_values,false); ext_curve=scan(ext_values,true);
        [din,ii]=min(in_curve); [dext,ie]=min(ext_curve);
        outside=ext_values(ie)<lo(k)-1e-10 || ext_values(ie)>hi(k)+1e-10;
        local_scale=max(din,1e-12);
        flat=(max(in_curve)-min(in_curve))/local_scale <= ...
            get_option(options,'flatness_threshold',0.05);
        profile(k)=struct('parameter_name',names{k}, ...
            'active',true,'in_grid',in_values,'in_distance_curve',in_curve, ...
            'ext_grid',ext_values,'ext_distance_curve',ext_curve, ...
            'in_min_distance',din,'ext_min_distance',dext, ...
            'in_min_value',in_values(ii),'ext_min_value',ext_values(ie), ...
            'extended_min_outside',outside,'lambda',din^2-dext^2, ...
            'relative_improvement',(din-dext)/(din+1e-12), ...
            'flat',flat,'scan_reliable',all(isfinite([in_curve ext_curve])));
    end
    function curve=scan(values,is_extended)
        curve=NaN(1,numel(values));
        for j=1:numel(values)
            fixed=in_result.theta; fixed.(names{k})=values(j);
            free=struct('names',{names(setdiff(1:numel(names),k))}, ...
                'lower',lo(setdiff(1:numel(names),k)), ...
                'upper',hi(setdiff(1:numel(names),k)));
            if is_extended
                free.lower=elo(setdiff(1:numel(names),k));
                free.upper=ehi(setdiff(1:numel(names),k));
            end
            op=options; op.fixed_theta=fixed;
            op.multi_start_count=get_option(options,'profile_multi_start_count',2);
            op.max_iterations=get_option(options,'profile_max_iterations',250);
            op.max_function_evaluations=get_option(options,'profile_max_function_evaluations',800);
            if isempty(free.names)
                curve(j)=fixed_distance(fixed);
            else
                fit=optimize_stage4a6_1_parameters(observed_views,frequency_hz,candidate,cfg,free, ...
                    [in_result.theta ext_result.theta initial_thetas],op);
                curve(j)=fit.distance;
            end
        end
    end
    function d=fixed_distance(t)
        [net,lc]=topology_apply_parameters(candidate.network,cfg,t);
        [m,~]=plc_measurement_bundle('siso_forward',net,t,lc);
        [v,~]=plc_multiview_response(frequency_hz,net,m,lc); e=0;n=0;
        for q=1:numel(v),z=v{q}(:)-observed_views{q}(:);e=e+sum(abs(z).^2);n=n+numel(z);end
        d=sqrt(e/max(n,1));
    end
end
function x=profile_template()
    x=struct('parameter_name','','active',false,'in_grid',[],'in_distance_curve',[], ...
        'ext_grid',[],'ext_distance_curve',[],'in_min_distance',NaN, ...
        'ext_min_distance',NaN,'in_min_value',NaN,'ext_min_value',NaN, ...
        'extended_min_outside',false,'lambda',NaN,'relative_improvement',NaN, ...
        'flat',false,'scan_reliable',false);
end
function v=get_option(s,n,d),if isfield(s,n)&&~isempty(s.(n)),v=s.(n);else,v=d;end,end
