function [Y, noise, details] = ofdm_apply_channel(X, H, snr_db, seed, noise_mode, reference_signal_power)
%OFDM_APPLY_CHANNEL Apply Y=X.*H+N with optional complex AWGN.
%   X and H are equal-sized row/column vectors. SNR is defined relative to
%   either the received pilot-signal power |X.*H|^2 (the default
%   fixed_received_snr mode), or a supplied reference power
%   (fixed_noise_power mode). +Inf dB means no noise; -Inf is invalid.
%   A supplied seed makes the generated noise repeatable; the caller's RNG
%   state is restored afterwards. This is a frequency-domain equivalent
%   observation model, not a time-domain PLC modem.

    if nargin < 5 || isempty(noise_mode)
        noise_mode = 'fixed_received_snr';
    end
    if nargin < 6
        reference_signal_power = [];
    end
    if isstring(noise_mode), noise_mode = char(noise_mode); end
    if ~(ischar(noise_mode) && isrow(noise_mode))
        error('ofdm_apply_channel:InvalidNoiseMode', ...
            'noise_mode must be fixed_received_snr or fixed_noise_power.');
    end
    noise_mode = lower(strtrim(noise_mode));
    if ~ismember(noise_mode, {'fixed_received_snr', 'fixed_noise_power'})
        error('ofdm_apply_channel:InvalidNoiseMode', ...
            'noise_mode must be fixed_received_snr or fixed_noise_power.');
    end

    X = X(:).';
    H = H(:).';
    if numel(X) ~= numel(H)
        error('ofdm_apply_channel:SizeMismatch', 'X and H must have equal length.');
    end
    if any(~isfinite(X)) || any(~isfinite(H))
        error('ofdm_apply_channel:NonfiniteInput', 'X and H must be finite.');
    end
    if ~(isnumeric(snr_db) && isscalar(snr_db) && isreal(snr_db) && ...
            (isfinite(snr_db) || isinf(snr_db))) || ...
            (isinf(snr_db) && snr_db < 0)
        error('ofdm_apply_channel:InvalidSNR', ...
            'snr_db must be a finite real scalar or +Inf; -Inf is invalid.');
    end
    signal = X .* H;
    signal_power = mean(abs(signal).^2);
    if ~isfinite(signal_power)
        error('ofdm_apply_channel:NonfiniteSignalPower', ...
            'The received pilot signal power must be finite.');
    end
    if isinf(snr_db) && snr_db > 0
        noise_variance = 0;
    else
        if strcmp(noise_mode, 'fixed_received_snr')
            reference_power = signal_power;
        else
            if nargin < 6 || isempty(reference_signal_power)
                error('ofdm_apply_channel:MissingNoiseReference', ...
                    'fixed_noise_power requires reference_signal_power.');
            end
            if ~(isnumeric(reference_signal_power) && ...
                    isscalar(reference_signal_power) && isreal(reference_signal_power) && ...
                    isfinite(reference_signal_power) && reference_signal_power > 0)
                error('ofdm_apply_channel:InvalidNoiseReference', ...
                    'reference_signal_power must be a positive finite real scalar.');
            end
            reference_power = reference_signal_power;
        end
        if reference_power <= 0
            error('ofdm_apply_channel:ZeroSignalPower', ...
                'Finite-SNR simulation requires nonzero reference signal power.');
        end
        noise_variance = reference_power / 10^(snr_db/10);
    end
    old_rng = rng;
    cleanup_rng = onCleanup(@() rng(old_rng)); %#ok<NASGU>
    if nargin >= 4 && ~isempty(seed)
        rng(seed, 'twister');
    end
    if noise_variance == 0
        noise = zeros(size(signal));
    else
        noise = sqrt(noise_variance/2) * ...
            (randn(size(signal)) + 1i*randn(size(signal)));
    end
    Y = signal + noise;
    details = struct('snr_db', snr_db, 'signal_power', signal_power, ...
        'reference_signal_power', reference_power_for_details(noise_mode, ...
        signal_power, nargin, reference_signal_power), ...
        'noise_variance', noise_variance, 'noise_mode', noise_mode, ...
        'measurement_count', numel(X));
end

function p = reference_power_for_details(mode, signal_power, nargin_count, supplied)
    if strcmp(mode, 'fixed_received_snr') || nargin_count < 6 || isempty(supplied)
        p = signal_power;
    else
        p = supplied;
    end
end
