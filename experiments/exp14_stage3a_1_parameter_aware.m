function result = exp14_stage3a_1_parameter_aware(root)
%EXP14_STAGE3A_1_PARAMETER_AWARE Parameter-aware topology baseline.
%   The nominal matcher and nuisance-aware grid matcher receive identical
%   OFDM observations. The joint objective is
%       D(Hhat,H(G,theta)) + lambda*R(theta).
%   The grid is bounded and one-factor-at-a-time; it is not field-trained.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));
    s3=stage3a_config(root);base=s3.base_config;ensure_result_dirs(base);
    rng(s3.random_seed+41000,'twister');started=tic;
    candidates_all=topology_candidates(base);candidates=candidates_all(s3.candidate_indices);
    f=s3.ofdm.active_frequency_hz(:).';full_cfg=s3.ofdm;
    full_cfg.pilot_bin_1based=s3.ofdm.active_bin_1based;
    full_cfg.pilot_frequency_hz=f;full_cfg.num_pilots=numel(f);
    kinds={'siso_forward','dual_receiver_complete','dual_receiver_highz_complete','three_view_complete'};
    [theta_grid,bounds]=stage3a_parameter_grid(base,s3);
    nominal=theta_grid(1);
    references=cell(1,numel(kinds));audits=cell(size(references));libraries=cell(size(references));
    for k=1:numel(kinds)
        refs=cell(1,numel(candidates));
        for t=1:numel(candidates),[refs{t},~]=stage3a_compute_observations(f,candidates(t),base,nominal,kinds{k});end
        references{k}=refs;
        audits{k}=topology_observability_classes(refs,candidates,full_cfg,s3.tie_tolerance);
        raw_library=stage3a_parameter_library(f,candidates,theta_grid,kinds{k},base);
        libraries{k}=topology_prepare_parameter_library(raw_library);
    end
    scenarios=make_scenarios(s3,base);records=repmat(empty_record(),0,1);raw=struct();raw.example={};
    raw_counter=0;
    for si=1:numel(scenarios)
        sc=scenarios(si);
        for ki=1:numel(kinds)
            kind=kinds{ki};audit=audits{ki};
            for truth=1:numel(candidates)
                for tr=1:sc.trials
                    theta=true_theta(sc,tr,s3,base,si,truth);
                    [true_views,~]=stage3a_compute_observations(f,candidates(truth),base,theta,kind);
                    measured=cellfun(@(x)x*theta.coupler_gain,true_views,'UniformOutput',false);
                    observed=cell(1,numel(measured));
                    for v=1:numel(measured)
                        sym=stage3a_generate_symbol(s3.ofdm,1, ...
                            s3.random_seed+si*100000+ki*10000+truth*100+tr);
                        ncfg=struct('kind','white_awgn','snr_db',sc.snr_db);
                        [rx,~]=stage3a_apply_ofdm_channel(sym,measured{v},s3.ofdm,ncfg,struct(), ...
                            s3.random_seed+si*100000+ki*10000+truth*100+tr*10+v);
                        [~,observed{v},~]=stage3a_receive_ofdm(rx,sym,s3.ofdm,struct());
                    end
                    cm=mean(cellfun(@(x,y)cfr_estimation_metrics(x,y).nmse,observed,measured));
                    methods=cell(1,3);
                    methods{1}=topology_equivalence_match(observed,references{ki},candidates,audit, ...
                        'amp_phase_joint_weighted',full_cfg,[.5,.5],struct('phase_mask_threshold_db',-40));
                    methods{2}=topology_equivalence_match(observed,references{ki},candidates,audit, ...
                        'amplitude',full_cfg,[.5,.5],struct());
                    methods{3}=topology_joint_match(observed,libraries{ki}, ...
                        'amp_phase_joint_weighted',full_cfg,[.5,.5],s3.audit_parameter_lambda, ...
                        struct('phase_mask_threshold_db',-40));
                    method_names={'nominal_nearest','topology_only','nuisance_aware_joint'};
                    for mi=1:3
                        match=methods{mi};pred=match.predicted_index;
                        if mi<3
                            amb=logical(match.ambiguous);best=match.best_distance;second=match.second_best_distance;
                            objective=best;theta_hat=nominal;param_reg=0;
                        else
                            scores=match.scores;best=min(scores);tied=find(scores<=best+s3.tie_tolerance*max(1,best));
                            amb=numel(tied)>1;second=second_score(scores,best);objective=match.objective;
                            theta_hat=match.theta_hat;param_reg=match.theta_hat.regularization;
                        end
                        truth_class=audit.class_index(truth);pred_class=audit.class_index(pred);
                        physical= audit.class_sizes(truth_class)>1;
                        strict=pred==truth;class_ok=pred_class==truth_class;
                        unique_ok=~amb && ~(audit.class_sizes(pred_class)>1);
                        em=topology_evaluation_metrics(truth,pred,candidates,amb);
                        rec=empty_record();rec.mode='parameter_aware';rec.scenario=sc.name;
                        rec.measurement_kind=kind;rec.observation_mode=stage3a_observation_config(kind).O;
                        rec.method=method_names{mi};rec.feature=feature_name(mi);rec.snr_db=sc.snr_db;
                        rec.trial=tr;rec.true_id=candidates(truth).id;rec.predicted_id=candidates(pred).id;
                        rec.true_class=audit.class_labels{truth};rec.predicted_class=audit.class_labels{pred};
                        rec.strict_correct=strict;rec.class_correct=class_ok;rec.strict_unique_correct=strict&&unique_ok;
                        rec.unique_identification=unique_ok;rec.physically_ambiguous_class=physical;rec.ambiguous=amb;
                        rec.false_unique=physical&&~amb;rec.best_distance=best;rec.second_best_distance=second;
                        rec.distance_margin=second-best;rec.objective=objective;rec.cfr_nmse=cm;
                        rec.theta_estimation_rmse=theta_error(theta_hat,theta,base);
                        rec.theta_boundary_hit=theta_boundary_hit(theta_hat,bounds,base);
                        rec.theta_true_label=theta.perturbation_label;rec.theta_hat_label=theta_hat.perturbation_label;
                        rec.parameter_regularization=param_reg;rec.grid_size=numel(theta_grid);
                        rec.view_count=numel(measured);rec.frequency_count=numel(f);rec.edge_precision=em.edge_micro.precision;
                        rec.edge_recall=em.edge_micro.recall;rec.edge_f1=em.edge_micro.f1;
                        rec.seed=s3.random_seed+si*100000+ki*10000+truth*100+tr;rec.runtime_s=toc(started);
                        records(end+1)=rec; %#ok<AGROW>
                    end
                    raw_counter=raw_counter+1;
                    if raw_counter==1
                        raw.frequency_hz=f;raw.H_true_views=measured;raw.H_hat_views=observed;
                        raw.theta_true=theta;raw.scenario=sc;raw.measurement_kind=kind;
                    end
                end
            end
        end
    end
    prefix='stage3a_1_parameter_aware';summary=summarize(records);confusion=make_confusion(records);
    config_rows=make_config_rows(scenarios,kinds,s3,theta_grid,bounds);
    writetable(struct2table(records),fullfile(base.results_data,[prefix '_trial_metrics.csv']));
    writetable(struct2table(summary),fullfile(base.results_data,[prefix '_summary.csv']));
    writetable(struct2table(confusion),fullfile(base.results_data,[prefix '_confusion.csv']));
    writetable(struct2table(config_rows),fullfile(base.results_data,[prefix '_config.csv']));
    save(fullfile(base.results_data,[prefix '_raw.mat']),'raw','summary','confusion','config_rows', ...
        'theta_grid','bounds','scenarios','-v7');
    write_example(raw,base,prefix);make_figures(summary,base,prefix);
    result=struct('mode','parameter_aware','trial_rows',numel(records),'summary_rows',numel(summary), ...
        'confusion_rows',numel(confusion),'grid_size',numel(theta_grid),'elapsed_s',toc(started));
    fprintf('EXP14 Stage 3A.1 parameter-aware completed: trials=%d summaries=%d grid=%d elapsed=%.3f s\n', ...
        numel(records),numel(summary),numel(theta_grid),result.elapsed_s);
end

function scenarios=make_scenarios(s3,base)
template=struct('name','','snr_db',s3.audit_parameter_snr_db,'trials',s3.audit_parameter_trials,'kind','none');
scenarios=repmat(template,0,1);
names={'nominal_noise_20','load_error_10','length_error_2','rlgc_error_2', ...
    'terminal_error_2','coupler_error','joint_bounded'};
for k=1:numel(names),t=template;t.name=names{k};scenarios(end+1)=t;end %#ok<AGROW>
end

function theta=true_theta(sc,tr,s3,base,si,truth)
theta=nominal_theta(base);
switch sc.name
    case 'load_error_10'
        theta.branch_load_scale=1+0.1*(-1)^tr;
    case 'length_error_2'
        theta.main_length_scale=1+0.02*(-1)^tr;theta.branch_length_scale=theta.main_length_scale;
    case 'rlgc_error_2'
        q=1+0.02*(-1)^tr;theta.R_scale=q;theta.L_scale=q;theta.G_scale=q;theta.C_scale=q;
    case 'terminal_error_2'
        q=1+0.02*(-1)^tr;theta.source_impedance_ohm=base.Zs*q;theta.receiver_impedance_ohm=base.Zr/q;
    case 'coupler_error'
        q=1+0.02*(-1)^tr;theta.coupler_gain=q*exp(1i*(pi/36)*(-1)^tr);
    case 'joint_bounded'
        old=rng;rng(s3.random_seed+si*100000+truth*1000+tr,'twister');cleanup=onCleanup(@()rng(old)); %#ok<NASGU>
        theta.main_length_scale=0.98+0.04*rand;theta.branch_length_scale=0.98+0.04*rand;
        theta.branch_load_scale=0.90+0.20*rand;theta.kG_scale=0.98+0.04*rand;
        theta.R_scale=0.98+0.04*rand;theta.L_scale=0.98+0.04*rand;
        theta.G_scale=0.98+0.04*rand;theta.C_scale=0.98+0.04*rand;
        theta.source_impedance_ohm=49+2*rand;theta.receiver_impedance_ohm=49+2*rand;
        theta.coupler_gain=(0.98+0.04*rand)*exp(1i*(-pi/36+2*pi/36*rand));
end
theta.perturbation_label=sc.name;theta.regularization=0;
end

function theta=nominal_theta(base)
theta=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1,'kG_scale',1, ...
    'source_impedance_ohm',base.Zs,'receiver_impedance_ohm',base.Zr,'R_scale',1,'L_scale',1, ...
    'G_scale',1,'C_scale',1,'coupler_gain',1,'regularization',0,'perturbation_label','nominal');
end

function name=feature_name(mi)
if mi==2,name='amplitude';else,name='amp_phase_joint_weighted';end
end

function e=theta_error(a,b,base)
va=[a.main_length_scale,a.branch_length_scale,a.branch_load_scale,a.kG_scale,a.R_scale,a.L_scale,a.G_scale,a.C_scale, ...
    a.source_impedance_ohm/base.Zs,a.receiver_impedance_ohm/base.Zr,abs(a.coupler_gain),angle(a.coupler_gain)];
vb=[b.main_length_scale,b.branch_length_scale,b.branch_load_scale,b.kG_scale,b.R_scale,b.L_scale,b.G_scale,b.C_scale, ...
    b.source_impedance_ohm/base.Zs,b.receiver_impedance_ohm/base.Zr,abs(b.coupler_gain),angle(b.coupler_gain)];
e=sqrt(mean((va-vb).^2));
end

function hit=theta_boundary_hit(t,bounds,base)
v=[t.main_length_scale,t.branch_length_scale,t.branch_load_scale,t.kG_scale, ...
    t.source_impedance_ohm,t.receiver_impedance_ohm,abs(t.coupler_gain),angle(t.coupler_gain)];
b={bounds.main_length_scale,bounds.branch_length_scale,bounds.branch_load_scale,bounds.kG_scale, ...
    bounds.source_impedance_ohm,bounds.receiver_impedance_ohm,bounds.coupler_amplitude,bounds.coupler_phase_rad};
 hit=false;for k=1:numel(v)
     endpoints=[min(b{k}),max(b{k})];
     hit=hit||any(abs(v(k)-endpoints)<1e-12);
 end
end

function s=second_score(scores,best)
o=sort(scores);if numel(o)>1,s=o(2);else,s=Inf;end
if s==best&&numel(o)>2,s=o(2);end
end

function r=empty_record()
r=struct('mode','','scenario','','measurement_kind','','observation_mode','','method','','feature','', ...
    'snr_db',20,'trial',0,'true_id','','predicted_id','','true_class','','predicted_class','', ...
    'strict_correct',false,'class_correct',false,'strict_unique_correct',false,'unique_identification',false, ...
    'physically_ambiguous_class',false,'ambiguous',false,'false_unique',false,'best_distance',NaN, ...
    'second_best_distance',NaN,'distance_margin',NaN,'objective',NaN,'cfr_nmse',NaN,'theta_estimation_rmse',NaN, ...
    'theta_boundary_hit',false,'theta_true_label','','theta_hat_label','','parameter_regularization',NaN, ...
    'grid_size',0,'view_count',0,'frequency_count',0,'edge_precision',NaN,'edge_recall',NaN,'edge_f1',NaN, ...
    'seed',0,'runtime_s',NaN);
end

function rows=summarize(records)
keys=arrayfun(@(x)sprintf('%s|%s|%s|%s|%g',x.scenario,x.measurement_kind,x.method,x.feature,x.snr_db),records,'UniformOutput',false);
groups=unique(keys,'stable');rows=repmat(empty_summary(),0,1);
for g=1:numel(groups)
    x=records(strcmp(keys,groups{g}));r=empty_summary();r.mode='parameter_aware';r.scenario=x(1).scenario;
    r.measurement_kind=x(1).measurement_kind;r.observation_mode=x(1).observation_mode;r.method=x(1).method;
    r.feature=x(1).feature;r.snr_db=x(1).snr_db;r.trials=numel(x);
    r.strict_accuracy=mean([x.strict_correct]);r.strict_accuracy_std=std(double([x.strict_correct]),0,2);
    r.strict_accuracy_ci95=1.96*r.strict_accuracy_std/sqrt(r.trials);
    r.strict_unique_rate=mean([x.strict_unique_correct]);r.strict_unique_rate_std=std(double([x.strict_unique_correct]),0,2);
    r.strict_unique_ci95=1.96*r.strict_unique_rate_std/sqrt(r.trials);
    r.equivalence_class_rate=mean([x.class_correct]);r.ambiguity_rate=mean([x.ambiguous]);
    r.false_unique_rate=mean([x.false_unique]);r.physically_ambiguous_class_rate=mean([x.physically_ambiguous_class]);
    r.cfr_nmse=mean([x.cfr_nmse]);r.cfr_nmse_std=std([x.cfr_nmse],0,2);r.cfr_nmse_ci95=1.96*r.cfr_nmse_std/sqrt(r.trials);
    r.theta_estimation_rmse=mean([x.theta_estimation_rmse]);r.theta_boundary_rate=mean([x.theta_boundary_hit]);
    r.edge_precision=mean([x.edge_precision]);r.edge_recall=mean([x.edge_recall]);r.edge_f1=mean([x.edge_f1]);
    r.mean_margin=mean([x.distance_margin]);r.grid_size=x(1).grid_size;r.view_count=x(1).view_count;
    r.frequency_count=x(1).frequency_count;r.runtime_s=mean([x.runtime_s]);rows(end+1)=r; %#ok<AGROW>
end
end

function r=empty_summary()
r=struct('mode','','scenario','','measurement_kind','','observation_mode','','method','','feature','','snr_db',20,'trials',0, ...
    'strict_accuracy',NaN,'strict_accuracy_std',NaN,'strict_accuracy_ci95',NaN,'strict_unique_rate',NaN, ...
    'strict_unique_rate_std',NaN,'strict_unique_ci95',NaN,'equivalence_class_rate',NaN,'ambiguity_rate',NaN, ...
    'false_unique_rate',NaN,'physically_ambiguous_class_rate',NaN,'cfr_nmse',NaN,'cfr_nmse_std',NaN, ...
    'cfr_nmse_ci95',NaN,'theta_estimation_rmse',NaN,'theta_boundary_rate',NaN,'edge_precision',NaN, ...
    'edge_recall',NaN,'edge_f1',NaN,'mean_margin',NaN,'grid_size',0,'view_count',0,'frequency_count',0,'runtime_s',NaN);
end

function rows=make_confusion(records)
rows=repmat(struct('mode','','scenario','','measurement_kind','','method','','feature','','snr_db',20, ...
    'true_id','','predicted_id','','count',0),0,1);
for k=1:numel(records)
    x=records(k);hit=find(arrayfun(@(z)strcmp(z.scenario,x.scenario)&&strcmp(z.measurement_kind,x.measurement_kind)&& ...
        strcmp(z.method,x.method)&&strcmp(z.feature,x.feature)&&z.snr_db==x.snr_db&&strcmp(z.true_id,x.true_id)&& ...
        strcmp(z.predicted_id,x.predicted_id),rows),1);
    if isempty(hit),rows(end+1)=struct('mode','parameter_aware','scenario',x.scenario, ...
        'measurement_kind',x.measurement_kind,'method',x.method,'feature',x.feature,'snr_db',x.snr_db, ...
        'true_id',x.true_id,'predicted_id',x.predicted_id,'count',1); %#ok<AGROW>
    else,rows(hit).count=rows(hit).count+1;end
end
end

function rows=make_config_rows(scenarios,kinds,s3,grid,bounds)
rows=repmat(struct('mode','','scenario','','measurement_kind','','snr_db',20,'trials',0,'feature', ...
    'amp_phase_joint_weighted','grid_size',0,'lambda',0,'random_seed',0,'nfft',0,'sample_rate_hz',0, ...
    'cyclic_prefix_samples',0,'frequency_start_hz',0,'frequency_end_hz',0,'frequency_count',0, ...
    'parameter_bounds_note',''),0,1);
note=sprintf('main=[%.3g,%.3g];branch=[%.3g,%.3g];load=[%.3g,%.3g];Zs=[%.3g,%.3g];Zr=[%.3g,%.3g];grid=%d', ...
    bounds.main_length_scale(1),bounds.main_length_scale(end),bounds.branch_length_scale(1),bounds.branch_length_scale(end), ...
    bounds.branch_load_scale(1),bounds.branch_load_scale(end),bounds.source_impedance_ohm(1),bounds.source_impedance_ohm(end), ...
    bounds.receiver_impedance_ohm(1),bounds.receiver_impedance_ohm(end),numel(grid));
for s=1:numel(scenarios),for k=1:numel(kinds)
    rows(end+1)=struct('mode','parameter_aware','scenario',scenarios(s).name,'measurement_kind',kinds{k}, ...
        'snr_db',scenarios(s).snr_db,'trials',scenarios(s).trials,'feature',s3.audit_parameter_feature, ...
        'grid_size',numel(grid),'lambda',s3.audit_parameter_lambda,'random_seed',s3.random_seed, ...
        'nfft',s3.ofdm.nfft,'sample_rate_hz',s3.ofdm.sample_rate_hz,'cyclic_prefix_samples',s3.ofdm.cyclic_prefix_samples, ...
        'frequency_start_hz',s3.ofdm.frequency_band_hz(1),'frequency_end_hz',s3.ofdm.frequency_band_hz(2), ...
        'frequency_count',s3.ofdm.num_active_subcarriers,'parameter_bounds_note',note); %#ok<AGROW>
end,end
end

function write_example(raw,base,prefix)
f=raw.frequency_hz(:);h=raw.H_true_views{1}(:);q=raw.H_hat_views{1}(:);
writetable(table(f,real(h),imag(h),real(q),imag(q),'VariableNames', ...
    {'frequency_hz','H_true_real','H_true_imag','H_hat_real','H_hat_imag'}), ...
    fullfile(base.results_data,[prefix '_example_cfr.csv']));
end

function make_figures(summary,base,prefix)
sel=strcmp({summary.method},'nuisance_aware_joint')&strcmp({summary.feature},'amp_phase_joint_weighted');z=summary(sel);
if isempty(z),return;end
kinds=unique({z.measurement_kind},'stable');
figure('Visible','off');vals=zeros(1,numel(kinds));
for k=1:numel(kinds),q=z(strcmp({z.measurement_kind},kinds{k})&strcmp({z.scenario},'nominal_noise_20'));vals(k)=q(1).strict_unique_rate;end
bar(vals);ylim([0 1]);grid on;set(gca,'XTick',1:numel(kinds),'XTickLabel',strrep(kinds,'_',' '),'XTickLabelRotation',25);ylabel('strict unique rate');title('Stage 3A.1 observation comparison');
print(gcf,fullfile(base.results_figures,[prefix '_measurement_comparison.png']),'-dpng','-r120');close(gcf);
sc=unique({z.scenario},'stable');vals=zeros(1,numel(sc));
for k=1:numel(sc),q=z(strcmp({z.scenario},sc{k})&strcmp({z.measurement_kind},'siso_forward'));vals(k)=q(1).theta_estimation_rmse;end
figure('Visible','off');bar(vals);grid on;set(gca,'XTick',1:numel(sc),'XTickLabel',strrep(sc,'_',' '),'XTickLabelRotation',35);ylabel('theta RMSE');title('Stage 3A.1 parameter estimation error');
print(gcf,fullfile(base.results_figures,[prefix '_parameter_error.png']),'-dpng','-r120');close(gcf);
end
