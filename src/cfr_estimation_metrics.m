function metrics = cfr_estimation_metrics(H_hat, H_true, options)
%CFR_ESTIMATION_METRICS Complex, magnitude and robust phase error metrics.
    if nargin < 3 || isempty(options), options = struct(); end
    H_hat = H_hat(:).';
    H_true = H_true(:).';
    if numel(H_hat) ~= numel(H_true)
        error('cfr_estimation_metrics:SizeMismatch', ...
            'Estimated and true CFRs must have equal length.');
    end
    if any(~isfinite(H_hat)) || any(~isfinite(H_true))
        error('cfr_estimation_metrics:NonfiniteInput', ...
            'Estimated and true CFRs must be finite.');
    end
    denominator = sum(abs(H_true).^2);
    if denominator <= 0
        error('cfr_estimation_metrics:ZeroReference', 'True CFR power must be positive.');
    end
    mag_hat_db = 20*log10(max(abs(H_hat), realmin));
    mag_true_db = 20*log10(max(abs(H_true), realmin));
    metrics.nmse = sum(abs(H_hat-H_true).^2) / denominator;
    metrics.amplitude_rmse_db = sqrt(mean((mag_hat_db-mag_true_db).^2));
    phase = cfr_phase_error_metrics(H_hat, H_true, options);
    metrics.phase_rmse_deg = phase.raw_unwrapped_rmse_deg;
    metrics.raw_phase_rmse_deg = phase.raw_unwrapped_rmse_deg;
    metrics.masked_phase_rmse_deg = phase.masked_unwrapped_rmse_deg;
    metrics.weighted_phase_rmse_deg = phase.weighted_circular_rmse_deg;
    metrics.circular_phase_rmse_deg = phase.circular_rmse_deg;
    metrics.valid_phase_fraction = phase.valid_fraction;
    metrics.phase_details = phase;
end
