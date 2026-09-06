function out = compute_subband_residuals(observed_views, cache, subband_index_sets)
%COMPUTE_SUBBAND_RESIDUALS Compute shared CFR residual evidence.
%   observed_views is a cell of complex CFR row/column vectors.  The cache
%   contains one contiguous CFR matrix per view.  Returned distances are
%   RMS complex, amplitude and circular-phase residuals per template.
    if ~iscell(observed_views), observed_views={observed_views}; end
    if ~isfield(cache,'cfr_views') || isempty(cache.cfr_views)
        error('stage4a5:MissingCacheViews','A compact CFR cache is required.');
    end
    if numel(observed_views)~=numel(cache.cfr_views)
        error('stage4a5:ViewCountMismatch','Observed and cached view counts differ.');
    end
    n_template=size(cache.cfr_views{1},1); n_freq=numel(cache.frequency_hz);
    if isempty(subband_index_sets), error('stage4a5:EmptySubbands','At least one subband is required.'); end
    full_e2=zeros(n_template,1); amp_e2=zeros(n_template,1); phase_e2=zeros(n_template,1);
    sub_e2=zeros(n_template,numel(subband_index_sets));
    for v=1:numel(observed_views)
        obs=observed_views{v}(:).'; ref=cache.cfr_views{v};
        if numel(obs)~=n_freq, error('stage4a5:FrequencyMismatch','Observation frequency count differs.'); end
        e2=abs(ref-obs).^2; full_e2=full_e2+sum(e2,2);
        amp_e2=amp_e2+sum((abs(ref)-abs(obs)).^2,2);
        pd=angle(exp(1i*(angle(ref)-angle(obs)))); phase_e2=phase_e2+sum(pd.^2,2);
        for b=1:numel(subband_index_sets)
            ix=subband_index_sets{b};
            if isempty(ix)||any(ix<1)|any(ix>n_freq), error('stage4a5:InvalidSubband','Subband index is out of range.'); end
            sub_e2(:,b)=sub_e2(:,b)+sum(e2(:,ix),2);
        end
    end
    denom=numel(observed_views)*n_freq;
    sub_d=zeros(n_template,numel(subband_index_sets));
    for b=1:numel(subband_index_sets),sub_d(:,b)=sqrt(sub_e2(:,b)/(numel(observed_views)*numel(subband_index_sets{b})));end
    out=struct('template_full_distance',sqrt(full_e2/denom), ...
        'template_amplitude_distance',sqrt(amp_e2/denom), ...
        'template_phase_distance',sqrt(phase_e2/denom), ...
        'template_subband_distance',sub_d,'subband_counts',cellfun(@numel,subband_index_sets), ...
        'frequency_count',n_freq, ...
        'template_count',n_template);
end
