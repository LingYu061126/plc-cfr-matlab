function metrics = cfr_phase_error_metrics(H_observed, H_reference, options)
%CFR_PHASE_ERROR_METRICS Report raw and amplitude-aware phase errors.
%   Raw unwrapped RMSE is retained for comparability with the stage-2
%   baseline. Low-amplitude bins are separately masked and weighted because
%   their phase is poorly conditioned. Circular phase error avoids artificial
%   2*pi jumps. Set options.remove_linear_phase=true only when a timing/sync
%   ambiguity is intentionally removed; it is false by default.

    if nargin < 3 || isempty(options), options = struct(); end
    H_observed = H_observed(:).';
    H_reference = H_reference(:).';
    if numel(H_observed) ~= numel(H_reference)
        error('cfr_phase_error_metrics:SizeMismatch', ...
            'Observed and reference CFRs must have equal length.');
    end
    if any(~isfinite(H_observed)) || any(~isfinite(H_reference))
        error('cfr_phase_error_metrics:NonfiniteInput', ...
            'Observed and reference CFRs must be finite.');
    end
    threshold_db = get_option(options, 'mask_threshold_db', -40);
    remove_linear = get_option(options, 'remove_linear_phase', false);
    if ~(isscalar(threshold_db) && isreal(threshold_db) && isfinite(threshold_db))
        error('cfr_phase_error_metrics:InvalidThreshold', ...
            'mask_threshold_db must be a finite real scalar.');
    end
    if ~(isscalar(remove_linear) && (islogical(remove_linear) || isnumeric(remove_linear)))
        error('cfr_phase_error_metrics:InvalidTrendOption', ...
            'remove_linear_phase must be scalar logical-like.');
    end

    phase_observed = unwrap(angle(H_observed));
    phase_reference = unwrap(angle(H_reference));
    phase_difference = phase_observed - phase_reference;
    n = numel(H_observed);
    amp = min(abs(H_observed), abs(H_reference));
    scale = max([amp, realmin]);
    mask = amp >= max(scale) * 10^(threshold_db/20);
    if ~any(mask), mask(:) = true; end

    % The historical metric removed a common phase offset by referencing the
    % first sample. Keep exactly that convention for raw comparability.
    raw_difference = phase_difference - phase_difference(1);
    metrics.raw_unwrapped_rmse_rad = sqrt(mean(raw_difference.^2));
    metrics.raw_unwrapped_rmse_deg = metrics.raw_unwrapped_rmse_rad * 180/pi;

    reference_index = find(mask, 1, 'first');
    masked_difference = phase_difference - phase_difference(reference_index);
    x = linspace(-1, 1, n);
    if logical(remove_linear)
        fit = polyfit(x(mask), masked_difference(mask), 1);
        masked_difference = masked_difference - polyval(fit, x);
    end
    metrics.mask = mask;
    metrics.mask_threshold_db = threshold_db;
    metrics.valid_fraction = mean(mask);
    metrics.masked_unwrapped_rmse_rad = sqrt(mean(masked_difference(mask).^2));
    metrics.masked_unwrapped_rmse_deg = metrics.masked_unwrapped_rmse_rad * 180/pi;

    circular_difference = angle(exp(1i * masked_difference));
    weights = amp;
    weights(~mask) = 0;
    if sum(weights) <= 0, weights(mask) = 1; end
    metrics.circular_rmse_rad = sqrt(mean(circular_difference(mask).^2));
    metrics.circular_rmse_deg = metrics.circular_rmse_rad * 180/pi;
    metrics.weighted_circular_rmse_rad = sqrt(sum(weights .* circular_difference.^2) / sum(weights));
    metrics.weighted_circular_rmse_deg = metrics.weighted_circular_rmse_rad * 180/pi;
    metrics.remove_linear_phase = logical(remove_linear);
end

function value = get_option(options, name, default_value)
    if isfield(options, name) && ~isempty(options.(name))
        value = options.(name);
    else
        value = default_value;
    end
end
