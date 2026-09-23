function summary=exp_stage6a_candidate_generation(root,mode)
%EXP_STAGE6A_CANDIDATE_GENERATION Controlled partial-prior comparison.
%   Compares the existing restricted seven-candidate library with three
%   Stage 6A partial-prior cases. Downstream evaluation reuses the existing
%   Stage 4A forward/profile functions and Stage 5B.1 decision functions.
%   This is a synthetic model-internal experiment, not field validation.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    base=default_config(root);sc=stage6a_candidate_generation_config(base,mode);
    if strcmpi(mode,'formal'),out=sc.output_root;else,out=fullfile(sc.output_root,mode);end
    ensure_dir(out);whole_timer=tic;

    t=tic;legacy=generate_radial_topology_candidates(sc.legacy_grammar);legacy_generation=toc(t);
    legacy_signatures=arrayfun(@(x)network_signature(x.network),legacy,'UniformOutput',false);
    truth_index=find(arrayfun(@(x)is_truth_network(x.network,sc.truth_branch_nodes),legacy),1);
    assert(~isempty(truth_index),'stage6a:TruthMissingFromLegacy','Controlled truth was not found in the legacy library.');
    truth_network=legacy(truth_index).network;truth_signature=network_signature(truth_network);

    names={'existing_library'};libraries={legacy};
    generation_rows=repmat(generation_row(),1+numel(sc.partial_prior_cases),1);
    runtime_rows=repmat(runtime_row(),1+numel(sc.partial_prior_cases),1);
    generation_rows(1)=make_generation_row('existing_library','none',legacy,legacy_signatures,truth_signature,legacy_generation,0,0,0);
    runtime_rows(1)=make_runtime_row('existing_library','none',legacy_generation,0,0,0,legacy_generation);
    generation_audits=cell(1,numel(sc.partial_prior_cases));
    for p=1:numel(sc.partial_prior_cases)
        prior=sc.partial_prior_cases(p);total=tic;
        q=tic;[raw,ga]=generate_candidate_topologies(prior);tg=toc(q);
        q=tic;[valid,ca]=apply_topology_constraints(raw,prior);tc=toc(q);
        q=tic;[ranked,ra]=rank_candidate_complexity(valid,sc.rank);tr=toc(q);
        q=tic;[lib,ea]=export_candidate_library(ranked,base,sc.export);te=toc(q);
        elapsed=toc(total);assert(~isempty(lib),'stage6a:EmptyExport','Case %s exported no candidates.',prior.case_id);
        names{end+1}=prior.case_id;libraries{end+1}=lib; %#ok<AGROW>
        generation_rows(p+1)=make_generation_row('stage6a_partial_prior',prior.case_id,lib,legacy_signatures,truth_signature,tg,tc,tr,te);
        runtime_rows(p+1)=make_runtime_row('stage6a_partial_prior',prior.case_id,tg,tc,tr,te,elapsed);
        generation_audits{p}=struct('generation',ga,'constraints',ca,'ranking',ra,'export',ea);
    end

    all_decisions=repmat(decision_row(),0,1);metrics=repmat(metric_row(),numel(libraries),1);
    downstream_models=cell(1,numel(libraries));
    for k=1:numel(libraries)
        [rows,metric,timing,models]=run_downstream(names{k},libraries{k},truth_network,truth_signature,base,sc,k);
        all_decisions=[all_decisions;rows(:)]; %#ok<AGROW>
        metrics(k)=metric;downstream_models{k}=models;
        runtime_rows(k).cache_time_s=timing.cache_time_s;
        runtime_rows(k).calibration_time_s=timing.calibration_time_s;
        runtime_rows(k).test_time_s=timing.test_time_s;
        runtime_rows(k).total_time_s=runtime_rows(k).candidate_pipeline_time_s+timing.cache_time_s+timing.calibration_time_s+timing.test_time_s;
        fprintf('Stage 6A downstream %s: candidates=%d samples=%d\n',names{k},numel(libraries{k}),numel(rows));
    end
    total_runtime=toc(whole_timer);
    summary=struct('stage_name','Stage 6A','mode',mode,'status',[mode '_completed'], ...
        'method_count',numel(libraries),'legacy_candidate_count',numel(legacy), ...
        'broad_candidate_count',numel(libraries{2}),'informative_candidate_count',numel(libraries{3}), ...
        'stale_candidate_count',numel(libraries{4}),'test_sample_count',numel(all_decisions), ...
        'total_runtime_s',total_runtime,'stage4a_forward_source_modified',false, ...
        'stage5b1_decision_source_modified',false,'validation_scope','controlled_synthetic_model_internal');
    writetable(struct2table(generation_rows),fullfile(out,'stage6a_candidate_generation_summary.csv'));
    writetable(struct2table(runtime_rows),fullfile(out,'stage6a_runtime.csv'));
    writetable(struct2table(all_decisions),fullfile(out,'stage6a_identification_summary.csv'));
    writetable(struct2table(metrics),fullfile(out,'stage6a_identification_metrics.csv'));
    save(fullfile(out,'stage6a_results.mat'),'summary','generation_rows','runtime_rows','all_decisions', ...
        'metrics','generation_audits','downstream_models','sc','-v7');
    fprintf('Stage 6A %s completed in %.3f s.\n',mode,total_runtime);
end

function [rows,metric,timing,models]=run_downstream(method,candidates,truth_network,truth_signature,base,sc,method_index)
    ids={candidates.topology_id};theta_grid=topology_parameter_grid(sc.parameter_search);
    t=tic;cache=stage4a7_2_r1_build_profile_template_cache(sc.frequency_hz,candidates,theta_grid,base,sc.measurement_kind);timing.cache_time_s=toc(t);
    n=numel(candidates)*sc.calibration_per_candidate;D=zeros(n,numel(candidates));truth=zeros(n,1);relative=zeros(n,1);cursor=0;t=tic;
    for j=1:numel(candidates)
        for r=1:sc.calibration_per_candidate
            cursor=cursor+1;rs=RandStream('mt19937ar','Seed',sc.seed+method_index*100000+j*1000+r);
            theta=random_theta(rs,sc.parameter_search);clean=forward_cfr(candidates(j).network,theta,base,sc.frequency_hz,sc.measurement_kind);
            obs=add_noise(clean,sc.calibration_snr_db,rs);p=stage4a7_2_r1_profile_distance({obs},cache,struct('feature','complex_raw'));
            D(cursor,:)=p.profile_distances;truth(cursor)=j;relative(cursor)=min(p.profile_distances)/max(sqrt(mean(abs(obs).^2)),eps);
        end
    end
    options=struct('minimum_per_candidate',sc.calibration_per_candidate,'resolution',eps, ...
        'compatibility_hash',stage4a4_scientific_config_hash(struct('stage','6A','method',method,'mode',sc.mode)));
    topology_model=stage4a7_2_r1_calibrate_profile_method(D,truth,ids,'absolute',sc.alpha,options);
    set_size=zeros(n,1);
    for q=1:n,a=stage4a7_2_r1_apply_profile_candidate_set(D(q,:),topology_model,'absolute');set_size(q)=a.set_size;end
    eopts=sc.evidence_calibration;eopts.candidate_ids=ids;
    evidence_model=calibrate_stage5b1_decision_metrics(D,truth,set_size,eopts);
    domain_threshold=fixed_quantile(relative,sc.domain_quantile);timing.calibration_time_s=toc(t);

    true_library_index=find(arrayfun(@(x)strcmp(network_signature(x.network),truth_signature),candidates),1);
    truth_included=~isempty(true_library_index);count=numel(sc.test_snr_db)*sc.test_replicates_per_snr;
    rows=repmat(decision_row(),count,1);cursor=0;t=tic;
    for s=1:numel(sc.test_snr_db)
        snr=sc.test_snr_db(s);
        for r=1:sc.test_replicates_per_snr
            cursor=cursor+1;rs=RandStream('mt19937ar','Seed',sc.seed+method_index*10000000+s*1000+r);
            theta=random_theta(rs,sc.parameter_search);clean=forward_cfr(truth_network,theta,base,sc.frequency_hz,sc.measurement_kind);
            obs=add_noise(clean,snr,rs);p=stage4a7_2_r1_profile_distance({obs},cache,struct('feature','complex_raw'));
            accepted=stage4a7_2_r1_apply_profile_candidate_set(p.profile_distances,topology_model,'absolute');
            margin=compute_candidate_margin(p.profile_distances,ids);confidence=compute_candidate_confidence(p.profile_distances,evidence_model.beta,ids);
            domain_relative=min(p.profile_distances)/max(sqrt(mean(abs(obs).^2)),eps);domain_accepted=domain_relative<=domain_threshold;
            best_in_set=any(strcmp(accepted.accepted_candidate_set,margin.best_candidate{1}));
            frozen=struct('candidate_set_size',accepted.set_size,'domain_accepted',domain_accepted,'best_candidate_in_set',best_in_set);
            decision=classify_stage5b1_decision_state(frozen,struct('margin',margin.margin), ...
                struct('top1_confidence',confidence.top1_confidence,'normalized_entropy',confidence.normalized_entropy),evidence_model);
            best_is_truth=strcmp(network_signature(candidates(margin.best_index).network),truth_signature);
            true_in_set=truth_included&&any(strcmp(accepted.accepted_candidate_set,ids{true_library_index}));
            rows(cursor)=struct('sample',sprintf('%s_snr_%g_r%02d',method,snr,r),'method',method, ...
                'snr_db',snr,'replicate',r,'candidate_count',numel(candidates), ...
                'true_topology_included',truth_included,'domain_relative_distance',domain_relative, ...
                'domain_threshold',domain_threshold,'domain_accepted',domain_accepted, ...
                'candidate_set_size',accepted.set_size,'best_candidate',margin.best_candidate{1}, ...
                'best_is_truth',best_is_truth,'true_topology_in_candidate_set',true_in_set, ...
                'margin',margin.margin,'top1_confidence',confidence.top1_confidence, ...
                'normalized_entropy',confidence.normalized_entropy, ...
                'decision_state',decision.enhanced_decision_state,'decision_reason',decision.decision_reason, ...
                'normalized_score_semantics','not_a_Bayesian_posterior');
        end
    end
    timing.test_time_s=toc(t);metric=aggregate_metric(method,rows,truth_included);
    models=struct('topology_model',topology_model,'evidence_model',evidence_model, ...
        'domain_threshold',domain_threshold,'candidate_ids',{ids},'truth_topology_included',truth_included);
end

function row=make_generation_row(method,case_id,lib,reference_signatures,truth_signature,tg,tc,tr,te)
    signatures=arrayfun(@(x)network_signature(x.network),lib,'UniformOutput',false);
    row=generation_row();row.sample=[method ':' case_id];row.method=method;row.prior_case=case_id;
    row.candidate_count=numel(lib);row.generation_time=tg;row.constraint_time_s=tc;row.ranking_time_s=tr;row.export_time_s=te;
    row.true_topology_included=any(strcmp(signatures,truth_signature));
    row.coverage=double(row.true_topology_included);
    row.reference_library_coverage=nnz(ismember(reference_signatures,signatures))/numel(reference_signatures);
end
function row=make_runtime_row(method,case_id,tg,tc,tr,te,total)
    row=runtime_row();row.method=method;row.prior_case=case_id;row.generation_time_s=tg;row.constraint_time_s=tc;
    row.ranking_time_s=tr;row.export_time_s=te;row.candidate_pipeline_time_s=total;
end
function m=aggregate_metric(method,rows,truth_included)
    states={rows.decision_state};m=metric_row();m.method=method;m.sample_count=numel(rows);m.true_topology_included=truth_included;
    m.unique_confident_count=nnz(strcmp(states,'UNIQUE_CONFIDENT'));m.multiple_ambiguous_count=nnz(strcmp(states,'MULTIPLE_AMBIGUOUS'));
    m.rejected_count=nnz(strcmp(states,'REJECTED'));m.low_confidence_count=nnz(strcmp(states,'LOW_CONFIDENCE'));
    m.best_truth_count=nnz([rows.best_is_truth]);m.true_in_candidate_set_count=nnz([rows.true_topology_in_candidate_set]);
    m.correct_unique_confident_count=nnz(strcmp(states,'UNIQUE_CONFIDENT')&[rows.best_is_truth]);
end
function y=forward_cfr(network,theta,base,f,kind)
    [net,local]=topology_apply_parameters(network,base,theta);[measurement,~]=plc_measurement_bundle(kind,net,theta,local);
    [views,~]=plc_multiview_response(f,net,measurement,local);y=views{1}(:).';
end
function theta=random_theta(rs,search)
    v=search.main_length_scale;theta=struct('main_length_scale',min(v)+(max(v)-min(v))*rand(rs), ...
        'branch_length_scale',search.branch_length_scale(1),'branch_load_scale',search.branch_load_scale(1), ...
        'source_impedance_ohm',search.source_impedance_ohm(1),'receiver_impedance_ohm',search.receiver_impedance_ohm(1),'regularization',0);
end
function y=add_noise(x,snr,rs)
    if isinf(snr),y=x;else,s=sqrt(mean(abs(x).^2)/10^(snr/10)/2);y=x+s*(randn(rs,size(x))+1i*randn(rs,size(x)));end
end
function tf=is_truth_network(network,branch_nodes)
    nodes=sort([network.branches.node]);tf=isequal(nodes,sort(branch_nodes));
end
function key=network_signature(network)
    b=network.branches;
    if isempty(b)
        bt='none';
    else
        rows=zeros(numel(b),4);
        for k=1:numel(b),rows(k,:)=[b(k).node b(k).length b(k).cable_type real(b(k).load)];end
        rows=sortrows(rows);bt=sprintf('%.12g,%.12g,%.12g,%.12g;',rows.');
    end
    key=sprintf('M=%s|T=%s|B=%s',sprintf('%.12g,',network.main_lengths),sprintf('%.12g,',network.main_cable_type),bt);
end
function y=fixed_quantile(x,q),x=sort(x(:));y=x(max(1,min(numel(x),ceil(q*numel(x)))));end
function ensure_dir(p),if exist(p,'dir')~=7,mkdir(p);end,end
function r=generation_row(),r=struct('sample','','method','','prior_case','','candidate_count',0,'generation_time',NaN,'constraint_time_s',NaN,'ranking_time_s',NaN,'export_time_s',NaN,'coverage',NaN,'true_topology_included',false,'reference_library_coverage',NaN);end
function r=runtime_row(),r=struct('method','','prior_case','','generation_time_s',0,'constraint_time_s',0,'ranking_time_s',0,'export_time_s',0,'candidate_pipeline_time_s',0,'cache_time_s',0,'calibration_time_s',0,'test_time_s',0,'total_time_s',0);end
function r=decision_row(),r=struct('sample','','method','','snr_db',NaN,'replicate',0,'candidate_count',0,'true_topology_included',false,'domain_relative_distance',NaN,'domain_threshold',NaN,'domain_accepted',false,'candidate_set_size',0,'best_candidate','','best_is_truth',false,'true_topology_in_candidate_set',false,'margin',NaN,'top1_confidence',NaN,'normalized_entropy',NaN,'decision_state','','decision_reason','','normalized_score_semantics','');end
function r=metric_row(),r=struct('method','','sample_count',0,'true_topology_included',false,'unique_confident_count',0,'multiple_ambiguous_count',0,'rejected_count',0,'low_confidence_count',0,'best_truth_count',0,'true_in_candidate_set_count',0,'correct_unique_confident_count',0);end
