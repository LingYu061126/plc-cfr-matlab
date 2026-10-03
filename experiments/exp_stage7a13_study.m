function result=exp_stage7a13_study(root,mode,run_id)
%EXP_STAGE7A13_STUDY Paired fair H50 calibration/CI confirmation study.
%   Truth and generating nuisance remain in this experiment/evaluation.
%   No old result is overwritten; the default execution path is serial.
    if isempty(regexp(run_id,'^[A-Za-z0-9_]+$','once'))
        error('stage7a13:RunId', ...
            'Run ID must contain only letters, digits, or underscores.');
    end
    base=default_config(root);cfg=stage7a13_config(base,mode);
    out=fullfile(cfg.output_dir,run_id);
    if exist(out,'dir')==7
        error('stage7a13:ExistingRun', ...
            'The Stage 7A.13 run directory already exists.');
    end
    started=datetime('now','TimeZone','UTC');total_timer=tic;
    [pool,~,~,~]=stage7a6_candidate_space(base);
    [~,~,~,catalog]=stage7a7_candidate_space(base, ...
        stage7a7_config(base,'formal','nominal'));
    cal_graphs=take(catalog,cfg.calibration_graph_ids);
    test_graphs=take(catalog,cfg.test_ids);
    assert(isempty(intersect(signatures(cal_graphs), ...
        signatures(test_graphs))),'stage7a13:StructureLeakage');
    fixed=take(catalog,{'G001','G002','G003','MIRROR_M3', ...
        'ADD_M1_M3','EXT_111'});
    fixed_three=map_ids({'G001','G002','G003'},{pool.topology_id});
    mirror_pair=map_ids({'G003','MIRROR_M3'},{pool.topology_id});
    bank=stage7a4_template_bank(pool,base,cfg);
    frozen_bank=stage7a4_template_bank(fixed,base,cfg);
    prior=load(fullfile(root,'results','data','stage7a_11','formal', ...
        'formal1','config_snapshot.mat'),'fixed_cal');
    frozen=prior.fixed_cal{1}.model_d;
    assert(strcmp(frozen.bank_identity,frozen_bank.identity), ...
        'stage7a13:FrozenIdentity');
    old=load(fullfile(root,'results','data','stage7a_12','formal', ...
        'confirm3','config_snapshot.mat'),'lf_cal');
    assert(abs(old.lf_cal.tolerance-cfg.lf_tolerance_ohm)<1e-12, ...
        'stage7a13:LfCalibrationIdentity');
    model=stage7a13_calibrate_h50(cal_graphs,bank,base,cfg);
    calibration_wall_s=toc(total_timer);
    [samples,~]=stage7a4_generate_split(test_graphs, ...
        1:numel(test_graphs),base,cfg,cfg.seed_cfr_T, ...
        cfg.n_test_per_graph,20,'standard');
    rows=repmat(sample_row(),0,1);
    distances=repmat(distance_row(),0,1);
    controls=repmat(control_row(),0,1);
    conditions={"synchronous","asynchronous","high_noise"};
    for i=1:numel(samples)
        observed=samples(i).observed;
        truth=test_graphs(samples(i).truth_global_index);
        true_network=truth.network;
        true_network.main_lengths=true_network.main_lengths* ...
            samples(i).theta.main_length_scale;
        true_ci=stage7a12_ci_matrix(true_network,cfg);
        meter_count=numel(true_ci.labels);
        ideal_timer=tic;
        ideal=stage7a12_generate_candidates(true_ci.R,true_ci.labels, ...
            pool,cfg,1e-12,cfg.lf_top_k);
        ideal_wall=toc(ideal_timer);
        eligible=ideal.eligible_indices;
        for c=1:numel(conditions)
            condition=conditions{c};lf_seed=cfg.seed_lf_test+i*1000;
            timer=tic;
            low=stage7a12_measure_ci(true_ci,cfg,lf_seed,char(condition));
            low_wall=toc(timer);
            timer=tic;
            estimate=stage7a12_estimate_ci(low,cfg.lf_ridge_lambda);
            estimate_wall=toc(timer);
            timer=tic;
            generated=stage7a12_generate_candidates( ...
                estimate.symmetric_ridge,true_ci.labels,pool,cfg, ...
                cfg.lf_tolerance_ohm,cfg.lf_top_k);
            graph_wall=toc(timer);
            timer=tic;
            noinfo=stage7a12_noinfo_candidates(true_ci.labels,pool,cfg, ...
                generated.candidate_count,cfg.seed_noinfo+i*100);
            noinfo_wall=toc(timer);
            h50=stage7a4_profile_views(observed,bank,eligible,5,model.sigma);
            truth_ix=find(strcmp(bank.candidate_ids(eligible), ...
                truth.topology_id),1);
            if isempty(truth_ix),truth_h50=NaN;
            else,truth_h50=h50.distances(truth_ix);end
            for q=1:numel(eligible)
                record=distance_row();record.sample_id=i;
                record.condition=condition;
                record.truth_id=string(truth.topology_id);
                record.candidate_id=string(bank.candidate_ids{eligible(q)});
                record.signature=string(bank.candidate_signatures{eligible(q)});
                record.h50_distance=h50.distances(q);
                record.distance_minus_truth=h50.distances(q)-truth_h50;
                record.ideal_selected=ismember(eligible(q),ideal.indices);
                record.estimated_selected= ...
                    ismember(eligible(q),generated.indices);
                record.noinfo_selected=ismember(eligible(q),noinfo);
                distances(end+1)=record; %#ok<AGROW>
            end
            methods={"A3_frozen","F3_pooled","F3_stratified", ...
                "B_ideal_pooled","B_ideal_stratified", ...
                "C_estimated_pooled","C_estimated_stratified", ...
                "D_count_pooled","D_count_stratified"};
            for k=1:numel(methods)
                method=methods{k};score_timer=tic;
                if method=="A3_frozen"
                    z=stage7a10_decide(observed,frozen_bank,frozen);
                    selected_graphs=fixed(1:3);
                    chosen_ids=frozen_bank.candidate_ids(1:3);
                    eligible_ids=chosen_ids;
                    truth_h50_pass=ismember(truth.topology_id, ...
                        frozen_bank.candidate_ids(1:3)) && ...
                        ismember(truth.topology_id, ...
                        frozen_bank.candidate_ids(z.first_set));
                    class_threshold=NaN;
                    fit_threshold=z.fit_threshold;
                    fallback=false;gen_wall=0;
                    candidate_distances=z.all_distances;
                else
                    [selected,selector_mode,gen_wall]=selection( ...
                        method,fixed_three,ideal.indices, ...
                        generated.indices,noinfo,ideal_wall, ...
                        low_wall+estimate_wall+graph_wall,noinfo_wall);
                    z=stage7a13_confirm(observed,bank,model,selected, ...
                        selected_eligible(method,fixed_three,eligible), ...
                        meter_count,selector_mode);
                    selected_graphs=pool(selected);
                    chosen_ids=bank.candidate_ids(selected);
                    eligible_ids=bank.candidate_ids( ...
                        selected_eligible(method,fixed_three,eligible));
                    truth_h50_pass=isfinite(truth_h50) && ...
                        truth_h50<=z.class_threshold;
                    class_threshold=z.class_threshold;
                    fit_threshold=z.fit_threshold;
                    fallback=z.stratum_fallback;
                    candidate_distances=z.all_distances;
                end
                confirm_wall=toc(score_timer);
                audit=stage7a13_structure_audit(truth.network,selected_graphs);
                row=sample_row();row.sample_id=i;row.condition=condition;
                row.method=method;row.truth_id=string(truth.topology_id);
                row.truth_signature=string( ...
                    stage6b_network_signature(truth.network));
                row.initial_library_in=ismember(truth.topology_id, ...
                    cfg.initial_ids);
                row.searchable_in=ismember(truth.topology_id, ...
                    bank.candidate_ids);
                row.meter_count=meter_count;
                row.parameter_seed=samples(i).parameter_seed;
                row.cfr_noise_seed=samples(i).noise_seed;
                row.lf_seed=lf_seed;
                row.candidate_ids=string(strjoin(chosen_ids,','));
                row.candidate_count=numel(chosen_ids);
                row.eligible_count=numel(eligible_ids);
                row.truth_generated=ismember(truth.topology_id,chosen_ids);
                row.truth_h50_class_pass=truth_h50_pass;
                row.truth_h50_distance=truth_h50;
                row.truth_in_set=ismember(truth.topology_id, ...
                    strsplit(z.candidate_set,','));
                row.best_candidate=string(z.best_candidate);
                row.best_is_truth=strcmp(z.best_candidate,truth.topology_id);
                row.candidate_set=string(z.candidate_set);
                row.candidate_set_size=z.candidate_set_size;
                row.decision_state=string(z.decision_state);
                row.decision_reason=string(z.decision_reason);
                row.correct_unique=strcmp(z.decision_state, ...
                    'UNIQUE_CONFIDENT')&&row.best_is_truth;
                row.false_unique=strcmp(z.decision_state, ...
                    'UNIQUE_CONFIDENT')&&~row.best_is_truth;
                row.distance=z.distance;row.margin=z.margin;
                row.class_threshold=class_threshold;
                row.fit_threshold=fit_threshold;
                row.fit_pass=z.distance<=fit_threshold;
                row.margin_pass=z.margin>=cfg.separation_threshold;
                row.stratum_fallback=fallback;
                if isfield(z,'selected_only_margin')
                    row.selected_only_margin=z.selected_only_margin;
                    row.pruned_guard_active= ...
                        z.candidate_set_size==1 && row.fit_pass && ...
                        z.selected_only_margin>=cfg.separation_threshold && ...
                        ~row.margin_pass;
                end
                [row.nearest_competitor,row.nearest_competitor_distance]= ...
                    nearest_other(eligible_ids,candidate_distances, ...
                    z.best_candidate);
                if isfinite(row.truth_h50_distance)
                    row.nearest_competitor_minus_truth= ...
                        row.nearest_competitor_distance-row.truth_h50_distance;
                end
                row.any_attachment_positions_match= ...
                    audit.any_attachment_positions_match;
                row.any_labelled_connectivity_match= ...
                    audit.any_labelled_connectivity_match;
                row.any_edge_attributes_match= ...
                    audit.any_edge_attributes_match;
                row.any_complete_physical_match= ...
                    audit.any_complete_physical_match;
                row.min_wrong_attachment_count= ...
                    audit.min_wrong_attachment_count;
                row.generation_wall_s=gen_wall;
                row.confirmation_wall_s=confirm_wall;
                rows(end+1)=row; %#ok<AGROW>
            end
            if strcmp(truth.topology_id,'G003')
                for variant=["pooled","stratified"]
                    pair=stage7a13_confirm(observed,bank,model, ...
                        mirror_pair,mirror_pair,meter_count,char(variant));
                    assert(~strcmp(pair.decision_state,'UNIQUE_CONFIDENT'), ...
                        'stage7a13:MirrorForcedUnique');
                    ctrl=control_row();ctrl.sample_id=i;
                    ctrl.condition=condition;ctrl.variant=variant;
                    ctrl.truth_id=string(truth.topology_id);
                    ctrl.decision_state=string(pair.decision_state);
                    ctrl.candidate_set=string(pair.candidate_set);
                    ctrl.distance=pair.distance;ctrl.margin=pair.margin;
                    controls(end+1)=ctrl; %#ok<AGROW>
                end
            end
        end
        if mod(i,cfg.n_test_per_graph)==0
            fprintf('Stage 7A.13: %d/%d paired observations.\n', ...
                i,numel(samples));
        end
    end
    sample_table=struct2table(rows);
    distance_table=struct2table(distances);
    summary=summarize(sample_table);
    calibration=calibration_table(model);
    graph_table=graph_catalog(catalog,pool,cal_graphs,test_graphs,cfg);
    metadata=struct('stage',string(cfg.stage),'run_id',string(run_id), ...
        'mode',string(mode),'baseline_commit',string(cfg.baseline_commit), ...
        'matlab_version',string(version),'computer_arch', ...
        string(computer('arch')),'start_utc',string(started), ...
        'parallel_workers',0,'inference_bank_identity', ...
        string(bank.identity),'frozen_bank_identity', ...
        string(frozen_bank.identity),'lf_tolerance_ohm', ...
        cfg.lf_tolerance_ohm,'seed_cfr_E',cfg.seed_cfr_E, ...
        'seed_cfr_A',cfg.seed_cfr_A,'seed_cfr_F',cfg.seed_cfr_F, ...
        'seed_cfr_T',cfg.seed_cfr_T,'seed_lf_T',cfg.seed_lf_test, ...
        'seed_noinfo',cfg.seed_noinfo, ...
        'calibration_n_per_split',model.A_n, ...
        'template_forward_calls',bank.forward_calls+ ...
        frozen_bank.forward_calls+model.cal_bank_forward_calls, ...
        'template_logical_bytes',bank.logical_cache_bytes+ ...
        frozen_bank.logical_cache_bytes+model.cal_bank_logical_bytes, ...
        'calibration_wall_s',calibration_wall_s, ...
        'total_wall_s',toc(total_timer));
    mkdir(out);
    writetable(sample_table,fullfile(out,'samples.csv'));
    writetable(distance_table,fullfile(out,'candidate_distances.csv'));
    writetable(summary,fullfile(out,'summary.csv'));
    writetable(struct2table(controls),fullfile(out,'mirror_control.csv'));
    writetable(calibration,fullfile(out,'calibration.csv'));
    writetable(graph_table,fullfile(out,'graph_catalog.csv'));
    writetable(struct2table(metadata),fullfile(out,'metadata.csv'));
    save(fullfile(out,'config_snapshot.mat'),'cfg','metadata','model', ...
        'graph_table');
    fprintf('PASS Stage 7A.13 %s %s: %d rows, %.3f s.\n', ...
        mode,run_id,height(sample_table),metadata.total_wall_s);
    result=struct('output_dir',out,'metadata',metadata,'summary',summary);
end

function graphs=take(catalog,ids)
    all={catalog.topology_id};graphs=repmat( ...
        struct('topology_id','','network',struct()),1,numel(ids));
    for k=1:numel(ids)
        ix=find(strcmp(all,ids{k}),1);
        assert(~isempty(ix),'stage7a13:GraphIdentity');
        graphs(k)=struct('topology_id',ids{k}, ...
            'network',catalog(ix).network);
    end
end

function out=signatures(graphs)
    out=arrayfun(@(g)stage6b_network_signature(g.network), ...
        graphs,'UniformOutput',false);
end

function ix=map_ids(wanted,all)
    ix=zeros(1,numel(wanted));
    for k=1:numel(wanted)
        ix(k)=find(strcmp(all,wanted{k}),1);
        assert(~isempty(ix(k)),'stage7a13:CandidateIdentity');
    end
end

function [selected,variant,generation_wall]=selection( ...
        method,fixed,ideal,estimated,noinfo,ideal_wall,estimated_wall,noinfo_wall)
    if startsWith(method,"F3_")
        selected=fixed;generation_wall=0;
    elseif startsWith(method,"B_")
        selected=ideal;generation_wall=ideal_wall;
    elseif startsWith(method,"C_")
        selected=estimated;generation_wall=estimated_wall;
    else
        selected=noinfo;generation_wall=noinfo_wall;
    end
    if endsWith(method,"stratified")
        variant='stratified';
    else
        variant='pooled';
    end
end

function eligible=selected_eligible(method,fixed,measured)
    if startsWith(method,"F3_")
        eligible=fixed;
    else
        eligible=measured;
    end
end

function [id,distance]=nearest_other(ids,distances,best)
    if isempty(distances)
        id="";distance=NaN;return;
    end
    other=find(~strcmp(ids,best));
    if isempty(other)
        id="";distance=NaN;return;
    end
    [distance,j]=min(distances(other));
    id=string(ids{other(j)});
end

function out=summarize(samples)
    keys=unique(samples(:,{'condition','method','truth_id'}));
    rows=repmat(summary_row(),height(keys),1);
    for i=1:height(keys)
        key=keys(i,:);
        x=samples(samples.condition==key.condition & ...
            samples.method==key.method & samples.truth_id==key.truth_id,:);
        row=summary_row();row.condition=key.condition;
        row.method=key.method;row.truth_id=key.truth_id;
        row.n=height(x);row.initial_library_in=all(x.initial_library_in);
        row.searchable_in=all(x.searchable_in);
        row.generated_truth_k=nnz(x.truth_generated);
        row.generated_and_h50_pass_k= ...
            nnz(x.truth_generated & x.truth_h50_class_pass);
        row.truth_in_set_k=nnz(x.truth_in_set);
        row.correct_unique_k=nnz(x.correct_unique);
        row.false_unique_k=nnz(x.false_unique);
        row.nonempty_set_k=nnz(x.candidate_set_size>0);
        row.ambiguous_k=nnz(x.decision_state=="MULTIPLE_AMBIGUOUS");
        row.low_confidence_k=nnz(x.decision_state=="LOW_CONFIDENCE");
        row.rejected_k=nnz(x.decision_state=="REJECTED");
        row.pruned_guard_k=nnz(x.pruned_guard_active);
        row.mean_candidate_count=mean(x.candidate_count);
        row.mean_set_size=mean(x.candidate_set_size);
        row.mean_generation_wall_s=mean(x.generation_wall_s);
        row.mean_confirmation_wall_s=mean(x.confirmation_wall_s);
        rows(i)=row;
    end
    out=struct2table(rows);
end

function out=calibration_table(model)
    n=numel(model.strata);
    row=struct('meter_count',0,'class_threshold', ...
        model.pooled_class_threshold,'fit_threshold', ...
        model.pooled_fit_threshold,'class_n',model.A_n, ...
        'fit_n',model.F_n,'class_structures', ...
        numel(model.calibration_signatures), ...
        'fit_structures',numel(model.calibration_signatures), ...
        'fallback',false);
    all_rows=repmat(row,n+1,1);all_rows(1)=row;
    for i=1:n
        all_rows(i+1)=model.strata(i);
    end
    out=struct2table(all_rows);
end

function out=graph_catalog(catalog,pool,cal_graphs,test_graphs,cfg)
    n=numel(catalog);
    rows=repmat(struct('graph_id',"",'signature',"",'branch_count',0, ...
        'calibration',false,'final_test',false,'initial_library',false, ...
        'searchable',false,'new_family_holdout',false),n,1);
    for i=1:n
        id=catalog(i).topology_id;
        rows(i)=struct('graph_id',string(id), ...
            'signature',string(stage6b_network_signature( ...
            catalog(i).network)), ...
            'branch_count',numel(catalog(i).network.branches), ...
            'calibration',ismember(id,{cal_graphs.topology_id}), ...
            'final_test',ismember(id,{test_graphs.topology_id}), ...
            'initial_library',ismember(id,cfg.initial_ids), ...
            'searchable',ismember(id,{pool.topology_id}), ...
            'new_family_holdout',ismember(id,cfg.new_family_ids));
    end
    out=struct2table(rows);
end

function r=sample_row()
    r=struct('sample_id',0,'condition',"",'method',"",'truth_id',"", ...
        'truth_signature',"",'initial_library_in',false, ...
        'searchable_in',false,'meter_count',0,'parameter_seed',0, ...
        'cfr_noise_seed',0,'lf_seed',0,'candidate_ids',"", ...
        'candidate_count',0,'eligible_count',0, ...
        'truth_generated',false,'truth_h50_class_pass',false, ...
        'truth_h50_distance',NaN,'truth_in_set',false, ...
        'best_candidate',"",'best_is_truth',false, ...
        'candidate_set',"",'candidate_set_size',0, ...
        'decision_state',"",'decision_reason',"", ...
        'correct_unique',false,'false_unique',false, ...
        'distance',NaN,'margin',NaN, ...
        'class_threshold',NaN,'fit_threshold',NaN, ...
        'fit_pass',false,'margin_pass',false, ...
        'stratum_fallback',false,'selected_only_margin',NaN, ...
        'pruned_guard_active',false,'nearest_competitor',"", ...
        'nearest_competitor_distance',NaN, ...
        'nearest_competitor_minus_truth',NaN, ...
        'any_attachment_positions_match',false, ...
        'any_labelled_connectivity_match',false, ...
        'any_edge_attributes_match',false, ...
        'any_complete_physical_match',false, ...
        'min_wrong_attachment_count',NaN, ...
        'generation_wall_s',NaN,'confirmation_wall_s',NaN);
end

function r=distance_row()
    r=struct('sample_id',0,'condition',"",'truth_id',"", ...
        'candidate_id',"",'signature',"",'h50_distance',NaN, ...
        'distance_minus_truth',NaN,'ideal_selected',false, ...
        'estimated_selected',false,'noinfo_selected',false);
end

function r=control_row()
    r=struct('sample_id',0,'condition',"",'variant',"", ...
        'truth_id',"",'decision_state',"",'candidate_set',"", ...
        'distance',NaN,'margin',NaN);
end

function r=summary_row()
    r=struct('condition',"",'method',"",'truth_id',"",'n',0, ...
        'initial_library_in',false,'searchable_in',false, ...
        'generated_truth_k',0,'generated_and_h50_pass_k',0, ...
        'truth_in_set_k',0,'correct_unique_k',0, ...
        'false_unique_k',0,'nonempty_set_k',0, ...
        'ambiguous_k',0,'low_confidence_k',0,'rejected_k',0, ...
        'pruned_guard_k',0,'mean_candidate_count',NaN, ...
        'mean_set_size',NaN,'mean_generation_wall_s',NaN, ...
        'mean_confirmation_wall_s',NaN);
end
