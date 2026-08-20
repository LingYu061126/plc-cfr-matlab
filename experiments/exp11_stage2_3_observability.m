function output = exp11_stage2_3_observability(cfg, run_mode)
%EXP11_STAGE2_3_OBSERVABILITY Equivalence, fairness and minimal-view audit.
%   Uses the complete-tree nodal model only.  The OFDM operation remains a
%   frequency-domain all-pilot LS measurement Y=X.*H+N; it is not a modem.
%   run_mode is 'formal' (100 independent packages) or 'smoke' (5).

    if nargin < 1 || isempty(cfg)
        cfg=default_config(fileparts(fileparts(mfilename('fullpath'))));
    end
    if nargin < 2 || isempty(run_mode), run_mode='formal'; end
    sc=cfg.stage2_3;
    if strcmpi(run_mode,'smoke'), trial_count=sc.smoke_trials; else, trial_count=sc.formal_trials; end
    ensure_result_dirs(cfg); tic_total=tic;
    f=cfg.ofdm.pilot_frequency_hz; pilot=ofdm_generate_pilot(cfg.ofdm);
    all_candidates=topology_candidates(cfg); candidates=all_candidates(sc.candidate_indices);
    kinds=sc.measurement_kinds; feature_options=struct('phase_mask_threshold_db',sc.phase_mask_threshold_db);
    condition_names={'noise_only','length','load','endpoint','joint'};
    records=repmat(empty_record(),0,1); pairwise=repmat(empty_pair(),0,1);
    config_rows=repmat(empty_config(),0,1); caches=cell(1,numel(kinds)); audits=cell(1,numel(kinds));

    for q=1:numel(kinds)
        kind=kinds{q}; theta0=base_theta(kind,sc);
        refs=reference_bundle(f,candidates,theta0,kind,cfg);
        audit=topology_observability_classes(refs,candidates,cfg.ofdm,sc.tie_tolerance);
        audits{q}=audit;
        config_rows(end+1)=config_row(kind,theta0,audit,refs); %#ok<AGROW>
        pairwise=[pairwise; make_pairs(kind,candidates,audit)]; %#ok<AGROW>
        % Joint libraries use the same measurement kind and a local endpoint
        % grid around the declared physical endpoint impedances.
        local_search=local_search_grid(sc.search,theta0);
        library=topology_parameter_library(f,candidates, ...
            topology_parameter_grid(local_search),kind,cfg);
        caches{q}=topology_prepare_parameter_library(library);
        fprintf('EXP11 prepared %s: views=%d templates=%d classes=%d\n', ...
            kind,audit.view_count,numel(library),numel(audit.class_sizes));

        for c=1:numel(condition_names)
            condition=condition_names{c};
            snrs=sc.parameter_snr_db;
            if strcmp(condition,'noise_only'), snrs=sc.snr_db; end
            for snr=snrs
                for trial=1:trial_count
                    trial_id=trial+get_option(sc,'trial_offset',0);
                    theta=true_theta(theta0,condition,sc,trial_id,q,snr);
                    % Endpoint perturbation intentionally changes the physical
                    % configuration. For symmetric SISO it may split T3/T5,
                    % so do not retain the nominal mirror class in that case.
                    sample_audit=audit;
                    if ismember(condition,{'endpoint','joint'}) && strcmp(kind,'siso_forward')
                        sample_audit=asymmetric_class_audit(f,candidates,theta,cfg,sc);
                    end
                    for truth=1:numel(candidates)
                        true_views=reference_bundle(f,candidates(truth),theta,kind,cfg);
                        [observed, estimate] = noisy_ls_views(true_views,pilot, ...
                            snr, seed_for(sc, q,c,trial_id,truth,snr));
                        estimate_metrics=mean_estimation_metrics(estimate,true_views,feature_options);
                        for fi=1:numel(sc.features)
                            feature=sc.features{fi}; tm=tic;
                            match=topology_equivalence_match(observed,refs,candidates, ...
                                sample_audit,feature,cfg.ofdm,sc.joint_weights,feature_options);
                            records(end+1)=record_from_match(kind,condition,snr,trial_id,truth, ...
                                'nominal_nearest',feature,match,candidates,sample_audit, ...
                                estimate_metrics,toc(tm)); %#ok<AGROW>
                        end
                        % Fair comparison: both methods use the same declared
                        % joint feature, views, noise realization and candidate set.
                        % The grid method is evaluated at 20 dB (noise-only)
                        % and all four nuisance conditions; other SNR rows are
                        % feature-ablation rows, not an unfair algorithm claim.
                        if (~strcmp(condition,'noise_only') || snr==sc.parameter_snr_db)
                            tm=tic; jm=topology_joint_match(observed,caches{q}, ...
                                sc.fair_feature,cfg.ofdm,sc.joint_weights, ...
                                sc.regularization_lambda,feature_options);
                            match=joint_as_equivalence_match(jm,candidates,sample_audit);
                            records(end+1)=record_from_match(kind,condition,snr,trial_id,truth, ...
                                'nuisance_aware_joint',sc.fair_feature,match,candidates, ...
                                sample_audit,estimate_metrics,toc(tm)); %#ok<AGROW>
                        end
                    end
                end
            end
        end
        caches{q}=[]; %#ok<NASGU> % release one large matrix cache before the next view kind
    end
    summary=summarize_records(records,candidates);
    confusion=make_confusion(records,candidates);
    write_outputs(cfg,sc,pairwise,summary,confusion,config_rows,records, ...
        audits,candidates,run_mode,toc(tic_total));
    output=struct('pairwise',pairwise,'summary',summary,'confusion',confusion, ...
        'records',records,'config',config_rows,'elapsed_s',toc(tic_total), ...
        'run_mode',run_mode);
    fprintf('EXP11 stage 2.3 %s completed in %.3f s; evaluation rows=%d.\n', ...
        run_mode,output.elapsed_s,numel(records));
end

function theta=base_theta(kind,sc)
    theta=struct('main_length_scale',1,'branch_length_scale',1, ...
        'branch_load_scale',1,'kG_scale',1,'source_impedance_ohm',50, ...
        'receiver_impedance_ohm',50);
    if ismember(kind,{'siso_forward_asymmetric','siso_reverse_role_fixed', ...
            'siso_reverse_endpoint_fixed','bidirectional_endpoint_fixed'})
        theta.source_impedance_ohm=sc.asymmetric_Zs;
        theta.receiver_impedance_ohm=sc.asymmetric_Zr;
    end
    if strcmp(kind,'siso_forward_asymmetric')
        theta.source_impedance_ohm=sc.asymmetric_Zs;
        theta.receiver_impedance_ohm=sc.asymmetric_Zr;
    end
end
function refs=reference_bundle(f,candidates,theta,kind,cfg)
    if numel(candidates)==1
        [network,cfg_local]=topology_apply_parameters(candidates.network,cfg,theta);
        m=plc_measurement_bundle(kind,network,theta,cfg_local);
        refs=plc_multiview_response(f,network,m,cfg_local);
    else
        refs=cell(1,numel(candidates));
        for k=1:numel(candidates),refs{k}=reference_bundle(f,candidates(k),theta,kind,cfg);end
    end
end
function search=local_search_grid(search,theta)
    search.source_impedance_ohm=theta.source_impedance_ohm+[-5 0 5];
    search.receiver_impedance_ohm=theta.receiver_impedance_ohm+[-5 0 5];
    search.nominal_source_impedance_ohm=theta.source_impedance_ohm;
    search.nominal_receiver_impedance_ohm=theta.receiver_impedance_ohm;
end
function audit=asymmetric_class_audit(f,candidates,theta,cfg,sc)
    % Any unequal endpoint pair breaks the exact mirror under this model.
    refs=reference_bundle(f,candidates,theta,'siso_forward',cfg);
    audit=topology_observability_classes(refs,candidates,cfg.ofdm,sc.tie_tolerance);
end
function theta=true_theta(base,condition,sc,trial,q,snr)
    old=rng;cleanup=onCleanup(@()rng(old));rng(seed_for(sc,q,condition,trial,0,snr),'twister');
    theta=base;
    if ismember(condition,{'length','joint'})
        theta.main_length_scale=uniform(sc.length_scale_range);
        theta.branch_length_scale=uniform(sc.length_scale_range);
    end
    if ismember(condition,{'load','joint'}),theta.branch_load_scale=uniform(sc.load_scale_range);end
    if ismember(condition,{'endpoint','joint'})
        theta.source_impedance_ohm=uniform(base.source_impedance_ohm+[-5,5]);
        theta.receiver_impedance_ohm=uniform(base.receiver_impedance_ohm+[-5,5]);
    end
    if strcmp(condition,'joint'),theta.kG_scale=uniform(sc.kG_scale_range);end
end
function value=uniform(bounds),value=bounds(1)+(bounds(2)-bounds(1))*rand;end
function seed=seed_for(sc,a,b,c,d,e)
    if ischar(b), b=sum(double(b)); end
    seed=mod(double(20260819)+100000*a+1000*b+100*c+10*d+round(e+100),2^31-2)+1;
end
function [observed,metrics]=noisy_ls_views(true_views,pilot,snr,seed)
    observed=cell(1,numel(true_views));metrics=cell(1,numel(true_views));
    for v=1:numel(true_views)
        [Y,~,~]=ofdm_apply_channel(pilot.X,true_views{v},snr,seed+v, ...
            'fixed_received_snr');
        observed{v}=ofdm_channel_estimate_ls(pilot.X,Y);
        metrics{v}=cfr_estimation_metrics(observed{v},true_views{v});
    end
end
function m=mean_estimation_metrics(items,~,~)
    names={'nmse','amplitude_rmse_db','raw_phase_rmse_deg', ...
        'weighted_phase_rmse_deg','valid_phase_fraction'};m=struct();
    for k=1:numel(names),x=cellfun(@(z)z.(names{k}),items);m.(names{k})=mean(x);end
end
function match=joint_as_equivalence_match(joint,candidates,audit)
    scores=Inf(1,numel(candidates));
    for k=1:numel(candidates)
        scores(k)=min(joint.scores(joint.template_topology_indices==k));
    end
    [best,index]=min(scores);ordered=sort(scores);
    match=struct('predicted_index',index,'scores',scores,'best_distance',best, ...
        'second_best_distance',ordered(2),'distance_gap',ordered(2)-best, ...
        'ambiguous',sum(scores<=best+audit.tie_tolerance*max(1,best))>1);
end
function row=record_from_match(kind,condition,snr,trial,truth,method,feature, ...
        match,candidates,audit,est,elapsed)
    truth_class=audit.class_index(truth);pred_class=audit.class_index(match.predicted_index);
    nonunique=audit.class_sizes(truth_class)>1;
    own=audit.class_index==truth_class;intra=min(match.scores(own));other=match.scores;other(own)=Inf;inter=min(other);
    row=empty_record();row.measurement_kind=kind;row.condition=condition;row.snr_db=snr;
    row.trial=trial;row.true_id=candidates(truth).id;row.predicted_id=candidates(match.predicted_index).id;
    row.method=method;row.feature=feature;row.true_class=audit.class_labels{truth};
    row.predicted_class=audit.class_labels{match.predicted_index};row.strict_correct=truth==match.predicted_index;
    row.class_correct=truth_class==pred_class;row.unique_strict_correct=row.strict_correct && ...
        ~match.ambiguous && audit.class_sizes(pred_class)==1;row.ambiguous=match.ambiguous;
    row.false_unique=nonunique && ~match.ambiguous;row.best_distance=match.best_distance;
    row.second_best_distance=match.second_best_distance;row.distance_margin=match.distance_gap;
    row.class_intra_distance=intra;row.nearest_class_inter_distance=inter;
    row.intra_inter_ratio=intra/inter;row.nmse=est.nmse;row.amplitude_rmse_db=est.amplitude_rmse_db;
    row.raw_phase_rmse_deg=est.raw_phase_rmse_deg;row.weighted_phase_rmse_deg=est.weighted_phase_rmse_deg;
    row.valid_phase_fraction=est.valid_phase_fraction;
    if isfield(match,'view_count'), row.view_count=match.view_count; else, row.view_count=NaN; end
    row.runtime_s=elapsed;
end
function summary=summarize_records(records,candidates)
    key=cell(numel(records),1);for k=1:numel(records),key{k}=sprintf('%s|%s|%g|%s|%s',records(k).measurement_kind,records(k).condition,records(k).snr_db,records(k).method,records(k).feature);end
    groups=unique(key,'stable');summary=repmat(empty_summary(),0,1);
    for g=1:numel(groups)
        x=records(strcmp(key,groups{g}));row=empty_summary();row.measurement_kind=x(1).measurement_kind;row.condition=x(1).condition;row.snr_db=x(1).snr_db;row.method=x(1).method;row.feature=x(1).feature;row.sample_count=numel(x);row.trials=numel(unique([x.trial]));
        row.strict_accuracy=mean([x.strict_correct]);row.equivalence_class_accuracy=mean([x.class_correct]);row.unique_strict_accuracy=mean([x.unique_strict_correct]);row.ambiguity_rate=mean([x.ambiguous]);row.false_unique_rate=mean([x.false_unique]);
        [row.accuracy_std,row.ci_low,row.ci_high]=trial_ci(x);row.mean_margin=mean([x.distance_margin]);row.mean_intra=mean([x.class_intra_distance]);row.mean_inter=mean([x.nearest_class_inter_distance]);row.intra_inter_ratio=row.mean_intra/row.mean_inter;
        row.nmse=mean([x.nmse]);row.amplitude_rmse_db=mean([x.amplitude_rmse_db]);row.raw_phase_rmse_deg=mean([x.raw_phase_rmse_deg]);row.weighted_phase_rmse_deg=mean([x.weighted_phase_rmse_deg]);row.valid_phase_fraction=mean([x.valid_phase_fraction]);row.runtime_s=mean([x.runtime_s]);
        truth=cellfun(@(z)find(strcmp({candidates.id},z),1),{x.true_id});pred=cellfun(@(z)find(strcmp({candidates.id},z),1),{x.predicted_id});em=topology_evaluation_metrics(truth,pred,candidates,[x.ambiguous]);row.edge_precision=em.edge_micro.precision;row.edge_recall=em.edge_micro.recall;row.edge_f1=em.edge_micro.f1;summary(end+1)=row; %#ok<AGROW>
    end
end
function [s,lo,hi]=trial_ci(x)
    trials=unique([x.trial]);a=zeros(size(trials));for k=1:numel(trials),a(k)=mean([x([x.trial]==trials(k)).strict_correct]);end;s=std(a,0);half=1.96*s/sqrt(numel(a));lo=max(0,mean(a)-half);hi=min(1,mean(a)+half);
end
function rows=make_pairs(kind,candidates,audit)
    rows=repmat(empty_pair(),0,1);for i=1:numel(candidates),for j=i+1:numel(candidates),r=empty_pair();r.measurement_kind=kind;r.topology_i=candidates(i).id;r.topology_j=candidates(j).id;r.complex_distance=audit.pairwise_complex_distance(i,j);r.complex_distance_raw=audit.pairwise_complex_distance_raw(i,j);r.same_equivalence_class=audit.class_index(i)==audit.class_index(j);r.class_i=audit.class_labels{i};r.class_j=audit.class_labels{j};r.view_count=audit.view_count;r.tie_tolerance=audit.tie_tolerance;rows(end+1)=r;end,end
end
function r=config_row(kind,theta,audit,refs)
    r=empty_config();r.measurement_kind=kind;r.source_impedance_ohm=theta.source_impedance_ohm;r.receiver_impedance_ohm=theta.receiver_impedance_ohm;r.view_count=numel(refs{1});r.internal_receiver_count=double(ismember(kind,{'dual_receiver_complete','three_view_complete'}));r.receiver_load_perturbs_network=r.internal_receiver_count>0;r.structural_group_count=audit.structural_indistinguishable_group_count;r.tie_tolerance=audit.tie_tolerance;
end
function confusion=make_confusion(records,candidates)
    pick=strcmp({records.feature},'amp_phase_joint_weighted');x=records(pick);
    key=cell(1,numel(x));for k=1:numel(x),key{k}=sprintf('%s|%s|%g|%s',x(k).measurement_kind,x(k).condition,x(k).snr_db,x(k).method);end
    keys=unique(key,'stable');confusion=repmat(struct('measurement_kind','','condition','','snr_db',0,'method','','true_id','','predicted_id','','count',0),0,1);
    for g=1:numel(keys)
        z=x(strcmp(key,keys{g}));
        for i=1:numel(candidates),for j=1:numel(candidates)
            r=struct('measurement_kind',z(1).measurement_kind,'condition',z(1).condition,'snr_db',z(1).snr_db,'method',z(1).method,'true_id',candidates(i).id,'predicted_id',candidates(j).id,'count',sum(strcmp({z.true_id},candidates(i).id)&strcmp({z.predicted_id},candidates(j).id)));confusion(end+1)=r; %#ok<AGROW>
        end,end
    end
end
function write_outputs(cfg,sc,pairwise,summary,confusion,config,records,audits,candidates,mode,elapsed)
    prefix=get_option(sc,'output_prefix','stage2_3');
    writetable(stage2_3_struct_table(pairwise,{'measurement_kind','topology_i','topology_j','complex_distance','complex_distance_raw','same_equivalence_class','class_i','class_j','view_count','tie_tolerance'}),fullfile(cfg.results_data,[prefix '_pairwise_distance.csv']));writetable(struct2table(summary),fullfile(cfg.results_data,[prefix '_summary.csv']));writetable(struct2table(confusion),fullfile(cfg.results_data,[prefix '_confusion.csv']));writetable(struct2table(config),fullfile(cfg.results_data,[prefix '_config.csv']));writetable(struct2table(records),fullfile(cfg.results_data,[prefix '_trials.csv']));
    save(fullfile(cfg.results_data,[prefix '_results.mat']),'sc','pairwise','summary','confusion','config','records','audits','candidates','mode','elapsed','-v7.3');
    if strcmp(prefix,'stage2_3'), make_figures(cfg,pairwise,summary,config); end
end
function value=get_option(s,name,default_value),if isfield(s,name)&&~isempty(s.(name)),value=s.(name);else,value=default_value;end,end
function make_figures(cfg,pairwise,summary,config)
    kinds={config.measurement_kind};figure('Visible','off','Position',[100 100 1400 800]);tiledlayout(2,4,'Padding','compact');for k=1:numel(kinds),nexttile;z=pairwise(strcmp({pairwise.measurement_kind},kinds{k}));ids=unique([{z.topology_i},{z.topology_j}],'stable');M=zeros(numel(ids));for q=1:numel(z),i=find(strcmp(ids,z(q).topology_i));j=find(strcmp(ids,z(q).topology_j));M(i,j)=z(q).complex_distance;M(j,i)=M(i,j);end;imagesc(M);axis image;colorbar;set(gca,'XTick',1:numel(ids),'XTickLabel',ids,'YTick',1:numel(ids),'YTickLabel',ids);title(strrep(kinds{k},'_',' '));end;sgtitle('Full-complex CFR pairwise distances: complete-network measurement configurations');print(gcf,fullfile(cfg.results_figures,'stage2_3_observability_matrix.png'),'-dpng','-r150');close(gcf);
    figure('Visible','off','Position',[100 100 1200 600]);sel=strcmp({summary.condition},'noise_only')&[summary.snr_db]==20&strcmp({summary.feature},'amp_phase_joint_weighted')&strcmp({summary.method},'nominal_nearest');z=summary(sel);bar([z.strict_accuracy;z.equivalence_class_accuracy;z.unique_strict_accuracy]');grid on;set(gca,'XTickLabel',strrep({z.measurement_kind},'_',' '),'XTickLabelRotation',25);legend('strict','equivalence class','unique strict','Location','best');ylabel('Accuracy');title('20 dB fixed-received-SNR: measurement configuration comparison');print(gcf,fullfile(cfg.results_figures,'stage2_3_measurement_comparison.png'),'-dpng','-r150');close(gcf);
    figure('Visible','off','Position',[100 100 1200 600]);sel=strcmp({summary.feature},'amp_phase_joint_weighted')&[summary.snr_db]==20&ismember({summary.method},{'nominal_nearest','nuisance_aware_joint'})&ismember({summary.condition},{'noise_only','joint'});z=summary(sel);bar([z.strict_accuracy]);grid on;set(gca,'XTick',1:numel(z),'XTickLabel',strrep(strcat({z.measurement_kind},' ',{z.condition},' ',{z.method}),'_',' '),'XTickLabelRotation',55,'FontSize',7);ylabel('Strict accuracy');title('Fair comparison: identical weighted amplitude/phase feature, views and observations');print(gcf,fullfile(cfg.results_figures,'stage2_3_algorithm_fair_comparison.png'),'-dpng','-r150');close(gcf);
end
function r=empty_record(),r=struct('measurement_kind','','condition','','snr_db',0,'trial',0,'true_id','','predicted_id','','method','','feature','','true_class','','predicted_class','','strict_correct',false,'class_correct',false,'unique_strict_correct',false,'ambiguous',false,'false_unique',false,'best_distance',NaN,'second_best_distance',NaN,'distance_margin',NaN,'class_intra_distance',NaN,'nearest_class_inter_distance',NaN,'intra_inter_ratio',NaN,'nmse',NaN,'amplitude_rmse_db',NaN,'raw_phase_rmse_deg',NaN,'weighted_phase_rmse_deg',NaN,'valid_phase_fraction',NaN,'view_count',0,'runtime_s',NaN);end
function r=empty_pair(),r=struct('measurement_kind','','topology_i','','topology_j','','complex_distance',NaN,'complex_distance_raw',NaN,'same_equivalence_class',false,'class_i','','class_j','','view_count',0,'tie_tolerance',NaN);end
function r=empty_config(),r=struct('measurement_kind','','source_impedance_ohm',NaN,'receiver_impedance_ohm',NaN,'view_count',0,'internal_receiver_count',0,'receiver_load_perturbs_network',false,'structural_group_count',0,'tie_tolerance',NaN);end
function r=empty_summary(),r=struct('measurement_kind','','condition','','snr_db',0,'method','','feature','','sample_count',0,'trials',0,'strict_accuracy',NaN,'equivalence_class_accuracy',NaN,'unique_strict_accuracy',NaN,'ambiguity_rate',NaN,'false_unique_rate',NaN,'accuracy_std',NaN,'ci_low',NaN,'ci_high',NaN,'mean_margin',NaN,'mean_intra',NaN,'mean_inter',NaN,'intra_inter_ratio',NaN,'nmse',NaN,'amplitude_rmse_db',NaN,'raw_phase_rmse_deg',NaN,'weighted_phase_rmse_deg',NaN,'valid_phase_fraction',NaN,'runtime_s',NaN,'edge_precision',NaN,'edge_recall',NaN,'edge_f1',NaN);end
