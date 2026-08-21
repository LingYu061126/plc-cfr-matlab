function y = stage3a_explicit_linear_convolution(x,h)
%STAGE3A_EXPLICIT_LINEAR_CONVOLUTION Direct finite linear convolution.
%   The impulse response h is derived from the sampled CFR and is not
%   asserted to be a causal, calibrated PLC impulse response.
    x=x(:).'; h=h(:).';
    if isempty(x)||isempty(h)||any(~isfinite(x))||any(~isfinite(h))
        error('stage3a_explicit_linear_convolution:InvalidInput', ...
            'x and h must be finite nonempty vectors.');
    end
    y=conv(x,h);
end
