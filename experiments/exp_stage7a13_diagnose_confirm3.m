function result=exp_stage7a13_diagnose_confirm3(root,run_id)
%EXP_STAGE7A13_DIAGNOSE_CONFIRM3 Reconstruct frozen Stage 7A.12 decisions.
%   Reads archived candidate IDs and regenerated CFR observations. Truth is
%   used only to label audit records. Writes new Stage 7A.13 files only.
    assert(~isempty(regexp(run_id,'^[A-Za-z0-9_]+$','once')), ...
        'stage7a13:RunId');
    out=fullfile(root,'results','data','stage7a_13','diagnostic',run_id);
    assert(exist(out,'dir')~=7,'stage7a13:ExistingRun');
    source=fullfile(root,'results','data','stage7a_12','formal','confirm3');
    archive=readtable(fullfile(source,'samples.csv'),'Delimiter',',', ...
        'TextType','string');
    for name=["candidate_ids","best_candidate","candidate_set"]
        archive.(name)(ismissing(archive.(name)))="";
    end
    snapshot=load(fullfile(source,'config_snapshot.mat'),'cfg','cfr_model');
    cfg=snapshot.cfg;model=snapshot.cfr_model;base=default_config(root);
    [pool,~,~,catalog]=stage7a6_candidate_space(base);
    [~,~,~,extra]=stage7a7_candidate_space(base, ...
        stage7a7_config(base,'formal','nominal'));
    catalog=[catalog(:);extra(end-1:end)];
    test=take(catalog,cfg.test_ids);
    fixed=take(catalog,{'G001','G002','G003','MIRROR_M3', ...
        'ADD_M1_M3','EXT_111'});
    bank=stage7a4_template_bank(pool,base,cfg);
    fixed_bank=stage7a4_template_bank(fixed,base,cfg);
    prior=load(fullfile(root,'results','data','stage7a_11','formal', ...
        'formal1','config_snapshot.mat'),'fixed_cal');
    frozen=prior.fixed_cal{1}.model_d;
    assert(strcmp(bank.identity,model.bank_identity) && ...
        strcmp(fixed_bank.identity,frozen.bank_identity), ...
        'stage7a13:FrozenBankIdentity');
    [observations,~]=stage7a4_generate_split(test,1:numel(test), ...
        base,cfg,cfg.seed_cfr_T,cfg.n_test_per_graph,20,'standard');
    rows=repmat(sample_row(),height(archive)/6*4,1);
    candidates=repmat(candidate_row(),0,1);cursor=0;mismatch=0;timer=tic;
    methods=["A_D_samecal_3","B_ideal_ci", ...
        "C_estimated_ci","D_count_matched"];
    conditions=["synchronous","asynchronous","high_noise"];
    for i=1:numel(observations)
        obs=observations(i).observed;truth=test(observations(i).truth_global_index);
        for condition=conditions
            for method=methods
                ix=find(archive.sample_id==i & ...
                    archive.condition==condition & archive.method==method);
                assert(isscalar(ix),'stage7a13:ArchiveRowIdentity');
                old=archive(ix,:);cursor=cursor+1;
                if method=="A_D_samecal_3"
                    local_bank=fixed_bank;chosen=1:3;eligible=1:3;
                    z=stage7a10_decide(obs,local_bank,frozen);
                    h50=stage7a4_profile_views(obs,local_bank,eligible,5, ...
                        frozen.sigma);
                    final=z.all_distances;
                    h50_threshold=frozen.first_threshold(:).';
                    final_threshold=frozen.class_threshold(:).';
                    fit_threshold=frozen.fit_threshold;
                    margin_threshold=frozen.margin_threshold;
                else
                    local_bank=bank;
                    chosen=parse_ids(old.candidate_ids,bank.candidate_ids);
                    meter_labels=cell(1,old.meter_count);
                    meter_labels{1}='RX';
                    for j=2:numel(meter_labels)
                        meter_labels{j}=sprintf('B%d',j-1);
                    end
                    eligible=meter_eligible(pool,cfg,meter_labels);
                    z=stage7a12_confirm(obs,bank,model,chosen,eligible);
                    h50=stage7a4_profile_views(obs,bank,eligible,5,model.sigma);
                    final=h50.distances;
                    h50_threshold=repmat(model.class_threshold,1,numel(eligible));
                    final_threshold=h50_threshold;
                    fit_threshold=model.fit_threshold;
                    margin_threshold=model.margin_threshold;
                end
                if ~same_decision(z,old)
                    mismatch=mismatch+1;
                    if mismatch<=5
                        fprintf('Mismatch sample=%d %s %s: state=%s/%s, ', ...
                            i,condition,method,z.decision_state,old.decision_state);
                        fprintf('reason=%s/%s, best=%s/%s, set=%s/%s, ', ...
                            z.decision_reason,old.decision_reason, ...
                            z.best_candidate,old.best_candidate, ...
                            z.candidate_set,old.candidate_set);
                        fprintf('distance=%.12g/%.12g, margin=%.12g/%.12g\n', ...
                            z.distance,old.distance,z.margin,old.margin);
                    end
                end
                ids=local_bank.candidate_ids(eligible);
                truth_position=find(strcmp(ids,truth.topology_id),1);
                if isempty(truth_position)
                    true_h50=NaN;true_class=false;
                    true_final=NaN;true_final_class=false;
                else
                    true_h50=h50.distances(truth_position);
                    true_class=true_h50<=h50_threshold(truth_position);
                    true_final=final(truth_position);
                    true_final_class=true_final<=final_threshold(truth_position);
                end
                generated=ismember(truth.topology_id, ...
                    local_bank.candidate_ids(chosen));
                [nearest_id,nearest_distance]=competitor(ids,final,z.best_candidate);
                selected_final=final(ismember(eligible,chosen));
                if numel(selected_final)<2
                    selected_margin=Inf;
                else
                    sorted=sort(selected_final);selected_margin=sorted(2)-sorted(1);
                end
                row=sample_row();row.sample_id=i;row.condition=condition;
                row.method=method;row.truth_id=string(truth.topology_id);
                row.truth_generated=generated;
                row.truth_h50_distance=true_h50;
                row.truth_h50_class_pass=true_class;
                row.truth_final_distance=true_final;
                row.truth_final_class_pass=true_final_class;
                row.truth_in_set=ismember(truth.topology_id, ...
                    strsplit(z.candidate_set,','));
                row.best_is_truth=strcmp(z.best_candidate,truth.topology_id);
                row.fit_pass=z.distance<=fit_threshold;
                row.fit_threshold=fit_threshold;
                row.margin_pass=z.margin>=margin_threshold;
                row.margin_threshold=margin_threshold;
                row.margin=z.margin;row.selected_only_margin=selected_margin;
                row.pruned_guard_active=z.candidate_set_size==1 && ...
                    row.fit_pass && selected_margin>=margin_threshold && ...
                    ~row.margin_pass;
                row.nearest_competitor=string(nearest_id);
                row.nearest_competitor_distance=nearest_distance;
                row.best_candidate=string(z.best_candidate);
                row.candidate_set=string(z.candidate_set);
                row.decision_state=string(z.decision_state);
                row.decision_reason=string(z.decision_reason);
                row.failure_layer=classify_failure(row);
                row.archive_match=same_decision(z,old);
                rows(cursor)=row;
                for j=1:numel(eligible)
                    candidate=candidate_row();candidate.sample_id=i;
                    candidate.condition=condition;candidate.method=method;
                    candidate.truth_id=string(truth.topology_id);
                    candidate.candidate_id=string(ids{j});
                    candidate.signature=string( ...
                        local_bank.candidate_signatures{eligible(j)});
                    candidate.generated=ismember(eligible(j),chosen);
                    candidate.h50_distance=h50.distances(j);
                    candidate.h50_threshold=h50_threshold(j);
                    candidate.h50_class_pass= ...
                        candidate.h50_distance<=candidate.h50_threshold;
                    candidate.final_distance=final(j);
                    candidate.final_threshold=final_threshold(j);
                    candidate.final_class_pass= ...
                        candidate.final_distance<=candidate.final_threshold;
                    candidate.in_final_set=ismember(ids{j}, ...
                        strsplit(z.candidate_set,','));
                    candidate.distance_minus_truth=final(j)-true_final;
                    candidates(end+1)=candidate; %#ok<AGROW>
                end
            end
        end
    end
    assert(cursor==numel(rows),'stage7a13:RowCount');
    assert(mismatch==0,'stage7a13:ArchiveMismatch', ...
        '%d Stage 7A.12 rows differ after reconstruction.',mismatch);
    metadata=struct('baseline_commit', ...
        "43b18eba60f1ceedc1f43b883bab46656c4e5e52", ...
        'source_run',"stage7a_12/formal/confirm3",'run_id',string(run_id), ...
        'matlab_version',string(version),'computer_arch', ...
        string(computer('arch')),'reconstructed_rows',cursor, ...
        'candidate_rows',numel(candidates),'mismatch_count',mismatch, ...
        'wall_s',toc(timer));
    mkdir(out);
    writetable(struct2table(rows),fullfile(out,'sample_diagnostics.csv'));
    writetable(struct2table(candidates),fullfile(out,'candidate_distances.csv'));
    writetable(struct2table(metadata),fullfile(out,'metadata.csv'));
    fprintf('PASS Stage 7A.13 confirm3 reconstruction: %d rows, %d mismatches.\n', ...
        cursor,mismatch);
    result=struct('output_dir',out,'metadata',metadata);
end

function out=take(catalog,ids)
    all={catalog.topology_id};out=repmat( ...
        struct('topology_id','','network',struct()),1,numel(ids));
    for k=1:numel(ids)
        j=find(strcmp(all,ids{k}),1);
        assert(~isempty(j),'stage7a13:GraphIdentity');
        out(k)=struct('topology_id',ids{k},'network',catalog(j).network);
    end
end

function indices=parse_ids(value,all_ids)
    if strlength(value)==0
        indices=[];return;
    end
    ids=strsplit(char(value),',');indices=zeros(1,numel(ids));
    for k=1:numel(ids)
        indices(k)=find(strcmp(all_ids,ids{k}),1);
        assert(~isempty(indices(k)),'stage7a13:CandidateIdentity');
    end
end

function indices=meter_eligible(pool,cfg,labels)
    indices=zeros(1,0);
    for k=1:numel(pool)
        ci=stage7a12_ci_matrix(pool(k).network,cfg);
        if isequal(ci.labels,labels)
            indices(end+1)=k; %#ok<AGROW>
        end
    end
end

function match=same_decision(z,old)
    match=strcmp(z.decision_state,old.decision_state) && ...
        strcmp(z.decision_reason,old.decision_reason) && ...
        strcmp(z.best_candidate,old.best_candidate) && ...
        strcmp(z.candidate_set,old.candidate_set) && ...
        same_number(z.distance,old.distance) && ...
        same_number(z.margin,old.margin);
end

function yes=same_number(a,b)
    yes=(isnan(a)&&isnan(b)) || (isinf(a)&&isinf(b)&&sign(a)==sign(b)) ...
        || abs(a-b)<1e-7;
end

function [id,distance]=competitor(ids,distances,best)
    other=find(~strcmp(ids,best));
    if isempty(other)
        id='';distance=NaN;return;
    end
    [distance,j]=min(distances(other));id=ids{other(j)};
end

function label=classify_failure(r)
    if ~r.truth_generated
        label="generation_miss";
    elseif ~r.truth_h50_class_pass
        label="h50_class_gate";
    elseif ~r.fit_pass
        label="fit_quality_gate";
    elseif ~r.truth_in_set
        label="final_set_exclusion";
    elseif r.decision_state=="UNIQUE_CONFIDENT" && r.best_is_truth
        label="correct_unique";
    elseif r.decision_state=="MULTIPLE_AMBIGUOUS"
        label="candidate_competition";
    elseif r.decision_state=="LOW_CONFIDENCE"
        label="insufficient_unique_evidence";
    else
        label="other_decision";
    end
end

function r=sample_row()
    r=struct('sample_id',0,'condition',"",'method',"",'truth_id',"", ...
        'truth_generated',false,'truth_h50_distance',NaN, ...
        'truth_h50_class_pass',false,'truth_final_distance',NaN, ...
        'truth_final_class_pass',false,'truth_in_set',false, ...
        'best_is_truth',false,'fit_pass',false,'fit_threshold',NaN, ...
        'margin_pass',false,'margin_threshold',NaN,'margin',NaN, ...
        'selected_only_margin',NaN,'pruned_guard_active',false, ...
        'nearest_competitor',"",'nearest_competitor_distance',NaN, ...
        'best_candidate',"",'candidate_set',"",'decision_state',"", ...
        'decision_reason',"",'failure_layer',"",'archive_match',false);
end

function r=candidate_row()
    r=struct('sample_id',0,'condition',"",'method',"",'truth_id',"", ...
        'candidate_id',"",'signature',"",'generated',false, ...
        'h50_distance',NaN,'h50_threshold',NaN, ...
        'h50_class_pass',false,'final_distance',NaN, ...
        'final_threshold',NaN,'final_class_pass',false, ...
        'in_final_set',false,'distance_minus_truth',NaN);
end
