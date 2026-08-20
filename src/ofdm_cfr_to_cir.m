function [cir, time_s, H_full, details] = ofdm_cfr_to_cir(H_pilot, cfg)
%OFDM_CFR_TO_CIR Compute a circular band-limited channel impulse response.
%   H_pilot follows cfg.pilot_bin_1based. H_full is the length-NFFT
%   frequency-domain vector with zeros on unmeasured bins, cir=ifft(H_full),
%   and time_s is the corresponding circular time axis. This implementation
%   has no cyclic prefix, no negative-frequency conjugate completion and no
%   time-domain synchronization. Therefore the output is explicitly a
%   circular band-limited CIR; its peak is only a circular-delay metric and
%   must not be called a physical ToA or a ranging result.

    H_pilot = H_pilot(:).';
    if ~isfield(cfg, 'nfft') || ~isfield(cfg, 'pilot_bin_1based') || ...
            ~isfield(cfg, 'sample_rate_hz')
        error('ofdm_cfr_to_cir:MissingConfig', 'Incomplete OFDM configuration.');
    end
    bins = cfg.pilot_bin_1based(:).';
    if numel(H_pilot) ~= numel(bins)
        error('ofdm_cfr_to_cir:SizeMismatch', ...
            'H_pilot length must equal the number of configured pilot bins.');
    end
    if any(~isfinite(H_pilot))
        error('ofdm_cfr_to_cir:NonfiniteInput', 'H_pilot must be finite.');
    end
    H_full = zeros(1, cfg.nfft);
    H_full(bins) = H_pilot;
    cir = ifft(H_full, cfg.nfft);
    time_s = (0:cfg.nfft-1) / cfg.sample_rate_hz;
    details = struct('name', 'circular band-limited CIR', ...
        'chinese_name', '循环带限信道冲激响应', ...
        'has_cyclic_prefix', false, ...
        'negative_frequency_conjugate_completion', false, ...
        'time_synchronization_applied', false, ...
        'peak_is_physical_toa', false, ...
        'measured_bin_count', numel(bins), 'nfft', cfg.nfft);
end
