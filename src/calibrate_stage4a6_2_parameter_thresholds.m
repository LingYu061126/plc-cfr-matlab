function model = calibrate_stage4a6_2_parameter_thresholds(calibration_evidence, sc, eta, hash)
%CALIBRATE_STAGE4A6_2_PARAMETER_THRESHOLDS Calibrate from reliable evidence.
%   The total evidence count is retained even when no evidence is usable.

    if nargin < 4, hash = ''; end
    if isempty(calibration_evidence), calibration_evidence = struct([]); end
    total = numel(calibration_evidence);
    reliable_mask = false(1,total);
    for k=1:total, reliable_mask(k)=isfield(calibration_evidence(k),'profile_reliable') && calibration_evidence(k).profile_reliable; end
    reliable = calibration_evidence(reliable_mask);
    reasons = reason_counts(calibration_evidence);
    model = struct('eta',eta,'calibration_status','insufficient_calibration', ...
        'total_calibration_evidence_count',total,'reliable_calibration_evidence_count',numel(reliable), ...
        'excluded_calibration_evidence_count',total-numel(reliable), ...
        'calibration_reliable_rate',ratio(numel(reliable),total), ...
        'exclusion_reason_counts',reasons,'parameter_thresholds',struct([]), ...
        'minimum_samples',getopt(sc.parameter_calibration,'minimum_samples',2), ...
        'minimum_profile_reliable_samples',getopt(sc.parameter_calibration,'minimum_profile_reliable_samples',2), ...
        'calibration_hash',stage4a4_scientific_config_hash(struct('evidence',calibration_evidence,'eta',eta,'rule',sc.parameter_calibration,'experiment_hash',hash)), ...
        'source','reliable in-domain calibration evidence only');
    if numel(reliable) < model.minimum_profile_reliable_samples
        return;
    end
    if isfield(sc,'parameter_search_names')
        names = sc.parameter_search_names;
    else
        names = stage4a6_1_parameter_names();
    end
    if isempty(names), names = stage4a6_1_parameter_names(); end
    thresholds = repmat(parameter_threshold_template(),0,1);
    for n=1:numel(names)
        vals_abs=[]; vals_rel=[]; vals_sens=[]; count=0;
        for k=1:numel(reliable)
            if ~isfield(reliable(k),'parameter_evidence'), continue; end
            p = reliable(k).parameter_evidence;
            j = find(strcmp({p.parameter_name},names{n}) & [p.active] & [p.profile_reliable],1);
            if isempty(j), continue; end
            count=count+1; vals_abs(end+1)=p.absolute_improvement; %#ok<AGROW>
            vals_rel(end+1)=p.relative_improvement; %#ok<AGROW>
            vals_sens(end+1)=p.local_sensitivity; %#ok<AGROW>
        end
        t=parameter_threshold_template();t.parameter_name=names{n};t.reliable_sample_count=count;
        if count >= model.minimum_profile_reliable_samples
            t.absolute_improvement_threshold=quantile_local(vals_abs,getopt(sc.parameter_calibration,'improvement_quantile',0.95));
            t.relative_improvement_threshold=quantile_local(vals_rel,getopt(sc.parameter_calibration,'relative_improvement_quantile',0.95));
            t.sensitivity_floor=max(quantile_local(vals_sens,getopt(sc.parameter_calibration,'sensitivity_floor_quantile',0.05)),1e-10);
            t.status='calibrated';
        else
            t.status='insufficient_calibration';
        end
        thresholds(end+1)=t; %#ok<AGROW>
    end
    model.parameter_thresholds=thresholds;
    if all(strcmp({thresholds.status},'calibrated'))
        model.calibration_status='calibrated';
    end
end

function t=parameter_threshold_template()
    t=struct('parameter_name','','reliable_sample_count',0,'absolute_improvement_threshold',NaN, ...
        'relative_improvement_threshold',NaN,'sensitivity_floor',NaN,'status','insufficient_calibration');
end
function c=reason_counts(e)
    names={'optimizer_failed','residual_nonfinite','multistart_inconsistent','low_sensitivity', ...
        'flat_profile','insufficient_valid_scan_points','profile_not_computed','topology_rejected','other'};
    c=struct();for k=1:numel(names),c.(names{k})=0;end
    for k=1:numel(e)
        if isfield(e(k),'profile_reliable')&&e(k).profile_reliable,continue;end
        reason='other';
        if isfield(e(k),'parameter_evidence')&&~isempty(e(k).parameter_evidence)
            p=e(k).parameter_evidence; active=p([p.active]);
            if isempty(active),reason='topology_rejected';
            elseif any(strcmp({active.profile_status},'optimizer_failed')),reason='optimizer_failed';
            elseif any(strcmp({active.profile_status},'scan_unreliable')),reason='insufficient_valid_scan_points';
            elseif any(strcmp({active.profile_status},'unidentifiable_flat')),reason='flat_profile';
            elseif any(strcmp({active.profile_status},'not_computed')),reason='profile_not_computed';
            elseif ~e(k).residual_finite,reason='residual_nonfinite';
            elseif ~e(k).multistart_consistent,reason='multistart_inconsistent';
            elseif ~e(k).active_parameters_identifiable,reason='low_sensitivity';end
        elseif isfield(e(k),'residual_finite')&&~e(k).residual_finite,reason='residual_nonfinite';
        elseif isfield(e(k),'multistart_consistent')&&~e(k).multistart_consistent,reason='multistart_inconsistent';end
        if ~isfield(c,reason),reason='other';end;c.(reason)=c.(reason)+1;
    end
end
function y=quantile_local(x,p),x=sort(x(isfinite(x)));if isempty(x),y=NaN;elseif numel(x)==1,y=x;else,t=1+(numel(x)-1)*p;l=floor(t);h=ceil(t);y=x(l)+(t-l)*(x(h)-x(l));end,end
function y=ratio(a,b),if b==0,y=NaN;else,y=a/b;end,end
function v=getopt(s,n,d),if isfield(s,n)&&~isempty(s.(n)),v=s.(n);else,v=d;end,end
