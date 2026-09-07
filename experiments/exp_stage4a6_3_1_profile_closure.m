function out = exp_stage4a6_3_1_profile_closure(root)
%EXP_STAGE4A6_3_1_PROFILE_CLOSURE
%   Reconciles the previously completed isolated profile cases with the
%   frozen A-grid topology decisions.  This is an offline aggregation step:
%   it does not regenerate CFRs, does not call a matcher, and keeps truth
%   labels confined to the scoring path.

if nargin < 1 || isempty(root)
    root = fileparts(fileparts(mfilename('fullpath')));
end
addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));

srcdir = fullfile(root,'results','data','stage4a6_3_1');
outdir = fullfile(srcdir,'profile_closure_A');
logdir = fullfile(root,'results','logs','stage4a6_3_1');
if ~exist(outdir,'dir'), mkdir(outdir); end
if ~exist(logdir,'dir'), mkdir(logdir); end

pilot_file = fullfile(srcdir,'stage4a6_3_1_pilot_results.mat');
model_file = fullfile(srcdir,'stage4a6_3_1_profile_parameter_calibration_model.mat');
decision_file = fullfile(srcdir,'stage4a6_3_1_pilot_match_decisions.csv');
label_file = fullfile(srcdir,'stage4a6_3_1_pilot_scoring_labels.csv');
profile_dir = fullfile(srcdir,'profile_final_A');
assert(exist(pilot_file,'file') == 2, 'Missing frozen pilot result.');
assert(exist(model_file,'file') == 2, 'Missing profile calibration model.');
assert(exist(decision_file,'file') == 2, 'Missing topology decisions.');
assert(exist(label_file,'file') == 2, 'Missing scoring labels.');

frozen = load(pilot_file,'sc','candidates','theta_grid','cache','compat_hash','source_hash');
model_wrap = load(model_file,'model','sample_evidence','compat_hash','source_hash');
model = model_wrap.model;
decisions = readtable(decision_file,'TextType','string');
labels = readtable(label_file,'TextType','string');
files = dir(fullfile(profile_dir,'*.mat'));
assert(~isempty(files), 'No isolated profile files found.');

% Preserve the historical frozen identity.  Recomputing the hash from the
% current mutable configuration is intentionally not used here.
expected_compat = char(frozen.compat_hash);
expected_source = char(frozen.source_hash);
expected_cal = char(getfield_default(model,'calibration_hash',''));
assert(strcmp(char(model_wrap.compat_hash),expected_compat), ...
    'Calibration model compatibility hash is inconsistent with frozen pilot.');
assert(strcmp(char(model_wrap.source_hash),expected_source), ...
    'Calibration model source hash is inconsistent with frozen pilot.');

% Add explicit audit columns without changing the historical decision file.
n = height(decisions);
decisions.profile_evaluated = false(n,1);
decisions.profile_computed = false(n,1);
decisions.profile_reliable = false(n,1);
decisions.profile_calibration_status = strings(n,1);
decisions.profile_source_file = strings(n,1);

profiles = repmat(profile_summary_template(),0,1);
profile_ids = strings(0,1);
compat_ok = 0; cal_ok = 0; member_mismatch = 0;
for k = 1:numel(files)
    p = load(fullfile(files(k).folder,files(k).name));
    assert(isfield(p,'sample_id') && isfield(p,'evidence') && isfield(p,'out'), ...
        'Profile file is missing required fields: %s',files(k).name);
    sid = string(p.sample_id);
    assert(~any(profile_ids == sid), 'Duplicate profile sample ID: %s',sid);
    profile_ids(end+1,1) = sid; %#ok<AGROW>
    assert(isfield(p,'compat_hash') && strcmp(char(p.compat_hash),expected_compat), ...
        'Profile compatibility hash mismatch: %s',files(k).name);
    compat_ok = compat_ok + 1;
    assert(strcmp(char(getfield_default(p.out,'parameter_calibration_hash','')),expected_cal), ...
        'Profile calibration hash mismatch: %s',files(k).name);
    cal_ok = cal_ok + 1;
    ev = p.evidence;
    ac = getfield_default(ev,'accepted_member_count',0);
    ec = getfield_default(ev,'evaluated_member_count',0);
    if ac ~= ec, member_mismatch = member_mismatch + 1; end
    ix = find(string(decisions.sample_id) == sid,1);
    assert(~isempty(ix), 'Profile sample is absent from frozen decisions: %s',sid);
    decisions.profile_evaluated(ix) = true;
    decisions.profile_computed(ix) = getfield_default(p.out,'profile_computed',false);
    decisions.profile_reliable(ix) = getfield_default(p.out,'profile_reliable',false);
    decisions.profile_calibration_status(ix) = string(getfield_default(p.out,'parameter_calibration_status',''));
    decisions.profile_source_file(ix) = string(files(k).name);
    decisions.parameter_domain_status(ix) = string(getfield_default(ev,'parameter_domain_status','parameter_domain_indeterminate'));
    decisions.accepted_member_count(ix) = ac;
    decisions.evaluated_member_count(ix) = ec;
    if isfield(ev,'accepted_topology_set') && strlength(string(ev.accepted_topology_set)) > 0
        decisions.accepted_topology_set(ix) = string(ev.accepted_topology_set);
    end
    q = profile_summary_template();
    q.sample_id = char(sid); q.split = char(getfield_default(p.out,'split',''));
    q.source_file = files(k).name; q.method_id = char(getfield_default(ev,'method_id',''));
    q.parameter_domain_status = char(getfield_default(ev,'parameter_domain_status',''));
    q.profile_computed = getfield_default(p.out,'profile_computed',false);
    q.profile_reliable = getfield_default(p.out,'profile_reliable',false);
    q.accepted_member_count = ac; q.evaluated_member_count = ec;
    q.compatibility_hash = expected_compat; q.calibration_hash = expected_cal;
    profiles(end+1) = q; %#ok<AGROW>
end

% Every profile is a profile-enabled evaluation, but unprofiled topology
% rejections remain in the full decision table and are not silently removed.
profiled_mask = decisions.profile_evaluated;
metrics = [metric_rows(decisions,labels,[], 'all_topology_evaluation'); ...
           metric_rows(decisions,labels,profiled_mask, 'profile_evaluated_subset')];

audit = struct('historical_pilot_decision_count',height(decisions), ...
    'isolated_profile_file_count',numel(files), ...
    'unique_profile_sample_count',numel(unique(profile_ids)), ...
    'profile_decision_id_matches',sum(ismember(profile_ids,string(decisions.sample_id))), ...
    'compatibility_hash_matches',compat_ok, ...
    'calibration_hash_matches',cal_ok, ...
    'member_count_mismatches',member_mismatch, ...
    'profile_reliable_count',sum([profiles.profile_reliable]), ...
    'profile_in_domain_count',sum(strcmp({profiles.parameter_domain_status},'parameter_in_domain')), ...
    'profile_out_suspected_count',sum(strcmp({profiles.parameter_domain_status},'parameter_out_suspected')), ...
    'profile_indeterminate_count',sum(strcmp({profiles.parameter_domain_status},'parameter_domain_indeterminate')), ...
    'frozen_compatibility_hash',expected_compat, ...
    'frozen_source_tree_hash',expected_source, ...
    'calibration_hash',expected_cal, ...
    'calibration_status',char(getfield_default(model,'calibration_status','')), ...
    'calibration_sample_count',getfield_default(model,'calibration_sample_count',NaN), ...
    'calibration_reliable_evidence_count',getfield_default(model,'reliable_calibration_evidence_count',NaN), ...
    'matlab_version',version,'aggregation_kind','offline_profile_closure');

decision_out = fullfile(outdir,'stage4a6_3_1_profile_closure_A_decisions.csv');
profile_out = fullfile(outdir,'stage4a6_3_1_profile_closure_A_profile_summary.csv');
metric_out = fullfile(outdir,'stage4a6_3_1_profile_closure_A_metrics.csv');
audit_out = fullfile(outdir,'stage4a6_3_1_profile_closure_A_audit.csv');
result_out = fullfile(outdir,'stage4a6_3_1_profile_closure_A_results.mat');
log_out = fullfile(logdir,'stage4a6_3_1_profile_closure_A.log');
writetable(decisions,decision_out);
write_rows(profiles,profile_out);
write_rows(metrics,metric_out);
write_rows(audit,audit_out);
save(result_out,'decisions','labels','profiles','metrics','audit','model','frozen','-v7.3');
write_text(log_out,sprintf(['Stage 4A.6.3.1 profile closure\\n' ...
    'MATLAB=%s\\n' ...
    'frozen_compatibility_hash=%s\\nsource_tree_hash=%s\\ncalibration_hash=%s\\n' ...
    'decision_count=%d\\nprofile_file_count=%d\\nprofile_reliable=%d\\n' ...
    'profile_in=%d\\nprofile_out_suspected=%d\\nprofile_indeterminate=%d\\n' ...
    'member_count_mismatches=%d\\n' ...
    'physical_profile_recalculation=false\\n'], ...
    version,expected_compat,expected_source,expected_cal,height(decisions),numel(files), ...
    audit.profile_reliable_count,audit.profile_in_domain_count, ...
    audit.profile_out_suspected_count,audit.profile_indeterminate_count,member_mismatch));

out = struct('decision_file',decision_out,'profile_file',profile_out,'metric_file',metric_out, ...
    'audit_file',audit_out,'result_file',result_out,'log_file',log_out,'audit',audit,'metrics',metrics);
fprintf('PROFILE_CLOSURE_COMPLETE decisions=%d profiles=%d reliable=%d in=%d out=%d indeterminate=%d\\n', ...
    height(decisions),numel(files),audit.profile_reliable_count,audit.profile_in_domain_count, ...
    audit.profile_out_suspected_count,audit.profile_indeterminate_count);
end

function r = profile_summary_template()
r = struct('sample_id','','split','','source_file','','method_id','', ...
    'parameter_domain_status','','profile_computed',false,'profile_reliable',false, ...
    'accepted_member_count',0,'evaluated_member_count',0, ...
    'compatibility_hash','','calibration_hash','');
end

function rows = metric_rows(d,l,mask,scope)
if isempty(mask), mask = true(height(d),1); end
ids = string(d.sample_id); lid = string(l.sample_id);
cats = unique(string(l.category),'stable'); rows = repmat(metric_template(),0,1);
for c = 1:numel(cats)
    li = string(l.category) == cats(c) & ismember(lid,ids(mask));
    if ~any(li), continue; end
    ls = l(li,:); [~,ia] = unique(string(ls.physical_scenario_id),'stable'); ls = ls(ia,:);
    [tf,di] = ismember(string(ls.sample_id),ids);
    ls = ls(tf,:); di = di(tf); di = di(mask(di)); %#ok<NASGU>
    % Recompute the index after applying the scope mask, preserving order.
    keep = ismember(string(ls.sample_id),ids(mask)); ls = ls(keep,:);
    di = zeros(height(ls),1);
    for k = 1:height(ls), di(k) = find(ids == string(ls.sample_id(k)) & mask,1); end
    if isempty(di), continue; end
    accepted = ~startsWith(string(d.decision(di)),'reject_');
    set_text = string(d.topology_set(di)); truth = string(ls.truth_topology_id);
    hit = false(numel(di),1);
    for k = 1:numel(di), hit(k) = any(strcmp(strsplit(char(set_text(k)),','),char(truth(k)))); end
    strict = accepted & string(d.decision(di)) == 'unique_topology' & hit;
    ptruth = string(ls.parameter_domain_truth);
    pstatus = string(d.parameter_domain_status(di));
    applicable = ptruth == 'in_domain' | ptruth == 'out_of_domain';
    outood = ptruth == 'out_of_domain'; inood = ptruth == 'in_domain';
    pout = pstatus == 'parameter_out_suspected'; pin = pstatus == 'parameter_in_domain';
    pind = pstatus == 'parameter_domain_indeterminate' | pstatus == 'parameter_not_evaluated';
    decided = ~pind & applicable;
    wrong = decided & ~hit;
    r = metric_template(); r.scope = scope; r.category = char(cats(c));
    r.nominal_row_count = sum(li); r.unique_physical_scenario_count = height(ls);
    r.duplicate_observation_count = r.nominal_row_count - r.unique_physical_scenario_count;
    r.topology_set_accuracy_num = sum(accepted & hit); r.topology_set_accuracy_den = numel(di);
    r.topology_set_accuracy = ratio(r.topology_set_accuracy_num,r.topology_set_accuracy_den);
    r.strict_unique_accuracy_num = sum(strict); r.strict_unique_accuracy_den = numel(di);
    r.strict_unique_accuracy = ratio(r.strict_unique_accuracy_num,r.strict_unique_accuracy_den);
    r.parameter_ood_recall_num = sum(outood & pout); r.parameter_ood_recall_den = sum(outood);
    r.parameter_ood_recall = ratio(r.parameter_ood_recall_num,r.parameter_ood_recall_den);
    r.parameter_ood_false_accept_num = sum(outood & pin); r.parameter_ood_false_accept_den = sum(outood);
    r.parameter_ood_false_accept_rate = ratio(r.parameter_ood_false_accept_num,r.parameter_ood_false_accept_den);
    r.in_domain_false_alarm_num = sum(inood & pout); r.in_domain_false_alarm_den = sum(inood);
    r.in_domain_false_alarm = ratio(r.in_domain_false_alarm_num,r.in_domain_false_alarm_den);
    r.indeterminate_num = sum(pind & applicable); r.indeterminate_den = sum(applicable);
    r.indeterminate_rate = ratio(r.indeterminate_num,r.indeterminate_den);
    r.parameter_decision_coverage_num = sum(decided); r.parameter_decision_coverage_den = sum(applicable);
    r.parameter_decision_coverage = ratio(r.parameter_decision_coverage_num,r.parameter_decision_coverage_den);
    r.selective_topology_risk_num = sum(wrong); r.selective_topology_risk_den = sum(decided);
    r.selective_topology_risk = ratio(r.selective_topology_risk_num,r.selective_topology_risk_den);
    r.accepted_topology_count = sum(accepted);
    [r.topology_set_ci_low,r.topology_set_ci_high] = wilson(r.topology_set_accuracy_num,r.topology_set_accuracy_den);
    [r.parameter_ood_ci_low,r.parameter_ood_ci_high] = wilson(r.parameter_ood_recall_num,r.parameter_ood_recall_den);
    rows(end+1) = r; %#ok<AGROW>
end
end

function r = metric_template()
r = struct('scope','','category','','nominal_row_count',0,'unique_physical_scenario_count',0, ...
    'duplicate_observation_count',0,'topology_set_accuracy_num',0,'topology_set_accuracy_den',0, ...
    'topology_set_accuracy',NaN,'topology_set_ci_low',NaN,'topology_set_ci_high',NaN, ...
    'strict_unique_accuracy_num',0,'strict_unique_accuracy_den',0,'strict_unique_accuracy',NaN, ...
    'parameter_ood_recall_num',0,'parameter_ood_recall_den',0,'parameter_ood_recall',NaN, ...
    'parameter_ood_ci_low',NaN,'parameter_ood_ci_high',NaN, ...
    'parameter_ood_false_accept_num',0,'parameter_ood_false_accept_den',0, ...
    'parameter_ood_false_accept_rate',NaN,'in_domain_false_alarm_num',0, ...
    'in_domain_false_alarm_den',0,'in_domain_false_alarm',NaN,'indeterminate_num',0, ...
    'indeterminate_den',0,'indeterminate_rate',NaN,'parameter_decision_coverage_num',0, ...
    'parameter_decision_coverage_den',0,'parameter_decision_coverage',NaN, ...
    'selective_topology_risk_num',0,'selective_topology_risk_den',0, ...
    'selective_topology_risk',NaN,'accepted_topology_count',0);
end

function [lo,hi] = wilson(a,b)
if b == 0, lo=NaN; hi=NaN; return; end
if exist('stage4a6_3_wilson_interval','file') == 2
    ci = stage4a6_3_wilson_interval(a,b); lo=ci(1); hi=ci(2); return;
end
z=1.959963984540054; ph=a/b; den=1+z^2/b; cen=(ph+z^2/(2*b))/den; half=z*sqrt(ph*(1-ph)/b+z^2/(4*b^2))/den; lo=max(0,cen-half); hi=min(1,cen+half);
end

function v = ratio(a,b)
if b == 0, v=NaN; else, v=a/b; end
end

function v = getfield_default(s,n,d)
if isstruct(s) && isfield(s,n), v=s.(n); else, v=d; end
end

function write_rows(x,p)
if isempty(x), return; end
if isscalar(x), t=struct2table(x,'AsArray',true); else, t=struct2table(x(:)); end
writetable(t,p);
end

function write_text(p,t)
f=fopen(p,'w'); fprintf(f,'%s',t); fclose(f);
end
