function [network_out, cfg_out] = topology_apply_parameters(network, cfg, theta)
%TOPOLOGY_APPLY_PARAMETERS Apply explicit nuisance parameters to a topology.
%   theta fields are scale factors unless an absolute impedance is supplied:
%   main_length_scale, branch_length_scale, branch_load_scale, kG_scale,
%   source_impedance_ohm and receiver_impedance_ohm. The topology/edge set is
%   unchanged. Inf and zero branch loads remain explicit physical limits.

    network_out = network; cfg_out = cfg;
    main_scale = get_theta(theta,'main_length_scale',1);
    branch_scale = get_theta(theta,'branch_length_scale',1);
    load_scale = get_theta(theta,'branch_load_scale',1);
    kg_scale = get_theta(theta,'kG_scale',1);
    validate_scale(main_scale,'main_length_scale',true);
    validate_scale(branch_scale,'branch_length_scale',true);
    validate_scale(load_scale,'branch_load_scale',false);
    validate_scale(kg_scale,'kG_scale',false);
    network_out.main_lengths = network.main_lengths .* main_scale;
    if isfield(network_out,'branches')
        for b = 1:numel(network_out.branches)
            network_out.branches(b).length = network_out.branches(b).length .* branch_scale;
            if isfinite(load_scale)
                network_out.branches(b).load = network_out.branches(b).load .* load_scale;
            elseif isinf(load_scale)
                network_out.branches(b).load = Inf;
            end
        end
    end
    cfg_out.kG = cfg.kG .* kg_scale;
    if isfield(theta,'source_impedance_ohm'), cfg_out.Zs = theta.source_impedance_ohm; end
    if isfield(theta,'receiver_impedance_ohm'), cfg_out.Zr = theta.receiver_impedance_ohm; end
end

function value=get_theta(theta,name,default_value)
    if isfield(theta,name)&&~isempty(theta.(name)), value=theta.(name); else, value=default_value; end
end
function validate_scale(x,name,allow_zero)
    lower = 0; if ~allow_zero, lower = eps; end
    if ~(isscalar(x)&&isreal(x)&&isfinite(x)&&x>=lower)
        error('topology_apply_parameters:InvalidScale','%s is invalid.',name);
    end
end
