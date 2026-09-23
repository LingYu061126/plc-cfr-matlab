function [model,timing]=stage6b_calibrate_candidate_library(candidates,base,sc,tag,seed_offset)
%STAGE6B_CALIBRATE_CANDIDATE_LIBRARY Calibration-only local experiment model.
%   This does not replace or overwrite frozen Stage 4A/5B.1 thresholds.
    if nargin<5,seed_offset=0;end
    candidates=ensure_ids(candidates);ids={candidates.topology_id};
    theta_grid=topology_parameter_grid(sc.parameter_search);t=tic;
    cache=stage4a7_2_r1_build_profile_template_cache(sc.frequency_hz,candidates,theta_grid,base,sc.measurement_kind);
    timing=struct('cache_time_s',toc(t),'calibration_time_s',0);t=tic;
    n=numel(candidates)*sc.calibration_per_candidate;distances=zeros(n,numel(candidates));
    truth_index=zeros(n,1);relative=zeros(n,1);cursor=0;
    for j=1:numel(candidates)
        for r=1:sc.calibration_per_candidate
            cursor=cursor+1;rs=RandStream('mt19937ar','Seed',sc.seed+seed_offset+j*1000+r);
            theta=random_theta(rs,sc.parameter_search);
            clean=stage6b_forward_cfr(candidates(j).network,theta,base,sc.frequency_hz,sc.measurement_kind);
            observation=add_noise(clean,sc.calibration_snr_db,rs);
            profile=stage4a7_2_r1_profile_distance({observation},cache,struct('feature','complex_raw'));
            distances(cursor,:)=profile.profile_distances;truth_index(cursor)=j;
            relative(cursor)=min(profile.profile_distances)/max(sqrt(mean(abs(observation).^2)),eps);
        end
    end
    options=struct('minimum_per_candidate',sc.calibration_per_candidate,'resolution',eps, ...
        'compatibility_hash',stage4a4_scientific_config_hash(struct('stage','6B','tag',tag,'mode',sc.mode)));
    topology_model=stage4a7_2_r1_calibrate_profile_method(distances,truth_index,ids,'absolute',sc.alpha,options);
    set_size=zeros(n,1);
    for q=1:n
        accepted=stage4a7_2_r1_apply_profile_candidate_set(distances(q,:),topology_model,'absolute');
        set_size(q)=accepted.set_size;
    end
    eopts=sc.evidence_calibration;eopts.candidate_ids=ids;
    evidence_model=calibrate_stage5b1_decision_metrics(distances,truth_index,set_size,eopts);
    domain_threshold=fixed_quantile(relative,sc.domain_quantile);
    model=struct('tag',tag,'candidates',candidates,'candidate_ids',{ids},'cache',cache, ...
        'topology_model',topology_model,'evidence_model',evidence_model, ...
        'domain_threshold',domain_threshold,'calibration_distances',distances, ...
        'calibration_truth_index',truth_index,'calibration_relative_distance',relative, ...
        'scope','stage6b_local_calibration_not_frozen_stage4a_threshold');
    timing.calibration_time_s=toc(t);
end

function candidates=ensure_ids(candidates)
    for k=1:numel(candidates)
        if ~isfield(candidates,'topology_id')||isempty(candidates(k).topology_id)
            if isfield(candidates,'id'),candidates(k).topology_id=char(candidates(k).id);
            else,candidates(k).topology_id=sprintf('S6B_%04d',k);end
        end
        if ~isfield(candidates,'canonical_key')||isempty(candidates(k).canonical_key)
            candidates(k).canonical_key=stage6b_network_signature(candidates(k).network);
        end
    end
end
function theta=random_theta(rs,search)
    v=search.main_length_scale;
    theta=struct('main_length_scale',min(v)+(max(v)-min(v))*rand(rs), ...
        'branch_length_scale',search.branch_length_scale(1),'branch_load_scale',search.branch_load_scale(1), ...
        'source_impedance_ohm',search.source_impedance_ohm(1),'receiver_impedance_ohm',search.receiver_impedance_ohm(1), ...
        'regularization',0);
end
function y=add_noise(x,snr,rs)
    if isinf(snr),y=x;else,s=sqrt(mean(abs(x).^2)/10^(snr/10)/2);y=x+s*(randn(rs,size(x))+1i*randn(rs,size(x)));end
end
function y=fixed_quantile(x,q),x=sort(double(x(:)));y=x(max(1,min(numel(x),ceil(q*numel(x)))));end
