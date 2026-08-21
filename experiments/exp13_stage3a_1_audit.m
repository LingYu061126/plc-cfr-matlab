function result = exp13_stage3a_1_audit(root,trial_override)
%EXP13_STAGE3A_1_AUDIT Expanded fixed-seed Stage-3A.1 audit.
%   Scans SNR=[5 10 15 20 30] dB, pilot spacing=[1 2 4 8], the four
%   original Stage-3A observation kinds, and four features. Each
%   SNR/spacing/observation/topology condition has 50 independent trials.
%   The physical reference CFR is computed once per topology and view; the
%   independent randomness is in the equivalent OFDM measurement chain.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));
    s3=stage3a_config(root);base=s3.base_config;ensure_result_dirs(base);
    if nargin>=2 && ~isempty(trial_override)
        if ~(isscalar(trial_override)&&isfinite(trial_override)&&trial_override>=1&&trial_override==fix(trial_override))
            error('exp13_stage3a_1_audit:InvalidTrialOverride','trial_override must be a positive integer.');
        end
        s3.audit_trials_per_condition=trial_override;
    end
    rng(s3.random_seed+31000,'twister');started=tic;
    candidates_all=topology_candidates(base);candidates=candidates_all(s3.candidate_indices);
    f=s3.ofdm.active_frequency_hz(:).';full_cfg=s3.ofdm;
    full_cfg.pilot_bin_1based=s3.ofdm.active_bin_1based;full_cfg.pilot_frequency_hz=f;full_cfg.num_pilots=numel(f);
    kinds=s3.measurement_kinds;features=s3.features;
    refs=cell(1,numel(kinds));audits=cell(size(refs));
    nominal=nominal_theta(base);
    for k=1:numel(kinds)
        refs{k}=cell(1,numel(candidates));
        for t=1:numel(candidates),[refs{k}{t},~]=stage3a_compute_observations(f,candidates(t),base,nominal,kinds{k});end
        audits{k}=topology_observability_classes(refs{k},candidates,full_cfg,s3.tie_tolerance);
    end
    records=repmat(empty_record(),0,1);example=struct();case_id=0;
    for si=1:numel(s3.audit_snr_db)
        snr=s3.audit_snr_db(si);
        for pi=1:numel(s3.audit_pilot_spacings)
            spacing=s3.audit_pilot_spacings(pi);input_mode='ofdm_sparse_interp';
            if spacing==1,input_mode='ofdm_dense_ls';end
            for ki=1:numel(kinds)
                case_id=case_id+1;kind=kinds{ki};audit=audits{ki};
                for truth=1:numel(candidates)
                    measured=refs{ki}{truth};
                    for tr=1:s3.audit_trials_per_condition
                        observed=cell(1,numel(measured));
                        for v=1:numel(measured)
                            seed=s3.random_seed+case_id*1000000+truth*10000+tr*100+v;
                            sym=stage3a_generate_symbol(s3.ofdm,spacing,seed);
                            ncfg=struct('kind',s3.audit_noise_kind,'snr_db',snr);
                            [rx,~]=stage3a_apply_ofdm_channel(sym,measured{v},s3.ofdm,ncfg,struct(),seed);
                            [~,observed{v},~]=stage3a_receive_ofdm(rx,sym,s3.ofdm,struct());
                        end
                        cfr_metrics=cell(1,numel(measured));true_delays=zeros(1,numel(measured));hat_delays=true_delays;
                        for v=1:numel(measured)
                            cfr_metrics{v}=cfr_estimation_metrics(observed{v},measured{v});
                            [true_delays(v),~]=stage3a_toa_feature(measured{v},full_cfg);
                            [hat_delays(v),~]=stage3a_toa_feature(observed{v},full_cfg);
                        end
                        for fi=1:numel(features)
                            feature=features{fi};
                            if strcmp(feature,'toa')
                                match=stage3a_match_toa(observed,refs{ki},full_cfg,audit.class_labels,s3.tie_tolerance);
                            else
                                match=topology_equivalence_match(observed,refs{ki},candidates,audit,feature,full_cfg,[.5,.5], ...
                                    struct('phase_mask_threshold_db',-40));
                            end
                            pred=match.predicted_index;truth_class=audit.class_index(truth);pred_class=audit.class_index(pred);
                            physical=audit.class_sizes(truth_class)>1;amb=logical(match.ambiguous);strict=pred==truth;
                            class_ok=pred_class==truth_class;unique_ok=~amb&&~(audit.class_sizes(pred_class)>1);
                            em=topology_evaluation_metrics(truth,pred,candidates,amb);
                            rec=empty_record();rec.mode='audit';rec.snr_db=snr;rec.pilot_spacing=spacing;rec.input_mode=input_mode;
                            rec.measurement_kind=kind;rec.observation_mode=stage3a_observation_config(kind).O;rec.feature=feature;rec.trial=tr;
                            rec.true_id=candidates(truth).id;rec.predicted_id=candidates(pred).id;rec.true_class=audit.class_labels{truth};rec.predicted_class=audit.class_labels{pred};
                            rec.strict_correct=strict;rec.class_correct=class_ok;rec.strict_unique_correct=strict&&unique_ok;rec.unique_identification=unique_ok;
                            rec.physically_ambiguous_class=physical;rec.ambiguous=amb;rec.false_unique=physical&&~amb;
                            rec.best_distance=match.best_distance;rec.second_best_distance=match.second_best_distance;rec.distance_margin=match.distance_gap;
                            rec.cfr_nmse=mean(cellfun(@(x)x.nmse,cfr_metrics));rec.amplitude_rmse_db=mean(cellfun(@(x)x.amplitude_rmse_db,cfr_metrics));
                            rec.weighted_phase_rmse_deg=mean(cellfun(@(x)x.weighted_phase_rmse_deg,cfr_metrics));
                            rec.circular_delay_error_s=mean(circular_delay_error(hat_delays,true_delays,1/s3.ofdm.sample_rate_hz));
                            rec.view_count=numel(measured);rec.frequency_count=numel(f);rec.edge_precision=em.edge_micro.precision;rec.edge_recall=em.edge_micro.recall;rec.edge_f1=em.edge_micro.f1;
                            rec.seed=s3.random_seed+case_id*1000000+truth*10000+tr;rec.runtime_s=toc(started);records(end+1)=rec; %#ok<AGROW>
                            if isempty(fieldnames(example))
                                example=struct('frequency_hz',f,'H_true_views',{measured},'H_hat_views',{observed},'snr_db',snr, ...
                                    'pilot_spacing',spacing,'measurement_kind',kind,'true_id',candidates(truth).id,'trial',tr,'seed',rec.seed);
                            end
                        end
                    end
                end
            end
        end
    end
    prefix='stage3a_1_audit';summary=summarize(records);confusion=make_confusion(records);config_rows=make_config_rows(s3,kinds);
    writetable(struct2table(records),fullfile(base.results_data,[prefix '_trial_metrics.csv']));
    writetable(struct2table(summary),fullfile(base.results_data,[prefix '_summary.csv']));
    writetable(struct2table(confusion),fullfile(base.results_data,[prefix '_confusion.csv']));
    writetable(struct2table(config_rows),fullfile(base.results_data,[prefix '_config.csv']));
    save(fullfile(base.results_data,[prefix '_raw.mat']),'summary','confusion','config_rows','example','-v7');
    write_example(example,base,prefix);make_figures(summary,base,prefix);
    result=struct('mode','audit','trial_rows',numel(records),'summary_rows',numel(summary),'confusion_rows',numel(confusion), ...
        'elapsed_s',toc(started),'trials_per_condition',s3.audit_trials_per_condition);
    fprintf('EXP13 Stage 3A.1 audit completed: trials=%d summaries=%d confusion=%d elapsed=%.3f s\n', ...
        numel(records),numel(summary),numel(confusion),result.elapsed_s);
end

function t=nominal_theta(base)
t=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1,'kG_scale',1,'source_impedance_ohm',base.Zs, ...
    'receiver_impedance_ohm',base.Zr,'R_scale',1,'L_scale',1,'G_scale',1,'C_scale',1,'coupler_gain',1);
end
function e=circular_delay_error(a,b,period),d=abs(a-b);e=min(d,period-d);end

function r=empty_record()
r=struct('mode','','snr_db',0,'pilot_spacing',1,'input_mode','','measurement_kind','','observation_mode','','feature','','trial',0, ...
    'true_id','','predicted_id','','true_class','','predicted_class','','strict_correct',false,'class_correct',false,'strict_unique_correct',false, ...
    'unique_identification',false,'physically_ambiguous_class',false,'ambiguous',false,'false_unique',false,'best_distance',NaN,'second_best_distance',NaN, ...
    'distance_margin',NaN,'cfr_nmse',NaN,'amplitude_rmse_db',NaN,'weighted_phase_rmse_deg',NaN,'circular_delay_error_s',NaN,'view_count',0,'frequency_count',0, ...
    'edge_precision',NaN,'edge_recall',NaN,'edge_f1',NaN,'seed',0,'runtime_s',NaN);
end

function rows=summarize(records)
keys=arrayfun(@(x)sprintf('%g|%d|%s|%s',x.snr_db,x.pilot_spacing,x.measurement_kind,x.feature),records,'UniformOutput',false);
groups=unique(keys,'stable');rows=repmat(empty_summary(),0,1);
for g=1:numel(groups)
    x=records(strcmp(keys,groups{g}));r=empty_summary();r.mode='audit';r.snr_db=x(1).snr_db;r.pilot_spacing=x(1).pilot_spacing;r.input_mode=x(1).input_mode;
    r.measurement_kind=x(1).measurement_kind;r.observation_mode=x(1).observation_mode;r.feature=x(1).feature;r.trials=numel(x);
    r.strict_accuracy=mean([x.strict_correct]);r.strict_accuracy_std=std(double([x.strict_correct]),0,2);r.strict_accuracy_ci95=1.96*r.strict_accuracy_std/sqrt(r.trials);
    r.strict_unique_rate=mean([x.strict_unique_correct]);r.strict_unique_rate_std=std(double([x.strict_unique_correct]),0,2);r.strict_unique_ci95=1.96*r.strict_unique_rate_std/sqrt(r.trials);
    r.equivalence_class_rate=mean([x.class_correct]);r.ambiguity_rate=mean([x.ambiguous]);r.false_unique_rate=mean([x.false_unique]);
    r.physically_ambiguous_class_rate=mean([x.physically_ambiguous_class]);r.cfr_nmse=mean([x.cfr_nmse]);r.cfr_nmse_std=std([x.cfr_nmse],0,2);r.cfr_nmse_ci95=1.96*r.cfr_nmse_std/sqrt(r.trials);
    r.amplitude_rmse_db=mean([x.amplitude_rmse_db]);r.weighted_phase_rmse_deg=mean([x.weighted_phase_rmse_deg]);r.circular_delay_error_s=mean([x.circular_delay_error_s]);
    r.mean_margin=mean([x.distance_margin]);r.view_count=x(1).view_count;r.frequency_count=x(1).frequency_count;r.edge_precision=mean([x.edge_precision]);r.edge_recall=mean([x.edge_recall]);r.edge_f1=mean([x.edge_f1]);r.runtime_s=mean([x.runtime_s]);rows(end+1)=r; %#ok<AGROW>
end
end
function r=empty_summary()
r=struct('mode','','snr_db',0,'pilot_spacing',1,'input_mode','','measurement_kind','','observation_mode','','feature','','trials',0, ...
    'strict_accuracy',NaN,'strict_accuracy_std',NaN,'strict_accuracy_ci95',NaN,'strict_unique_rate',NaN,'strict_unique_rate_std',NaN,'strict_unique_ci95',NaN, ...
    'equivalence_class_rate',NaN,'ambiguity_rate',NaN,'false_unique_rate',NaN,'physically_ambiguous_class_rate',NaN,'cfr_nmse',NaN,'cfr_nmse_std',NaN,'cfr_nmse_ci95',NaN, ...
    'amplitude_rmse_db',NaN,'weighted_phase_rmse_deg',NaN,'circular_delay_error_s',NaN,'mean_margin',NaN,'view_count',0,'frequency_count',0,'edge_precision',NaN,'edge_recall',NaN,'edge_f1',NaN,'runtime_s',NaN);
end

function rows=make_confusion(records)
rows=repmat(struct('mode','','snr_db',0,'pilot_spacing',1,'measurement_kind','','feature','','true_id','','predicted_id','','count',0),0,1);
for k=1:numel(records)
    x=records(k);hit=find(arrayfun(@(z)z.snr_db==x.snr_db&&z.pilot_spacing==x.pilot_spacing&&strcmp(z.measurement_kind,x.measurement_kind)&&strcmp(z.feature,x.feature)&&strcmp(z.true_id,x.true_id)&&strcmp(z.predicted_id,x.predicted_id),rows),1);
    if isempty(hit),rows(end+1)=struct('mode','audit','snr_db',x.snr_db,'pilot_spacing',x.pilot_spacing,'measurement_kind',x.measurement_kind,'feature',x.feature,'true_id',x.true_id,'predicted_id',x.predicted_id,'count',1); %#ok<AGROW>
    else,rows(hit).count=rows(hit).count+1;end
end
end

function rows=make_config_rows(s3,kinds)
rows=repmat(struct('mode','','snr_db',0,'pilot_spacing',1,'input_mode','','measurement_kind','','feature_count',0,'trials_per_topology',0,'nfft',0,'sample_rate_hz',0,'cyclic_prefix_samples',0,'frequency_start_hz',0,'frequency_end_hz',0,'frequency_count',0,'random_seed',0,'noise_kind',''),0,1);
for snr=s3.audit_snr_db
    for spacing=s3.audit_pilot_spacings
        inp='ofdm_sparse_interp';if spacing==1,inp='ofdm_dense_ls';end
        for k=1:numel(kinds)
            rows(end+1)=struct('mode','audit','snr_db',snr,'pilot_spacing',spacing,'input_mode',inp,'measurement_kind',kinds{k},'feature_count',numel(s3.features), ...
                'trials_per_topology',s3.audit_trials_per_condition,'nfft',s3.ofdm.nfft,'sample_rate_hz',s3.ofdm.sample_rate_hz,'cyclic_prefix_samples',s3.ofdm.cyclic_prefix_samples, ...
                'frequency_start_hz',s3.ofdm.frequency_band_hz(1),'frequency_end_hz',s3.ofdm.frequency_band_hz(2),'frequency_count',s3.ofdm.num_active_subcarriers,'random_seed',s3.random_seed,'noise_kind',s3.audit_noise_kind); %#ok<AGROW>
        end
    end
end
end

function write_example(example,base,prefix)
if isempty(fieldnames(example)),return;end
f=example.frequency_hz(:);h=example.H_true_views{1}(:);q=example.H_hat_views{1}(:);
writetable(table(f,real(h),imag(h),real(q),imag(q),'VariableNames',{'frequency_hz','H_true_real','H_true_imag','H_hat_real','H_hat_imag'}),fullfile(base.results_data,[prefix '_example_cfr.csv']));
end
function make_figures(summary,base,prefix)
sel=strcmp({summary.feature},'amp_phase_joint_weighted')&strcmp({summary.measurement_kind},'siso_forward');z=summary(sel);
if isempty(z),return;end
figure('Visible','off');hold on;sp=unique([z.pilot_spacing]);
for k=1:numel(sp),q=z([z.pilot_spacing]==sp(k));[x,ix]=sort([q.snr_db]);plot(x,[q(ix).strict_unique_rate],'-o','DisplayName',sprintf('spacing %d',sp(k)));end
grid on;ylim([0 1]);xlabel('SNR (dB)');ylabel('strict unique rate');title('Stage 3A.1 SISO pilot/SNR audit');legend('Location','best');
print(gcf,fullfile(base.results_figures,[prefix '_snr_pilot_audit.png']),'-dpng','-r120');close(gcf);
end
