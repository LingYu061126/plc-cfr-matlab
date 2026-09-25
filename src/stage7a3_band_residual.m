function out=stage7a3_band_residual(observation,cache,profile)
%STAGE7A3_BAND_RESIDUAL Compute truth-free worst-subband normalized CFR fit error.
%   OBSERVATION and cached best-fit CFR are complex row vectors over the
%   cache frequency grid. Four contiguous, near-equal index bands are used.
    y=observation(:).';n=numel(cache.frequency_hz);
    assert(numel(y)==n&&all(isfinite(y))&&numel(profile.profile_distances)==numel(cache.H), ...
        'stage7a3:ResidualShape','Observation/profile/cache shapes differ.');
    d=double(profile.profile_distances(:).');
    assert(all(isfinite(d)),'stage7a3:ResidualDistance','Profile distances must be finite.');
    order=sortrows([d(:),(1:numel(d)).'],[1 2]);best=order(1,2);
    ti=profile.best_template_indices(best);
    assert(ti>=1&&ti<=size(cache.H{best},1)&&all(isfinite(cache.H{best}(ti,:))), ...
        'stage7a3:ResidualTemplate','Best cached template is invalid.');
    fit=cache.H{best}(ti,:);residual=fit-y;
    edges=round(linspace(1,n+1,5));
    band_rms=zeros(1,4);observation_rms=zeros(1,4);relative=zeros(1,4);
    for b=1:4
        ix=edges(b):edges(b+1)-1;
        band_rms(b)=sqrt(mean(abs(residual(ix)).^2));
        observation_rms(b)=sqrt(mean(abs(y(ix)).^2));
        relative(b)=band_rms(b)/max(observation_rms(b),eps);
    end
    out=struct('best_index',best,'best_template_index',ti, ...
        'best_candidate',cache.candidate_ids{best},'fit_cfr',fit, ...
        'residual_cfr',residual,'band_edges',edges,'band_rms',band_rms, ...
        'observation_band_rms',observation_rms, ...
        'band_relative_residual',relative,'max_band_relative_residual',max(relative));
end
