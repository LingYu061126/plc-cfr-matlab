function result=exp_stage7a_profile_search(root,mode)
%EXP_STAGE7A_PROFILE_SEARCH Independent baseline/new controlled comparison.
%   Writes only results/data/stage7a/{smoke,formal}; Stage 6 is read-only.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);sc=stage7a_profile_search_config(base,mode);
    out=fullfile(sc.output_root,sc.mode);if exist(out,'dir')~=7,mkdir(out);end
    started=tic;rows=repmat(sample_row(),0,1);resources=repmat(resource_row(),0,1);

    % The medium library is shared by parameter replay and independent
    % in-domain/out-of-domain tests. Both methods score identical observations.
    medium=sc.stage6b.parameter.grammar;
    [lib,~]=stage6b_build_candidate_library('radial_grammar',medium,base,struct());
    [old,old_t]=stage6b_calibrate_candidate_library(lib,base,sc.stage6b,'parameter_uncertainty',700000);
    [new,new_t]=stage7a_calibrate_candidate_library(lib,base,sc,'parameter_uncertainty',700000);
    resources(end+1)=measure_resource('parameter_medium',lib,old,new,old_t,new_t); %#ok<AGROW>
    truth=truth_network(lib,sc.stage6b.truth_branch_nodes);
    [rows,replay_audit]=parameter_replay(rows,root,base,sc,old,new,truth);
    rows=independent_parameters(rows,base,sc,old,new,truth,'in_domain');
    rows=independent_parameters(rows,base,sc,old,new,truth,'out_of_domain');

    [rows,prior_resources,prior_audit]=prior_controls(rows,root,base,sc);
    resources=[resources prior_resources]; %#ok<AGROW>
    [rows,scale_resources]=scale_controls(rows,base,sc);
    resources=[resources scale_resources]; %#ok<AGROW>
    [rows,control_audit]=identifiability_controls(rows,base,sc);

    summary=aggregate(rows);safety=safety_audit(rows,summary,control_audit);
    result=struct('stage','Stage 7A','mode',sc.mode,'status','completed', ...
        'sample_count',numel(rows),'replay_audit',replay_audit, ...
        'prior_audit',prior_audit,'control_audit',control_audit, ...
        'safety',safety,'runtime_s',toc(started),'use_parallel',false, ...
        'worker_count',0,'validation_scope',sc.validation_scope);
    writetable(struct2table(rows),fullfile(out,'stage7a_comparison.csv'));
    writetable(struct2table(summary),fullfile(out,'stage7a_summary.csv'));
    writetable(struct2table(resources),fullfile(out,'stage7a_resources.csv'));
    writetable(struct2table(safety),fullfile(out,'stage7a_safety.csv'));
    snapshot=sc;
    snapshot.output_root='results/data/stage7a';
    snapshot.log_root='results/logs/stage7a';
    snapshot.stage6b.output_root='results/data/stage6b';
    snapshot.stage6b.figure_root='results/figures/stage6b';
    snapshot.stage6b.identifiability.stage5b1_model_file= ...
        'results/data/stage5b1/formal/stage5b1_results.mat';
    save(fullfile(out,'stage7a_config_snapshot.mat'),'snapshot','result','-v7');
    saved_snapshot=load(fullfile(out,'stage7a_config_snapshot.mat'),'snapshot');
    metadata=table(string({'development_base_commit';'baseline_source_commit';'stage7a_config_hash'; ...
        'search_domain_hash';'calibration_seed';'test_seed';'calibration_per_candidate'; ...
        'main_scale_bounds';'branch_load_scale_bounds';'frequency_points'; ...
        'use_parallel';'worker_count';'validation_scope'}), ...
        string({sc.development_base_commit;sc.baseline_source_commit; ...
        stage4a4_scientific_config_hash(saved_snapshot.snapshot);new.search_domain_hash; ...
        num2str(sc.calibration_seed);num2str(sc.test_seed);num2str(sc.calibration_per_candidate); ...
        mat2str(sc.search.main_scale_bounds);mat2str(sc.search.branch_load_scale_bounds); ...
        num2str(numel(sc.frequency_hz));'0';'0';sc.validation_scope}), ...
        'VariableNames',{'key','value'});
    writetable(metadata,fullfile(out,'stage7a_metadata.csv'));
    fprintf('Stage 7A %s completed: paired rows=%d, safety=%d, elapsed=%.3f s.\n', ...
        sc.mode,numel(rows),safety.pass,result.runtime_s);
end

function [rows,audit]=parameter_replay(rows,root,base,sc,old,new,truth)
    archived=readtable(fullfile(root,'results','data','stage6b','stage6b_parameter_uncertainty.csv'), ...
        'TextType','string');errors=sc.stage6b.parameter.length_errors;
    reps=sc.test_replicates;matched=0;maximum_error=0;
    for q=1:numel(errors)
        for r=1:reps
            rs=RandStream('mt19937ar','Seed',sc.stage6b.seed+7000000+q*1000+r);
            load_error=sc.stage6b.parameter.load_perturbation_fraction*(2*rand(rs)-1);
            theta=nominal_theta(sc);theta.main_length_scale=1+errors(q);theta.branch_load_scale=1+load_error;
            clean=stage6b_forward_cfr(truth,theta,base,sc.frequency_hz,sc.measurement_kind);
            y=add_noise(clean,sc.stage6b.parameter.snr_db,rs);
            sample=sprintf('length_%+03g_load_%+06.2f_r%02d',100*errors(q),100*load_error,r);
            b=stage6b_evaluate_observation(y,old,truth);
            hit=find(archived.sample==string(sample),1);
            assert(~isempty(hit),'stage7a:MissingArchivedSample','Stage 6B sample %s is missing.',sample);
            delta=abs(b.distance-archived.distance(hit));maximum_error=max(maximum_error,delta);
            assert(strcmp(b.decision_state,char(archived.decision_state(hit)))&&delta<=1e-12, ...
                'stage7a:BaselineReplayMismatch','Stage 6B replay differs from archived sample %s.',sample);
            matched=matched+1;
            z=stage7a_score_observation(y,new,sc.search);
            outside=theta.main_length_scale<sc.search.main_scale_bounds(1)-1e-12|| ...
                theta.main_length_scale>sc.search.main_scale_bounds(2)+1e-12;
            rows=append_pair(rows,'parameter_replay',sample,b,old,z,new,truth, ...
                outside,false,100*errors(q),100*load_error);
        end
    end
    audit=struct('matched_baseline_samples',matched,'maximum_baseline_distance_error',maximum_error, ...
        'archived_sample_count',height(archived));
end

function rows=independent_parameters(rows,base,sc,old,new,truth,scenario)
    if strcmp(scenario,'in_domain'),scales=[.925 .975 1.025 1.075];
    else,scales=[.85 1.15];end
    for r=1:sc.test_replicates
        if strcmp(scenario,'out_of_domain'),group=1;
        else,group=0;end
        rs=RandStream('mt19937ar','Seed',sc.test_seed+100000+group*10000+r);
        theta=nominal_theta(sc);theta.main_length_scale=scales(mod(r-1,numel(scales))+1);
        theta.branch_load_scale=1+sc.stage6b.parameter.load_perturbation_fraction*(2*rand(rs)-1);
        clean=stage6b_forward_cfr(truth,theta,base,sc.frequency_hz,sc.measurement_kind);
        y=add_noise(clean,sc.stage6b.parameter.snr_db,rs);
        sample=sprintf('%s_r%02d',scenario,r);
        b=stage6b_evaluate_observation(y,old,truth);z=stage7a_score_observation(y,new,sc.search);
        rows=append_pair(rows,scenario,sample,b,old,z,new,truth,group==1,false, ...
            100*(theta.main_length_scale-1),100*(theta.branch_load_scale-1));
    end
end

function [rows,resources,audit]=prior_controls(rows,root,base,sc)
    p=sc.stage6b.prior.base_prior;
    kinds={'wrong_open','wrong_closed'};
    edges={sc.stage6b.prior.wrong_open_edge,sc.stage6b.prior.wrong_closed_edge};
    states={'open','closed'};offsets=[200000 300000];
    opts=struct('rank',sc.stage6b.rank,'export',sc.stage6b.export);
    correct=stage6b_build_candidate_library('partial_prior',p,base,opts);
    truth=truth_network(correct,sc.stage6b.truth_branch_nodes);
    archived=readtable(fullfile(root,'results','data','stage6b','stage6b_prior_sensitivity.csv'), ...
        'TextType','string');resources=repmat(resource_row(),0,1);matched=0;
    rates=sc.stage6b.prior.error_rates;reps=sc.stage6b.prior.replicates_per_rate;
    for q=1:2
        wrong=set_switch(p,edges{q},states{q});
        lib=stage6b_build_candidate_library('partial_prior',wrong,base,opts);
        tag=['prior_' kinds{q}];
        [old,old_t]=stage6b_calibrate_candidate_library(lib,base,sc.stage6b,tag,offsets(q));
        [new,new_t]=stage7a_calibrate_candidate_library(lib,base,sc,tag,offsets(q));
        resources(end+1)=measure_resource(tag,lib,old,new,old_t,new_t); %#ok<AGROW>
        if strcmp(sc.mode,'smoke'),rate_indices=2;else,rate_indices=2:numel(rates);end
        for u=rate_indices
            count=round(rates(u)*reps);
            for r=1:count
                rs=RandStream('mt19937ar','Seed',sc.stage6b.seed+q*1000000+u*10000+r);
                theta=nominal_theta(sc);v=sc.stage6b.parameter_search.main_length_scale;
                theta.main_length_scale=min(v)+(max(v)-min(v))*rand(rs);
                clean=stage6b_forward_cfr(truth,theta,base,sc.frequency_hz,sc.measurement_kind);
                y=add_noise(clean,sc.stage6b.prior.snr_db,rs);
                sample=sprintf('%s_rate_%02g_r%02d',kinds{q},100*rates(u),r);
                b=stage6b_evaluate_observation(y,old,truth);
                hit=find(archived.sample==string(sample),1);
                assert(~isempty(hit)&&strcmp(b.decision_state,char(archived.decision_state(hit))), ...
                    'stage7a:PriorReplayMismatch','Stage 6B prior replay differs for %s.',sample);
                matched=matched+1;
                z=stage7a_score_observation(y,new,sc.search);
                rows=append_pair(rows,['prior_' kinds{q}],sample,b,old,z,new,truth, ...
                    false,false,100*(theta.main_length_scale-1),0);
            end
        end
    end
    audit=struct('matched_corrupted_baseline_samples',matched, ...
        'expected_formal_corrupted_samples',14);
end

function [rows,resources]=scale_controls(rows,base,sc)
    resources=repmat(resource_row(),0,1);
    grammars=sc.stage6b.scale.grammars;
    medium=stage6b_build_candidate_library('radial_grammar',grammars(2),base,struct());
    truth=truth_network(medium,sc.stage6b.truth_branch_nodes);
    for q=1:numel(grammars)
        g=grammars(q);lib=stage6b_build_candidate_library('radial_grammar',g,base,struct());
        tag=['scale_' g.scale_id];
        [old,old_t]=stage6b_calibrate_candidate_library(lib,base,sc.stage6b,tag,q*100000);
        [new,new_t]=stage7a_calibrate_candidate_library(lib,base,sc,tag,q*100000);
        resources(end+1)=measure_resource(tag,lib,old,new,old_t,new_t); %#ok<AGROW>
        for r=1:sc.test_replicates
            rs=RandStream('mt19937ar','Seed',sc.stage6b.seed+500000+r);
            theta=nominal_theta(sc);v=sc.stage6b.parameter_search.main_length_scale;
            theta.main_length_scale=min(v)+(max(v)-min(v))*rand(rs);
            clean=stage6b_forward_cfr(truth,theta,base,sc.frequency_hz,sc.measurement_kind);
            y=add_noise(clean,sc.stage6b.scale.snr_db,rs);
            b=stage6b_evaluate_observation(y,old,truth);z=stage7a_score_observation(y,new,sc.search);
            rows=append_pair(rows,tag,sprintf('%s_r%02d',tag,r),b,old,z,new,truth, ...
                false,false,100*(theta.main_length_scale-1),0);
        end
    end
end

function [rows,audit]=identifiability_controls(rows,base,sc)
    saved=load(sc.stage6b.identifiability.stage5b1_model_file,'evidence_model');
    evidence=saved.evidence_model;all=topology_candidates(base);
    t3=all(strcmp({all.id},'T3'));t5=all(strcmp({all.id},'T5'));
    t4=all(strcmp({all.id},'T4'));t4.id='T4_NEAR_T3';
    t4.network.branches(1).length=sc.stage6b.identifiability.near_invisible_branch_length_m;
    t4.network.branches(1).load=sc.stage6b.identifiability.near_invisible_branch_load_ohm;
    sets={[t3 t5],[t3 t5 t4]};names={'two_topology_T3_T5','three_topology_close'};
    archived=readtable(fullfile(base.root_dir,'results','data','stage6b','stage6b_identifiability.csv'), ...
        'TextType','string');new_states=cell(1,2);maximum_gap=zeros(1,2);
    theta=nominal_theta(sc);theta.source_impedance_ohm=sc.stage6b.identifiability.matched_impedance_ohm;
    theta.receiver_impedance_ohm=theta.source_impedance_ohm;
    y=stage6b_forward_cfr(t3.network,theta,base,sc.frequency_hz,sc.measurement_kind);
    for q=1:2
        candidates=sets{q};cache=stage7a_build_profile_cache(candidates,base,sc);
        profile=stage7a_profile_distance(y,cache,sc.search);d=profile.profile_distances;
        margin=compute_candidate_margin(d,cache.candidate_ids);
        confidence=compute_candidate_confidence(d,evidence.beta,cache.candidate_ids);
        frozen=struct('candidate_set_size',numel(candidates),'domain_accepted',true, ...
            'best_candidate_in_set',true);
        decision=classify_stage5b1_decision_state(frozen,struct('margin',margin.margin), ...
            struct('top1_confidence',confidence.top1_confidence, ...
            'normalized_entropy',confidence.normalized_entropy),evidence);
        hit=find(archived.scenario==string(names{q}),1);
        assert(~isempty(hit),'stage7a:MissingIdentifiabilityBaseline', ...
            'Missing archived identifiability positive control.');
        old=control_row(names{q},'stage6b',char(archived.decision_state(hit)), ...
            archived.margin(hit),archived.top1_confidence(hit), ...
            archived.entropy(hit),numel(candidates),NaN);
        new=control_row(names{q},'stage7a',decision.enhanced_decision_state, ...
            margin.margin,confidence.top1_confidence,confidence.normalized_entropy, ...
            numel(candidates),profile.runtime_s);
        rows(end+1)=old;rows(end+1)=new; %#ok<AGROW>
        new_states{q}=new.decision_state;maximum_gap(q)=max(d)-min(d);
    end
    audit=struct('stage7a_states',{new_states},'stage7a_candidate_gaps',maximum_gap, ...
        'control_decision_source','frozen_stage5b1_evidence_control_only_not_local_calibration');
end

function rows=append_pair(rows,scenario,sample,b,old,z,new,truth,outside,nonunique,len,load)
    rows(end+1)=make_row(scenario,sample,'stage6b',b,old,truth,outside,nonunique,len,load); %#ok<AGROW>
    rows(end+1)=make_row(scenario,sample,'stage7a',z,new,truth,outside,nonunique,len,load); %#ok<AGROW>
end
function row=make_row(scenario,sample,method,z,model,truth,outside,nonunique,len,load)
    row=sample_row();row.scenario=scenario;row.sample=sample;row.method=method;
    row.candidate_count=z.candidate_count;row.candidate_library_hash=library_hash(model);
    row.truth_signature=stage6b_network_signature(truth);
    sig=arrayfun(@(x)stage6b_network_signature(x.network),model.candidates,'UniformOutput',false);
    row.truth_in_library=any(strcmp(sig,row.truth_signature));
    row.best_is_truth=strcmp(sig{find(strcmp(model.candidate_ids,z.best_candidate),1)},row.truth_signature);
    row.correct_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT')&&row.best_is_truth;
    row.false_unique=strcmp(z.decision_state,'UNIQUE_CONFIDENT')&&~row.best_is_truth;
    row.library_outside=~row.truth_in_library;row.parameter_outside=logical(outside);
    row.is_nonunique_control=logical(nonunique);
    row.decision_state=z.decision_state;row.candidate_set_size=z.candidate_set_size;
    if row.truth_in_library
        ix=find(strcmp(sig,row.truth_signature),1);
        row.truth_in_candidate_set=any(strcmp(strsplit(z.candidate_set,','),model.candidate_ids{ix}));
    else,row.truth_in_candidate_set=NaN;end
    row.distance=z.distance;row.margin=z.margin;row.top1_confidence=z.top1_confidence;
    row.normalized_entropy=z.normalized_entropy;row.domain_relative_distance=z.domain_relative_distance;
    row.domain_threshold=z.domain_threshold;row.scoring_time_s=z.scoring_time_s;
    row.length_error_percent=len;row.load_error_percent=load;
    if isfield(z,'best_main_scale'),row.best_main_scale=z.best_main_scale;end
    if isfield(z,'best_branch_load_scale'),row.best_branch_load_scale=z.best_branch_load_scale;end
end
function row=control_row(scenario,method,state,margin,confidence,entropy,count,runtime)
    row=sample_row();row.scenario=scenario;row.sample=scenario;row.method=method;
    row.candidate_count=count;row.is_nonunique_control=true;row.decision_state=state;
    row.false_unique=strcmp(state,'UNIQUE_CONFIDENT');row.candidate_set_size=count;
    row.margin=margin;row.top1_confidence=confidence;row.normalized_entropy=entropy;
    row.scoring_time_s=runtime;
end
function hash=library_hash(model)
    if isfield(model,'candidate_library_hash'),hash=model.candidate_library_hash;
    else,hash=stage4a4_scientific_config_hash(struct('ids',{model.candidate_ids}, ...
        'signatures',{arrayfun(@(x)stage6b_network_signature(x.network), ...
        model.candidates,'UniformOutput',false)}));end
end

function summary=aggregate(rows)
    keys=unique(strcat(string({rows.scenario}),"|",string({rows.method})),'stable');
    summary=repmat(summary_row(),numel(keys),1);
    for k=1:numel(keys)
        part=split(keys(k),'|');idx=strcmp({rows.scenario},char(part(1)))& ...
            strcmp({rows.method},char(part(2)));x=rows(idx);states={x.decision_state};
        in=[x.truth_in_library];usable=~[x.is_nonunique_control];
        coverage=NaN;if any(usable),coverage=mean(in(usable));end
        set_cover=[x.truth_in_candidate_set];valid=isfinite(set_cover);
        outside=[x.library_outside];out_accept=NaN;
        if any(outside),out_accept=mean(~strcmp(states(outside),'REJECTED'));end
        domain=[x.parameter_outside];domain_reject=NaN;
        if any(domain),domain_reject=mean(strcmp(states(domain),'REJECTED'));end
        nonunique=[x.is_nonunique_control];ambig=NaN;
        if any(nonunique),ambig=mean(strcmp(states(nonunique),'MULTIPLE_AMBIGUOUS'));end
        summary(k)=struct('scenario',char(part(1)),'method',char(part(2)), ...
            'sample_count',numel(x),'truth_candidate_coverage_rate',coverage, ...
            'correct_unique_rate',mean([x.correct_unique]), ...
            'false_unique_rate',mean([x.false_unique]), ...
            'library_outside_acceptance_rate',out_accept, ...
            'domain_outside_rejection_rate',domain_reject, ...
            'nonunique_ambiguous_rate',ambig, ...
            'candidate_set_coverage_rate',mean_or_nan(set_cover(valid)), ...
            'mean_candidate_set_size',mean([x.candidate_set_size]), ...
            'unique_count',nnz(strcmp(states,'UNIQUE_CONFIDENT')), ...
            'ambiguous_count',nnz(strcmp(states,'MULTIPLE_AMBIGUOUS')), ...
            'low_confidence_count',nnz(strcmp(states,'LOW_CONFIDENCE')), ...
            'rejected_count',nnz(strcmp(states,'REJECTED')), ...
            'mean_scoring_time_s',mean([x.scoring_time_s],'omitnan'));
    end
end
function value=mean_or_nan(x),if isempty(x),value=NaN;else,value=mean(x);end,end
function safety=safety_audit(rows,summary,control)
    methods={rows.method};ordinary=~[rows.is_nonunique_control];
    old=rows(strcmp(methods,'stage6b')&ordinary);new=rows(strcmp(methods,'stage7a')&ordinary);
    old_out=old([old.library_outside]);new_out=new([new.library_outside]);
    old_false=nnz([old.false_unique]);new_false=nnz([new.false_unique]);
    old_accept=nnz(~strcmp({old_out.decision_state},'REJECTED'));
    new_accept=nnz(~strcmp({new_out.decision_state},'REJECTED'));
    controls_ok=all(strcmp(control.stage7a_states,'MULTIPLE_AMBIGUOUS'));
    safety=struct('pass',new_false<=old_false&&new_accept<=old_accept&&controls_ok, ...
        'baseline_false_unique_count',old_false,'stage7a_false_unique_count',new_false, ...
        'baseline_library_outside_accept_count',old_accept, ...
        'stage7a_library_outside_accept_count',new_accept, ...
        'library_outside_sample_count',numel(new_out),'nonunique_controls_ambiguous',controls_ok, ...
        'prespecified_rule','no_increase_in_false_unique_or_library_outside_acceptance_and_two_ambiguous_controls');
    %#ok<NASGU> summary remains the complete, non-cherry-picked metric table.
end
function r=measure_resource(tag,lib,old,new,old_t,new_t)
    old_info=whos('old');new_info=whos('new');
    r=struct('library_tag',tag,'candidate_count',numel(lib), ...
        'stage6b_model_bytes',old_info.bytes,'stage7a_model_bytes',new_info.bytes, ...
        'stage6b_cache_time_s',old_t.cache_time_s,'stage7a_cache_time_s',new_t.cache_time_s, ...
        'stage6b_calibration_time_s',old_t.calibration_time_s, ...
        'stage7a_calibration_time_s',new_t.calibration_time_s, ...
        'stage7a_forward_evaluations',new.cache.forward_evaluation_count, ...
        'stage7a_search_domain_hash',new.search_domain_hash, ...
        'stage7a_candidate_library_hash',new.candidate_library_hash);
end
function net=truth_network(lib,nodes)
    ix=find(arrayfun(@(x)isequal(sort([x.network.branches.node]),sort(nodes)),lib),1);
    assert(~isempty(ix),'stage7a:MissingTruth','Controlled truth is absent from correct library.');
    net=lib(ix).network;
end
function p=set_switch(p,edge,state)
    for k=1:numel(p.switch_state)
        a=sort({p.switch_state(k).from,p.switch_state(k).to});
        if isequal(a,sort(edge)),p.switch_state(k).state=state;return;end
    end
    error('stage7a:MissingSwitch','Controlled wrong-prior edge was not found.');
end
function theta=nominal_theta(sc)
    theta=struct('main_length_scale',1,'branch_length_scale',1, ...
        'branch_load_scale',1,'source_impedance_ohm',sc.search.source_impedance_ohm, ...
        'receiver_impedance_ohm',sc.search.receiver_impedance_ohm,'regularization',0);
end
function y=add_noise(x,snr,rs)
    if isinf(snr),y=x;return;end
    s=sqrt(mean(abs(x).^2)/10^(snr/10)/2);
    y=x+s*(randn(rs,size(x))+1i*randn(rs,size(x)));
end
function row=sample_row()
    row=struct('scenario','','sample','','method','','candidate_count',0, ...
        'candidate_library_hash','','truth_signature','','truth_in_library',false, ...
        'best_is_truth',false,'correct_unique',false,'false_unique',false, ...
        'library_outside',false,'parameter_outside',false,'is_nonunique_control',false, ...
        'decision_state','','candidate_set_size',0,'truth_in_candidate_set',NaN, ...
        'distance',NaN,'margin',NaN,'top1_confidence',NaN,'normalized_entropy',NaN, ...
        'domain_relative_distance',NaN,'domain_threshold',NaN, ...
        'scoring_time_s',NaN,'length_error_percent',NaN,'load_error_percent',NaN, ...
        'best_main_scale',NaN,'best_branch_load_scale',NaN);
end
function row=summary_row()
    row=struct('scenario','','method','','sample_count',0, ...
        'truth_candidate_coverage_rate',NaN,'correct_unique_rate',NaN, ...
        'false_unique_rate',NaN,'library_outside_acceptance_rate',NaN, ...
        'domain_outside_rejection_rate',NaN,'nonunique_ambiguous_rate',NaN, ...
        'candidate_set_coverage_rate',NaN,'mean_candidate_set_size',NaN, ...
        'unique_count',0,'ambiguous_count',0,'low_confidence_count',0, ...
        'rejected_count',0,'mean_scoring_time_s',NaN);
end
function row=resource_row()
    row=struct('library_tag','','candidate_count',0,'stage6b_model_bytes',0, ...
        'stage7a_model_bytes',0,'stage6b_cache_time_s',NaN,'stage7a_cache_time_s',NaN, ...
        'stage6b_calibration_time_s',NaN,'stage7a_calibration_time_s',NaN, ...
        'stage7a_forward_evaluations',0,'stage7a_search_domain_hash','', ...
        'stage7a_candidate_library_hash','');
end
