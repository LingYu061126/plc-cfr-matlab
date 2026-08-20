function [H_hat, details] = ofdm_channel_estimate_ls(X, Y)
%OFDM_CHANNEL_ESTIMATE_LS Least-squares pilot CFR estimate H_hat=Y./X.
%   X and Y are equal-sized frequency-domain pilot and received vectors.
%   Known pilots must be nonzero. This function does not interpolate missing
%   subcarriers and does not perform synchronization or equalization.

    X = X(:).';
    Y = Y(:).';
    if numel(X) ~= numel(Y)
        error('ofdm_channel_estimate_ls:SizeMismatch', 'X and Y must have equal length.');
    end
    if any(~isfinite(X)) || any(~isfinite(Y))
        error('ofdm_channel_estimate_ls:NonfiniteInput', 'X and Y must be finite.');
    end
    if any(X == 0)
        error('ofdm_channel_estimate_ls:ZeroPilot', 'LS pilots must be nonzero.');
    end
    H_hat = Y ./ X;
    details = struct('pilot_count', numel(X), ...
        'zero_noise_exact_operation', true);
end
