function pilot = ofdm_generate_pilot(cfg)
%OFDM_GENERATE_PILOT Generate known nonzero complex-baseband pilots.
%   pilot.X is a row vector ordered by cfg.pilot_frequency_hz. X_full is a
%   length-cfg.nfft sparse frequency-domain vector using MATLAB's 1-based
%   FFT-bin convention. The pilot sequence is deterministic QPSK and does
%   not change the physical CFR model.

    required = {'nfft', 'pilot_bin_1based', 'pilot_frequency_hz', ...
        'pilot_seed'};
    for k = 1:numel(required)
        if ~isfield(cfg, required{k})
            error('ofdm_generate_pilot:MissingConfig', ...
                'Missing OFDM configuration field %s.', required{k});
        end
    end
    bins = cfg.pilot_bin_1based(:).';
    if isempty(bins) || any(bins < 1) || any(bins > cfg.nfft) || ...
            any(bins ~= fix(bins))
        error('ofdm_generate_pilot:InvalidBins', ...
            'Pilot FFT-bin indices must be valid positive integers.');
    end
    if numel(unique(bins)) ~= numel(bins)
        error('ofdm_generate_pilot:DuplicateBins', 'Pilot bins must be unique.');
    end

    % Deterministic QPSK sequence. pilot_seed is retained in the output and
    % configuration for reproducibility bookkeeping; no global RNG state is
    % changed by this function.
    qpsk_index = mod((0:numel(bins)-1) + double(cfg.pilot_seed), 4);
    pilot_symbols = exp(1i*(pi/4 + qpsk_index*pi/2));
    pilot = struct('X', pilot_symbols, 'X_full', zeros(1, cfg.nfft), ...
        'frequency_hz', cfg.pilot_frequency_hz(:).', ...
        'bin_1based', bins, 'seed', cfg.pilot_seed, ...
        'mode', cfg.pilot_mode);
    pilot.X_full(bins) = pilot_symbols;
end
