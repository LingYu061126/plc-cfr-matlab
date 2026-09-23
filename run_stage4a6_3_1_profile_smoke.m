function out = run_stage4a6_3_1_profile_smoke(root,frequency_limit,budget,sample_override,output_suffix,split_override,parameter_model_file,output_dir)
%RUN_STAGE4A6_3_1_PROFILE_SMOKE Bounded isolated profile-case diagnostic.
%   The default split is the existing pilot/evaluation bank.  The optional
%   calibration split is used only to produce raw, truth-free profile
%   evidence for a later parameter-threshold calibration step.  This entry
%   point remains intentionally isolated: one MATLAB process writes one MAT
%   result and never rewrites the formal pilot tables.
    if nargin < 1 || isempty(root)
        root = fileparts(mfilename('fullpath'));
    end
    if nargin < 2 || isempty(frequency_limit), frequency_limit = 9; end
    if nargin < 3 || isempty(budget), budget = [10 30]; end
    if nargin < 4, sample_override = ''; end
    if nargin < 5 || isempty(output_suffix), output_suffix = 'profile_smoke'; end
    if nargin < 6 || isempty(split_override), split_override = 'pilot'; end
    if nargin < 7, parameter_model_file = ''; end
    if nargin < 8 || isempty(output_dir), output_dir = fullfile(root,'results','data','stage4a6_3_1'); end
    if ~exist(output_dir,'dir'), mkdir(output_dir); end
    split_override = lower(char(split_override));
    if ~ismember(split_override,{'pilot','calibration'})
        error('stage4a6_3_1:UnsupportedSplit','Split must be pilot or calibration.');
    end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    result_file = fullfile(root,'results','data','stage4a6_3_1','stage4a6_3_1_pilot_results.mat');
    if ~exist(result_file,'file')
        error('stage4a6_3_1:MissingPilot','Completed topology pilot result is required.');
    end
    z = load(result_file,'sc','candidates','bank','cache','compat_hash','calmodel');
    sc = z.sc; candidates = z.candidates; bank = z.bank; cache = z.cache;
    compat_hash = z.compat_hash; calmodel = z.calmodel;
    eval_bank = bank(strcmp({bank.split},split_override));
    if isempty(eval_bank)
        error('stage4a6_3_1:MissingSplit','No samples found for requested split.');
    end
    if strcmp(split_override,'pilot')
        decision_file = fullfile(root,'results','data','stage4a6_3_1','stage4a6_3_1_pilot_match_decisions.csv');
        d = readtable(decision_file,'TextType','string');
        accepted = strlength(string(d.accepted_topology_set)) > 0 & ...
            ~startsWith(string(d.decision),'reject_');
        if ~any(accepted)
            error('stage4a6_3_1:NoAcceptedCase','Pilot has no accepted topology case.');
        end
        if ~isempty(sample_override)
            selected = accepted & strcmp(string(d.sample_id),string(sample_override));
            if ~any(selected), error('stage4a6_3_1:RequestedCaseMissing','Requested sample is not accepted.'); end
            row = d(find(selected,1,'first'),:);
        else
            multi = accepted & double(d.accepted_member_count) > 1;
            if any(multi)
                row = d(find(multi,1,'first'),:);
            else
                row = d(find(accepted,1,'first'),:);
            end
        end
        sample_id = char(row.sample_id);
        member_text = char(row.accepted_topology_set);
        member_ids = strsplit(member_text,',');
        member_ids = member_ids(~cellfun(@isempty,member_ids));
        decision = char(row.decision);
    else
        if ~isempty(sample_override)
            selected = strcmp({eval_bank.sample_id},char(sample_override));
            if ~any(selected), error('stage4a6_3_1:RequestedCaseMissing','Requested calibration sample is absent.'); end
            k0 = find(selected,1,'first');
        else
            k0 = 1;
        end
        sample_id = eval_bank(k0).sample_id;
        [sets,~] = stage4a5_make_subbands(sc.grids(1).frequency_hz(:).',sc.confirmation.M,sc.grid_id,compat_hash);
        spec = sc.confirmation;
        spec.stability_seed = stable_seed(sc.seeds.calibration,sample_id);
        conf = confirm_stage4a6_3_1_topology(make_observation(eval_bank(k0),default_config(root),sc.grids(1).frequency_hz(:).'),cache,sets,calmodel,spec,compat_hash);
        member_ids = conf.accepted_member_ids;
        member_text = conf.accepted_topology_set;
        decision = conf.decision;
    end
    k = find(strcmp({eval_bank.sample_id},sample_id),1);
    if isempty(k)
        error('stage4a6_3_1:CaseMismatch','Requested sample is absent from the selected bank.');
    end
    if isempty(member_ids)
        error('stage4a6_3_1:RejectedCase','Selected case did not pass the frozen topology confirmer.');
    end
    member_id = member_ids{1};
    j = find(strcmp({candidates.topology_id},member_id),1);
    if isempty(j), error('stage4a6_3_1:MemberMissing','Accepted member is absent from candidates.'); end

    cfg = default_config(root);
    full_f = sc.grids(1).frequency_hz(:).';
    nfreq = min(frequency_limit,numel(full_f));
    f = full_f(1:nfreq);
    obs = make_observation(eval_bank(k),cfg,full_f);
    obs = cellfun(@(x)x(1:nfreq),obs,'UniformOutput',false);
    domain = build_extended_parameter_domain(sc.parameter_search,sc.extended_domain_eta);
    options = sc.optimization;
    options.solver = 'auto';
    options.multi_start_count = 1;
    options.max_iterations = budget(1);
    options.max_function_evaluations = budget(min(2,numel(budget)));
    options.profile = sc.profile;
    options.profile.enabled = true;
    options.profile.initial_grid_points = 2;
    options.profile.refinement_points = 0;
    options.profile.max_refinement_rounds = 0;
    options.profile.use_adaptive_refinement = false;
    options.profile.profile_multi_start_count = 1;
    options.profile.profile_max_iterations = budget(1);
    options.profile.profile_max_function_evaluations = budget(min(2,numel(budget)));
    options.profile.critical_points_required = false;
    options.profile.minimum_valid_fraction = 0.5;
    options.minimum_sensitivity_floor = 1e-10;
    confirmation = struct('accepted_member_ids',{member_ids}, ...
        'accepted_member_count',numel(member_ids), ...
        'best_parameter_values',[],'decision',decision, ...
        'accepted_topology_set',member_text,'calibration_hash','');
    parameter_model = invalid_model(compat_hash);
    if ~isempty(parameter_model_file)
        pm = load(parameter_model_file,'model');
        if ~isfield(pm,'model') || ~strcmp(getfield_default(pm.model,'compatibility_hash',''),compat_hash)
            error('stage4a6_3_1:ParameterCalibrationCompatibility','Parameter calibration model compatibility mismatch.');
        end
        parameter_model = pm.model;
    end
    t0 = tic;
    evidence = run_stage4a6_3_1_member_profiles(obs,f,confirmation,candidates,cfg,domain,options,parameter_model);
    runtime_s = toc(t0);
    out = struct('sample_id',sample_id,'split',split_override,'member_id',member_id,'frequency_count',nfreq, ...
        'runtime_s',runtime_s,'parameter_domain_status',evidence.parameter_domain_status, ...
        'evaluated_member_count',evidence.evaluated_member_count, ...
        'profile_computed',getfield_default(evidence,'profile_computed',false), ...
        'profile_reliable',getfield_default(evidence,'profile_reliable',false), ...
        'parameter_calibration_status',getfield_default(parameter_model,'calibration_status','not_loaded'), ...
        'parameter_calibration_hash',getfield_default(parameter_model,'calibration_hash',''));
    output_suffix = regexprep(char(output_suffix),'[^A-Za-z0-9_-]','_');
    out_file = fullfile(output_dir, ...
        ['stage4a6_3_1_' output_suffix '.mat']);
    save(out_file,'out','evidence','sample_id','member_id','compat_hash','-v7.3');
    fprintf('PROFILE_SMOKE_COMPLETE sample=%s member=%s nfreq=%d runtime_s=%.3f status=%s\n', ...
        sample_id,member_id,nfreq,runtime_s,evidence.parameter_domain_status);
end

function [views,meta] = make_observation(b,cfg,f)
    [n,lc] = topology_apply_parameters(b.truth_network,cfg,b.truth_theta);
    [m,~] = plc_measurement_bundle('siso_forward',n,b.truth_theta,lc);
    [views,meta] = plc_multiview_response(f,n,m,lc);
end

function m = invalid_model(h)
    m = struct('calibration_status','insufficient_calibration', ...
        'parameter_thresholds',struct([]),'compatibility_hash',h, ...
        'calibration_hash','','minimum_profile_reliable_samples',2);
end

function v = getfield_default(s,n,d)
    if isstruct(s) && isfield(s,n), v=s.(n); else, v=d; end
end

function s = stable_seed(master,id)
    v = double(char(id));
    s = max(1,round(mod(master+sum(v.*(1:numel(v))),2^31-1)));
end
