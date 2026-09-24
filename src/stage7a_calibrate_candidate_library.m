function [model,timing]=stage7a_calibrate_candidate_library(candidates,base,sc,tag,seed_offset)
%STAGE7A_CALIBRATE_CANDIDATE_LIBRARY Local calibration for one exact library.
%   Calibration observations are generated with independent fixed seeds.
%   No formal-test observations or generating parameters enter this API.
    if nargin<5,seed_offset=0;end
    build=tic;cache=stage7a_build_profile_cache(candidates,base,sc);
    timing=struct('cache_time_s',toc(build),'calibration_time_s',0);start=tic;
    ids=cache.candidate_ids;n=numel(candidates)*sc.calibration_per_candidate;
    distances=zeros(n,numel(candidates));truth_index=zeros(n,1);relative=zeros(n,1);
    cursor=0;
    for j=1:numel(candidates)
        for r=1:sc.calibration_per_candidate
            cursor=cursor+1;
            rs=RandStream('mt19937ar','Seed',sc.calibration_seed+sc.calibration_seed_offset+seed_offset+j*1000+r);
            admissible=cache.main_scale(cache.admissible{j});
            theta=random_theta(rs,sc.search,[min(admissible) max(admissible)]);
            clean=stage6b_forward_cfr(candidates(j).network,theta,base,sc.frequency_hz,sc.measurement_kind);
            observation=add_noise(clean,sc.calibration_snr_db,rs);
            profile=stage7a_profile_distance(observation,cache,sc.search);
            distances(cursor,:)=profile.profile_distances;truth_index(cursor)=j;
            relative(cursor)=min(profile.profile_distances)/max(sqrt(mean(abs(observation).^2)),eps);
        end
    end
    options=struct('minimum_per_candidate',sc.calibration_per_candidate,'resolution',eps, ...
        'compatibility_hash',stage4a4_scientific_config_hash(struct('stage','7A', ...
        'tag',tag,'mode',sc.mode,'ids',{ids},'search',sc.search, ...
        'admissible',{cache.admissible},'frequency_hz',sc.frequency_hz)));
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
        'calibration_seed',sc.calibration_seed,'calibration_seed_offset',seed_offset, ...
        'candidate_library_hash',stage4a4_scientific_config_hash(struct('ids',{ids}, ...
        'signatures',{cache.candidate_signatures})), ...
        'search_domain_hash',stage4a4_scientific_config_hash(struct('search',sc.search, ...
        'admissible',{cache.admissible})), ...
        'cache_grid_hash',stage4a4_scientific_config_hash(struct( ...
        'main_scale',cache.main_scale,'branch_load_scale',cache.branch_load_scale, ...
        'coarse_mask',cache.coarse_mask)), ...
        'calibration_frequency_hz',sc.frequency_hz, ...
        'scope','stage7a_local_calibration_only_not_frozen_threshold');
    timing.calibration_time_s=toc(start);
end
function theta=random_theta(rs,search,a)
    b=search.branch_load_scale_bounds;
    theta=struct('main_length_scale',a(1)+(a(2)-a(1))*rand(rs), ...
        'branch_length_scale',search.branch_length_scale, ...
        'branch_load_scale',b(1)+(b(2)-b(1))*rand(rs), ...
        'source_impedance_ohm',search.source_impedance_ohm, ...
        'receiver_impedance_ohm',search.receiver_impedance_ohm,'regularization',0);
end
function y=add_noise(x,snr,rs)
    if isinf(snr),y=x;return;end
    s=sqrt(mean(abs(x).^2)/10^(snr/10)/2);
    y=x+s*(randn(rs,size(x))+1i*randn(rs,size(x)));
end
function y=fixed_quantile(x,q)
    x=sort(double(x(:)));y=x(max(1,min(numel(x),ceil(q*numel(x)))));
end
