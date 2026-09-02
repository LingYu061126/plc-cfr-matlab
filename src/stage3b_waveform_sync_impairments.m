function [y, meta] = stage3b_waveform_sync_impairments(x, cfg, spec)
%STAGE3B_WAVEFORM_SYNC_IMPAIRMENTS Apply post-line/pre-ADC abstract errors.
%   Fractional timing and SCO are discrete receiver-domain interpolations,
%   not calibrated modem synchronizers.
    if nargin < 3 || isempty(spec), spec = cfg.impairments; end
    spec = fill_defaults(spec,cfg.impairments);
    y = x(:).'; n = 0:numel(y)-1;
    if spec.fractional_timing_offset_samples ~= 0
        q = n - spec.fractional_timing_offset_samples;
        y = interp1(n,y,q,'linear',0);
    end
    if spec.integer_timing_offset_samples ~= 0
        d = spec.integer_timing_offset_samples;
        if d < 0, error('stage3b_waveform_sync_impairments:NegativeIntegerOffset','Negative integer offset is unsupported.'); end
        y = [zeros(1,d) y];
    end
    if spec.sco_ppm ~= 0
        n2 = 0:numel(y)-1; q = n2/(1+spec.sco_ppm*1e-6);
        y = interp1(n2,y,q,'linear',0);
    end
    n3 = 0:numel(y)-1;
    y = y .* exp(1i*(2*pi*spec.cfo_hz*n3/cfg.fs_hz + spec.phase_offset_rad));
    meta = struct('application_point','after linear line convolution; before receiver ADC/FFT', ...
        'spec',spec,'model_status','abstract receiver-domain impairment interface');
end

function s = fill_defaults(s,d)
    names = fieldnames(d);
    for k=1:numel(names), if ~isfield(s,names{k}), s.(names{k})=d.(names{k}); end, end
end
