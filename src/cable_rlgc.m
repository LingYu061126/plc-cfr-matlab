function [R, L, G, C, gamma, Zc] = cable_rlgc(f_hz, cable, kG, lossless)
%CABLE_RLGC Calculate frequency-dependent RLGC and gamma/Zc.
%   f_hz is a vector in Hz. R, L, G, C are row vectors with units
%   ohm/m, H/m, S/m and F/m; gamma and Zc are row vectors with units
%   1/m and ohm. kG is the empirical conductance factor, not length.
%   The calibrated broadband model is defined only for strictly positive
%   frequencies. With lossless=true, R=G=0 for the ideal comparison.

    if nargin < 3 || isempty(kG)
        kG = 1;
    end
    if nargin < 4 || isempty(lossless)
        lossless = false;
    end
    if ~isstruct(cable)
        cable = cable_parameters(cable);
    end
    f_hz = f_hz(:).';
    if isempty(f_hz) || any(f_hz <= 0) || any(~isfinite(f_hz))
        error('cable_rlgc:InvalidFrequency', ...
            'Frequency must contain finite, strictly positive values in Hz.');
    end
    if ~(isscalar(kG) && isfinite(kG) && kG >= 0)
        error('cable_rlgc:InvalidKG', 'kG must be a finite nonnegative scalar.');
    end

    L = cable.L_uH_per_m * 1e-6 * ones(size(f_hz));
    C = cable.C_pF_per_m * 1e-12 * ones(size(f_hz));
    if lossless
        R = zeros(size(f_hz));
        G = zeros(size(f_hz));
    else
        R = cable.R0 * 1e-5 .* sqrt(f_hz);
        G = cable.G0 * kG * 1e-14 .* (2*pi*f_hz);
    end
    omega = 2*pi*f_hz;
    gamma = sqrt((R + 1i*omega.*L) .* (G + 1i*omega.*C));
    Zc = sqrt((R + 1i*omega.*L) ./ (G + 1i*omega.*C));
end
