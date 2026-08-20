function [Zin, Vout_over_Vin] = terminated_line_response(gamma, Zc, length_m, Zload)
%TERMINATED_LINE_RESPONSE Stable input impedance and voltage ratio.
%   gamma, Zc and Zload are frequency vectors (Zload may also be scalar).
%   Zin is the impedance looking into a line of length_m metres terminated
%   by Zload. Vout_over_Vin is the right-end voltage divided by the
%   left-end voltage. The voltage ratio is evaluated as
%
%     2*Zload*exp(-x) / ((Zload+Zc)+(Zload-Zc)*exp(-2*x)), x=gamma*d,
%
%   avoiding direct cosh/sinh growth. Open, short and zero length are
%   handled explicitly. This formulation assumes passive propagation with
%   real(gamma)>=0, as produced by cable_rlgc.

    gamma = gamma(:).';
    Zc = Zc(:).';
    if numel(gamma) ~= numel(Zc)
        error('terminated_line_response:SizeMismatch', ...
            'gamma and Zc must have the same number of points.');
    end
    if ~(isscalar(length_m) && isreal(length_m) && ...
            isfinite(length_m) && length_m >= 0)
        error('terminated_line_response:InvalidLength', ...
            'length_m must be a finite nonnegative scalar in m.');
    end
    if any(real(gamma) < -1e-14)
        error('terminated_line_response:ActivePropagation', ...
            'Stable recursion requires passive propagation with real(gamma)>=0.');
    end
    if isscalar(Zload)
        Zload = Zload * ones(size(gamma));
    else
        Zload = Zload(:).';
    end
    if numel(Zload) ~= numel(gamma) || any(isnan(Zload)) || ...
            any(~(isfinite(Zload) | isinf(Zload)))
        error('terminated_line_response:InvalidLoad', ...
            'Zload must be scalar or match gamma, with finite values or Inf.');
    end
    if length_m == 0
        Zin = Zload;
        Vout_over_Vin = ones(size(gamma));
        return;
    end

    x = gamma * length_m;
    t = tanh(x);
    em = exp(-x);
    em2 = exp(-2*x);
    Zin = zeros(size(gamma));
    Vout_over_Vin = zeros(size(gamma));
    open_mask = isinf(Zload);
    short_mask = (Zload == 0);
    finite_mask = ~(open_mask | short_mask);

    Zin(open_mask) = Zc(open_mask) ./ t(open_mask);
    Vout_over_Vin(open_mask) = 2*em(open_mask) ./ (1 + em2(open_mask));
    Zin(short_mask) = Zc(short_mask) .* t(short_mask);
    Vout_over_Vin(short_mask) = 0;
    Zin(finite_mask) = Zc(finite_mask) .* ...
        (Zload(finite_mask) + Zc(finite_mask).*t(finite_mask)) ./ ...
        (Zc(finite_mask) + Zload(finite_mask).*t(finite_mask));
    Vout_over_Vin(finite_mask) = ...
        2*Zload(finite_mask).*em(finite_mask) ./ ...
        ((Zload(finite_mask)+Zc(finite_mask)) + ...
        (Zload(finite_mask)-Zc(finite_mask)).*em2(finite_mask));
end
