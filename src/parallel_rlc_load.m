function Z = parallel_rlc_load(f_hz, R_ohm, Q, f0_hz)
%PARALLEL_RLC_LOAD Cañete parallel-RLC frequency-selective load model.
%   Z(f)=R/[1+jQ(f/f0-f0/f)]. f_hz and f0_hz are Hz, R_ohm is the
%   resonance resistance in ohms, and Q is dimensionless. Parameters are
%   literature-model/simulation parameters, not field-measured loads.

    f_hz = f_hz(:).';
    if isempty(f_hz) || any(~isfinite(f_hz)) || any(f_hz <= 0)
        error('parallel_rlc_load:InvalidFrequency', ...
            'f_hz must contain finite, strictly positive values.');
    end
    if ~(isscalar(R_ohm) && isreal(R_ohm) && isfinite(R_ohm) && R_ohm > 0)
        error('parallel_rlc_load:InvalidResistance', 'R_ohm must be positive and finite.');
    end
    if ~(isscalar(Q) && isreal(Q) && isfinite(Q) && Q > 0)
        error('parallel_rlc_load:InvalidQ', 'Q must be positive and finite.');
    end
    if ~(isscalar(f0_hz) && isreal(f0_hz) && isfinite(f0_hz) && f0_hz > 0)
        error('parallel_rlc_load:InvalidResonance', 'f0_hz must be positive and finite.');
    end
    Z = R_ohm ./ (1 + 1i*Q.*(f_hz./f0_hz - f0_hz./f_hz));
end
