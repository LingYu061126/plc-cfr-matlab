function summary=exp_stage5b1_objective_confirmation_upgrade(root,mode)
%EXP_STAGE5B1_OBJECTIVE_CONFIRMATION_UPGRADE Add-only Stage 5B.1 analysis.
%   Replays frozen Stage 4A Pilot and T3/T5 observations, verifies their
%   hashes/decisions, then adds margin, normalized confidence and entropy.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);cfg=stage5b1_objective_confirmation_config(base,mode);
    out=fullfile(cfg.output_root,mode);ensure_dir(out);t0=tic;
    source_summary=fullfile(cfg.source_formal_dir,'summary.mat');
    source_identity=fullfile(cfg.source_formal_dir,'checkpoint_identity.mat');
    stage4_summary=fullfile(cfg.stage4a_formal_dir,'stage4a7_3_summary.mat');
    stage4_pilot_csv=fullfile(cfg.stage4a_formal_dir,'paired_domain_validation.csv');
    stage4_nonunique_csv=fullfile(cfg.stage4a_formal_dir,'nonunique_benchmark_ledger.csv');
    required={source_summary,source_identity,stage4_summary,stage4_pilot_csv,stage4_nonunique_csv};
    for k=1:numel(required),assert(exist(required{k},'file')==2,'stage5b1:MissingFrozenInput','Missing %s.',required{k});end

    z=load(source_summary,'selected_model','calD','cal','ids');
    q=load(source_identity,'cache','scored','ids');
    r4=load(stage4_summary,'domain_model','sc','identity');
    frozen_model=z.selected_model;cache=q.cache;candidates=q.scored;domain_model=r4.domain_model;sc4=r4.sc;
    assert(numel(candidates)==87&&numel(cache.candidate_ids)==87,'stage5b1:FrozenCandidateCount','Expected 87 frozen candidates.');
    assert(strcmp(domain_model.method_id,cfg.expected_rule_a_method),'stage5b1:RuleAMethodChanged','Frozen Rule A method changed.');
    assert(abs(domain_model.threshold-cfg.expected_rule_a_threshold)<1e-14,'stage5b1:RuleAThresholdChanged','Frozen Rule A threshold changed.');

    % Calibrate only the new evidence layer from the already frozen calibration split.
    truth_index=zeros(numel(z.cal),1);set_size=zeros(numel(z.cal),1);
    for k=1:numel(z.cal)
        truth_index(k)=find(strcmp(frozen_model.candidate_ids,z.cal(k).truth_topology_id),1);
        a=stage4a7_2_r1_apply_profile_candidate_set(z.calD(k,:),frozen_model,frozen_model.method_id);
        set_size(k)=a.set_size;
    end
    copts=cfg.calibration;copts.candidate_ids=frozen_model.candidate_ids;
    evidence_model=calibrate_stage5b1_decision_metrics(z.calD,truth_index,set_size,copts);

    baseline_pilot=readtable(stage4_pilot_csv,'TextType','string');
    baseline_nonunique=readtable(stage4_nonunique_csv,'TextType','string');
    pilot_map=make_row_map(baseline_pilot.sample_id);nonunique_map=make_row_map(baseline_nonunique.sample_id);
    if strcmp(mode,'formal'),candidate_count=numel(candidates);nonunique_per_noise=sc4.nonunique.test_per_noise;
    else,candidate_count=min(cfg.smoke_candidate_count,numel(candidates));nonunique_per_noise=cfg.smoke_nonunique_per_noise;end
    n_pilot=candidate_count*numel(cfg.pilot_categories);n_non=numel(sc4.nonunique.noise_levels_db)*nonunique_per_noise;
    margins=repmat(margin_row(),n_pilot+n_non,1);decisions=repmat(decision_row(),n_pilot+n_non,1);
    confidences=repmat(confidence_row(),n_pilot*numel(cache.candidate_ids)+n_non*2,1);
    im=0;idc=0;ic=0;

    % Deterministically replay the canonical Stage 4A.7.3 Pilot.
    for k=1:candidate_count
        pair_id=sprintf('pilot_C%03d_R01',k);seed=stage4a7_2_r2_1_stable_case_seed(sc4.seeds.pilot,pair_id);
        rs=RandStream('mt19937ar','Seed',seed);nuisance=theta_in_domain(rs);
        noise_base=randn(rs,1,numel(cache.frequency_hz))+1i*randn(rs,1,numel(cache.frequency_hz));
        for c=1:numel(cfg.pilot_categories)
            category=cfg.pilot_categories{c};theta=nuisance;theta.main_length_scale=category_value(category,rs,sc4.parameter_domain);
            [net,local]=topology_apply_parameters(candidates(k).network,base,theta);
            [measurement,~]=plc_measurement_bundle(sc4.measurement_kind,net,theta,local);
            [views,~]=plc_multiview_response(cache.frequency_hz,net,measurement,local);
            truth=views{1}(:).';obs=add_noise_base(truth,sc4.noise.snr_db,noise_base);
            profile=stage4a7_2_r1_profile_distance({obs},cache,struct('feature',sc4.feature,'ofdm_config',base.ofdm));
            accepted=stage4a7_2_r1_apply_profile_candidate_set(profile.profile_distances,frozen_model,frozen_model.method_id);
            drelative=min(profile.profile_distances)/max(sqrt(mean(abs(obs).^2)),eps);
            domain=stage4a7_3_apply_domain_model(drelative,domain_model);
            sample=sprintf('r73_pilot_%s_C%03d_R01',category,k);truth_id=getid(candidates(k));
            b=baseline_pilot(pilot_map(sample),:);
            assert_frozen_pilot_match(b,sample,profile.profile_distances,drelative,accepted,domain,obs);
            [mr,cr,dr]=evaluate_one(sample,'pilot',category,profile.profile_distances,cache.candidate_ids, ...
                accepted.accepted_candidate_set,domain.domain_accepted,truth_id,{truth_id},evidence_model);
            im=im+1;margins(im)=mr;decisions(im)=dr;
            confidences(ic+(1:numel(cr)))=cr;ic=ic+numel(cr);idc=idc+1;
        end
        if mod(k,10)==0||k==candidate_count,fprintf('Stage 5B.1 Pilot replay: %d/%d candidates\n',k,candidate_count);end
    end

    % Replay the frozen T3/T5 matched-end-impedance non-unique control.
    [control_cache,control_model]=build_control(base,sc4);
    expected_control_hash=unique(baseline_nonunique.calibration_hash);
    assert(isscalar(expected_control_hash)&&strcmp(control_model.calibration_hash,char(expected_control_hash)), ...
        'stage5b1:NonuniqueCalibrationChanged','T3/T5 frozen calibration hash changed.');
    for qn=1:numel(sc4.nonunique.noise_levels_db)
        snr=sc4.nonunique.noise_levels_db(qn);
        for rr=1:nonunique_per_noise
            sample=sprintf('r73_non_%g_%02d',snr,rr);rs=RandStream('mt19937ar','Seed', ...
                stage4a7_2_r2_1_stable_case_seed(sc4.seeds.nonunique_test,sample));
            theta=theta_in_domain(rs);theta.receiver_impedance_ohm=theta.source_impedance_ohm;
            theta.main_length_scale=1+sc4.nonunique.parameter_perturbation_fraction*(2*rand(rs)-1);
            truth=control_cfr(control_cache.candidates(1),theta,base,control_cache.frequency_hz);
            obs=add_noise_base(truth,snr,randn(rs,size(truth))+1i*randn(rs,size(truth)));
            profile=stage4a7_2_r1_profile_distance({obs},control_cache,struct('feature','complex_raw'));
            accepted=stage4a7_2_r1_apply_profile_candidate_set(profile.profile_distances,control_model,'absolute');
            b=baseline_nonunique(nonunique_map(sample),:);
            assert_frozen_nonunique_match(b,sample,accepted,obs);
            category=sprintf('snr_%g_db',snr);
            [mr,cr,dr]=evaluate_one(sample,'T3_T5',category,profile.profile_distances,control_cache.candidate_ids, ...
                accepted.accepted_candidate_set,true,'T3',{'T3','T5'},evidence_model);
            im=im+1;margins(im)=mr;decisions(im)=dr;
            confidences(ic+(1:numel(cr)))=cr;ic=ic+numel(cr);idc=idc+1;
        end
    end
    assert(im==numel(margins)&&idc==numel(decisions)&&ic==numel(confidences),'stage5b1:OutputCount','Internal output count mismatch.');

    metrics=build_metrics(decisions,cfg.pilot_categories,sc4.nonunique.noise_levels_db);
    runtime_s=toc(t0);
    summary=build_summary(mode,decisions,evidence_model,runtime_s,candidate_count,n_pilot,n_non);
    writetable(struct2table(margins),fullfile(out,'candidate_margin.csv'));
    writetable(struct2table(confidences),fullfile(out,'candidate_confidence.csv'));
    writetable(struct2table(decisions),fullfile(out,'enhanced_decision_summary.csv'));
    writetable(struct2table(metrics),fullfile(out,'stage5b1_decision_metrics.csv'));
    writetable(struct2table(calibration_row(evidence_model,z.selected_model,r4.domain_model)),fullfile(out,'stage5b1_calibration.csv'));
    writetable(struct2table(summary),fullfile(out,'stage5b1_runtime.csv'));
    save(fullfile(out,'stage5b1_results.mat'),'summary','evidence_model','metrics','cfg','-v7');
    fprintf('Stage 5B.1 %s completed: pilot=%d T3/T5=%d in %.3f s.\n',mode,n_pilot,n_non,runtime_s);
end

function [margin_row_out,confidence_rows,decision_row_out]=evaluate_one(sample,dataset,category,distances,ids,accepted_ids,domain_accepted,truth_id,truth_set,model)
    accepted_ids=cellstr(accepted_ids);margin=compute_candidate_margin(distances,ids);
    confidence=compute_candidate_confidence(distances,model.beta,ids);
    frozen=struct('candidate_set_size',numel(accepted_ids),'domain_accepted',logical(domain_accepted), ...
        'best_candidate_in_set',any(strcmp(accepted_ids,margin.best_candidate{1})));
    enhanced=classify_stage5b1_decision_state(frozen,scalar_margin(margin),scalar_confidence(confidence),model);
    residual_accepted=frozen.domain_accepted&&frozen.candidate_set_size>0;
    if ~residual_accepted,baseline_state='REJECTED';
    elseif frozen.candidate_set_size==1,baseline_state='UNIQUE';else,baseline_state='AMBIGUOUS';end
    truth_complete=all(ismember(truth_set,accepted_ids));
    baseline_false_unique=strcmp(baseline_state,'UNIQUE')&&~truth_complete;
    enhanced_false_unique=strcmp(enhanced.enhanced_decision_state,'UNIQUE_CONFIDENT')&&numel(truth_set)>1;
    if isscalar(truth_set)
        enhanced_false_unique=strcmp(enhanced.enhanced_decision_state,'UNIQUE_CONFIDENT')&&~strcmp(margin.best_candidate{1},truth_id);
    end
    margin_row_out=margin_row();margin_row_out.sample=sample;margin_row_out.best_candidate=margin.best_candidate{1};
    margin_row_out.second_candidate=margin.second_candidate{1};margin_row_out.d1=margin.d1;margin_row_out.d2=margin.d2;
    margin_row_out.margin=margin.margin;margin_row_out.dataset=dataset;margin_row_out.category=category;
    confidence_rows=repmat(confidence_row(),numel(ids),1);
    [~,ord]=sortrows([distances(:),(1:numel(ids)).'],[1 2]);rank=zeros(1,numel(ids));rank(ord)=1:numel(ids);
    for j=1:numel(ids)
        confidence_rows(j)=struct('sample',sample,'candidate',ids{j},'distance',distances(j), ...
            'normalized_confidence_score',confidence.normalized_confidence_scores(j),'rank',rank(j), ...
            'top1_confidence',confidence.top1_confidence,'entropy',confidence.entropy, ...
            'normalized_entropy',confidence.normalized_entropy,'beta',confidence.beta, ...
            'candidate_count',numel(ids),'dataset',dataset,'category',category, ...
            'probability_semantics','normalized_confidence_score_not_posterior_probability');
    end
    decision_row_out=decision_row();decision_row_out.sample=sample;decision_row_out.dataset=dataset;decision_row_out.category=category;
    decision_row_out.truth_topology=truth_id;decision_row_out.truth_equivalence_set=strjoin(truth_set,',');
    decision_row_out.best_candidate=margin.best_candidate{1};decision_row_out.second_candidate=margin.second_candidate{1};
    decision_row_out.d1=margin.d1;decision_row_out.d2=margin.d2;decision_row_out.margin=margin.margin;
    decision_row_out.top1_confidence=confidence.top1_confidence;decision_row_out.entropy=confidence.entropy;
    decision_row_out.normalized_entropy=confidence.normalized_entropy;decision_row_out.frozen_candidate_set=strjoin(accepted_ids,',');
    decision_row_out.frozen_candidate_set_size=numel(accepted_ids);decision_row_out.domain_accepted=logical(domain_accepted);
    decision_row_out.baseline_decision_state=baseline_state;decision_row_out.enhanced_decision_state=enhanced.enhanced_decision_state;
    decision_row_out.decision_reason=enhanced.decision_reason;decision_row_out.margin_pass=enhanced.margin_pass;
    decision_row_out.confidence_pass=enhanced.confidence_pass;decision_row_out.entropy_pass=enhanced.entropy_pass;
    decision_row_out.evidence_sufficient=enhanced.evidence_sufficient;decision_row_out.baseline_false_unique=baseline_false_unique;
    decision_row_out.enhanced_false_unique=enhanced_false_unique;
    decision_row_out.enhanced_ambiguity_detected=ismember(enhanced.enhanced_decision_state,{'MULTIPLE_AMBIGUOUS','LOW_CONFIDENCE'});
end

function [cache,model]=build_control(base,sc)
    all=topology_candidates(base);cand=all(ismember({all.id},sc.nonunique.candidate_ids));
    assert(numel(cand)==2,'stage5b1:MissingNonuniqueControl','T3/T5 candidates are required.');
    grid=topology_parameter_grid(base.stage2_2.search);grid=grid([grid.source_impedance_ohm]==[grid.receiver_impedance_ohm]);
    f=sc.frequency_hz;H=cell(1,2);
    for k=1:2,H{k}=zeros(numel(grid),numel(f));for q=1:numel(grid),H{k}(q,:)=control_cfr(cand(k),grid(q),base,f);end,end
    cache=struct('frequency_hz',f,'candidate_ids',{{cand.id}},'candidates',cand,'theta_grid',grid,'H',{H},'measurement_kind','siso_forward');
    delta=max(abs(H{1}(:)-H{2}(:)));assert(delta<=sc.nonunique.numerical_tolerance,'stage5b1:NonuniqueControlInvalid','T3/T5 equivalence changed.');
    calD=zeros(2*sc.nonunique.calibration_per_candidate,2);calI=zeros(size(calD,1),1);ix=0;
    for k=1:2
        for rr=1:sc.nonunique.calibration_per_candidate
            ix=ix+1;id=sprintf('r73_non_cal_%d_%d',k,rr);
            rs=RandStream('mt19937ar','Seed',stage4a7_2_r2_1_stable_case_seed(sc.seeds.nonunique_calibration,id));
            theta=theta_in_domain(rs);theta.receiver_impedance_ohm=theta.source_impedance_ohm;
            y=control_cfr(cand(k),theta,base,f);p=stage4a7_2_r1_profile_distance({y},cache,struct('feature','complex_raw'));
            calD(ix,:)=p.profile_distances;calI(ix)=k;
        end
    end
    model=stage4a7_2_r1_calibrate_profile_method(calD,calI,cache.candidate_ids,'absolute',sc.alpha, ...
        struct('minimum_per_candidate',sc.nonunique.calibration_per_candidate,'resolution',eps, ...
        'compatibility_hash',r4_experiment_hash()));
end

function h=control_cfr(c,theta,base,f)
    [net,local]=topology_apply_parameters(c.network,base,theta);z=cascade_network_stable(f,net,local);h=z.H_port(:).';
end
function h=r4_experiment_hash()
    % Frozen Stage 4A.7.3 used its experiment hash as this compatibility ID.
    % Recover it from the canonical summary identity when available in config.
    root=fileparts(fileparts(mfilename('fullpath')));z=load(fullfile(root,'results','data','stage4a_freeze_r1_1','stage4a7_3','formal','stage4a7_3_summary.mat'),'identity');h=z.identity.experiment_hash;
end

function assert_frozen_pilot_match(b,sample,distances,drelative,accepted,domain,obs)
    assert(strcmp(char(b.sample_id),sample),'stage5b1:PilotSampleOrder','Pilot sample mismatch.');
    assert(abs(b.dmin-min(distances))<1e-12&&abs(b.drelative-drelative)<1e-12,'stage5b1:PilotDistanceDrift','Pilot distance drift for %s.',sample);
    assert(strcmp(char(b.topology_set),strjoin(cellstr(accepted.accepted_candidate_set),',')),'stage5b1:PilotSetDrift','Pilot candidate set drift for %s.',sample);
    assert(logical(b.domain_accepted)==logical(domain.domain_accepted),'stage5b1:PilotDomainDrift','Pilot domain decision drift for %s.',sample);
    assert(strcmp(char(b.observation_hash),stage4a4_scientific_config_hash(obs)),'stage5b1:PilotObservationDrift','Pilot observation hash drift for %s.',sample);
end
function assert_frozen_nonunique_match(b,sample,accepted,obs)
    assert(strcmp(char(b.sample_id),sample),'stage5b1:NonuniqueSampleOrder','Nonunique sample mismatch.');
    assert(strcmp(char(b.accepted_set),strjoin(cellstr(accepted.accepted_candidate_set),',')),'stage5b1:NonuniqueSetDrift','T3/T5 set drift for %s.',sample);
    assert(strcmp(char(b.observation_hash),stage4a4_scientific_config_hash(obs)),'stage5b1:NonuniqueObservationDrift','T3/T5 observation hash drift for %s.',sample);
end

function metrics=build_metrics(rows,pilot_categories,noise_levels)
    metrics=repmat(metric_row(),0,1);
    metrics(end+1)=metric_for(rows(strcmp({rows.dataset},'pilot')),'pilot','ALL');
    for k=1:numel(pilot_categories),ix=strcmp({rows.dataset},'pilot')&strcmp({rows.category},pilot_categories{k});metrics(end+1)=metric_for(rows(ix),'pilot',pilot_categories{k});end %#ok<AGROW>
    metrics(end+1)=metric_for(rows(strcmp({rows.dataset},'T3_T5')),'T3_T5','ALL');
    for k=1:numel(noise_levels),cat=sprintf('snr_%g_db',noise_levels(k));ix=strcmp({rows.dataset},'T3_T5')&strcmp({rows.category},cat);metrics(end+1)=metric_for(rows(ix),'T3_T5',cat);end %#ok<AGROW>
end
function m=metric_for(x,dataset,category)
    m=metric_row();m.dataset=dataset;m.category=category;m.sample_count=numel(x);
    if isempty(x),return;end
    b={x.baseline_decision_state};e={x.enhanced_decision_state};
    m.baseline_unique_count=nnz(strcmp(b,'UNIQUE'));m.baseline_ambiguous_count=nnz(strcmp(b,'AMBIGUOUS'));m.baseline_rejected_count=nnz(strcmp(b,'REJECTED'));
    m.enhanced_unique_confident_count=nnz(strcmp(e,'UNIQUE_CONFIDENT'));m.enhanced_multiple_ambiguous_count=nnz(strcmp(e,'MULTIPLE_AMBIGUOUS'));
    m.enhanced_low_confidence_count=nnz(strcmp(e,'LOW_CONFIDENCE'));m.enhanced_rejected_count=nnz(strcmp(e,'REJECTED'));
    m.baseline_false_unique_count=nnz([x.baseline_false_unique]);m.enhanced_false_unique_count=nnz([x.enhanced_false_unique]);
    m.false_unique_reduction=m.baseline_false_unique_count-m.enhanced_false_unique_count;
    m.baseline_ambiguity_detection_count=m.baseline_ambiguous_count;
    m.enhanced_ambiguity_detection_count=nnz([x.enhanced_ambiguity_detected]);
    m.ambiguity_detection_gain=m.enhanced_ambiguity_detection_count-m.baseline_ambiguity_detection_count;
end

function summary=build_summary(mode,rows,model,runtime_s,candidate_count,n_pilot,n_non)
    b={rows.baseline_decision_state};e={rows.enhanced_decision_state};
    summary=struct('stage_name','Stage 5B.1','mode',mode,'status',[mode '_completed'], ...
        'candidate_count',candidate_count,'pilot_sample_count',n_pilot,'nonunique_sample_count',n_non, ...
        'baseline_unique_count',nnz(strcmp(b,'UNIQUE')),'baseline_ambiguous_count',nnz(strcmp(b,'AMBIGUOUS')), ...
        'baseline_rejected_count',nnz(strcmp(b,'REJECTED')),'enhanced_unique_confident_count',nnz(strcmp(e,'UNIQUE_CONFIDENT')), ...
        'enhanced_multiple_ambiguous_count',nnz(strcmp(e,'MULTIPLE_AMBIGUOUS')), ...
        'enhanced_low_confidence_count',nnz(strcmp(e,'LOW_CONFIDENCE')),'enhanced_rejected_count',nnz(strcmp(e,'REJECTED')), ...
        'baseline_false_unique_count',nnz([rows.baseline_false_unique]),'enhanced_false_unique_count',nnz([rows.enhanced_false_unique]), ...
        'beta',model.beta,'margin_threshold',model.margin_threshold,'top1_confidence_threshold',model.top1_confidence_threshold, ...
        'normalized_entropy_threshold',model.normalized_entropy_threshold,'evidence_calibration_hash',model.calibration_hash, ...
        'use_parallel',false,'worker_count',1,'runtime_s',runtime_s);
end
function r=calibration_row(m,topology_model,domain_model)
    r=struct('definition_version',m.definition_version,'calibration_sample_count',m.calibration_sample_count, ...
        'reference_sample_count',m.reference_sample_count,'reference_definition',m.reference_definition, ...
        'margin_quantile',m.margin_quantile,'margin_threshold',m.margin_threshold, ...
        'temperature_target_odds',m.temperature_target_odds,'reference_median_margin',m.reference_median_margin,'beta',m.beta, ...
        'confidence_quantile',m.confidence_quantile,'top1_confidence_threshold',m.top1_confidence_threshold, ...
        'entropy_quantile',m.entropy_quantile,'normalized_entropy_threshold',m.normalized_entropy_threshold, ...
        'pilot_used_for_calibration',m.pilot_used_for_calibration,'evidence_calibration_hash',m.calibration_hash, ...
        'frozen_topology_calibration_hash',topology_model.calibration_hash,'frozen_rule_a_calibration_hash',domain_model.calibration_hash);
end

function m=scalar_margin(x),m=struct('margin',x.margin(1));end
function c=scalar_confidence(x),c=struct('top1_confidence',x.top1_confidence(1),'normalized_entropy',x.normalized_entropy(1));end
function theta=theta_in_domain(rs),theta=struct('main_length_scale',.95+.10*rand(rs),'branch_length_scale',.95+.10*rand(rs),'branch_load_scale',.8+.4*rand(rs),'source_impedance_ohm',45+10*rand(rs),'receiver_impedance_ohm',45+10*rand(rs),'regularization',0);end
function v=category_value(category,rs,p)
    switch category
        case 'in_domain',v=p.lower+(p.upper-p.lower)*rand(rs);
        case 'exact_lower_boundary',v=p.lower;case 'exact_upper_boundary',v=p.upper;
        case 'near_lower_ood',v=p.near_lower;case 'near_upper_ood',v=p.near_upper;
        case 'medium_lower_ood',v=p.medium_lower;case 'medium_upper_ood',v=p.medium_upper;
        case 'far_lower_ood',v=p.far_lower;case 'far_upper_ood',v=p.far_upper;
        otherwise,error('stage5b1:UnknownCategory','Unknown category %s.',category);
    end
end
function y=add_noise_base(x,snr,z),if isinf(snr),y=x;else,s=sqrt(mean(abs(x).^2)/10^(snr/10)/2);y=x+s*z;end,end
function id=getid(c),if isfield(c,'topology_id')&&~isempty(c.topology_id),id=char(c.topology_id);else,id=char(c.graph_candidate_id);end,end
function map=make_row_map(ids),keys=cellstr(ids);map=containers.Map(keys,num2cell(1:numel(keys)));end
function ensure_dir(p),if exist(p,'dir')~=7,mkdir(p);end,end
function r=margin_row(),r=struct('sample','','best_candidate','','second_candidate','','d1',NaN,'d2',NaN,'margin',NaN,'dataset','','category','');end
function r=confidence_row(),r=struct('sample','','candidate','','distance',NaN,'normalized_confidence_score',NaN,'rank',0,'top1_confidence',NaN,'entropy',NaN,'normalized_entropy',NaN,'beta',NaN,'candidate_count',0,'dataset','','category','','probability_semantics','');end
function r=decision_row(),r=struct('sample','','dataset','','category','','truth_topology','','truth_equivalence_set','','best_candidate','','second_candidate','','d1',NaN,'d2',NaN,'margin',NaN,'top1_confidence',NaN,'entropy',NaN,'normalized_entropy',NaN,'frozen_candidate_set','','frozen_candidate_set_size',0,'domain_accepted',false,'baseline_decision_state','','enhanced_decision_state','','decision_reason','','margin_pass',false,'confidence_pass',false,'entropy_pass',false,'evidence_sufficient',false,'baseline_false_unique',false,'enhanced_false_unique',false,'enhanced_ambiguity_detected',false);end
function r=metric_row(),r=struct('dataset','','category','','sample_count',0,'baseline_unique_count',0,'baseline_ambiguous_count',0,'baseline_rejected_count',0,'enhanced_unique_confident_count',0,'enhanced_multiple_ambiguous_count',0,'enhanced_low_confidence_count',0,'enhanced_rejected_count',0,'baseline_false_unique_count',0,'enhanced_false_unique_count',0,'false_unique_reduction',0,'baseline_ambiguity_detection_count',0,'enhanced_ambiguity_detection_count',0,'ambiguity_detection_gain',0);end
