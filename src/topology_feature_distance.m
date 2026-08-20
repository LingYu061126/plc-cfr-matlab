function [distance, metrics] = topology_feature_distance(H_observed, H_reference, feature, ofdm_cfg, weights, options)
%TOPOLOGY_FEATURE_DISTANCE Compute normalized, interpretable CFR/CIR distances.
%   The returned metrics always include:
%     D_amp       RMS distance between unit-norm |H| vectors;
%     D_phase     RMS unwrapped phase distance in radians, divided by pi;
%     D_phase_masked / D_phase_weighted / D_phase_circular amplitude-aware
%       phase distances;
%     D_complex   RMS distance between unit-norm complex CFR vectors;
%     D_cir       RMS distance between unit-norm circular CIR vectors;
%     D_amp_raw_db retains absolute attenuation; D_amp and
%       D_amp_db_standardized are shape-only features and discard level;
%     D_joint     sqrt(w_amp*D_amp^2+w_phase*D_phase^2).
%   The selected feature is explicit and is not a claim of unique physical
%   topology identifiability.

    H_observed = H_observed(:).';
    H_reference = H_reference(:).';
    if numel(H_observed) ~= numel(H_reference)
        error('topology_feature_distance:SizeMismatch', ...
            'Observed and reference CFRs must have equal length.');
    end
    if any(~isfinite(H_observed)) || any(~isfinite(H_reference))
        error('topology_feature_distance:NonfiniteInput', ...
            'Observed and reference CFRs must be finite.');
    end
    if nargin < 5 || isempty(weights)
        weights = [0.5, 0.5];
    end
    if nargin < 6 || isempty(options), options = struct(); end
    if ~(isnumeric(weights) && numel(weights) == 2 && ...
            all(isfinite(weights)) && all(weights >= 0) && sum(weights) > 0)
        error('topology_feature_distance:InvalidWeights', ...
            'weights must contain two nonnegative finite values with positive sum.');
    end
    weights = weights(:).' / sum(weights);

    amp_obs = normalize_vector(abs(H_observed));
    amp_ref = normalize_vector(abs(H_reference));
    complex_obs = normalize_vector(H_observed);
    complex_ref = normalize_vector(H_reference);
    phase_options = struct('mask_threshold_db', get_option(options, ...
        'phase_mask_threshold_db', -40), 'remove_linear_phase', ...
        get_option(options, 'remove_linear_phase', false));
    phase_metrics = cfr_phase_error_metrics(H_observed, H_reference, phase_options);
    mag_obs_db = 20*log10(max(abs(H_observed), realmin));
    mag_ref_db = 20*log10(max(abs(H_reference), realmin));
    mag_obs_z = standardize_vector(mag_obs_db);
    mag_ref_z = standardize_vector(mag_ref_db);
    amp_obs_z = standardize_vector(abs(H_observed));
    amp_ref_z = standardize_vector(abs(H_reference));

    metrics = struct();
    metrics.D_amp = rms_distance(amp_obs, amp_ref);
    metrics.D_phase_rad = phase_metrics.raw_unwrapped_rmse_rad;
    metrics.D_phase = metrics.D_phase_rad / pi;
    metrics.D_phase_masked_rad = phase_metrics.masked_unwrapped_rmse_rad;
    metrics.D_phase_masked = metrics.D_phase_masked_rad / pi;
    metrics.D_phase_weighted_rad = phase_metrics.weighted_circular_rmse_rad;
    metrics.D_phase_weighted = metrics.D_phase_weighted_rad / pi;
    metrics.D_phase_circular_rad = phase_metrics.circular_rmse_rad;
    metrics.D_phase_circular = metrics.D_phase_circular_rad / pi;
    metrics.D_complex = rms_distance(complex_obs, complex_ref);
    metrics.D_complex_raw = rms_distance(H_observed, H_reference);
    metrics.D_amp_raw_db = rms_distance(mag_obs_db, mag_ref_db);
    metrics.D_amp_db_standardized = rms_distance(mag_obs_z, mag_ref_z);
    metrics.D_amp_standardized = rms_distance(amp_obs_z, amp_ref_z);
    metrics.phase_valid_fraction = phase_metrics.valid_fraction;
    metrics.phase_details = phase_metrics;
    metrics.D_joint = sqrt(weights(1)*metrics.D_amp^2 + ...
        weights(2)*metrics.D_phase^2);
    metrics.D_joint_masked = sqrt(weights(1)*metrics.D_amp^2 + ...
        weights(2)*metrics.D_phase_masked^2);
    metrics.D_joint_weighted = sqrt(weights(1)*metrics.D_amp^2 + ...
        weights(2)*metrics.D_phase_weighted^2);
    absolute_scale_db = get_option(options,'absolute_amplitude_scale_db',20);
    if ~(isscalar(absolute_scale_db)&&isreal(absolute_scale_db)&& ...
            isfinite(absolute_scale_db)&&absolute_scale_db>0)
        error('topology_feature_distance:InvalidAmplitudeScale', ...
            'absolute_amplitude_scale_db must be positive and finite.');
    end
    metrics.D_joint_absolute_weighted = sqrt(weights(1)* ...
        (metrics.D_amp_raw_db/absolute_scale_db)^2 + ...
        weights(2)*metrics.D_phase_weighted^2);
    metrics.weights = weights;
    metrics.observed_amplitude_rmse_db = metrics.D_amp_raw_db;
    metrics.observed_phase_rmse_rad = metrics.D_phase_rad;

    feature_key = lower(char(feature));
    switch feature_key
        case {'amp', 'amplitude', 'cfr_amplitude'}
            distance = metrics.D_amp;
        case {'phase', 'cfr_phase'}
            distance = metrics.D_phase;
        case {'phase_masked', 'masked_phase', 'cfr_phase_masked'}
            distance = metrics.D_phase_masked;
        case {'phase_weighted', 'weighted_phase', 'cfr_phase_weighted'}
            distance = metrics.D_phase_weighted;
        case {'phase_circular', 'circular_phase'}
            distance = metrics.D_phase_circular;
        case {'complex', 'cfr_complex'}
            distance = metrics.D_complex;
        case {'complex_raw', 'cfr_complex_raw', 'raw_complex'}
            distance = metrics.D_complex_raw;
        case {'cir'}
            % Compute the circular band-limited CIR only when requested.
            [cir_obs, ~] = ofdm_cfr_to_cir(H_observed, ofdm_cfg);
            [cir_ref, ~] = ofdm_cfr_to_cir(H_reference, ofdm_cfg);
            distance = rms_distance(normalize_vector(cir_obs), normalize_vector(cir_ref));
            metrics.D_cir = distance;
        case {'amplitude_raw_db', 'amp_raw_db', 'magnitude_db'}
            distance = metrics.D_amp_raw_db;
        case {'amplitude_db_standardized', 'amp_db_standardized'}
            distance = metrics.D_amp_db_standardized;
        case {'amplitude_standardized', 'amp_standardized'}
            distance = metrics.D_amp_standardized;
        case {'amp_phase_joint', 'joint', 'amplitude_phase'}
            distance = metrics.D_joint;
        case {'amp_phase_joint_masked', 'joint_masked'}
            distance = metrics.D_joint_masked;
        case {'amp_phase_joint_weighted', 'joint_weighted'}
            distance = metrics.D_joint_weighted;
        case {'amp_phase_joint_absolute_weighted','joint_absolute_weighted'}
            distance = metrics.D_joint_absolute_weighted;
        otherwise
            error('topology_feature_distance:UnknownFeature', ...
                'Unknown feature %s.', feature_key);
    end
    metrics.selected_feature = feature_key;
    metrics.selected_distance = distance;
end

function value = get_option(options,name,default_value)
    if isfield(options,name)&&~isempty(options.(name)),value=options.(name);else,value=default_value;end
end

function y = standardize_vector(x)
    x = x(:).';
    s = std(x, 0, 2);
    if ~isfinite(s) || s <= sqrt(eps)
        y = zeros(size(x));
    else
        y = (x - mean(x)) / s;
    end
end

function y = normalize_vector(x)
    scale = sqrt(sum(abs(x).^2));
    if scale <= realmin
        y = zeros(size(x));
    else
        y = x / scale;
    end
end

function d = rms_distance(x, y)
    d = sqrt(mean(abs(x-y).^2));
end
