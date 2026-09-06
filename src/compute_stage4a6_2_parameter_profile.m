function profiles = compute_stage4a6_2_parameter_profile(observed_views, frequency_hz, candidate, cfg, domain, in_result, ext_result, initial_thetas, options)
%COMPUTE_STAGE4A6_2_PARAMETER_PROFILE Robust per-parameter profile evidence.
%   The result explicitly distinguishes an uncomputed profile from a
%   reliable profile. Each scan point retains solver and validity evidence.

    if nargin < 9 || isempty(options), options = struct(); end
    names = domain.names(:).';
    active = topology_active_parameter_mask(candidate, names);
    profiles = repmat(profile_template(), numel(names), 1);
    for k = 1:numel(names)
        profiles(k).parameter_name = names{k};
        profiles(k).active = active(k);
        if ~active(k)
            profiles(k).profile_status = 'inactive';
            profiles(k).reliability_reason = 'parameter has no physical meaning for this topology';
        elseif ~getopt(options, 'enabled', true)
            profiles(k).profile_status = 'not_computed';
            profiles(k).reliability_reason = 'profile execution disabled';
        end
    end
    if ~getopt(options, 'enabled', true) || ~any(active)
        return;
    end

    active_names = names(active);
    active_lo = domain.in_lower(active);
    active_hi = domain.in_upper(active);
    active_elo = domain.ext_lower(active);
    active_ehi = domain.ext_upper(active);
    base_starts = [in_result.theta, ext_result.theta];
    if ~isempty(initial_thetas), base_starts = [base_starts, initial_thetas]; end

    for k = 1:numel(names)
        if ~active(k), continue; end
        j = find(strcmp(active_names, names{k}), 1);
        in_values = make_grid(active_lo(j), active_hi(j), in_result.theta.(names{k}), options, false);
        ext_values = make_grid(active_elo(j), active_ehi(j), ext_result.theta.(names{k}), options, true);
        in_points = scan_values(in_values, false, j, k);
        ext_points = scan_values(ext_values, true, j, k);
        in_distances = [in_points.distance];
        ext_distances = [ext_points.distance];
        in_valid = [in_points.point_valid] & isfinite(in_distances);
        ext_valid = [ext_points.point_valid] & isfinite(ext_distances);
        [din, ii] = min_finite(in_distances(in_valid));
        [dext, ie] = min_finite(ext_distances(ext_valid));
        in_valid_indices = find(in_valid);
        ext_valid_indices = find(ext_valid);
        if ~isnan(ii), ii = in_valid_indices(ii); end
        if ~isnan(ie), ie = ext_valid_indices(ie); end
        if isnan(din), ii = 1; end
        if isnan(dext), ie = 1; end
        in_value = value_at(in_values, ii);
        ext_value = value_at(ext_values, ie);
        all_dist = [in_distances(in_valid), ext_distances(ext_valid)];
        [flat,relative_dynamic_range,absolute_dynamic_range]=stage4a6_2_flatness_rule(all_dist, ...
            getopt(options,'flatness_threshold',0.05),getopt(options,'absolute_flatness_threshold', ...
            getopt(options,'minimum_absolute_dynamic_range',1e-9)));
        valid_points = [in_points(in_valid), ext_points(ext_valid)];
        total_count = numel(in_points) + numel(ext_points);
        valid_count = numel(valid_points);
        valid_fraction = valid_count/max(total_count, 1);
        scan_finite = valid_count > 0 && all(isfinite(all_dist));
        scan_converged = valid_count > 0 && all([valid_points.optimizer_converged]);
        evaluated = [valid_points.multistart_evaluated];
        if any(evaluated)
            scan_consistent = all([valid_points(evaluated).multistart_consistent]);
            multistart_summary = ternary(scan_consistent, true, false);
        else
            scan_consistent = true;
            multistart_summary = 'not_applicable';
        end
        critical_valid = true;
        if getopt(options, 'critical_points_required', true)
            critical_valid = critical_scan_points_valid(in_points, ext_points, in_distances, ext_distances);
        end
        computed = true;
        reliable = computed && valid_fraction >= getopt(options, 'minimum_valid_fraction', 0.80) && ...
            (~getopt(options, 'require_all_scan_points', false) || valid_count == total_count) && ...
            scan_finite && scan_converged && scan_consistent && critical_valid && ~flat;
        if ~computed
            status = 'not_computed'; reason = 'profile was not executed';
        elseif valid_fraction < getopt(options, 'minimum_valid_fraction', 0.80) || ...
                (getopt(options, 'require_all_scan_points', false) && valid_count < total_count)
            status = 'scan_unreliable'; reason = 'insufficient valid scan points';
        elseif ~critical_valid
            status = 'scan_unreliable_critical_points_missing'; reason = 'required profile boundary or minimum points are invalid';
        elseif ~scan_finite || ~scan_converged || ~scan_consistent
            status = 'scan_unreliable'; reason = 'scan point solver state was not reliable';
        elseif flat
            status = 'unidentifiable_flat'; reason = 'profile distance is flat over the scanned domain';
        else
            status = 'indeterminate'; reason = 'profile computed; calibration is required for domain status';
        end
        profiles(k).in_grid = in_values;
        profiles(k).in_distance_curve = in_distances;
        profiles(k).in_points = in_points;
        profiles(k).ext_grid = ext_values;
        profiles(k).ext_distance_curve = ext_distances;
        profiles(k).ext_points = ext_points;
        profiles(k).in_min_distance = din;
        profiles(k).ext_min_distance = dext;
        profiles(k).in_min_value = in_value;
        profiles(k).ext_min_value = ext_value;
        profiles(k).extended_min_outside = isfinite(ext_value) && ...
            (ext_value < active_lo(j)-1e-10 || ext_value > active_hi(j)+1e-10);
        profiles(k).lambda = din^2-dext^2;
        profiles(k).relative_improvement = (din-dext)/(din+1e-12);
        profiles(k).flat = flat;
        profiles(k).flatness_metric = relative_dynamic_range;
        profiles(k).relative_dynamic_range = relative_dynamic_range;
        profiles(k).absolute_dynamic_range = absolute_dynamic_range;
        profiles(k).profile_computed = computed;
        profiles(k).profile_scan_finite = scan_finite;
        profiles(k).profile_scan_converged = scan_converged;
        profiles(k).profile_multistart_evaluated = any(evaluated);
        profiles(k).profile_multistart_consistent = multistart_summary;
        profiles(k).profile_nonflat = ~flat;
        profiles(k).profile_parameter_identifiable = ~flat;
        profiles(k).profile_reliable = reliable;
        profiles(k).profile_valid_point_count = valid_count;
        profiles(k).profile_total_point_count = total_count;
        profiles(k).profile_valid_fraction = valid_fraction;
        profiles(k).profile_scan_status = ternary(reliable, 'reliable', status);
        profiles(k).profile_status = status;
        profiles(k).reliability_reason = reason;
    end

    function points = scan_values(values, is_extended, parameter_index, full_index)
        points = repmat(point_template(), 1, numel(values));
        previous_theta = [];
        for q = 1:numel(values)
            fixed = in_result.theta;
            if is_extended, fixed = ext_result.theta; end
            fixed.(names{full_index}) = values(q);
            free_idx = setdiff(1:numel(active_names), parameter_index);
            free = struct('names', {active_names(free_idx)}, ...
                'lower', active_lo(free_idx), 'upper', active_hi(free_idx));
            if is_extended
                free.lower = active_elo(free_idx); free.upper = active_ehi(free_idx);
            end
            op = options;
            op.fixed_theta = fixed;
            op.multi_start_count = getopt(options, 'profile_multi_start_count', 1);
            op.max_iterations = getopt(options, 'profile_max_iterations', 120);
            op.max_function_evaluations = getopt(options, 'profile_max_function_evaluations', 400);
            starts = base_starts;
            warm_source = 'baseline';
            if getopt(options, 'warm_start', true) && ~isempty(previous_theta)
                starts = [previous_theta, starts]; warm_source = 'previous_scan_point';
            end
            point = point_template(); point.parameter_name = names{full_index};
            point.fixed_value = values(q); point.is_extended = is_extended;
            point.warm_start_source = warm_source; point.started_at = datestr(now, 30);
            t0 = tic;
            try
                if isempty(free.names)
                    d = fixed_distance(fixed);
                    fit = fixed_fit(fixed, d);
                else
                    fit = optimize_stage4a6_1_parameters(observed_views, frequency_hz, candidate, cfg, free, starts, op);
                end
                point.distance = fit.distance;
                point.optimizer_converged = getfield_default(fit, 'optimizer_converged', false);
                point.residual_finite = getfield_default(fit, 'residual_finite', false) && isfinite(fit.distance);
                requested_starts = max(1, round(getopt(options, 'profile_multi_start_count', 1)));
                point.multistart_evaluated = requested_starts > 1;
                if point.multistart_evaluated
                    point.multistart_consistent = getfield_default(fit, 'multistart_consistent', false);
                else
                    point.multistart_consistent = 'not_applicable';
                end
                point.exitflag = getfield_default(fit, 'best_exitflag', best_exit_from_runs(fit));
                point.iterations = best_output_from_runs(fit, 'iterations');
                point.function_evaluations = best_output_from_runs(fit, 'function_evaluations');
                point.boundary_hit = any(getfield_default(fit, 'near_lower', false) | getfield_default(fit, 'near_upper', false));
                point.multistart_requirement_met = ~point.multistart_evaluated || point.multistart_consistent;
                point.point_valid = point.residual_finite && point.optimizer_converged && point.multistart_requirement_met;
                if ~point.residual_finite
                    point.failure_identifier = 'nonfinite_residual';
                elseif ~point.optimizer_converged
                    point.failure_identifier = 'optimizer_not_converged';
                elseif ~point.multistart_requirement_met
                    point.failure_identifier = 'multistart_inconsistent';
                else
                    point.failure_identifier = '';
                end
                previous_theta = fit.theta;
            catch err
                point.distance = Inf; point.failure_identifier = err.identifier;
                point.point_valid = false; point.residual_finite = false;
            end
            point.runtime_s = toc(t0); point.finished_at = datestr(now, 30);
            points(q) = point;
        end
    end
    function d = fixed_distance(theta)
        [net, local_cfg] = topology_apply_parameters(candidate.network, cfg, theta);
        [measurements, ~] = plc_measurement_bundle('siso_forward', net, theta, local_cfg);
        [views, ~] = plc_multiview_response(frequency_hz, net, measurements, local_cfg);
        ss = 0; nn = 0;
        for v = 1:numel(views)
            z = views{v}(:)-observed_views{v}(:); ss = ss+sum(abs(z).^2); nn = nn+numel(z);
        end
        d = sqrt(ss/max(nn,1));
    end
    function fit = fixed_fit(theta, distance)
        fit = struct('theta',theta,'distance',distance,'optimizer_converged',true, ...
            'residual_finite',isfinite(distance),'multistart_consistent',true, ...
            'near_lower',false,'near_upper',false,'runs',struct([]), ...
            'best_exitflag',1,'iterations',0,'function_evaluations',1);
    end
end

function p = profile_template()
    p = struct('parameter_name','','active',false,'in_grid',[],'in_distance_curve',[], ...
        'in_points',struct([]),'ext_grid',[],'ext_distance_curve',[],'ext_points',struct([]), ...
        'in_min_distance',NaN,'ext_min_distance',NaN,'in_min_value',NaN,'ext_min_value',NaN, ...
        'extended_min_outside',false,'lambda',NaN,'relative_improvement',NaN,'flat',false, ...
        'flatness_metric',NaN,'profile_computed',false,'profile_scan_finite',false, ...
        'profile_scan_converged',false,'profile_multistart_evaluated',false, ...
        'profile_multistart_consistent','not_applicable', ...
        'profile_nonflat',false,'profile_parameter_identifiable',false,'profile_reliable',false, ...
        'profile_valid_point_count',0,'profile_total_point_count',0,'profile_valid_fraction',0, ...
        'relative_dynamic_range',NaN,'absolute_dynamic_range',NaN, ...
        'profile_scan_status','not_computed','profile_status','not_computed', ...
        'reliability_reason','');
end
function p = point_template()
    p = struct('parameter_name','','fixed_value',NaN,'is_extended',false,'distance',Inf, ...
        'solver','','exitflag',NaN,'optimizer_converged',false,'residual_finite',false, ...
        'multistart_consistent','not_applicable','multistart_evaluated',false, ...
        'multistart_requirement_met',false,'iterations',NaN,'function_evaluations',NaN, ...
        'boundary_hit',false,'runtime_s',NaN,'failure_identifier','', ...
        'warm_start_source','','point_valid',false,'started_at','','finished_at','');
end
function values = make_grid(lo, hi, optimum, options, is_extended)
    n = getopt(options, 'initial_grid_points', 3);
    values = linspace(lo, hi, max(2, n));
    if isfinite(optimum), values = [values, optimum]; end
    strategy = getopt(options, 'grid_strategy', 'fixed_grid_with_midpoints');
    if strcmp(strategy, 'fixed_grid_with_midpoints') && numel(values) >= 3
        values = [values, (values(1:end-1)+values(2:end))/2];
    end
    values = unique(min(max(values,lo),hi));
end
function ok = critical_scan_points_valid(in_points, ext_points, in_distances, ext_distances)
    ok = true;
    groups = {in_points, ext_points}; distances = {in_distances, ext_distances};
    for g = 1:2
        p = groups{g}; d = distances{g};
        if isempty(p), ok = false; continue; end
        indices = unique([1 numel(p)]);
        finite_indices = find(isfinite(d));
        if isempty(finite_indices), ok = false; continue; end
        [~, local] = min(d(finite_indices));
        indices(end+1) = finite_indices(local); %#ok<AGROW>
        indices = unique(indices);
        if any(~[p(indices).point_valid]), ok = false; end
    end
end
function [v, i] = min_finite(x)
    % Profile curves are logically one-dimensional; flatten them before
    % taking the minimum so a row/column shape cannot leak a vector into a
    % scalar boundary or improvement decision.
    y = x(:);
    if isempty(y), v=NaN; i=NaN; return; end
    y(~isfinite(y)) = Inf; [v,i] = min(y); if isinf(v), v=NaN; end
end
function v = value_at(x, i)
    if isempty(x), v=NaN; return; end
    y=x(:); if isempty(i) || ~isfinite(i), i=1; end
    v=y(min(max(round(i),1),numel(y)));
end
function v = getfield_default(s, f, d), if isstruct(s)&&isfield(s,f), v=s.(f); else, v=d; end, end
function v = best_exit_from_runs(fit)
    v = NaN; if isfield(fit,'runs')&&~isempty(fit.runs), [~,i]=min([fit.runs.final_distance]); v=fit.runs(i).exitflag; end
end
function v = best_output_from_runs(fit, name)
    v = NaN; if isfield(fit,'runs')&&~isempty(fit.runs), [~,i]=min([fit.runs.final_distance]); if isfield(fit.runs(i),name), v=fit.runs(i).(name); end, end
end
function y = ternary(test, a, b), if test, y=a; else, y=b; end, end
function v = getopt(s,n,d), if isfield(s,n)&&~isempty(s.(n)), v=s.(n); else, v=d; end, end
