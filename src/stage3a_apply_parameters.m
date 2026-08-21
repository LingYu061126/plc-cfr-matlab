function [network_out,cfg_out,theta_out] = stage3a_apply_parameters(network,cfg,theta)
%STAGE3A_APPLY_PARAMETERS Apply explicit nuisance parameters to a network.
%   The topology and legacy physical formulas are unchanged. Optional
%   network.rlgc_scale is consumed only by the new Stage-3A path.
    if nargin < 3 || isempty(theta), theta=struct(); end
    defaults=struct('main_length_scale',1,'branch_length_scale',1, ...
        'branch_load_scale',1,'kG_scale',1,'source_impedance_ohm',cfg.Zs, ...
        'receiver_impedance_ohm',cfg.Zr,'R_scale',1,'L_scale',1, ...
        'G_scale',1,'C_scale',1,'coupler_gain',1);
    theta_out=theta; names=fieldnames(defaults);
    for k=1:numel(names)
        if ~isfield(theta_out,names{k})||isempty(theta_out.(names{k})),theta_out.(names{k})=defaults.(names{k});end
    end
    validate_scale(theta_out.main_length_scale,'main_length_scale',true);
    validate_scale(theta_out.branch_length_scale,'branch_length_scale',true);
    validate_scale(theta_out.branch_load_scale,'branch_load_scale',false);
    validate_scale(theta_out.kG_scale,'kG_scale',false);
    validate_scale(theta_out.R_scale,'R_scale',false);validate_scale(theta_out.L_scale,'L_scale',false);
    validate_scale(theta_out.G_scale,'G_scale',false);validate_scale(theta_out.C_scale,'C_scale',false);
    validate_impedance(theta_out.source_impedance_ohm,'source_impedance_ohm');
    validate_impedance(theta_out.receiver_impedance_ohm,'receiver_impedance_ohm');
    if ~(isscalar(theta_out.coupler_gain)&&isfinite(theta_out.coupler_gain))
        error('stage3a_apply_parameters:InvalidCouplerGain','coupler_gain must be finite scalar.');
    end
    network_out=network;network_out.main_lengths=network.main_lengths*theta_out.main_length_scale;
    if isfield(network_out,'branches')&&~isempty(network_out.branches)
        for k=1:numel(network_out.branches)
            network_out.branches(k).length=network_out.branches(k).length*theta_out.branch_length_scale;
            if isinf(theta_out.branch_load_scale),network_out.branches(k).load=Inf;
            else,network_out.branches(k).load=network_out.branches(k).load*theta_out.branch_load_scale;end
        end
    end
    network_out.rlgc_scale=struct('R_scale',theta_out.R_scale,'L_scale',theta_out.L_scale, ...
        'G_scale',theta_out.G_scale,'C_scale',theta_out.C_scale);
    cfg_out=cfg;cfg_out.kG=cfg.kG*theta_out.kG_scale;
    cfg_out.Zs=theta_out.source_impedance_ohm;cfg_out.Zr=theta_out.receiver_impedance_ohm;
end
function validate_impedance(x,name)
    if ~(isscalar(x)&&isnumeric(x)&&~islogical(x)&&isfinite(x))
        error('stage3a_apply_parameters:InvalidImpedance','%s must be a finite scalar.',name);
    end
end
function validate_scale(x,name,allow_zero)
    low=eps;if allow_zero,low=0;end
    if ~(isscalar(x)&&isreal(x)&&isfinite(x)&&x>=low)
        error('stage3a_apply_parameters:InvalidScale','%s is invalid.',name);
    end
end
