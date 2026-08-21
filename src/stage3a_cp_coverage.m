function coverage = stage3a_cp_coverage(h,cp,threshold_db)
%STAGE3A_CP_COVERAGE Diagnose circular impulse support versus CP length.
%   The sampled-CFR impulse response has no guaranteed causal origin. The
%   diagnostic circularly rotates its largest tap to index 1 and reports the
%   thresholded post-peak support. This is a model audit, not a physical
%   propagation-delay or CP design guarantee.
    h=h(:).';
    if nargin<2||isempty(cp),cp=0;end
    if nargin<3||isempty(threshold_db),threshold_db=-40;end
    if isempty(h)||any(~isfinite(h))||~(isscalar(cp)&&isreal(cp)&&isfinite(cp)&&cp==fix(cp)&&cp>=0)
        error('stage3a_cp_coverage:InvalidInput','h and cp are invalid.');
    end
    if ~(isscalar(threshold_db)&&isreal(threshold_db)&&isfinite(threshold_db)&&threshold_db<0)
        error('stage3a_cp_coverage:InvalidThreshold','threshold_db must be finite and negative.');
    end
    [peak,peak_index]=max(abs(h));
    if peak<=realmin
        coverage=struct('peak_index',peak_index,'peak_magnitude',peak, ...
            'effective_delay_samples',0,'cp_samples',cp,'threshold_db',threshold_db, ...
            'energy_fraction',1,'covered',true,'is_physical_delay',false);
        return;
    end
    rotated=circshift(h,[0,1-peak_index]);
    threshold=peak*10^(threshold_db/20);
    support=find(abs(rotated)>=threshold);
    effective_delay=max(support)-1;
    used=min(cp+1,numel(rotated));
    energy_fraction=sum(abs(rotated(1:used)).^2)/max(sum(abs(rotated).^2),realmin);
    coverage=struct('peak_index',peak_index,'peak_magnitude',peak, ...
        'effective_delay_samples',effective_delay,'cp_samples',cp, ...
        'threshold_db',threshold_db,'energy_fraction',energy_fraction, ...
        'covered',cp>=effective_delay,'is_physical_delay',false);
end
