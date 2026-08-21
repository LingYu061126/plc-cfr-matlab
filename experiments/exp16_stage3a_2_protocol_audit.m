function result = exp16_stage3a_2_protocol_audit(root,calibration_override,test_override)
%EXP16_STAGE3A_2_PROTOCOL_AUDIT Independent calibration/test protocol audit.
%   Calibration seeds select only lambda from the configured candidates.
%   Test seeds are disjoint and are used once for final reporting. The
%   topology grid remains the fixed Stage-3A.1 27-point bounded grid.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'));addpath(fullfile(root,'config'));
    s3=stage3a_config(root);base=s3.base_config;ensure_result_dirs(base);
    calibration_trials=s3.stage3a2_calibration_trials;test_trials=s3.stage3a2_test_trials;
    smoke=(nargin>=2&&~isempty(calibration_override))||(nargin>=3&&~isempty(test_override));
    if nargin>=2&&~isempty(calibration_override),calibration_trials=calibration_override;end
    if nargin>=3&&~isempty(test_override),test_trials=test_override;end
    started=tic;old=rng;rng(s3.random_seed+74000,'twister');cleanup=onCleanup(@()rng(old)); %#ok<NASGU>
    candidates_all=topology_candidates(base);candidates=candidates_all(s3.candidate_indices);
    f=s3.ofdm.active_frequency_hz(:).';full_cfg=s3.ofdm;
    full_cfg.pilot_bin_1based=s3.ofdm.active_bin_1based;full_cfg.pilot_frequency_hz=f;full_cfg.num_pilots=numel(f);
    kinds=s3.stage3a2_measurement_kinds;scenarios=s3.stage3a2_scenarios;
    [theta_grid,bounds]=stage3a_parameter_grid(base,s3);nominal=nominal_theta(base);
    references=cell(1,numel(kinds));audits=cell(size(references));libraries=cell(size(references));
    for k=1:numel(kinds)
        refs=cell(1,numel(candidates));
        for t=1:numel(candidates),[refs{t},~]=stage3a_compute_observations(f,candidates(t),base,nominal,kinds{k});end
        references{k}=refs;audits{k}=topology_observability_classes(refs,candidates,full_cfg,s3.tie_tolerance);
        libraries{k}=topology_prepare_parameter_library(stage3a_parameter_library(f,candidates,theta_grid,kinds{k},base));
    end
    lambda_grid=s3.stage3a2_lambda_grid;
    calibration=repmat(empty_record(),0,1);
    for si=1:numel(scenarios)
        for ki=1:numel(kinds)
            for truth=1:numel(candidates)
                for tr=1:calibration_trials
                    seed=s3.random_seed+s3.stage3a2_calibration_seed_offset+si*100000+ki*10000+truth*100+tr;
                    [observed,true_views,theta]=make_observation(scenarios{si},candidates(truth),base, ...
                        f,kinds{ki},s3,seed);
                    audit=audits{ki};
                    for li=1:numel(lambda_grid)
                        match=topology_joint_match(observed,libraries{ki},'amp_phase_joint_weighted', ...
                            full_cfg,[.5,.5],lambda_grid(li),struct('phase_mask_threshold_db',-40));
                        calibration(end+1)=make_record('calibration',scenarios{si},kinds{ki}, ...
                            truth,candidates,match,observed,true_views,theta,audit,base,f, ...
                            lambda_grid(li),numel(theta_grid),seed,bounds); %#ok<AGROW>
                    end
                end
                fprintf('EXP16 calibration scenario %d/%d kind %d/%d complete\n',si,numel(scenarios),ki,numel(kinds));
            end
        end
    end
    calibration_selection=select_lambda(calibration,lambda_grid);
    selected_lambda=calibration_selection(1).selected_lambda;
    test_records=repmat(empty_record(),0,1);
    for si=1:numel(scenarios)
        for ki=1:numel(kinds)
            for truth=1:numel(candidates)
                for tr=1:test_trials
                    seed=s3.random_seed+s3.stage3a2_test_seed_offset+si*100000+ki*10000+truth*100+tr;
                    [observed,true_views,theta]=make_observation(scenarios{si},candidates(truth),base, ...
                        f,kinds{ki},s3,seed);
                    audit=audits{ki};
                    m1=topology_equivalence_match(observed,references{ki},candidates,audit, ...
                        'amp_phase_joint_weighted',full_cfg,[.5,.5],struct('phase_mask_threshold_db',-40));
                    m2=topology_equivalence_match(observed,references{ki},candidates,audit, ...
                        'amplitude',full_cfg,[.5,.5],struct());
                    m3=topology_joint_match(observed,libraries{ki},'amp_phase_joint_weighted', ...
                        full_cfg,[.5,.5],selected_lambda,struct('phase_mask_threshold_db',-40));
                    test_records(end+1)=make_record('test',scenarios{si},kinds{ki},truth,candidates,m1, ...
                        observed,true_views,theta,audit,base,f,0,numel(theta_grid),seed,bounds,'nominal_nearest'); %#ok<AGROW>
                    test_records(end+1)=make_record('test',scenarios{si},kinds{ki},truth,candidates,m2, ...
                        observed,true_views,theta,audit,base,f,0,numel(theta_grid),seed,bounds,'topology_only'); %#ok<AGROW>
                    test_records(end+1)=make_record('test',scenarios{si},kinds{ki},truth,candidates,m3, ...
                        observed,true_views,theta,audit,base,f,selected_lambda,numel(theta_grid),seed,bounds,'nuisance_aware_joint'); %#ok<AGROW>
                end
                fprintf('EXP16 test scenario %d/%d kind %d/%d complete\n',si,numel(scenarios),ki,numel(kinds));
            end
        end
    end
    all_records=[calibration(:);test_records(:)];summary=summarize(all_records);confusion=make_confusion(test_records(:));
    config_rows=make_config_rows(s3,kinds,scenarios,theta_grid,bounds,selected_lambda,calibration_trials,test_trials);
    prefix='stage3a_2_protocol';if smoke,prefix='stage3a_2_protocol_smoke';end
    writetable(struct2table(all_records),fullfile(base.results_data,[prefix '_trial_metrics.csv']));
    writetable(struct2table(summary),fullfile(base.results_data,[prefix '_summary.csv']));
    writetable(struct2table(confusion),fullfile(base.results_data,[prefix '_confusion.csv']));
    writetable(struct2table(calibration_selection),fullfile(base.results_data,[prefix '_calibration_selection.csv']));
    writetable(struct2table(config_rows),fullfile(base.results_data,[prefix '_config.csv']));
    raw=struct('frequency_hz',f,'selected_lambda',selected_lambda,'lambda_grid',lambda_grid, ...
        'calibration_seeds',[calibration.seed],'test_seeds',[test_records.seed], ...
        'scenario_names',{scenarios},'measurement_kinds',{kinds});
    save(fullfile(base.results_data,[prefix '_raw.mat']),'raw','summary','confusion', ...
        'calibration_selection','config_rows','theta_grid','bounds','-v7');
    make_figures(summary,calibration_selection,base,prefix,kinds);
    result=struct('mode',prefix,'calibration_rows',numel(calibration),'test_rows',numel(test_records), ...
        'summary_rows',numel(summary),'confusion_rows',numel(confusion),'selected_lambda',selected_lambda, ...
        'grid_size',numel(theta_grid),'calibration_trials_per_topology',calibration_trials, ...
        'test_trials_per_topology',test_trials,'elapsed_s',toc(started));
    fprintf('EXP16 Stage 3A.2 protocol audit completed: calibration=%d test=%d lambda=%.6g elapsed=%.3f s\n', ...
        result.calibration_rows,result.test_rows,result.selected_lambda,result.elapsed_s);
end

function [observed,true_views,theta]=make_observation(name,candidate,base,f,kind,s3,seed)
    theta=protocol_theta(name,base,seed);
    [true_views,~]=stage3a_compute_observations(f,candidate,base,theta,kind);
    measured=cellfun(@(x)x*theta.coupler_gain,true_views,'UniformOutput',false);
    observed=cell(1,numel(measured));
    for v=1:numel(measured)
        sym=stage3a_generate_symbol(s3.ofdm,1,seed+v);
        [rx,~]=stage3a_apply_ofdm_channel(sym,measured{v},s3.ofdm, ...
            struct('kind','white_awgn','snr_db',s3.stage3a2_snr_db), ...
            struct('channel_mode','circular_sampled_cfr'),seed+10*v);
        [~,observed{v},~]=stage3a_receive_ofdm(rx,sym,s3.ofdm,struct());
    end
    true_views=measured;
end

function theta=protocol_theta(name,base,seed)
    theta=nominal_theta(base);
    switch name
        case 'nominal_noise_20'
        case 'load_error_10'
            theta.branch_load_scale=1+0.1*(-1)^seed;
        case 'joint_bounded'
            old=rng;rng(seed,'twister');cleanup=onCleanup(@()rng(old)); %#ok<NASGU>
            theta.main_length_scale=0.98+0.04*rand;theta.branch_length_scale=0.98+0.04*rand;
            theta.branch_load_scale=0.90+0.20*rand;theta.kG_scale=0.98+0.04*rand;
            theta.R_scale=0.98+0.04*rand;theta.L_scale=0.98+0.04*rand;
            theta.G_scale=0.98+0.04*rand;theta.C_scale=0.98+0.04*rand;
            theta.source_impedance_ohm=49+2*rand;theta.receiver_impedance_ohm=49+2*rand;
            theta.coupler_gain=(0.98+0.04*rand)*exp(1i*(-pi/36+2*pi/36*rand));
        otherwise
            error('exp16_stage3a_2_protocol_audit:UnknownScenario','Unknown scenario %s.',name);
    end
    theta.perturbation_label=name;theta.regularization=0;
end

function theta=nominal_theta(base)
    theta=struct('main_length_scale',1,'branch_length_scale',1,'branch_load_scale',1,'kG_scale',1, ...
        'source_impedance_ohm',base.Zs,'receiver_impedance_ohm',base.Zr,'R_scale',1,'L_scale',1, ...
        'G_scale',1,'C_scale',1,'coupler_gain',1,'regularization',0,'perturbation_label','nominal');
end

function rec=make_record(split,scenario,kind,truth,candidates,match,observed,true_views,theta,audit,base,f,lambda,grid_size,seed,bounds,method)
    if nargin<17||isempty(method),method='nuisance_aware_joint';end
    if isfield(match,'best_distance')
        best=match.best_distance;second=match.second_best_distance;amb=logical(match.ambiguous);
    else
        best=min(match.scores);ordered=sort(match.scores);second=Inf;if numel(ordered)>1,second=ordered(2);end
        tied=find(match.scores<=best+audit.tie_tolerance*max(1,best));amb=numel(tied)>1;
    end
    pred=match.predicted_index;truth_class=audit.class_index(truth);pred_class=audit.class_index(pred);
    physical=audit.class_sizes(truth_class)>1;strict=pred==truth;class_ok=pred_class==truth_class;
    unique_ok=~amb&&~(audit.class_sizes(pred_class)>1);em=topology_evaluation_metrics(truth,pred,candidates,amb);
    if strcmp(method,'nuisance_aware_joint')
        theta_hat=match.theta_hat;objective=match.objective;param_reg=theta_hat.regularization;
    else
        theta_hat=nominal_theta(base);objective=best;param_reg=0;
    end
    cm=mean(cellfun(@(x,y)cfr_estimation_metrics(x,y).nmse,observed,true_views));
    rec=empty_record();rec.split=split;rec.scenario=scenario;rec.measurement_kind=kind;
    rec.observation_mode=stage3a_observation_config(kind).O;rec.method=method;
    rec.feature=feature_name(method);rec.snr_db=20;rec.trial=seed;rec.true_id=candidates(truth).id;
    rec.predicted_id=candidates(pred).id;rec.true_class=audit.class_labels{truth};rec.predicted_class=audit.class_labels{pred};
    rec.strict_correct=strict;rec.class_correct=class_ok;rec.strict_unique_correct=strict&&unique_ok;
    rec.unique_identification=unique_ok;rec.physically_ambiguous_class=physical;rec.ambiguous=amb;
    rec.false_unique=physical&&~amb;rec.best_distance=best;rec.second_best_distance=second;
    rec.distance_margin=second-best;rec.objective=objective;rec.cfr_nmse=cm;
    rec.theta_estimation_rmse=theta_error(theta_hat,theta,base);rec.theta_boundary_hit=theta_boundary_hit(theta_hat,bounds);
    rec.theta_true_label=theta.perturbation_label;rec.theta_hat_label=theta_hat.perturbation_label;
    rec.parameter_regularization=param_reg;rec.lambda=lambda;rec.grid_size=grid_size;rec.view_count=numel(observed);
    rec.frequency_count=numel(f);rec.edge_precision=em.edge_micro.precision;rec.edge_recall=em.edge_micro.recall;rec.edge_f1=em.edge_micro.f1;
    rec.seed=seed;rec.runtime_s=NaN;
end

function name=feature_name(method)
    if strcmp(method,'topology_only'),name='amplitude';else,name='amp_phase_joint_weighted';end
end

function e=theta_error(a,b,base)
    va=[a.main_length_scale,a.branch_length_scale,a.branch_load_scale,a.kG_scale,a.R_scale,a.L_scale,a.G_scale,a.C_scale, ...
        a.source_impedance_ohm/base.Zs,a.receiver_impedance_ohm/base.Zr,abs(a.coupler_gain),angle(a.coupler_gain)];
    vb=[b.main_length_scale,b.branch_length_scale,b.branch_load_scale,b.kG_scale,b.R_scale,b.L_scale,b.G_scale,b.C_scale, ...
        b.source_impedance_ohm/base.Zs,b.receiver_impedance_ohm/base.Zr,abs(b.coupler_gain),angle(b.coupler_gain)];
    e=sqrt(mean((va-vb).^2));
end

function hit=theta_boundary_hit(t,bounds)
    v=[t.main_length_scale,t.branch_length_scale,t.branch_load_scale,t.kG_scale,t.source_impedance_ohm,t.receiver_impedance_ohm,abs(t.coupler_gain),angle(t.coupler_gain)];
    b={bounds.main_length_scale,bounds.branch_length_scale,bounds.branch_load_scale,bounds.kG_scale,bounds.source_impedance_ohm,bounds.receiver_impedance_ohm,bounds.coupler_amplitude,bounds.coupler_phase_rad};
    hit=false;for k=1:numel(v),e=[min(b{k}),max(b{k})];hit=hit||any(abs(v(k)-e)<1e-12);end
end

function rows=select_lambda(records,lambda_grid)
    template=struct('split','calibration','lambda',0,'trials',0,'strict_accuracy',NaN,'equivalence_class_rate',NaN, ...
        'ambiguity_rate',NaN,'false_unique_rate',NaN,'mean_objective',NaN,'selected',false);
    rows=repmat(template,0,1);
    for l=lambda_grid
        x=records([records.lambda]==l);r=template;r.lambda=l;r.trials=numel(x);
        r.strict_accuracy=mean([x.strict_correct]);r.equivalence_class_rate=mean([x.class_correct]);
        r.ambiguity_rate=mean([x.ambiguous]);r.false_unique_rate=mean([x.false_unique]);r.mean_objective=mean([x.objective]);rows(end+1)=r; %#ok<AGROW>
    end
    key=[[rows.equivalence_class_rate].',[rows.strict_accuracy].',-[rows.ambiguity_rate].',-[rows.lambda].'];
    [~,order]=sortrows(key,[-1,-2,-3,-4]);rows(order(1)).selected=true;selected=rows(order(1)).lambda;
    [rows.selected_lambda]=deal(selected);
end

function r=empty_record()
    r=struct('split','','scenario','','measurement_kind','','observation_mode','','method','','feature','','snr_db',20,'trial',0, ...
        'true_id','','predicted_id','','true_class','','predicted_class','','strict_correct',false,'class_correct',false, ...
        'strict_unique_correct',false,'unique_identification',false,'physically_ambiguous_class',false,'ambiguous',false,'false_unique',false, ...
        'best_distance',NaN,'second_best_distance',NaN,'distance_margin',NaN,'objective',NaN,'cfr_nmse',NaN,'theta_estimation_rmse',NaN, ...
        'theta_boundary_hit',false,'theta_true_label','','theta_hat_label','','parameter_regularization',NaN,'lambda',NaN,'grid_size',0, ...
        'view_count',0,'frequency_count',0,'edge_precision',NaN,'edge_recall',NaN,'edge_f1',NaN,'seed',0,'runtime_s',NaN,'trial_label',0);
end

function rows=summarize(records)
    keys=arrayfun(@(x)sprintf('%s|%s|%s|%s|%g|%g',x.split,x.scenario,x.measurement_kind,x.method,x.lambda,x.snr_db),records,'UniformOutput',false);
    groups=unique(keys,'stable');rows=repmat(empty_summary(),0,1);
    for g=1:numel(groups)
        x=records(strcmp(keys,groups{g}));r=empty_summary();r.split=x(1).split;r.scenario=x(1).scenario;r.measurement_kind=x(1).measurement_kind;
        r.observation_mode=x(1).observation_mode;r.method=x(1).method;r.feature=x(1).feature;r.snr_db=x(1).snr_db;r.lambda=x(1).lambda;r.trials=numel(x);
        r.strict_accuracy=mean([x.strict_correct]);r.strict_unique_rate=mean([x.strict_unique_correct]);r.equivalence_class_rate=mean([x.class_correct]);
        r.ambiguity_rate=mean([x.ambiguous]);r.false_unique_rate=mean([x.false_unique]);r.cfr_nmse=mean([x.cfr_nmse]);
        r.theta_rmse=mean([x.theta_estimation_rmse]);r.theta_boundary_rate=mean([x.theta_boundary_hit]);r.edge_precision=mean([x.edge_precision]);
        r.edge_recall=mean([x.edge_recall]);r.edge_f1=mean([x.edge_f1]);r.mean_margin=mean([x.distance_margin]);r.view_count=x(1).view_count;
        r.frequency_count=x(1).frequency_count;rows(end+1)=r; %#ok<AGROW>
    end
end

function r=empty_summary()
    r=struct('split','','scenario','','measurement_kind','','observation_mode','','method','','feature','','snr_db',20,'lambda',NaN,'trials',0, ...
        'strict_accuracy',NaN,'strict_unique_rate',NaN,'equivalence_class_rate',NaN,'ambiguity_rate',NaN,'false_unique_rate',NaN,'cfr_nmse',NaN, ...
        'theta_rmse',NaN,'theta_boundary_rate',NaN,'edge_precision',NaN,'edge_recall',NaN,'edge_f1',NaN,'mean_margin',NaN,'view_count',0,'frequency_count',0);
end

function rows=make_confusion(records)
    rows=repmat(struct('split','test','scenario','','measurement_kind','','method','','feature','','true_id','','predicted_id','','count',0),0,1);
    for k=1:numel(records)
        x=records(k);hit=find(arrayfun(@(z)strcmp(z.scenario,x.scenario)&&strcmp(z.measurement_kind,x.measurement_kind)&&strcmp(z.method,x.method)&&strcmp(z.true_id,x.true_id)&&strcmp(z.predicted_id,x.predicted_id),rows),1);
        if isempty(hit),rows(end+1)=struct('split','test','scenario',x.scenario,'measurement_kind',x.measurement_kind,'method',x.method,'feature',x.feature,'true_id',x.true_id,'predicted_id',x.predicted_id,'count',1); %#ok<AGROW>
        else,rows(hit).count=rows(hit).count+1;end
    end
end

function rows=make_config_rows(s3,kinds,scenarios,grid,bounds,selected,calibration_trials,test_trials)
    template=struct('split','','scenario','','measurement_kind','','snr_db',20,'calibration_trials',0,'test_trials',0,'grid_size',0,'lambda_grid','','selected_lambda',0,'nfft',0,'sample_rate_hz',0,'cp_samples',0,'frequency_count',0,'random_seed_base',0,'seed_offset',0,'parameter_bounds_note','');
    rows=repmat(template,0,1);
    note=sprintf('main=[%.3g,%.3g];branch=[%.3g,%.3g];load=[%.3g,%.3g];Zs=[%.3g,%.3g];Zr=[%.3g,%.3g]',bounds.main_length_scale(1),bounds.main_length_scale(end),bounds.branch_length_scale(1),bounds.branch_length_scale(end),bounds.branch_load_scale(1),bounds.branch_load_scale(end),bounds.source_impedance_ohm(1),bounds.source_impedance_ohm(end),bounds.receiver_impedance_ohm(1),bounds.receiver_impedance_ohm(end));
    lambda_text=strjoin(arrayfun(@(x)sprintf('%.6g',x),s3.stage3a2_lambda_grid,'UniformOutput',false),';');
    for split={'calibration','test'}
        split_name=split{1};offset=s3.stage3a2_calibration_seed_offset;if strcmp(split_name,'test'),offset=s3.stage3a2_test_seed_offset;end
        trials=s3.stage3a2_calibration_trials;if strcmp(split_name,'test'),trials=s3.stage3a2_test_trials;end
        for si=1:numel(scenarios),for ki=1:numel(kinds)
            r=template;r.split=split_name;r.scenario=scenarios{si};r.measurement_kind=kinds{ki};r.snr_db=s3.stage3a2_snr_db;r.calibration_trials=calibration_trials;r.test_trials=test_trials;r.grid_size=numel(grid);r.lambda_grid=lambda_text;r.selected_lambda=selected;r.nfft=s3.ofdm.nfft;r.sample_rate_hz=s3.ofdm.sample_rate_hz;r.cp_samples=s3.ofdm.cyclic_prefix_samples;r.frequency_count=s3.ofdm.num_active_subcarriers;r.random_seed_base=s3.random_seed;r.seed_offset=offset;r.parameter_bounds_note=note;rows(end+1)=r; %#ok<AGROW>
        end,end
    end
end

function make_figures(summary,selection,base,prefix,kinds)
    z=summary(strcmp({summary.split},'test')&strcmp({summary.method},'nuisance_aware_joint')&strcmp({summary.scenario},'nominal_noise_20'));
    vals=zeros(1,numel(kinds));for k=1:numel(kinds),q=z(strcmp({z.measurement_kind},kinds{k}));if ~isempty(q),vals(k)=q(1).strict_unique_rate;end,end
    figure('Visible','off');bar(vals);ylim([0 1]);grid on;set(gca,'XTick',1:numel(kinds),'XTickLabel',strrep(kinds,'_',' '),'XTickLabelRotation',25);ylabel('strict unique rate');title('Stage 3A.2 independent test observation protocol');
    print(gcf,fullfile(base.results_figures,[prefix '_observation_protocol.png']),'-dpng','-r120');close(gcf);
    figure('Visible','off');bar([selection.lambda],[selection.strict_accuracy]);grid on;xlabel('lambda');ylabel('calibration strict accuracy');title('Stage 3A.2 calibration-only lambda selection');
    print(gcf,fullfile(base.results_figures,[prefix '_calibration_selection.png']),'-dpng','-r120');close(gcf);
end
