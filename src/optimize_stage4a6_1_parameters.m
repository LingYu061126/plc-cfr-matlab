function result = optimize_stage4a6_1_parameters(observed_views, frequency_hz, candidate, cfg, bounds, initial_thetas, options)
%OPTIMIZE_STAGE4A6_1_PARAMETERS Bounded, truth-free continuous fitting.
%   The objective is the existing complex-CFR RMS distance expressed as a
%   real residual vector.  lsqnonlin is used when available; deterministic
%   logistic fminsearch is retained as a toolbox-free fallback.

    if nargin < 7 || isempty(options), options = struct(); end
    if ~iscell(observed_views), observed_views = {observed_views}; end
    names = bounds.names(:).';
    lo = bounds.lower(:).'; hi = bounds.upper(:).';
    if numel(names) ~= numel(lo) || numel(names) ~= numel(hi) || ...
            any(~isfinite(lo)) || any(~isfinite(hi)) || any(hi <= lo)
        error('stage4a6_1:InvalidBounds','Bounds must be finite and ordered.');
    end
    all_names = stage4a6_1_parameter_names();
    fixed = default_theta(cfg);
    if isfield(options,'fixed_theta') && ~isempty(options.fixed_theta)
        fixed = merge_theta(fixed, options.fixed_theta);
    end
    starts = initial_matrix(initial_thetas, names, lo, hi);
    starts = [starts; (lo+hi)/2]; %#ok<AGROW>
    starts = clamp_starts(starts,lo,hi);
    starts = unique(round(starts,12),'rows','stable');
    n_requested = get_option(options,'multi_start_count',size(starts,1));
    starts = starts(1:min(n_requested,size(starts,1)),:);
    if isempty(starts), starts = (lo+hi)/2; end

    solver = choose_solver(get_option(options,'solver','auto'));
    runs = repmat(run_template(numel(names)), size(starts,1), 1);
    best_distance = Inf; best_theta = fixed; best_index = 1;
    t_all = tic;
    for s = 1:size(starts,1)
        x0 = starts(s,:);
        t0 = tic;
        try
            if strcmp(solver,'lsqnonlin')
                [x,resnorm,residual,exitflag,output] = solve_lsq(x0); %#ok<ASGLU>
                distance = sqrt(max(resnorm,0));
                iterations = get_output(output,'iterations',NaN);
                evaluations = get_output(output,'funcCount',NaN);
            else
                [x,distance,exitflag,output] = solve_fmin(x0);
                residual = residual_for(x); %#ok<NASGU>
                iterations = get_output(output,'iterations',NaN);
                evaluations = get_output(output,'funcCount',NaN);
            end
            theta = make_theta(x,fixed,names,all_names);
            finite_result = isfinite(distance) && all(isfinite(x));
            if ~finite_result, distance = Inf; end
            runs(s) = make_run(s,x0,theta,distance,exitflag,iterations, ...
                evaluations,toc(t0),finite_result,'');
            if finite_result && distance < best_distance
                best_distance = distance;
                best_theta = theta;
                best_index = s;
            end
        catch err
            runs(s) = make_run(s,x0,fixed,Inf,-99,NaN,NaN,toc(t0),false, ...
                err.identifier);
        end
    end
    finite_distances = [runs.final_distance];
    finite_distances = finite_distances(isfinite(finite_distances));
    residual_finite = ~isempty(finite_distances) && isfinite(best_distance);
    if residual_finite
        distance_tolerance = get_option(options,'multistart_distance_tolerance',1e-3) * max(best_distance,1e-12);
        near = [runs.final_distance] <= min(finite_distances) + distance_tolerance & ...
            isfinite([runs.final_distance]);
        near_distances = [runs(near).final_distance];
        rel_dist = max(near_distances)-min(near_distances) <= distance_tolerance;
        theta_consistent = parameter_consistency(runs,near,names,lo,hi,options);
        multistart_consistent = rel_dist && theta_consistent;
    else
        multistart_consistent = false;
    end
    normpos = NaN(1,numel(all_names)); near_lo = false(1,numel(all_names));
    near_hi = false(1,numel(all_names)); active = false(1,numel(all_names));
    for k = 1:numel(all_names)
        j = find(strcmp(names,all_names{k}),1);
        if ~isempty(j)
            active(k) = true;
            normpos(k) = (best_theta.(all_names{k})-lo(j))/(hi(j)-lo(j));
            near_lo(k) = normpos(k) <= get_option(options,'boundary_fraction',0.05);
            near_hi(k) = normpos(k) >= 1-get_option(options,'boundary_fraction',0.05);
        end
    end
    best_exit = 0;
    if residual_finite && best_index <= numel(runs), best_exit = runs(best_index).exitflag; end
    optimizer_converged = residual_finite && best_exit > 0;
    result = struct( ...
        'solver',solver, ...
        'distance',best_distance, ...
        'theta',best_theta, ...
        'theta_vector',theta_vector(best_theta,all_names), ...
        'active_parameter_names',{names}, ...
        'active_parameter_mask',active, ...
        'normalized_position',normpos, ...
        'near_lower',near_lo, ...
        'near_upper',near_hi, ...
        'minimum_boundary_distance',min_finite(normpos), ...
        'best_start_index',best_index, ...
        'runs',runs, ...
        'optimizer_converged',optimizer_converged, ...
        'converged',optimizer_converged, ...
        'multistart_consistent',multistart_consistent, ...
        'finite_start_count',sum(isfinite([runs.final_distance])), ...
        'near_best_start_count',sum(near), ...
        'residual_finite',residual_finite, ...
        'runtime_s',toc(t_all), ...
        'bounds',bounds, ...
        'fixed_theta',fixed);

    function [x,resnorm,residual,exitflag,output] = solve_lsq(x0)
        opts = optimoptions('lsqnonlin','Display','off', ...
            'MaxIterations',get_option(options,'max_iterations',500), ...
            'MaxFunctionEvaluations',get_option(options,'max_function_evaluations',2000), ...
            'StepTolerance',get_option(options,'tolerance_x',1e-8), ...
            'FunctionTolerance',get_option(options,'tolerance_fun',1e-10));
        [x,resnorm,residual,exitflag,output] = lsqnonlin(@residual_for,x0,lo,hi,opts);
    end
    function [x,d,exitflag,output] = solve_fmin(x0)
        opts = optimset('Display','off', ...
            'MaxIter',get_option(options,'max_iterations',500), ...
            'MaxFunEvals',get_option(options,'max_function_evaluations',2000), ...
            'TolX',get_option(options,'tolerance_x',1e-8), ...
            'TolFun',get_option(options,'tolerance_fun',1e-10));
        u0 = inverse_logistic(x0,lo,hi);
        [u,d,exitflag,output] = fminsearch(@objective_u,u0,opts);
        x = transform(u,lo,hi);
    end
    function y = objective_u(u), y = sum(residual_for(transform(u,lo,hi)).^2); end
    function r = residual_for(x)
        theta = make_theta(x,fixed,names,all_names);
        try
            [network_out,cfg_out] = topology_apply_parameters(candidate.network,cfg,theta);
            [measurements,~] = plc_measurement_bundle('siso_forward',network_out,theta,cfg_out);
            [views,~] = plc_multiview_response(frequency_hz,network_out,measurements,cfg_out);
            err = [];
            for v = 1:numel(views)
                z = views{v}(:)-observed_views{v}(:);
                err = [err; real(z); imag(z)]; %#ok<AGROW>
            end
            r = err / sqrt(max(numel(err)/2,1));
            if any(~isfinite(r)), r = realmax('double')/1e100*ones(size(r)); end
        catch
            r = realmax('double')/1e100*ones(max(2,2*numel(frequency_hz)),1);
        end
    end
end

function solver = choose_solver(requested)
    requested = lower(char(requested));
    if strcmp(requested,'fminsearch')
        solver = 'fminsearch';
    elseif strcmp(requested,'lsqnonlin')
        if exist('lsqnonlin','file') ~= 2
            error('stage4a6_1:MissingSolver','lsqnonlin was requested but is unavailable.');
        end
        solver = 'lsqnonlin';
    elseif exist('lsqnonlin','file') == 2
        solver = 'lsqnonlin';
    else
        solver = 'fminsearch';
    end
end

function theta = default_theta(cfg)
    theta = struct('main_length_scale',1,'branch_length_scale',1, ...
        'branch_load_scale',1,'source_impedance_ohm',cfg.Zs, ...
        'receiver_impedance_ohm',cfg.Zr,'regularization',NaN);
end
function theta = merge_theta(theta,extra)
    f = fieldnames(extra); for k = 1:numel(f), theta.(f{k}) = extra.(f{k}); end
end
function theta = make_theta(x,fixed,names,all_names)
    theta = fixed;
    for k = 1:numel(names), theta.(names{k}) = x(k); end
    theta.regularization = NaN;
    for k = 1:numel(all_names)
        if ~isfield(theta,all_names{k}), theta.(all_names{k}) = NaN; end
    end
end
function x = theta_vector(theta,names)
    x = NaN(1,numel(names)); for k = 1:numel(names), x(k) = theta.(names{k}); end
end
function x = initial_matrix(t,names,lo,hi)
    if isempty(t)
        x = (lo+hi)/2;
    elseif isstruct(t)
        x = zeros(numel(t),numel(names));
        for i = 1:numel(t)
            for k = 1:numel(names)
                if isfield(t(i),names{k}), x(i,k) = t(i).(names{k});
                else, x(i,k) = (lo(k)+hi(k))/2; end
            end
        end
    else
        x = t;
    end
    if size(x,2) ~= numel(names), error('stage4a6_1:StartDimension','Initial point dimension mismatch.'); end
end
function x = clamp_starts(x,lo,hi)
    margin = max(1e-8*(hi-lo),1e-12); x = min(max(x,lo+margin),hi-margin);
end
function u = inverse_logistic(x,lo,hi)
    q = min(max((x-lo)./(hi-lo),1e-8),1-1e-8); u = log(q./(1-q));
end
function x = transform(u,lo,hi)
    q = 1./(1+exp(-max(min(u,40),-40))); x = lo+(hi-lo).*q;
end
function tf = parameter_consistency(runs,near,names,lo,hi,options)
    if sum(near) <= 1, tf = true; return; end
    x = zeros(sum(near),numel(names)); q = 0;
    for k = 1:numel(runs)
        if near(k), q = q+1; for j=1:numel(names), x(q,j)=runs(k).final_theta.(names{j}); end, end
    end
    span = max(hi-lo,eps); tf = all(max(abs(x-min(x,[],1)),[],1)./span <= ...
        get_option(options,'multistart_parameter_tolerance',0.05));
end
function r = make_run(index,start,theta,d,flag,it,fev,elapsed,finite_result,err)
    r = struct('start_index',index,'initial_parameters',start,'initial_theta',theta, ...
        'final_parameters',theta_vector(theta,stage4a6_1_parameter_names()), ...
        'final_theta',theta,'initial_distance',NaN,'final_distance',d, ...
        'iterations',it,'function_evaluations',fev,'exitflag',flag, ...
        'runtime_s',elapsed,'residual_finite',finite_result,'error_identifier',err);
end
function r = run_template(n)
    r = struct('start_index',0,'initial_parameters',NaN(1,n),'initial_theta',struct(), ...
        'final_parameters',NaN(1,5),'final_theta',struct(), ...
        'initial_distance',NaN,'final_distance',Inf,'iterations',0, ...
        'function_evaluations',0,'exitflag',0,'runtime_s',NaN, ...
        'residual_finite',false,'error_identifier','');
end
function v = get_option(s,name,default_value)
    if isfield(s,name) && ~isempty(s.(name)), v = s.(name); else, v = default_value; end
end
function v = get_output(s,name,default_value)
    if isstruct(s) && isfield(s,name), v = s.(name); else, v = default_value; end
end
function v = min_finite(x)
    x = x(isfinite(x)); if isempty(x), v = NaN; else, v = min(min(x,1-x)); end
end
