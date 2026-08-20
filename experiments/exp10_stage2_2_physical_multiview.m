function exp10_stage2_2_physical_multiview(cfg)
%EXP10_STAGE2_2_PHYSICAL_MULTIVIEW Physical multiview and joint inversion.
%   All CFR views are solved on one complete distributed-line tree. The
%   OFDM layer remains Y=XH+N with LS pilots; this is not a complete modem.

    ensure_result_dirs(cfg); total_clock=tic; s=cfg.stage2_2; ocfg=cfg.ofdm;
    pilot=ofdm_generate_pilot(ocfg); all_candidates=topology_candidates(cfg);
    candidates=all_candidates(s.candidate_indices); f=ocfg.pilot_frequency_hz;
    grid=topology_parameter_grid(s.search); nominal=grid([grid.regularization]==0);
    if numel(nominal)~=1,error('exp10:NominalGrid','Parameter grid needs one nominal point.');end
    fprintf('EXP10 stage 2.2: %d candidates, %d pilots, %d grid points/topology, %d trials\n', ...
        numel(candidates),numel(f),numel(grid),s.monte_carlo_trials);

    physical=physical_audit(f,candidates,nominal,cfg,ocfg,s);
    main_kinds={'siso_forward','three_view_complete'};
    libraries=cell(1,numel(main_kinds)); nominal_refs=cell(1,numel(main_kinds));
    for k=1:numel(main_kinds)
        fprintf('  building %s parameter library...\n',main_kinds{k});
        raw_library=topology_parameter_library(f,candidates,grid,main_kinds{k},cfg);
        libraries{k}=topology_prepare_parameter_library(raw_library);
        nominal_refs{k}=topology_parameter_library(f,candidates,nominal,main_kinds{k},cfg);
    end
    noise_rows=run_noise_statistics(candidates,main_kinds,libraries,nominal_refs, ...
        nominal,pilot,cfg,ocfg,s);
    parameter_rows=run_parameter_statistics(candidates,main_kinds,libraries, ...
        nominal_refs,pilot,cfg,ocfg,s);
    sweep_rows=run_parameter_sweeps(candidates,main_kinds,libraries,nominal_refs, ...
        nominal,cfg,ocfg,s);
    feature_rows=run_feature_threshold_audit(candidates,nominal_refs{2},nominal, ...
        pilot,cfg,ocfg,s);
    all_rows=[noise_rows,parameter_rows];
    summary=aggregate_rows(all_rows,candidates);
    confusion=aggregate_confusion(all_rows,candidates);

    write_physical_csv(fullfile(cfg.results_data,'stage2_2_physical_audit.csv'),physical);
    write_trial_csv(fullfile(cfg.results_data,'stage2_2_trials.csv'),all_rows);
    write_summary_csv(fullfile(cfg.results_data,'stage2_2_summary.csv'),summary);
    write_confusion_csv(fullfile(cfg.results_data,'stage2_2_confusion.csv'),confusion);
    write_sweep_csv(fullfile(cfg.results_data,'stage2_2_parameter_sweeps.csv'),sweep_rows);
    write_feature_csv(fullfile(cfg.results_data,'stage2_2_feature_audit.csv'),feature_rows);
    write_config(fullfile(cfg.results_data,'stage2_2_config.csv'),cfg,grid);
    plot_results(summary,physical,sweep_rows,cfg);
    elapsed=toc(total_clock);
    write_text(fullfile(cfg.results_data,'stage2_2_summary.txt'),cfg,candidates, ...
        physical,summary,elapsed,numel(grid));
    save(fullfile(cfg.results_data,'stage2_2_results.mat'),'cfg','candidates','grid', ...
        'nominal','physical','noise_rows','parameter_rows','sweep_rows', ...
        'feature_rows','summary','confusion','elapsed','-v7.3');
    fprintf('EXP10 stage 2.2 completed in %.3f s; raw trial rows=%d.\n',elapsed,numel(all_rows));
end

function rows=physical_audit(f,candidates,theta,cfg,ocfg,s)
    kinds={'siso_forward','siso_forward_asymmetric','siso_reverse_role_fixed','siso_reverse_endpoint_fixed', ...
        'bidirectional_endpoint_fixed','dual_receiver_complete','three_view_complete'};
    asym=theta; asym.source_impedance_ohm=50; asym.receiver_impedance_ohm=75;
    rows=repmat(physical_row(),0,1);
    for k=1:numel(kinds)
        use=theta;if contains(kinds{k},'asymmetric')||contains(kinds{k},'reverse')||contains(kinds{k},'bidirectional'),use=asym;end
        refs=topology_parameter_library(f,candidates,use,kinds{k},cfg);
        groups={candidates.observability_group}; pred=zeros(1,numel(candidates));tie=false(size(pred));
        t35=NaN;
        for t=1:numel(candidates)
            r=topology_multiview_match(refs(t).views,{refs.views},'complex',ocfg, ...
                s.joint_weights,cfg.stage2.tie_tolerance,groups);
            pred(t)=r.predicted_index;tie(t)=r.ambiguous;
        end
        i3=find(strcmp({candidates.id},'T3'));i5=find(strcmp({candidates.id},'T5'));
        if ~isempty(i3)&&~isempty(i5)
            d=zeros(1,numel(refs(i3).views));
            for v=1:numel(d),d(v)=topology_feature_distance(refs(i3).views{v},refs(i5).views{v},'complex',ocfg,s.joint_weights);end
            t35=sqrt(mean(d.^2));
        end
        e=topology_evaluation_metrics(1:numel(candidates),pred,candidates,tie);
        [~,meta]=plc_measurement_bundle(kinds{k},candidates(1).network,use,cfg);
        row=physical_row();row.scenario=kinds{k};row.view_count=numel(refs(1).views);
        row.strict_accuracy=e.accuracy;row.group_accuracy=e.group_accuracy;
        row.unique_strict_accuracy=mean((pred==(1:numel(candidates)))&~tie);
        row.numeric_tie_rate=e.numeric_tie_rate;row.t3_t5_distance=t35;
        row.Zs_ohm=use.source_impedance_ohm;row.Zr_ohm=use.receiver_impedance_ohm;
        row.network_truncated=meta.network_is_truncated;row.result_class='ideal_noiseless_model';
        rows(end+1)=row; %#ok<AGROW>
    end
end

function rows=run_noise_statistics(candidates,kinds,libraries,nominal_refs,theta,pilot,cfg,ocfg,s)
    rows=repmat(trial_row(),0,1); groups={candidates.observability_group};
    for vk=1:numel(kinds)
        ref_power=view_reference_power(nominal_refs{vk}(s.reference_noise_topology_index).views,pilot.X);
        for m=1:numel(s.noise_modes)
            for si=1:numel(s.snr_db)
                for trial=1:s.monte_carlo_trials
                    for t=1:numel(candidates)
                        seed=cfg.random_seed+4200000+vk*1000000+m*100000+si*10000+trial*100+t;
                        [obs,est]=noisy_views(nominal_refs{vk}(t).views,pilot,s.snr_db(si), ...
                            seed,s.noise_modes{m},ref_power);
                        matches=three_methods(obs,nominal_refs{vk},nominal_refs{vk},libraries{vk}, ...
                            s,cfg,ocfg,groups,theta);
                        rows=append_method_rows(rows,'noise_only',s.noise_modes{m}, ...
                            kinds{vk},s.snr_db(si),trial,t,candidates,theta,matches,est);
                    end
                end
            end
        end
    end
end

function rows=run_parameter_statistics(candidates,kinds,libraries,nominal_refs,pilot,cfg,ocfg,s)
    rows=repmat(trial_row(),0,1);groups={candidates.observability_group};snr=s.audit_snr_db;
    for vk=1:numel(kinds)
        ref_power=view_reference_power(nominal_refs{vk}(s.reference_noise_topology_index).views,pilot.X);
        for m=1:numel(s.noise_modes)
            for trial=1:s.monte_carlo_trials
                for t=1:numel(candidates)
                    seed=cfg.random_seed+5200000+vk*1000000+m*100000+trial*100+t;
                    theta=random_theta(seed,s);theta.regularization=0;
                    [net,local]=topology_apply_parameters(candidates(t).network,cfg,theta);
                    meas=plc_measurement_bundle(kinds{vk},net,theta,local);
                    true_views=plc_multiview_response(ocfg.pilot_frequency_hz,net,meas,local);
                    [obs,est]=noisy_views(true_views,pilot,snr,seed+33,s.noise_modes{m},ref_power);
                    oracle=topology_parameter_library(ocfg.pilot_frequency_hz,candidates,theta,kinds{vk},cfg);
                    matches=three_methods(obs,oracle,nominal_refs{vk},libraries{vk},s,cfg,ocfg,groups,theta);
                    rows=append_method_rows(rows,'joint_parameter_uncertainty',s.noise_modes{m}, ...
                        kinds{vk},snr,trial,t,candidates,theta,matches,est);
                end
            end
        end
    end
end

function rows=run_parameter_sweeps(candidates,kinds,libraries,nominal_refs,nominal,cfg,ocfg,s)
    definitions={ ...
        'main_length_-1pct',struct('main_length_scale',.99); ...
        'main_length_+1pct',struct('main_length_scale',1.01); ...
        'main_length_-2pct',struct('main_length_scale',.98); ...
        'main_length_+2pct',struct('main_length_scale',1.02); ...
        'main_length_-5pct',struct('main_length_scale',.95); ...
        'main_length_+5pct',struct('main_length_scale',1.05); ...
        'branch_length_-1pct',struct('branch_length_scale',.99); ...
        'branch_length_+1pct',struct('branch_length_scale',1.01); ...
        'branch_length_-2pct',struct('branch_length_scale',.98); ...
        'branch_length_+2pct',struct('branch_length_scale',1.02); ...
        'branch_length_-5pct',struct('branch_length_scale',.95); ...
        'branch_length_+5pct',struct('branch_length_scale',1.05); ...
        'all_length_-5pct',struct('main_length_scale',.95,'branch_length_scale',.95); ...
        'all_length_+5pct',struct('main_length_scale',1.05,'branch_length_scale',1.05); ...
        'load_-10pct',struct('branch_load_scale',.9); ...
        'load_+10pct',struct('branch_load_scale',1.1); ...
        'load_-20pct',struct('branch_load_scale',.8); ...
        'load_+20pct',struct('branch_load_scale',1.2); ...
        'load_Canete_RLC_simulation',struct('load_model','canete_rlc'); ...
        'kG_-5pct',struct('kG_scale',.95); ...
        'kG_+5pct',struct('kG_scale',1.05); ...
        'endpoint_45_55',struct('source_impedance_ohm',45,'receiver_impedance_ohm',55); ...
        'endpoint_55_45',struct('source_impedance_ohm',55,'receiver_impedance_ohm',45)};
    rows=repmat(sweep_row(),0,1);groups={candidates.observability_group};
    for vk=1:numel(kinds)
        for q=1:size(definitions,1)
            theta=merge_theta(nominal,definitions{q,2});
            obs=cell(1,numel(candidates));
            for t=1:numel(candidates)
                [net,local]=topology_apply_parameters(candidates(t).network,cfg,theta);
                net=apply_special_load(net,theta,ocfg.pilot_frequency_hz,cfg);
                meas=plc_measurement_bundle(kinds{vk},net,theta,local);
                obs{t}=plc_multiview_response(ocfg.pilot_frequency_hz,net,meas,local);
            end
            pred=zeros(1,numel(candidates));intra=zeros(size(pred));inter=zeros(size(pred));
            for t=1:numel(candidates)
                r=topology_joint_match(obs{t},libraries{vk},s.matching_feature,ocfg, ...
                    s.joint_weights,s.regularization_lambda);
                pred(t)=r.predicted_index;
                [intra(t),inter(t)]=joint_intra_inter(r,libraries{vk},t);
            end
            e=topology_evaluation_metrics(1:numel(candidates),pred,candidates);
            row=sweep_row();row.scenario=definitions{q,1};row.view_kind=kinds{vk};
            row.method='joint';row.strict_accuracy=e.accuracy;row.group_accuracy=e.group_accuracy;
            row.intra_distance=mean(intra);row.inter_distance=mean(inter);row.intra_inter_ratio=mean(intra)/mean(inter);
            row.result_class='ideal_noiseless_parameter_sweep';
            rows(end+1)=row; %#ok<AGROW>
        end
    end
end

function rows=run_feature_threshold_audit(candidates,refs,theta,pilot,cfg,ocfg,s)
    rows=repmat(feature_row(),0,1); ntrial=min(10,s.monte_carlo_trials);groups={candidates.observability_group};
    observations={};truth=[];
    ref_power=view_reference_power(refs(s.reference_noise_topology_index).views,pilot.X);
    for trial=1:ntrial,for t=1:numel(candidates)
        seed=cfg.random_seed+6200000+trial*100+t;
        [o,~]=noisy_views(refs(t).views,pilot,s.audit_snr_db,seed,'fixed_received_snr',ref_power);
        observations{end+1}=o;truth(end+1)=t; %#ok<AGROW>
    end,end
    settings={};
    base={'amplitude','amplitude_raw_db','amplitude_db_standardized','phase_weighted','complex'};
    for k=1:numel(base),settings(end+1,:)={base{k},.5,.5,-40};end %#ok<AGROW>
    for th=s.phase_mask_thresholds_db,settings(end+1,:)={'phase_masked',.5,.5,th};end %#ok<AGROW>
    for w=1:size(s.joint_weight_scan,1),settings(end+1,:)={'amp_phase_joint_weighted',s.joint_weight_scan(w,1),s.joint_weight_scan(w,2),-40};end %#ok<AGROW>
    for q=1:size(settings,1)
        pred=zeros(size(truth));
        for k=1:numel(truth)
            r=topology_multiview_match(observations{k},{refs.views},settings{q,1},ocfg, ...
                [settings{q,2},settings{q,3}],cfg.stage2.tie_tolerance,groups, ...
                struct('phase_mask_threshold_db',settings{q,4}));
            pred(k)=r.predicted_index;
        end
        e=topology_evaluation_metrics(truth,pred,candidates);
        row=feature_row();row.feature=settings{q,1};row.weight_amplitude=settings{q,2};
        row.weight_phase=settings{q,3};row.phase_threshold_db=settings{q,4};
        row.sample_count=numel(truth);row.strict_accuracy=e.accuracy;row.group_accuracy=e.group_accuracy;
        row.snr_db=s.audit_snr_db;row.noise_mode='fixed_received_snr';
        row.result_class='noisy_equivalent_pilot_measurement';
        rows(end+1)=row; %#ok<AGROW>
    end
end

function matches=three_methods(obs,oracle_refs,nominal_refs,library,s,cfg,ocfg,groups,true_theta)
    oracle=topology_multiview_match(obs,{oracle_refs.views},s.matching_feature,ocfg, ...
        s.joint_weights,cfg.stage2.tie_tolerance,groups);
    joint=topology_joint_match(obs,library,s.matching_feature,ocfg,s.joint_weights,s.regularization_lambda);
    baseline=topology_multiview_match(obs,{nominal_refs.views},s.single_feature_baseline,ocfg, ...
        s.joint_weights,cfg.stage2.tie_tolerance,groups);
    matches=struct('name',{'oracle','joint','single_feature'}, ...
        'result',{oracle,joint,baseline},'theta_hat',{true_theta,joint.theta_hat,struct()});
end

function rows=append_method_rows(rows,experiment,mode,kind,snr,trial,t,candidates,theta,matches,est)
    for k=1:numel(matches)
        r=trial_row();r.experiment=experiment;r.noise_mode=mode;r.view_kind=kind;r.snr_db=snr;
        r.trial=trial;r.true_index=t;r.true_id=candidates(t).id;r.method=matches(k).name;
        r.predicted_index=matches(k).result.predicted_index;r.predicted_id=candidates(r.predicted_index).id;
        r.correct=r.predicted_index==t;r.group_correct=strcmp(candidates(t).observability_group,candidates(r.predicted_index).observability_group);
        r.nmse=est.nmse;r.amplitude_rmse_db=est.amplitude_rmse_db;r.weighted_phase_rmse_deg=est.weighted_phase_rmse_deg;
        if strcmp(matches(k).name,'joint')
            [r.intra_distance,r.inter_distance]=joint_intra_inter(matches(k).result,[],t);
            [r.length_error_m,r.main_length_error_m,r.branch_length_error_m]= ...
                physical_length_errors(candidates(t).network,matches(k).theta_hat,theta);
            r.load_relative_error=matches(k).theta_hat.branch_load_scale-theta.branch_load_scale;
            r.Zs_error_ohm=matches(k).theta_hat.source_impedance_ohm-theta.source_impedance_ohm;
            r.Zr_error_ohm=matches(k).theta_hat.receiver_impedance_ohm-theta.receiver_impedance_ohm;
        else
            scores=matches(k).result.scores;r.intra_distance=scores(t);scores(t)=Inf;r.inter_distance=min(scores);
            if strcmp(matches(k).name,'oracle'),r.length_error_m=0;r.main_length_error_m=0;r.branch_length_error_m=0;r.load_relative_error=0;r.Zs_error_ohm=0;r.Zr_error_ohm=0;end
        end
        rows(end+1)=r; %#ok<AGROW>
    end
end

function [intra,inter]=joint_intra_inter(result,library,truth)
    if isempty(library)
        ids=result.template_topology_indices;
        intra=min(result.data_distances(ids==truth));other=result.data_distances;other(ids==truth)=Inf;inter=min(other);
    else
        if isfield(library,'is_prepared_parameter_library'),ids=library.topology_indices;else,ids=[library.topology_index];end
        intra=min(result.data_distances(ids==truth));inter=min(result.data_distances(ids~=truth));
    end
end

function [obs,metrics]=noisy_views(true_views,pilot,snr,seed,mode,reference_power)
    obs=cell(size(true_views)); allm=cell(1,numel(true_views));
    for v=1:numel(true_views)
        if strcmp(mode,'fixed_noise_power')
            [Y,~]=ofdm_apply_channel(pilot.X,true_views{v},snr,seed+v,mode,reference_power(v));
        else
            [Y,~]=ofdm_apply_channel(pilot.X,true_views{v},snr,seed+v,mode);
        end
        obs{v}=ofdm_channel_estimate_ls(pilot.X,Y);
        allm{v}=cfr_estimation_metrics(obs{v},true_views{v});
    end
    nmse=cellfun(@(x)x.nmse,allm);amp=cellfun(@(x)x.amplitude_rmse_db,allm);
    phase=cellfun(@(x)x.weighted_phase_rmse_deg,allm);
    metrics=struct('nmse',mean(nmse),'amplitude_rmse_db',mean(amp), ...
        'weighted_phase_rmse_deg',mean(phase));
end

function p=view_reference_power(views,X)
    p=zeros(1,numel(views));for v=1:numel(views),p(v)=mean(abs(X.*views{v}).^2);end
end
function theta=random_theta(seed,s)
    old=rng;cleanup=onCleanup(@()rng(old)); %#ok<NASGU>
    rng(seed,'twister');theta=struct();
    theta.main_length_scale=uniform(s.true_main_length_scale_range);
    theta.branch_length_scale=uniform(s.true_branch_length_scale_range);
    theta.branch_load_scale=uniform(s.true_load_scale_range);
    theta.source_impedance_ohm=uniform(s.true_Zs_range_ohm);
    theta.receiver_impedance_ohm=uniform(s.true_Zr_range_ohm);
    theta.kG_scale=uniform(s.true_kG_scale_range);
end
function x=uniform(range),x=range(1)+(range(2)-range(1))*rand;end
function out=merge_theta(base,extra),out=base;fields=fieldnames(extra);for k=1:numel(fields),out.(fields{k})=extra.(fields{k});end;end

function net=apply_special_load(net,theta,f,cfg)
    if isfield(theta,'load_model')&&strcmp(theta.load_model,'canete_rlc')
        % Literature-form simulation load; these are not field measurements.
        Z=parallel_rlc_load(f,cfg.topology.branch_load_ohm,5,15e6);
        for b=1:numel(net.branches),net.branches(b).load=Z;end
    end
end

function [all_rmse,main_rmse,branch_rmse]=physical_length_errors(net,estimate,truth)
    dm=estimate.main_length_scale-truth.main_length_scale;
    db=estimate.branch_length_scale-truth.branch_length_scale;
    main_errors=net.main_lengths(:)*dm;
    branch_lengths=zeros(numel(net.branches),1);
    for b=1:numel(net.branches),branch_lengths(b)=net.branches(b).length;end
    branch_errors=branch_lengths*db;
    main_rmse=sqrt(mean(main_errors.^2));
    if isempty(branch_errors),branch_rmse=NaN;else,branch_rmse=sqrt(mean(branch_errors.^2));end
    all_rmse=sqrt(mean([main_errors;branch_errors].^2));
end

function summary=aggregate_rows(rows,candidates)
    keys=cell(1,numel(rows));for k=1:numel(rows),keys{k}=sprintf('%s|%s|%s|%g|%s',rows(k).experiment,rows(k).noise_mode,rows(k).view_kind,rows(k).snr_db,rows(k).method);end
    unique_keys=unique(keys,'stable');summary=repmat(summary_row(),0,1);
    for q=1:numel(unique_keys)
        ix=find(strcmp(keys,unique_keys{q}));r=rows(ix);trials=unique([r.trial]);acc=zeros(size(trials));grp=acc;
        for z=1:numel(trials),hit=[r.trial]==trials(z);acc(z)=mean([r(hit).correct]);grp(z)=mean([r(hit).group_correct]);end
        row=summary_row();row.experiment=r(1).experiment;row.noise_mode=r(1).noise_mode;row.view_kind=r(1).view_kind;row.snr_db=r(1).snr_db;row.method=r(1).method;
        row.sample_count=numel(r);row.trial_count=numel(trials);[row.accuracy_mean,row.accuracy_std,row.accuracy_ci_low,row.accuracy_ci_high]=stats(acc);
        [row.group_accuracy_mean,row.group_accuracy_std,row.group_accuracy_ci_low,row.group_accuracy_ci_high]=stats(grp);
        e=topology_evaluation_metrics([r.true_index],[r.predicted_index],candidates);row.edge_precision=e.edge_micro.precision;row.edge_recall=e.edge_micro.recall;row.edge_f1=e.edge_micro.f1;
        row.nmse=mean([r.nmse]);row.amplitude_rmse_db=mean([r.amplitude_rmse_db]);row.weighted_phase_rmse_deg=mean([r.weighted_phase_rmse_deg]);
        row.intra_distance=finite_mean([r.intra_distance]);row.inter_distance=finite_mean([r.inter_distance]);row.intra_inter_ratio=row.intra_distance/row.inter_distance;
        row.length_rmse_m=sqrt(finite_mean([r.length_error_m].^2));row.main_length_rmse_m=sqrt(finite_mean([r.main_length_error_m].^2));row.branch_length_rmse_m=sqrt(finite_mean([r.branch_length_error_m].^2));row.load_relative_rmse=sqrt(finite_mean([r.load_relative_error].^2));
        row.Zs_rmse_ohm=sqrt(finite_mean([r.Zs_error_ohm].^2));row.Zr_rmse_ohm=sqrt(finite_mean([r.Zr_error_ohm].^2));summary(end+1)=row; %#ok<AGROW>
    end
end
function confusion=aggregate_confusion(rows,candidates)
    keys=cell(1,numel(rows));
    for k=1:numel(rows),keys{k}=sprintf('%s|%s|%s|%g|%s',rows(k).experiment,rows(k).noise_mode,rows(k).view_kind,rows(k).snr_db,rows(k).method);end
    unique_keys=unique(keys,'stable');confusion=repmat(confusion_row(),0,1);
    for q=1:numel(unique_keys)
        selected=rows(strcmp(keys,unique_keys{q}));
        for t=1:numel(candidates),for p=1:numel(candidates)
            row=confusion_row();row.experiment=selected(1).experiment;
            row.noise_mode=selected(1).noise_mode;row.view_kind=selected(1).view_kind;
            row.snr_db=selected(1).snr_db;row.method=selected(1).method;
            row.true_id=candidates(t).id;row.predicted_id=candidates(p).id;
            row.count=sum([selected.true_index]==t & [selected.predicted_index]==p);
            confusion(end+1)=row; %#ok<AGROW>
        end,end
    end
end
function [mu,sd,lo,hi]=stats(x),mu=mean(x);sd=std(x,0);half=1.96*sd/sqrt(numel(x));lo=max(0,mu-half);hi=min(1,mu+half);end
function x=finite_mean(x),x=x(isfinite(x));if isempty(x),x=NaN;else,x=mean(x);end;end

function r=trial_row(),r=struct('experiment','','noise_mode','','view_kind','','snr_db',NaN,'trial',0,'true_index',0,'true_id','','method','','predicted_index',0,'predicted_id','','correct',false,'group_correct',false,'nmse',NaN,'amplitude_rmse_db',NaN,'weighted_phase_rmse_deg',NaN,'intra_distance',NaN,'inter_distance',NaN,'length_error_m',NaN,'main_length_error_m',NaN,'branch_length_error_m',NaN,'load_relative_error',NaN,'Zs_error_ohm',NaN,'Zr_error_ohm',NaN);end
function r=summary_row(),r=struct('experiment','','noise_mode','','view_kind','','snr_db',NaN,'method','','sample_count',0,'trial_count',0,'accuracy_mean',NaN,'accuracy_std',NaN,'accuracy_ci_low',NaN,'accuracy_ci_high',NaN,'group_accuracy_mean',NaN,'group_accuracy_std',NaN,'group_accuracy_ci_low',NaN,'group_accuracy_ci_high',NaN,'edge_precision',NaN,'edge_recall',NaN,'edge_f1',NaN,'nmse',NaN,'amplitude_rmse_db',NaN,'weighted_phase_rmse_deg',NaN,'intra_distance',NaN,'inter_distance',NaN,'intra_inter_ratio',NaN,'length_rmse_m',NaN,'main_length_rmse_m',NaN,'branch_length_rmse_m',NaN,'load_relative_rmse',NaN,'Zs_rmse_ohm',NaN,'Zr_rmse_ohm',NaN);end
function r=physical_row(),r=struct('scenario','','view_count',0,'Zs_ohm',NaN,'Zr_ohm',NaN,'strict_accuracy',NaN,'unique_strict_accuracy',NaN,'group_accuracy',NaN,'numeric_tie_rate',NaN,'t3_t5_distance',NaN,'network_truncated',false,'result_class','');end
function r=sweep_row(),r=struct('scenario','','view_kind','','method','','strict_accuracy',NaN,'group_accuracy',NaN,'intra_distance',NaN,'inter_distance',NaN,'intra_inter_ratio',NaN,'result_class','');end
function r=feature_row(),r=struct('feature','','weight_amplitude',NaN,'weight_phase',NaN,'phase_threshold_db',NaN,'snr_db',NaN,'noise_mode','','sample_count',0,'strict_accuracy',NaN,'group_accuracy',NaN,'result_class','');end
function r=confusion_row(),r=struct('experiment','','noise_mode','','view_kind','','snr_db',NaN,'method','','true_id','','predicted_id','','count',0);end

function write_physical_csv(file,r),fid=fopen(file,'w');fprintf(fid,'scenario,view_count,Zs_ohm,Zr_ohm,strict_accuracy,unique_strict_accuracy,group_accuracy,numeric_tie_rate,t3_t5_distance,network_truncated,result_class\n');for x=r,fprintf(fid,'%s,%d,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%d,%s\n',x.scenario,x.view_count,x.Zs_ohm,x.Zr_ohm,x.strict_accuracy,x.unique_strict_accuracy,x.group_accuracy,x.numeric_tie_rate,x.t3_t5_distance,x.network_truncated,x.result_class);end;fclose(fid);end
function write_trial_csv(file,r),fid=fopen(file,'w');fprintf(fid,'experiment,noise_mode,view_kind,snr_db,trial,true_id,method,predicted_id,correct,group_correct,nmse,amplitude_rmse_db,weighted_phase_rmse_deg,intra_distance,inter_distance,length_error_m,main_length_error_m,branch_length_error_m,load_relative_error,Zs_error_ohm,Zr_error_ohm\n');for x=r,fprintf(fid,'%s,%s,%s,%.17g,%d,%s,%s,%s,%d,%d,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g\n',x.experiment,x.noise_mode,x.view_kind,x.snr_db,x.trial,x.true_id,x.method,x.predicted_id,x.correct,x.group_correct,x.nmse,x.amplitude_rmse_db,x.weighted_phase_rmse_deg,x.intra_distance,x.inter_distance,x.length_error_m,x.main_length_error_m,x.branch_length_error_m,x.load_relative_error,x.Zs_error_ohm,x.Zr_error_ohm);end;fclose(fid);end
function write_summary_csv(file,r),fid=fopen(file,'w');names=fieldnames(r);fprintf(fid,'%s',names{1});for k=2:numel(names),fprintf(fid,',%s',names{k});end;fprintf(fid,'\n');for x=r,for k=1:numel(names),if k>1,fprintf(fid,',');end;value=x.(names{k});if ischar(value),fprintf(fid,'%s',value);else,fprintf(fid,'%.17g',value);end;end;fprintf(fid,'\n');end;fclose(fid);end
function write_confusion_csv(file,r),fid=fopen(file,'w');fprintf(fid,'experiment,noise_mode,view_kind,snr_db,method,true_id,predicted_id,count\n');for x=r,fprintf(fid,'%s,%s,%s,%.17g,%s,%s,%s,%d\n',x.experiment,x.noise_mode,x.view_kind,x.snr_db,x.method,x.true_id,x.predicted_id,x.count);end;fclose(fid);end
function write_sweep_csv(file,r),fid=fopen(file,'w');fprintf(fid,'scenario,view_kind,method,strict_accuracy,group_accuracy,intra_distance,inter_distance,intra_inter_ratio,result_class\n');for x=r,fprintf(fid,'%s,%s,%s,%.17g,%.17g,%.17g,%.17g,%.17g,%s\n',x.scenario,x.view_kind,x.method,x.strict_accuracy,x.group_accuracy,x.intra_distance,x.inter_distance,x.intra_inter_ratio,x.result_class);end;fclose(fid);end
function write_feature_csv(file,r),fid=fopen(file,'w');fprintf(fid,'feature,weight_amplitude,weight_phase,phase_threshold_db,snr_db,noise_mode,sample_count,strict_accuracy,group_accuracy,result_class\n');for x=r,fprintf(fid,'%s,%.17g,%.17g,%.17g,%.17g,%s,%d,%.17g,%.17g,%s\n',x.feature,x.weight_amplitude,x.weight_phase,x.phase_threshold_db,x.snr_db,x.noise_mode,x.sample_count,x.strict_accuracy,x.group_accuracy,x.result_class);end;fclose(fid);end
function write_config(file,cfg,grid),fid=fopen(file,'w');fprintf(fid,'parameter,value\nMATLAB_version,%s\nrandom_seed,%d\nNFFT,%d\nFs_hz,%.17g\npilot_count,%d\nfrequency_low_hz,%.17g\nfrequency_high_hz,%.17g\ntrials,%d\ngrid_points_per_topology,%d\nlambda,%.17g\n',version,cfg.random_seed,cfg.ofdm.nfft,cfg.ofdm.sample_rate_hz,cfg.ofdm.num_pilots,cfg.ofdm.frequency_band_hz(1),cfg.ofdm.frequency_band_hz(2),cfg.stage2_2.monte_carlo_trials,numel(grid),cfg.stage2_2.regularization_lambda);fclose(fid);end

function plot_results(summary,physical,sweeps,cfg)
    hit=strcmp({summary.experiment},'noise_only')&strcmp({summary.noise_mode},'fixed_received_snr');r=summary(hit);figure('Visible','off','Position',[100 100 1100 760]);
    kinds={'siso_forward','three_view_complete'};methods={'oracle','joint','single_feature'};
    for k=1:2
        subplot(1,2,k);hold on;
        for m=1:3
            q=r(strcmp({r.view_kind},kinds{k})&strcmp({r.method},methods{m}));
            [x,ix]=sort([q.snr_db]);q=q(ix);mu=[q.accuracy_mean];
            errorbar(x,mu,mu-[q.accuracy_ci_low],[q.accuracy_ci_high]-mu, ...
                '-o','LineWidth',1);
        end
        hold off;grid on;ylim([0 1.05]);title(strrep(kinds{k},'_',' '));
        xlabel('SNR (dB)');ylabel('Strict topology accuracy (95% CI)');
        legend(strrep(methods,'_',' '),'Location','best');
    end
    print(gcf,fullfile(cfg.results_figures,'stage2_2_noise_accuracy.png'),'-dpng','-r150');close(gcf);

    figure('Visible','off','Position',[100 100 1200 720]);
    bar([[physical.unique_strict_accuracy];[physical.group_accuracy]].');grid on;ylim([0 1.05]);
    labels=strrep({physical.scenario},'_',' ');
    set(gca,'XTick',1:numel(physical),'XTickLabel',labels,'XTickLabelRotation',25, ...
        'TickLabelInterpreter','none');
    legend('unique strict','legacy structural group','Location','best');
    title('Ideal complete-network separability (ties are not unique decisions; not field performance)');
    ylabel('Accuracy');
    print(gcf,fullfile(cfg.results_figures,'stage2_2_physical_views.png'),'-dpng','-r150');close(gcf);

    scenarios=unique({sweeps.scenario},'stable');view_kinds={'siso_forward','three_view_complete'};
    ratio=NaN(numel(scenarios),numel(view_kinds));
    for q=1:numel(scenarios),for k=1:numel(view_kinds)
        selected=strcmp({sweeps.scenario},scenarios{q})&strcmp({sweeps.view_kind},view_kinds{k});
        ratio(q,k)=sweeps(selected).intra_inter_ratio;
    end,end
    figure('Visible','off','Position',[100 100 1200 1050]);barh(ratio);xline(1,'--');grid on;
    set(gca,'YTick',1:numel(scenarios),'YTickLabel',strrep(scenarios,'_',' '), ...
        'TickLabelInterpreter','none','FontSize',8);
    xlabel('D_{intra}/D_{inter}');ylabel('Parameter scenario');
    title('Noiseless parameter sweeps: joint-matching distance ratio');
    legend(strrep(view_kinds,'_',' '),'Location','best');
    print(gcf,fullfile(cfg.results_figures,'stage2_2_parameter_robustness.png'),'-dpng','-r150');close(gcf);
end

function write_text(file,cfg,candidates,physical,summary,elapsed,ngrid)
    fid=fopen(file,'w');fprintf(fid,'阶段2.2物理多视图与拓扑/参数联合反演摘要\n模型：完整树分布参数节点导纳 + 频域等效导频Y=XH+N；不是完整OFDM收发机。\n');fprintf(fid,'候选=');fprintf(fid,'%s ',candidates.id);fprintf(fid,'\nNFFT=%d Fs=%.17g pilots=%d grid=%d elapsed_s=%.17g\n',cfg.ofdm.nfft,cfg.ofdm.sample_rate_hz,cfg.ofdm.num_pilots,ngrid,elapsed);for r=physical,fprintf(fid,'IDEAL %s views=%d apparentStrict=%.17g uniqueStrict=%.17g legacyGroup=%.17g tie=%.17g T3T5dist=%.17g truncated=%d\n',r.scenario,r.view_count,r.strict_accuracy,r.unique_strict_accuracy,r.group_accuracy,r.numeric_tie_rate,r.t3_t5_distance,r.network_truncated);end;hit=strcmp({summary.method},'joint');for r=summary(hit),fprintf(fid,'%s %s %s SNR=%.17g joint strict=%.17g CI=[%.17g,%.17g] group=%.17g lengthRMSE=%.17g loadRelRMSE=%.17g\n',r.experiment,r.noise_mode,r.view_kind,r.snr_db,r.accuracy_mean,r.accuracy_ci_low,r.accuracy_ci_high,r.group_accuracy_mean,r.length_rmse_m,r.load_relative_rmse);end;fclose(fid);
end
