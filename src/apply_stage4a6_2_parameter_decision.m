function out = apply_stage4a6_2_parameter_decision(topology_decision, member_evidence, model, method_id)
%APPLY_STAGE4A6_2_PARAMETER_DECISION Aggregate independent member evidence.
%   No truth label, coverage status or scenario label is accepted.
%   M2 uses calibrated profile improvement (absolute OR relative). M3 adds
%   absolute AND relative improvement, sensitivity and boundary/outward
%   corroboration; partial evidence remains indeterminate.

    out = struct('topology_status',map_topology(getfield_default(topology_decision,'decision','reject_low_confidence')), ...
        'topology_set',getfield_default(topology_decision,'accepted_topology_set',''), ...
        'best_topology_id',getfield_default(topology_decision,'best_topology_id',''), ...
        'parameter_domain_status','parameter_not_evaluated', ...
        'parameter_evidence','topology not accepted','method_id',method_id, ...
        'parameter_statuses',struct([]),'member_count',numel(member_evidence), ...
        'member_optimizer_converged_count',0,'any_member_optimizer_converged',false, ...
        'all_members_optimizer_converged',false,'member_profile_reliable_count',0, ...
        'profile_computed',false,'profile_reliable',false);
    if isempty(member_evidence) || startsWith(out.topology_status,'reject_'), return; end
    out.any_member_optimizer_converged = any([member_evidence.optimizer_converged]);
    out.all_members_optimizer_converged = all([member_evidence.optimizer_converged]);
    out.member_optimizer_converged_count = sum([member_evidence.optimizer_converged]);
    out.member_profile_reliable_count = sum([member_evidence.profile_reliable]);
    out.profile_computed = any([member_evidence.profile_computed]);
    out.profile_reliable = all([member_evidence.profile_reliable]);
    if strcmp(method_id,'A6_2_M0_topology_only') || ~out.profile_computed
        if ~out.profile_computed, out.parameter_domain_status='parameter_not_evaluated'; end
        out.parameter_statuses = aggregate_parameter_statuses(member_evidence, []);
        return;
    end
    names = all_parameter_names(member_evidence);
    statuses = repmat(status_template(),numel(names),1);
    for n=1:numel(names)
        vals = cell(1,numel(member_evidence)); active=false(1,numel(member_evidence));
        for k=1:numel(member_evidence)
            p=member_evidence(k).parameter_evidence; j=find(strcmp({p.parameter_name},names{n}),1);
            if isempty(j), vals{k}='not_computed'; else, vals{k}=p(j).profile_status; active(k)=p(j).active; end
        end
        statuses(n).parameter_name=names{n};statuses(n).active=any(active);statuses(n).member_statuses=strjoin(vals,',');
        if ~statuses(n).active, statuses(n).profile_status='inactive';continue;end
        if any(strcmp(vals,'optimizer_failed')) || any(strcmp(vals,'scan_unreliable')) || ...
                any(strcmp(vals,'scan_unreliable_critical_points_missing')) || any(strcmp(vals,'not_computed'))
            statuses(n).profile_status='indeterminate';statuses(n).reason='profile evidence incomplete';continue;
        end
        if any(strcmp(vals,'unidentifiable_flat'))
            statuses(n).profile_status='indeterminate_unidentifiable';statuses(n).reason='flat profile';continue;
        end
        pvals=member_parameter_evidence(member_evidence,names{n});
        t=threshold_for(model,names{n});
        mapped=map_parameter_status(pvals,method_id,t);
        statuses(n).profile_status=aggregate_status(mapped);statuses(n).reason=reason_for(mapped);
        statuses(n).absolute_improvement=max_finite([pvals.absolute_improvement]);
        statuses(n).relative_improvement=max_finite([pvals.relative_improvement]);
        statuses(n).valid_point_fraction=min_finite([pvals.valid_point_fraction]);
    end
    out.parameter_statuses=statuses;
    active_status={statuses([statuses.active]).profile_status};
    if isempty(active_status)
        out.parameter_domain_status='parameter_not_evaluated';
    elseif any(strcmp(active_status,'out_suspected'))
        out.parameter_domain_status='parameter_out_suspected';
    elseif all(strcmp(active_status,'in_domain'))
        out.parameter_domain_status='parameter_in_domain';
    else
        out.parameter_domain_status='parameter_domain_indeterminate';
    end
    out.parameter_evidence=sprintf('%s; active_parameters=%d; method=%s',out.parameter_domain_status,numel(active_status),method_id);
end

function p=member_parameter_evidence(e,name)
    p=repmat(parameter_row_template(),0,1);
    for k=1:numel(e)
        q=e(k).parameter_evidence;j=find(strcmp({q.parameter_name},name),1);
        if ~isempty(j),p(end+1)=normalize_parameter_row(q(j));end
    end
end
function p=parameter_row_template()
    p=struct('parameter_name','','active',false,'profile_status','','in_domain_min_distance',NaN,'extended_min_distance',NaN,'absolute_improvement',NaN,'relative_improvement',NaN,'extended_optimum',NaN,'extended_optimum_outside',false,'boundary_behavior','','outward_decrease',false,'flatness_metric',NaN,'relative_dynamic_range',NaN,'absolute_dynamic_range',NaN,'valid_point_fraction',0,'local_sensitivity',NaN,'multistart_evaluated',false,'multistart_consistent','not_applicable','profile_reliable',false,'reliability_reason','');
end
function p=normalize_parameter_row(q)
    p=parameter_row_template();f=fieldnames(p);
    for k=1:numel(f),if isfield(q,f{k}),p.(f{k})=q.(f{k});end,end
end
function mapped=map_parameter_status(p,method,t)
    mapped=cell(1,numel(p));
    for k=1:numel(p)
        q=p(k);
        if ~q.profile_reliable,mapped{k}=q.profile_status;continue;end
        if ~threshold_calibrated(t,method)
            mapped{k}='indeterminate_insufficient_calibration';
            continue;
        end
        switch method
            case 'A6_2_M1_boundary'
                mapped{k}=ternary(strcmp(q.boundary_behavior,'lower_boundary')||strcmp(q.boundary_behavior,'upper_boundary'),'out_suspected','in_domain');
            case 'A6_2_M2_profile'
                out=q.extended_optimum_outside && ...
                    (q.absolute_improvement>=t.absolute_improvement_threshold || ...
                     q.relative_improvement>=t.relative_improvement_threshold);
                if out
                    mapped{k}='out_suspected';
                elseif q.extended_optimum_outside
                    mapped{k}='indeterminate_conflicting_evidence';
                else
                    mapped{k}='in_domain';
                end
            case 'A6_2_M3_joint_diagnostic'
                base=q.extended_optimum_outside && ...
                    q.absolute_improvement>=t.absolute_improvement_threshold && ...
                    q.relative_improvement>=t.relative_improvement_threshold && ...
                    q.local_sensitivity>=t.sensitivity_floor;
                corroborated=strcmp(q.boundary_behavior,'lower_boundary') || ...
                    strcmp(q.boundary_behavior,'upper_boundary') || q.outward_decrease;
                if base && corroborated
                    mapped{k}='out_suspected';
                elseif q.extended_optimum_outside
                    mapped{k}='indeterminate_conflicting_evidence';
                else
                    mapped{k}='in_domain';
                end
            otherwise
                mapped{k}='indeterminate';
        end
    end
end
function ok=threshold_calibrated(t,method)
    if ~isfield(t,'status') || ~strcmp(t.status,'calibrated'),ok=false;return;end
    required=isfinite(getfield_default(t,'absolute_improvement_threshold',NaN)) && ...
        isfinite(getfield_default(t,'relative_improvement_threshold',NaN));
    if strcmp(method,'A6_2_M3_joint_diagnostic')
        required=required && isfinite(getfield_default(t,'sensitivity_floor',NaN));
    end
    ok=required;
end
function s=aggregate_status(x)
    if any(strcmp(x,'out_suspected')) && any(strcmp(x,'in_domain'))
        s='indeterminate_conflicting_evidence';
    elseif any(strcmp(x,'indeterminate_conflicting_evidence'))
        s='indeterminate_conflicting_evidence';
    elseif any(strcmp(x,'indeterminate_insufficient_calibration'))
        s='indeterminate_insufficient_calibration';
    elseif any(strcmp(x,'out_suspected'))
        s='out_suspected';
    elseif all(strcmp(x,'in_domain'))
        s='in_domain';
    elseif any(strcmp(x,'indeterminate_unidentifiable'))
        s='indeterminate_unidentifiable';
    else
        s='indeterminate';
    end
end
function r=reason_for(x),r=strjoin(x,',');end
function names=all_parameter_names(e),names={};for k=1:numel(e),q=e(k).parameter_evidence;if ~isempty(q),names=[names,{q.parameter_name}];end,end,names=unique(names,'stable');end
function out=aggregate_parameter_statuses(e,names),if nargin<2||isempty(names),names=all_parameter_names(e);end;out=repmat(status_template(),numel(names),1);for k=1:numel(names),out(k).parameter_name=names{k};p=member_parameter_evidence(e,names{k});out(k).active=any([p.active]);if ~out(k).active,out(k).profile_status='inactive';else,out(k).profile_status='not_computed';end,end,end
function s=status_template(),s=struct('parameter_name','','active',false,'profile_status','not_computed','member_statuses','','absolute_improvement',NaN,'relative_improvement',NaN,'valid_point_fraction',NaN,'reason','');end
function t=threshold_for(m,name)
    t=struct('parameter_name',name,'status','insufficient_calibration', ...
        'absolute_improvement_threshold',NaN,'relative_improvement_threshold',NaN, ...
        'sensitivity_floor',NaN);
    if isfield(m,'parameter_thresholds')&&~isempty(m.parameter_thresholds)
        j=find(strcmp({m.parameter_thresholds.parameter_name},name),1);
        if ~isempty(j),t=m.parameter_thresholds(j);end
    end
    if isfield(m,'calibration_status') && ~strcmp(m.calibration_status,'calibrated')
        t.status='insufficient_calibration';
    end
end
function v=max_finite(x),x=x(isfinite(x));if isempty(x),v=NaN;else,v=max(x);end,end
function v=min_finite(x),x=x(isfinite(x));if isempty(x),v=NaN;else,v=min(x);end,end
function v=getfield_default(s,f,d),if isstruct(s)&&isfield(s,f),v=s.(f);else,v=d;end,end
function s=map_topology(d),if ismember(d,{'unique_topology','unique_given_prior','equivalence_class'}),s=d;elseif strcmp(d,'reject_no_feasible_candidate'),s='reject_structure_mismatch';else,s='reject_low_confidence';end,end
function y=ternary(tf,a,b),if tf,y=a;else,y=b;end,end
