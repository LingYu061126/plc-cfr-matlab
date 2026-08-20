function Zin = branch_input_impedance(gamma, Zc, length_m, Zload)
%BRANCH_INPUT_IMPEDANCE Translate a branch load to its connection node.
%   gamma and Zc are row vectors; length_m is in metres. Zload may be a
%   scalar real/complex impedance or a vector matching gamma. Zin is a row
%   vector in ohms. Open circuit Inf, short circuit 0, and zero length are
%   handled elementwise and explicitly.

    gamma = gamma(:).';
    Zc = Zc(:).';
    if numel(gamma) ~= numel(Zc)
        error('branch_input_impedance:SizeMismatch', 'gamma and Zc must have the same number of points.');
    end
    if ~(isscalar(length_m) && isreal(length_m) && isfinite(length_m) && length_m >= 0)
        error('branch_input_impedance:InvalidLength', 'length_m must be a finite nonnegative scalar in m.');
    end
    if isscalar(Zload)
        Zload = Zload * ones(size(gamma));
    else
        Zload = Zload(:).';
    end
    if numel(Zload) ~= numel(gamma) || any(isnan(Zload)) || ...
            any(~(isfinite(Zload) | isinf(Zload)))
        error('branch_input_impedance:InvalidLoad', ...
            'Zload must be scalar or match gamma, with finite values or Inf.');
    end
    if length_m == 0
        Zin = Zload;
        return;
    end
    t = tanh(gamma * length_m);
    Zin = zeros(size(gamma));
    open_mask = isinf(Zload);
    short_mask = (Zload == 0);
    finite_mask = ~(open_mask | short_mask);
    Zin(open_mask) = Zc(open_mask) ./ t(open_mask);
    Zin(short_mask) = Zc(short_mask) .* t(short_mask);
    Zin(finite_mask) = Zc(finite_mask) .* ...
        (Zload(finite_mask) + Zc(finite_mask).*t(finite_mask)) ./ ...
        (Zc(finite_mask) + Zload(finite_mask).*t(finite_mask));
end
