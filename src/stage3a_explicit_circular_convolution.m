function y = stage3a_explicit_circular_convolution(x,h)
%STAGE3A_EXPLICIT_CIRCULAR_CONVOLUTION Direct periodic convolution.
%   y[n] = sum_m h[m] x[(n-m) mod N]. This is an explicit time-domain
%   implementation of the same N-point circular filtering used by the
%   Stage-3A sampled-CFR model; it is not a causal finite PLC impulse model.
%   x and h are finite row/column vectors with equal length.
    x=x(:).'; h=h(:).'; n=numel(x);
    if n<1 || numel(h)~=n || any(~isfinite(x)) || any(~isfinite(h))
        error('stage3a_explicit_circular_convolution:InvalidInput', ...
            'x and h must be finite nonempty vectors of equal length.');
    end
    y=complex(zeros(1,n)); offsets=0:n-1;
    for k=1:n
        indices=mod((k-1)-offsets,n)+1;
        y(k)=sum(h.*x(indices));
    end
end
