function T = shunt_abcd(Zin)
%SHUNT_ABCD ABCD matrices for a shunt branch input impedance.
%   Zin is a row vector in ohms and T is 2x2xN. The shunt is represented
%   by [1 0; 1/Zin 1] under the project's current convention. An open
%   circuit is therefore a unity matrix; a zero-ohm branch has infinite
%   admittance and is rejected as a nonphysical finite network.

    Zin = Zin(:).';
    if any(isnan(Zin))
        error('shunt_abcd:InvalidImpedance', 'Zin contains NaN.');
    end
    if any(Zin == 0)
        error('shunt_abcd:ZeroImpedance', 'A zero-ohm shunt is singular and cannot be represented by finite ABCD entries.');
    end
    n = numel(Zin);
    T = zeros(2, 2, n);
    T(1,1,:) = ones(1,1,n);
    T(2,2,:) = ones(1,1,n);
    T(2,1,:) = 1 ./ Zin;
end
