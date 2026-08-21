function result = exp12_stage3a_communication_baseline(mode)
%EXP12_STAGE3A_COMMUNICATION_BASELINE Communication-OFDM topology baseline.
%   This experiment adds a time-domain OFDM symbol/CP wrapper around the
%   existing complete-network CFR. It does not optimize pilots or rewrite
%   the stage-1.5 physical model. Run with mode='smoke' or 'formal'.
    if nargin < 1 || isempty(mode), mode='smoke'; end
    mode=lower(char(mode));
    if ~ismember(mode,{'smoke','formal'})
        error('exp12_stage3a:InvalidMode','mode must be smoke or formal.');
    end
    root=fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root,'src')); addpath(fullfile(root,'config'));
    s3=stage3a_config(root); base=s3.base_config; ensure_result_dirs(base);
    rng(s3.random_seed,'twister');
    candidates_all=topology_candidates(base); candidates=candidates_all(s3.candidate_indices);
    f=s3.ofdm.active_frequency_hz(:).'; full_cfg=full_grid_config(s3.ofdm);
    [reference_bundles,class_audits,reference_details]=make_reference_library( ...
        f,candidates,base,s3,full_cfg);
    cases=make_cases(s3,mode);
    records=repmat(empty_record(),0,1); raw=repmat(empty_raw(),0,1);
    started=tic; raw_id=0;
    for ci=1:numel(cases)
        sc=cases(ci);
        kind_list=sc.measurement_kinds;
        for oi=1:numel(kind_list)
            kind=kind_list{oi};
            ok=find(strcmp(s3.measurement_kinds,kind),1);
            if isempty(ok), error('exp12_stage3a:UnknownMeasurement','Unknown %s.',kind); end
            for truth=1:numel(candidates)
                for tr=1:sc.trials
                    theta=case_theta(sc,tr,s3);
                    [true_views,phys_details]=stage3a_compute_observations(f,candidates(truth), ...
                        base,theta,kind);
                    coupler_gain=theta.coupler_gain;
                    measured_views=cellfun(@(x)x*coupler_gain,true_views,'UniformOutput',false);
                    previous_views={};
                    if strcmp(sc.perturbation,'load_time_varying')
                        previous_theta=theta; previous_theta.branch_load_scale= ...
                            max(eps,theta.branch_load_scale*(1+0.1*(-1)^tr));
                        [previous_views,~]=stage3a_compute_observations(f,candidates(truth), ...
                            base,previous_theta,kind);
                        previous_views=cellfun(@(x)x*coupler_gain,previous_views,'UniformOutput',false);
                    end
                    input_mode=sc.input_mode; spacing=sc.pilot_spacing;
                    observed_views=cell(1,numel(measured_views)); est_details=cell(1,numel(measured_views));
                    true_cirs=cell(1,numel(measured_views)); hat_cirs=cell(1,numel(measured_views));
                    true_delays=zeros(1,numel(measured_views)); hat_delays=zeros(1,numel(measured_views));
                    Hhat_views=cell(1,numel(measured_views)); noise_details=cell(1,numel(measured_views));
                    for v=1:numel(measured_views)
                        [true_cirs{v},~,~,~]=ofdm_cfr_to_cir(measured_views{v},full_cfg);
                        [true_delays(v),~]=stage3a_toa_feature(measured_views{v},full_cfg);
                        if strcmp(input_mode,'ideal_true_cfr')
                            observed_views{v}=measured_views{v}; Hhat_views{v}=measured_views{v};
                            est_details{v}=struct('mode',input_mode,'pilot_count',numel(f));
                            noise_details{v}=struct('kind','none','snr_db',Inf);
                        else
                            sym=stage3a_generate_symbol(s3.ofdm,spacing, ...
                                s3.random_seed+ci*100000+oi*1000+truth*100+tr);
                            ncfg=struct('kind',sc.noise_kind,'snr_db',sc.snr_db, ...
                                'colored_tilt',s3.colored_noise_tilt, ...
                                'burst_length_samples',s3.impulsive_burst_length_samples, ...
                                'burst_factor',s3.impulsive_burst_factor);
                            imp=struct('timing_offset_samples',sc.timing_offset_samples, ...
                                'sample_clock_offset_ppm',sc.sample_clock_offset_ppm, ...
                                'pilot_phase_rotation_rad',sc.pilot_phase_rotation_rad);
                            [rx,dch]=stage3a_apply_ofdm_channel(sym,measured_views{v},s3.ofdm,ncfg,imp, ...
                                s3.random_seed+ci*100000+oi*1000+truth*100+tr*10+v);
                            [~,Hhat_views{v},drx]=stage3a_receive_ofdm(rx,sym,s3.ofdm,imp);
                            observed_views{v}=Hhat_views{v}; est_details{v}=drx; noise_details{v}=dch.noise_details;
                        end
                        [hat_cirs{v},~,~,~]=ofdm_cfr_to_cir(Hhat_views{v},full_cfg);
                        [hat_delays(v),~]=stage3a_toa_feature(Hhat_views{v},full_cfg);
                    end
                    cfr_metrics=cell(1,numel(measured_views));
                    for v=1:numel(measured_views)
                        cfr_metrics{v}=cfr_estimation_metrics(Hhat_views{v},measured_views{v});
                    end
                    raw_id=raw_id+1;
                    rr=empty_raw(); rr.id=raw_id; rr.mode=mode; rr.scenario=sc.name;
                    rr.input_mode=input_mode; rr.measurement_kind=kind; rr.true_id=candidates(truth).id;
                    rr.trial=tr; rr.seed=s3.random_seed+ci*100000+oi*1000+truth*100+tr;
                    rr.theta=theta; rr.H_true_views=measured_views; rr.H_physical_views=true_views;
                    rr.H_previous_views=previous_views; rr.H_hat_views=Hhat_views;
                    rr.true_cir_views=true_cirs; rr.hat_cir_views=hat_cirs;
                    rr.true_circular_delay_s=true_delays; rr.hat_circular_delay_s=hat_delays;
                    rr.noise_details=noise_details; rr.physical_details=phys_details;
                    rr.view_count=numel(measured_views); rr.frequency_hz=f; raw(end+1)=rr; %#ok<AGROW>
                    for fi=1:numel(s3.features)
                        feature=s3.features{fi};
                        if strcmp(feature,'toa')
                            match=stage3a_match_toa(observed_views,reference_bundles{ok}, ...
                                full_cfg,class_audits{ok}.class_labels,s3.tie_tolerance);
                        else
                            match=topology_equivalence_match(observed_views,reference_bundles{ok}, ...
                                candidates,class_audits{ok},feature,full_cfg,[0.5,0.5], ...
                                struct('phase_mask_threshold_db',-40));
                        end
                        pred=match.predicted_index; truth_class=class_audits{ok}.class_index(truth);
                        pred_class=class_audits{ok}.class_index(pred);
                        physical_ambiguous=class_audits{ok}.class_sizes(pred_class)>1;
                        strict=pred==truth; class_ok=pred_class==truth_class;
                        amb=logical(match.ambiguous); unique_ok=~amb && ~physical_ambiguous;
                        em=topology_evaluation_metrics(truth,pred,candidates,amb);
                        cm=mean(cellfun(@(x)x.nmse,cfr_metrics));
                        am=mean(cellfun(@(x)x.amplitude_rmse_db,cfr_metrics));
                        pm=mean(cellfun(@(x)x.weighted_phase_rmse_deg,cfr_metrics));
                        de=mean(circular_delay_error(hat_delays,true_delays,1/s3.ofdm.sample_rate_hz));
                        rec=empty_record(); rec.mode=mode; rec.scenario=sc.name; rec.input_mode=input_mode;
                        rec.measurement_kind=kind; rec.observation_mode=stage3a_observation_config(kind).O;
                        rec.feature=feature; rec.pilot_spacing=spacing; rec.snr_db=sc.snr_db;
                        rec.noise_kind=sc.noise_kind; rec.trial=tr; rec.true_id=candidates(truth).id;
                        rec.predicted_id=candidates(pred).id; rec.true_class=class_audits{ok}.class_labels{truth};
                        rec.predicted_class=class_audits{ok}.class_labels{pred}; rec.strict_correct=strict;
                        rec.class_correct=class_ok; rec.strict_unique_correct=strict&&unique_ok;
                        rec.unique_identification=unique_ok; rec.physically_ambiguous_class=physical_ambiguous;
                        rec.ambiguous=amb; rec.false_unique=class_audits{ok}.class_sizes(truth_class)>1 && ~amb;
                        rec.best_distance=match.best_distance; rec.second_best_distance=match.second_best_distance;
                        rec.distance_margin=match.distance_gap; rec.cfr_nmse=cm; rec.amplitude_rmse_db=am;
                        rec.weighted_phase_rmse_deg=pm; rec.circular_delay_error_s=de;
                        rec.true_circular_delay_s=mean(true_delays); rec.hat_circular_delay_s=mean(hat_delays);
                        rec.view_count=numel(measured_views); rec.frequency_count=numel(f);
                        rec.edge_precision=em.edge_micro.precision; rec.edge_recall=em.edge_micro.recall;
                        rec.edge_f1=em.edge_micro.f1; rec.seed=rr.seed; rec.runtime_s=toc(started);
                        records(end+1)=rec; %#ok<AGROW>
                    end
                end
            end
        end
    end
    prefix=['stage3a_' mode];
    summary=summarize_records(records,candidates);
    confusion=make_confusion(records);
    config_rows=make_config_rows(s3,cases,mode);
    writetable(struct2table(records),fullfile(s3.results_data,[prefix '_trial_metrics.csv']));
    writetable(struct2table(summary),fullfile(s3.results_data,[prefix '_summary.csv']));
    writetable(struct2table(confusion),fullfile(s3.results_data,[prefix '_confusion.csv']));
    writetable(struct2table(config_rows),fullfile(s3.results_data,[prefix '_config.csv']));
    save(fullfile(s3.results_data,[prefix '_raw.mat']),'raw','summary','confusion', ...
        'config_rows','cases','s3','reference_details','class_audits','-v7');
    write_example_csv(raw,s3,prefix);
    make_figures(summary,class_audits,candidates,s3,prefix);
    result=struct('mode',mode,'trial_rows',numel(records),'raw_rows',numel(raw), ...
        'summary_rows',numel(summary),'confusion_rows',numel(confusion), ...
        'elapsed_s',toc(started),'data_prefix',prefix);
    fprintf('EXP12 Stage 3A %s completed: trials=%d raw=%d summaries=%d elapsed=%.3f s\n', ...
        mode,numel(records),numel(raw),numel(summary),result.elapsed_s);
end

function [bundles,audits,details]=make_reference_library(f,candidates,base,s3,full_cfg)
bundles=cell(1,numel(s3.measurement_kinds)); audits=cell(size(bundles)); details=cell(size(bundles));
theta=nominal_theta(base);
for k=1:numel(s3.measurement_kinds)
    kind=s3.measurement_kinds{k}; b=cell(1,numel(candidates)); d=cell(size(b));
    for c=1:numel(candidates), [b{c},d{c}]=stage3a_compute_observations(f,candidates(c),base,theta,kind); end
    bundles{k}=b; details{k}=d;
    audits{k}=topology_observability_classes(b,candidates,full_cfg,s3.tie_tolerance);
end
end

function theta=nominal_theta(base)
theta=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1, ...
    'kG_scale',1,'source_impedance_ohm',base.Zs,'receiver_impedance_ohm',base.Zr, ...
    'R_scale',1,'L_scale',1,'G_scale',1,'C_scale',1,'coupler_gain',1);
end

function cases=make_cases(s3,mode)
n=s3.smoke_trials_per_case; if strcmp(mode,'formal'),n=s3.formal_trials_per_case;end
cases=repmat(case_template(),0,1);
cases(end+1)=make_case('ideal_true_cfr','ideal_true_cfr','none',Inf,1,0,0,0,'none',n,s3.measurement_kinds);
cases(end+1)=make_case('white_dense_20','ofdm_dense_ls','white_awgn',20,1,0,0,0,'none',n,s3.measurement_kinds);
cases(end+1)=make_case('white_sparse_20','ofdm_sparse_interp','white_awgn',20,4,0,0,0,'none',n,s3.measurement_kinds);
cases(end+1)=make_case('colored_dense_20','ofdm_dense_ls','colored_gaussian',20,1,0,0,0,'none',n,{'siso_forward','three_view_complete'});
cases(end+1)=make_case('impulsive_dense_20','ofdm_dense_ls','impulsive',20,1,0,0,0,'none',n,{'siso_forward','three_view_complete'});
cases(end+1)=make_case('load_change_20','ofdm_dense_ls','white_awgn',20,1,0,0,0,'load',n,{'siso_forward','three_view_complete'});
cases(end+1)=make_case('load_time_varying_20','ofdm_dense_ls','white_awgn',20,1,0,0,0,'load_time_varying',n,{'siso_forward','three_view_complete'});
cases(end+1)=make_case('length_error_20','ofdm_dense_ls','white_awgn',20,1,0,0,0,'length',n,{'siso_forward','three_view_complete'});
cases(end+1)=make_case('rlgc_error_20','ofdm_dense_ls','white_awgn',20,1,0,0,0,'rlgc',n,{'siso_forward','three_view_complete'});
cases(end+1)=make_case('timing_offset_20','ofdm_dense_ls','white_awgn',20,1,2,0,0,'none',n,{'siso_forward','three_view_complete'});
cases(end+1)=make_case('sample_clock_20','ofdm_dense_ls','white_awgn',20,1,0,50,0,'none',n,{'siso_forward','three_view_complete'});
cases(end+1)=make_case('pilot_phase_rotation_20','ofdm_dense_ls','white_awgn',20,1,0,0,pi/12,'none',n,{'siso_forward','three_view_complete'});
cases(end+1)=make_case('terminal_impedance_error_20','ofdm_dense_ls','white_awgn',20,1,0,0,0,'terminal',n,{'siso_forward','three_view_complete'});
cases(end+1)=make_case('coupler_error_20','ofdm_dense_ls','white_awgn',20,1,0,0,0,'coupler',n,{'siso_forward','three_view_complete'});
end

function c=make_case(name,input,noise,snr,spacing,timing,sco,phase,perturb,tr,obs)
c=case_template(); c.name=name;c.input_mode=input;c.noise_kind=noise;c.snr_db=snr;
c.pilot_spacing=spacing;c.timing_offset_samples=timing;c.sample_clock_offset_ppm=sco;
c.pilot_phase_rotation_rad=phase;c.perturbation=perturb;c.trials=tr;c.measurement_kinds=obs;
end
function c=case_template(),c=struct('name','','input_mode','','noise_kind','','snr_db',Inf, ...
    'pilot_spacing',1,'timing_offset_samples',0,'sample_clock_offset_ppm',0, ...
    'pilot_phase_rotation_rad',0,'perturbation','none','trials',0,'measurement_kinds',{{}});end

function theta=case_theta(sc,tr,s3)
theta=nominal_theta(s3.base_config);
switch sc.perturbation
    case {'load','load_time_varying'}
        theta.branch_load_scale=s3.load_scales(1+mod(tr-1,numel(s3.load_scales)));
    case 'length'
        theta.main_length_scale=s3.length_error_scales(1+mod(tr-1,numel(s3.length_error_scales)));
        theta.branch_length_scale=theta.main_length_scale;
    case 'rlgc'
        scale=s3.rlgc_error_scales(1+mod(tr-1,numel(s3.rlgc_error_scales)));
        theta.R_scale=scale;theta.L_scale=scale;theta.G_scale=scale;theta.C_scale=scale;
    case 'terminal'
        scale=1+0.02*(-1)^tr;
        theta.source_impedance_ohm=s3.base_config.Zs*scale;
        theta.receiver_impedance_ohm=s3.base_config.Zr/scale;
    case 'coupler'
        ai=s3.coupler_amplitude_scales(1+mod(tr-1,numel(s3.coupler_amplitude_scales)));
        pi0=s3.coupler_phase_errors_rad(1+mod(tr-1,numel(s3.coupler_phase_errors_rad)));
        theta.coupler_gain=ai*exp(1i*pi0);
end
end

function cfg=full_grid_config(ofdm)
cfg=ofdm; cfg.pilot_bin_1based=ofdm.active_bin_1based;
cfg.pilot_frequency_hz=ofdm.active_frequency_hz; cfg.num_pilots=numel(ofdm.active_bin_1based);
end

function e=circular_delay_error(a,b,period)
d=abs(a-b); e=min(d,period-d); e=e(:).';
end

function rows=summarize_records(records,candidates)
keys=cell(numel(records),1);
for k=1:numel(records),keys{k}=sprintf('%s|%s|%s|%s|%g|%s',records(k).scenario, ...
        records(k).input_mode,records(k).measurement_kind,records(k).feature,records(k).snr_db,records(k).noise_kind);end
groups=unique(keys,'stable'); rows=repmat(empty_summary(),0,1);
for g=1:numel(groups)
    x=records(strcmp(keys,groups{g})); r=empty_summary(); r.mode=x(1).mode;r.scenario=x(1).scenario;
    r.input_mode=x(1).input_mode;r.measurement_kind=x(1).measurement_kind;r.observation_mode=x(1).observation_mode;
    r.feature=x(1).feature;r.noise_kind=x(1).noise_kind;r.snr_db=x(1).snr_db;r.pilot_spacing=x(1).pilot_spacing;
    r.trials=numel(x);r.strict_accuracy=mean([x.strict_correct]);r.strict_unique_rate=mean([x.strict_unique_correct]);
    r.equivalence_class_rate=mean([x.class_correct]);r.ambiguity_rate=mean([x.ambiguous]);
    r.false_unique_rate=mean([x.false_unique]);r.physically_ambiguous_class_rate=mean([x.physically_ambiguous_class]);
    r.cfr_nmse=mean([x.cfr_nmse]);r.amplitude_rmse_db=mean([x.amplitude_rmse_db]);
    r.weighted_phase_rmse_deg=mean([x.weighted_phase_rmse_deg]);r.circular_delay_error_s=mean([x.circular_delay_error_s]);
    r.mean_margin=mean([x.distance_margin]);r.view_count=x(1).view_count;r.frequency_count=x(1).frequency_count;
    truth=arrayfun(@(z)find(strcmp({candidates.id},z.true_id),1),x); pred=arrayfun(@(z)find(strcmp({candidates.id},z.predicted_id),1),x);
    em=topology_evaluation_metrics(truth,pred,candidates,[x.ambiguous]);r.edge_precision=em.edge_micro.precision;
    r.edge_recall=em.edge_micro.recall;r.edge_f1=em.edge_micro.f1;r.runtime_s=mean([x.runtime_s]);
    rows(end+1)=r; %#ok<AGROW>
end
end

function r=empty_summary(),r=struct('mode','','scenario','','input_mode','','measurement_kind','','observation_mode','', ...
    'feature','','noise_kind','','snr_db',Inf,'pilot_spacing',1,'trials',0,'strict_accuracy',NaN, ...
    'strict_unique_rate',NaN,'equivalence_class_rate',NaN,'ambiguity_rate',NaN,'false_unique_rate',NaN, ...
    'physically_ambiguous_class_rate',NaN,'cfr_nmse',NaN,'amplitude_rmse_db',NaN,'weighted_phase_rmse_deg',NaN, ...
    'circular_delay_error_s',NaN,'mean_margin',NaN,'view_count',0,'frequency_count',0,'edge_precision',NaN, ...
    'edge_recall',NaN,'edge_f1',NaN,'runtime_s',NaN);end

function r=empty_record(),r=struct('mode','','scenario','','input_mode','','measurement_kind','','observation_mode','', ...
    'feature','','pilot_spacing',1,'snr_db',Inf,'noise_kind','','trial',0,'true_id','','predicted_id','', ...
    'true_class','','predicted_class','','strict_correct',false,'class_correct',false,'strict_unique_correct',false, ...
    'unique_identification',false,'physically_ambiguous_class',false,'ambiguous',false,'false_unique',false, ...
    'best_distance',NaN,'second_best_distance',NaN,'distance_margin',NaN,'cfr_nmse',NaN,'amplitude_rmse_db',NaN, ...
    'weighted_phase_rmse_deg',NaN,'circular_delay_error_s',NaN,'true_circular_delay_s',NaN,'hat_circular_delay_s',NaN, ...
    'view_count',0,'frequency_count',0,'edge_precision',NaN,'edge_recall',NaN,'edge_f1',NaN,'seed',0,'runtime_s',NaN);end

function r=empty_raw(),r=struct('id',0,'mode','','scenario','','input_mode','','measurement_kind','','true_id','', ...
    'trial',0,'seed',0,'theta',struct(),'H_true_views',{{}},'H_physical_views',{{}},'H_previous_views',{{}}, ...
    'H_hat_views',{{}},'true_cir_views',{{}},'hat_cir_views',{{}},'true_circular_delay_s',[], ...
    'hat_circular_delay_s',[],'noise_details',{{}},'physical_details',struct(),'view_count',0, ...
    'frequency_hz',[]);end

function rows=make_confusion(records)
rows=repmat(struct('mode','','scenario','','input_mode','','measurement_kind','','feature','','snr_db',Inf, ...
    'noise_kind','','true_id','','predicted_id','','count',0),0,1);
keys=arrayfun(@(x)sprintf('%s|%s|%s|%s|%g|%s|%s|%s',x.mode,x.scenario,x.input_mode,x.measurement_kind,x.snr_db,x.noise_kind,x.feature,x.true_id),records,'UniformOutput',false); %#ok<NASGU>
for k=1:numel(records)
    x=records(k); hit=find(arrayfun(@(z)strcmp(z.mode,x.mode)&&strcmp(z.scenario,x.scenario)&& ...
        strcmp(z.input_mode,x.input_mode)&&strcmp(z.measurement_kind,x.measurement_kind)&& ...
        strcmp(z.feature,x.feature)&&z.snr_db==x.snr_db&&strcmp(z.noise_kind,x.noise_kind)&& ...
        strcmp(z.true_id,x.true_id)&&strcmp(z.predicted_id,x.predicted_id),rows));
    if isempty(hit)
        rows(end+1)=struct('mode',x.mode,'scenario',x.scenario,'input_mode',x.input_mode, ...
            'measurement_kind',x.measurement_kind,'feature',x.feature,'snr_db',x.snr_db, ...
            'noise_kind',x.noise_kind,'true_id',x.true_id,'predicted_id',x.predicted_id,'count',1); %#ok<AGROW>
    else, rows(hit).count=rows(hit).count+1; end
end
end

function rows=make_config_rows(s3,cases,mode)
rows=repmat(struct('mode','','scenario','','input_mode','','noise_kind','','snr_db',Inf,'pilot_spacing',1, ...
    'measurement_kind','','view_count',0,'nfft',0,'sample_rate_hz',0,'cyclic_prefix_samples',0, ...
    'frequency_start_hz',0,'frequency_end_hz',0,'active_frequency_count',0,'random_seed',0, ...
    'timing_offset_samples',0,'sample_clock_offset_ppm',0,'pilot_phase_rotation_rad',0, ...
    'parameter_perturbation','','FDR_TFDR_proxy_not_physical',true),0,1);
for c=1:numel(cases),for k=1:numel(cases(c).measurement_kinds)
    info=stage3a_observation_config(cases(c).measurement_kinds{k});
    rows(end+1)=struct('mode',mode,'scenario',cases(c).name,'input_mode',cases(c).input_mode, ...
        'noise_kind',cases(c).noise_kind,'snr_db',cases(c).snr_db,'pilot_spacing',cases(c).pilot_spacing, ...
        'measurement_kind',cases(c).measurement_kinds{k},'view_count',info.view_count,'nfft',s3.ofdm.nfft, ...
        'sample_rate_hz',s3.ofdm.sample_rate_hz,'cyclic_prefix_samples',s3.ofdm.cyclic_prefix_samples, ...
        'frequency_start_hz',s3.ofdm.frequency_band_hz(1),'frequency_end_hz',s3.ofdm.frequency_band_hz(2), ...
        'active_frequency_count',s3.ofdm.num_active_subcarriers,'random_seed',s3.random_seed, ...
        'timing_offset_samples',cases(c).timing_offset_samples,'sample_clock_offset_ppm',cases(c).sample_clock_offset_ppm, ...
        'pilot_phase_rotation_rad',cases(c).pilot_phase_rotation_rad,'parameter_perturbation',cases(c).perturbation, ...
        'FDR_TFDR_proxy_not_physical',true); %#ok<AGROW>
end,end
end

function write_example_csv(raw,s3,prefix)
if isempty(raw),return;end
r=raw(1); h=r.H_true_views{1}; q=r.H_hat_views{1}; f=r.frequency_hz(:);
t=table(f,real(h(:)),imag(h(:)),real(q(:)),imag(q(:)), ...
    'VariableNames',{'frequency_hz','H_true_real','H_true_imag','H_hat_real','H_hat_imag'});
writetable(t,fullfile(s3.results_data,[prefix '_example_cfr.csv']));
end

function make_figures(summary,audits,candidates,s3,prefix)
sel=strcmp({summary.feature},'amp_phase_joint_weighted')&strcmp({summary.scenario},'white_dense_20');
z=summary(sel); if ~isempty(z)
    kinds=unique({z.measurement_kind},'stable'); vals=zeros(numel(kinds),1);
    for k=1:numel(kinds), vals(k)=mean([z(strcmp({z.measurement_kind},kinds{k})).strict_unique_rate]);end
    figure('Visible','off');bar(vals);grid on;ylim([0 1]);set(gca,'XTick',1:numel(kinds),'XTickLabel',strrep(kinds,'_',' '),'XTickLabelRotation',25);
    ylabel('strict unique rate');title('Stage 3A white-noise OFDM topology baseline');
    print(gcf,fullfile(s3.results_figures,[prefix '_measurement_comparison.png']),'-dpng','-r120');close(gcf);
end
sel=strcmp({summary.feature},'amp_phase_joint_weighted'); z=summary(sel);
if ~isempty(z)
    [~,~,ic]=unique({z.input_mode}); nm=accumarray(ic,[z.cfr_nmse],[],@mean);
    figure('Visible','off');bar(nm);grid on;set(gca,'XTickLabel',unique({z.input_mode}));ylabel('CFR NMSE');title('Stage 3A CFR estimation error by input mode');
    print(gcf,fullfile(s3.results_figures,[prefix '_estimation_errors.png']),'-dpng','-r120');close(gcf);
end
if ~isempty(audits)
    a=audits{1}; figure('Visible','off');imagesc(a.pairwise_complex_distance);axis image;colorbar;
    ids={candidates.id};set(gca,'XTick',1:numel(ids),'XTickLabel',ids,'YTick',1:numel(ids),'YTickLabel',ids);
    title('Stage 3A siso forward normalized CFR observability');
    print(gcf,fullfile(s3.results_figures,[prefix '_observability.png']),'-dpng','-r120');close(gcf);
end
end
