function cable = cable_parameters(cable_type)
%CABLE_PARAMETERS Return the prescribed PLC cable parameters.
%   cable = CABLE_PARAMETERS(cable_type) returns a scalar struct for cable
%   type 0 or 1. Units: area mm^2, epsilon dimensionless, Z0 ohm,
%   C pF/m, L uH/m, R0 and G0 are the coefficients in the task formulas.
%   The tabulated Z0 is nominal only; calculations use frequency-dependent
%   complex Zc obtained from cable_rlgc.

    if ~(isscalar(cable_type) && (cable_type == 0 || cable_type == 1))
        error('cable_parameters:InvalidType', ...
            'cable_type must be the scalar value 0 or 1.');
    end

    if cable_type == 0
        cable = struct('type', 0, 'area_mm2', 1.5, 'epsilon_r', 1.45, ...
            'Z0_nominal_ohm', 270, 'C_pF_per_m', 15, ...
            'L_uH_per_m', 1.08, 'R0', 12, 'G0', 30.9);
    else
        cable = struct('type', 1, 'area_mm2', 2.5, 'epsilon_r', 1.52, ...
            'Z0_nominal_ohm', 234, 'C_pF_per_m', 17.5, ...
            'L_uH_per_m', 0.96, 'R0', 9.34, 'G0', 34.7);
    end
end
