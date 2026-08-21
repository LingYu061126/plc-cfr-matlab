function cable = cable_apply_rlgc_scale(cable,scale)
%CABLE_APPLY_RLGC_SCALE Apply optional multiplicative RLGC uncertainty.
%   Without an explicit network.rlgc_scale field, legacy calculations are
%   unchanged. Units remain ohm/m, H/m, S/m and F/m through cable metadata.
    if nargin<2||isempty(scale),return;end
    if ~isstruct(scale),error('cable_apply_rlgc_scale:InvalidScale','scale must be a struct.');end
    names={'R_scale','L_scale','G_scale','C_scale'};
    for k=1:numel(names)
        if ~isfield(scale,names{k}),scale.(names{k})=1;end
        if ~(isscalar(scale.(names{k}))&&isreal(scale.(names{k}))&&isfinite(scale.(names{k}))&&scale.(names{k})>=0)
            error('cable_apply_rlgc_scale:InvalidScale','Invalid %s.',names{k});
        end
    end
    cable.R0=cable.R0*scale.R_scale;cable.L_uH_per_m=cable.L_uH_per_m*scale.L_scale;
    cable.G0=cable.G0*scale.G_scale;cable.C_pF_per_m=cable.C_pF_per_m*scale.C_scale;
end
