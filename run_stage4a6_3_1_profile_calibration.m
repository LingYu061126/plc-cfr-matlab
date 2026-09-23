function out = run_stage4a6_3_1_profile_calibration(root)
%RUN_STAGE4A6_3_1_PROFILE_CALIBRATION Build a parameter calibration model.
%   This aggregates only completed isolated calibration profile cases.  For
%   an observational equivalence class, member evidence is reduced to one
%   conservative physical-sample record: all active members must be
%   reliable, the largest improvement is retained, and the smallest local
%   sensitivity is retained.  Thus equivalent members do not inflate the
%   independent calibration denominator.
    if nargin < 1 || isempty(root), root = fileparts(mfilename('fullpath')); end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    result_file = fullfile(root,'results','data','stage4a6_3_1','stage4a6_3_1_pilot_results.mat');
    z = load(result_file,'sc','compat_hash','source_hash');
    sc = z.sc; compat_hash = z.compat_hash; source_hash = z.source_hash;
    files = dir(fullfile(root,'results','data','stage4a6_3_1','stage4a6_3_1_calibration_cal_*.mat'));
    sample_evidence = repmat(empty_evidence(),0,1);
    total_files = numel(files); excluded_files = 0;
    for k = 1:numel(files)
        x = load(fullfile(files(k).folder,files(k).name),'evidence','out','sample_id');
        if ~isfield(x,'evidence') || ~isfield(x.evidence,'member_evidence') || ...
                isempty(x.evidence.member_evidence) || ~getfield_default(x.out,'profile_reliable',false)
            excluded_files = excluded_files + 1;
            continue;
        end
        q = aggregate_member_sample(x.evidence.member_evidence);
        q.sample_id = getfield_default(x,'sample_id',files(k).name);
        q.profile_source_file = files(k).name;
        sample_evidence(end+1) = q; %#ok<AGROW>
    end
    model = calibrate_stage4a6_2_parameter_thresholds(sample_evidence,sc,sc.extended_domain_eta,compat_hash);
    model.compatibility_hash = compat_hash;
    model.source_tree_hash = source_hash;
    model.calibration_split_id = 'stage4a6_3_1_isolated_calibration_profiles';
    model.calibration_sample_count = numel(sample_evidence);
    model.calibration_file_count = total_files;
    model.excluded_file_count = excluded_files;
    model.calibration_evidence_kind = 'sample_level_conservative_member_aggregate';
    model.created_at = char(datetime('now','Format','yyyyMMdd''T''HHmmss'));
    model.matlab_version = version;
    model.calibration_scientific_hash = stage4a4_scientific_config_hash(struct( ...
        'compatibility_hash',compat_hash,'sample_ids',{ {sample_evidence.sample_id} }, ...
        'source_tree_hash',source_hash,'parameter_rule',sc.parameter_calibration));
    out_file = fullfile(root,'results','data','stage4a6_3_1', ...
        'stage4a6_3_1_profile_parameter_calibration_model.mat');
    save(out_file,'model','sample_evidence','compat_hash','source_hash','-v7.3');
    write_rows(model_rows(model,compat_hash,source_hash),fullfile(root,'results','data','stage4a6_3_1', ...
        'stage4a6_3_1_profile_parameter_calibration_thresholds.csv'));
    write_rows(struct('total_profile_files',total_files,'excluded_profile_files',excluded_files, ...
        'sample_level_reliable_evidence',numel(sample_evidence),'calibration_status',model.calibration_status, ...
        'compatibility_hash',compat_hash,'source_tree_hash',source_hash, ...
        'calibration_scientific_hash',model.calibration_scientific_hash), ...
        fullfile(root,'results','data','stage4a6_3_1','stage4a6_3_1_profile_parameter_calibration_summary.csv'));
    out = struct('model',model,'sample_evidence',sample_evidence,'output_file',out_file);
end

function q = aggregate_member_sample(e)
    q = empty_evidence();
    q.topology_id = strjoin({e.topology_id},',');
    q.canonical_key = strjoin({e.canonical_key},'||');
    q.profile_reliable = all([e.profile_reliable]);
    q.profile_computed = all([e.profile_computed]);
    q.optimizer_converged = all([e.optimizer_converged]);
    q.multistart_consistent = all([e.multistart_consistent]);
    q.residual_finite = all([e.residual_finite]);
    q.active_parameters_identifiable = all([e.active_parameters_identifiable]);
    names = {};
    for k = 1:numel(e)
        p = e(k).parameter_evidence;
        names = unique([names,{p.parameter_name}],'stable');
    end
    q.parameter_evidence = repmat(parameter_template(),0,1);
    for n = 1:numel(names)
        rows = repmat(parameter_template(),0,1);
        for k = 1:numel(e)
            p = e(k).parameter_evidence;
            j = find(strcmp({p.parameter_name},names{n}) & [p.active],1);
            if ~isempty(j), rows(end+1) = normalize_parameter(p(j)); end %#ok<AGROW>
        end
        if isempty(rows), continue; end
        p = rows(1);
        p.active = true;
        p.profile_reliable = all([rows.profile_reliable]) && q.profile_reliable;
        p.absolute_improvement = max_finite([rows.absolute_improvement]);
        p.relative_improvement = max_finite([rows.relative_improvement]);
        p.local_sensitivity = min_finite([rows.local_sensitivity]);
        p.valid_point_fraction = min_finite([rows.valid_point_fraction]);
        if ~p.profile_reliable
            p.profile_status = 'indeterminate';
            p.reliability_reason = 'not all accepted members were reliable';
        end
        q.parameter_evidence(end+1) = p;
    end
end

function q = empty_evidence()
    q = struct('topology_id','','canonical_key','','profile_reliable',false, ...
        'profile_computed',false,'optimizer_converged',false,'multistart_consistent',false, ...
        'residual_finite',false,'active_parameters_identifiable',false, ...
        'parameter_evidence',struct([]),'sample_id','','profile_source_file','');
end

function p = parameter_template()
    p = struct('parameter_name','','active',false,'in_domain_min_distance',NaN, ...
        'extended_min_distance',NaN,'absolute_improvement',NaN,'relative_improvement',NaN, ...
        'extended_optimum',NaN,'extended_optimum_outside',false,'boundary_behavior','', ...
        'outward_decrease',false,'flatness_metric',NaN,'relative_dynamic_range',NaN, ...
        'absolute_dynamic_range',NaN,'valid_point_fraction',0,'local_sensitivity',NaN, ...
        'multistart_evaluated',false,'multistart_consistent','not_applicable', ...
        'profile_reliable',false,'reliability_reason','');
end

function p = normalize_parameter(x)
    p = parameter_template(); f = fieldnames(p);
    for k = 1:numel(f), if isfield(x,f{k}), p.(f{k}) = x.(f{k}); end, end
end

function rows = model_rows(m,h,sh)
    if isempty(m.parameter_thresholds)
        rows = struct('parameter_name','','status',m.calibration_status, ...
            'reliable_sample_count',0,'absolute_improvement_threshold',NaN, ...
            'relative_improvement_threshold',NaN,'sensitivity_floor',NaN, ...
            'compatibility_hash',h,'source_tree_hash',sh);
        return;
    end
    rows = m.parameter_thresholds;
    for k = 1:numel(rows)
        rows(k).compatibility_hash = h;
        rows(k).source_tree_hash = sh;
    end
end

function v = getfield_default(s,n,d)
    if isstruct(s) && isfield(s,n), v = s.(n); else, v = d; end
end
function v = max_finite(x), x=x(isfinite(x)); if isempty(x),v=NaN;else,v=max(x);end,end
function v = min_finite(x), x=x(isfinite(x)); if isempty(x),v=NaN;else,v=min(x);end,end
function write_rows(x,p)
    if isempty(x), return; end
    if isscalar(x), t=struct2table(x,'AsArray',true); else, t=struct2table(x(:)); end
    writetable(t,p);
end
