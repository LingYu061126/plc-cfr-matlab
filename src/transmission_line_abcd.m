function T = transmission_line_abcd(gamma, Zc, length_m)
%TRANSMISSION_LINE_ABCD ABCD matrices for a uniform transmission line.
%   T is 2x2xN, where N is the number of frequency points. It uses the
%   project convention [V1; I1] = T [V2; I2], with currents directed from
%   the sending port toward the receiving port. length_m is in metres.

    if ~(isscalar(length_m) && isreal(length_m) && isfinite(length_m) && length_m >= 0)
        error('transmission_line_abcd:InvalidLength', 'length_m must be a finite nonnegative scalar in m.');
    end
    gamma = gamma(:).';
    Zc = Zc(:).';
    if numel(gamma) ~= numel(Zc)
        error('transmission_line_abcd:SizeMismatch', 'gamma and Zc must have the same number of points.');
    end
    x = gamma * length_m;
    co = cosh(x);
    si = sinh(x);
    n = numel(x);
    T = zeros(2, 2, n);
    T(1,1,:) = co;
    T(1,2,:) = Zc .* si;
    T(2,1,:) = si ./ Zc;
    T(2,2,:) = co;
end
