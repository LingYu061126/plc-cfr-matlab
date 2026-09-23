function out=stage7a_profile_distance(observation,cache,search)
%STAGE7A_PROFILE_DISTANCE Truth-free bounded coarse-to-fine CFR matching.
%   Observation is one complex CFR row over cache.frequency_hz. Lower RMS
%   complex distance is better. Cached templates are never recomputed here.
    y=observation(:).';
    assert(numel(y)==numel(cache.frequency_hz)&&all(isfinite(y)), ...
        'stage7a:InvalidObservation','Observation/frequency shape or values are invalid.');
    n=numel(cache.candidate_ids);d=Inf(1,n);best=zeros(1,n);count=0;t=tic;
    for k=1:n
        H=cache.H{k};allow=cache.admissible{k};coarse=find(cache.coarse_mask&allow);
        coarse_d=sqrt(mean(abs(H(coarse,:)-y).^2,2));
        [~,coarse_pos]=min(coarse_d);pivot=coarse(coarse_pos);
        local=allow & abs(cache.main_scale-cache.main_scale(pivot))<= ...
            search.coarse_main_step+1e-12 & ...
            abs(cache.branch_load_scale-cache.branch_load_scale(pivot))<= ...
            search.coarse_load_step/2+1e-12;
        indices=find(local);fine_d=sqrt(mean(abs(H(indices,:)-y).^2,2));
        [d(k),local_pos]=min(fine_d);best(k)=indices(local_pos);
        count=count+numel(coarse)+numel(indices);
    end
    out=struct('profile_distances',d,'best_template_indices',best, ...
        'best_main_scale',cache.main_scale(best),'best_branch_load_scale',cache.branch_load_scale(best), ...
        'template_comparisons',count,'forward_evaluations',0,'runtime_s',toc(t), ...
        'definition_version','stage7a_cached_coarse_to_fine_complex_rms_v1');
end
