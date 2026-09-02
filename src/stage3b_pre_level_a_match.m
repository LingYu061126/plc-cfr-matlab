function out = stage3b_pre_level_a_match(f_hz, candidates, base_cfg, theta, snr_db, seed, cfg)
%STAGE3B_PRE_LEVEL_A_MATCH Ideal-CFR plus receiver-sample-noise diagnostic.
%   One CFR vector is observed per trial. No waveform energy, symbol time,
%   repetitions, averaging, coupler loss or receiver noise figure is modeled.
    refs=topology_reference_cfr(f_hz,candidates,base_cfg);
    views=cell(1,numel(refs));
    for v=1:numel(refs), views{v}={refs(v).reference_H}; end
    classes=topology_observability_classes(views,candidates,struct(),cfg.tie_tolerance);
    truth=[];matches={};intra=[];inter=[];nearest={};n=0;
    old=rng;cleanup=onCleanup(@()rng(old));rng(seed,'twister'); %#ok<NASGU>
    for t=1:numel(candidates)
        [net,cfg_true]=topology_apply_parameters(candidates(t).network,base_cfg,theta);
        Htrue=cascade_network_stable(f_hz,net,cfg_true);Htrue=Htrue.H_port;
        for q=1:cfg.trials_per_truth
            n=n+1;Hobs=add_noise(Htrue,snr_db);
            matches{n}=topology_nearest_match(Hobs,refs,cfg.feature,struct(),cfg.weights,cfg.tie_tolerance); %#ok<AGROW>
            truth(n)=t; %#ok<AGROW>
            own=classes.class_index==classes.class_index(t);scores=matches{n}.scores;
            intra(n)=min(scores(own));other=scores;other(own)=Inf;inter(n)=min(other); %#ok<AGROW>
            [~,j]=min(other);nearest{n}=candidates(j).id; %#ok<AGROW>
        end
    end
    metrics=topology_equivalence_evaluation(truth,matches,candidates,classes);
    out=struct('metrics',metrics,'classes',classes,'truth',truth,'matches',{matches}, ...
        'class_intra_distance',intra,'nearest_class_inter_distance',inter, ...
        'nearest_competitor',{nearest},'cfr_sampling_nmse_ideal_input',0, ...
        'noise_is_receiver_domain',isfinite(snr_db));
end

function y=add_noise(x,snr_db)
    if isinf(snr_db),y=x;return;end
    variance=mean(abs(x).^2)/10^(snr_db/10);
    y=x+sqrt(variance/2)*(randn(size(x))+1i*randn(size(x)));
end
