function [H_V, H_port, denominator] = abcd_to_transfer(T, Zs, Zr, Zport_ref)
%ABCD_TO_TRANSFER Convert a total ABCD matrix to voltage transfer functions.
%   T is 2x2xN with [V1;I1]=T[V2;I2]. Zs and Zr are source/load ohms.
%   H_V=Vr/Vs uses the open-circuit Thevenin source voltage Vs. H_port is
%   normalized to Vref=Vs*Zport_ref/(Zs+Zport_ref), the voltage produced
%   across a reference termination. With Zs=Zport_ref=50 ohm only,
%   Vref=Vs/2 and H_port=2*H_V.

    if ~((ndims(T) == 2 && all(size(T) == [2, 2])) || ...
            (ndims(T) == 3 && size(T,1) == 2 && size(T,2) == 2))
        error('abcd_to_transfer:InvalidMatrix', 'T must have size 2x2xN.');
    end
    if nargin < 4 || isempty(Zport_ref)
        Zport_ref = 50;
    end
    if ~(isscalar(Zs) && isfinite(Zs) && isscalar(Zr) && ...
            (isfinite(Zr) || isinf(Zr)))
        error('abcd_to_transfer:InvalidTermination', ...
            'Zs must be finite and Zr must be a finite scalar or Inf.');
    end
    if ~(isscalar(Zport_ref) && isreal(Zport_ref) && ...
            isfinite(Zport_ref) && Zport_ref > 0)
        error('abcd_to_transfer:InvalidPortReference', ...
            'Zport_ref must be a finite positive real scalar in ohms.');
    end
    A = squeeze(T(1,1,:)).';
    B = squeeze(T(1,2,:)).';
    C = squeeze(T(2,1,:)).';
    D = squeeze(T(2,2,:)).';
    if isinf(Zr)
        denominator = A + Zs .* C;
        H_V = 1 ./ denominator;
    else
        denominator = A .* Zr + B + Zs .* (C .* Zr + D);
        H_V = Zr ./ denominator;
    end
    H_port = ((Zs + Zport_ref) / Zport_ref) .* H_V;
end
