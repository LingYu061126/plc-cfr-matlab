function info = stage3a_observation_config(kind)
%STAGE3A_OBSERVATION_CONFIG Label observation O without conflating physics.
%   Ordinary OFDM CFR views use the complete network measurement bundle.
%   FDR/TFDR and input-admittance entries are explicitly named proxies and
%   are not presented as completed reflection instruments.
    if nargin < 1 || isempty(kind), kind = 'siso_forward'; end
    key = lower(char(kind));
    info = struct('kind',key,'O','','physical_quantity','','view_count',0, ...
        'network_is_complete',false,'is_proxy',false,'is_counterfactual',false, ...
        'description','');
    switch key
        case {'siso_forward','siso_forward_asymmetric', ...
                'siso_reverse_role_fixed','siso_reverse_endpoint_fixed', ...
                'bidirectional_endpoint_fixed','dual_receiver_complete', ...
                'dual_receiver_highz_complete', ...
                'three_view_complete'}
            info.O = 'ordinary_ofdm_cfr';
            info.physical_quantity = 'endpoint_or_node_voltage_CFR';
            info.network_is_complete = true;
            info.description = 'Complete-network voltage CFR measured by OFDM pilots.';
            if strcmp(key,'siso_forward') || contains(key,'reverse')
                info.view_count = 1;
            elseif strcmp(key,'bidirectional_endpoint_fixed') || ...
                    strcmp(key,'dual_receiver_complete') || ...
                    strcmp(key,'dual_receiver_highz_complete')
                info.view_count = 2;
            else
                info.view_count = 3;
            end
        case {'fdr_tfdr_reflection','fdr_tfdr_reflection_proxy'}
            info.kind = 'fdr_tfdr_reflection_proxy';
            info.O = 'fdr_tfdr_reflection_proxy';
            info.physical_quantity = 'input_reflection_coefficient_proxy';
            info.network_is_complete = true;
            info.is_proxy = true;
            info.view_count = 1;
            info.description = ['Frequency-domain input reflection proxy; not a ' ...
                'time-domain FDR/TFDR instrument model.'];
        case {'input_admittance','input_admittance_proxy'}
            info.kind = 'input_admittance_proxy';
            info.O = 'input_admittance_proxy';
            info.physical_quantity = 'input_admittance';
            info.network_is_complete = true;
            info.is_proxy = true;
            info.view_count = 1;
            info.description = 'Input admittance derived from the complete-network input impedance.';
        case 'dual_receiver_counterfactual'
            info.O = 'ordinary_ofdm_cfr';
            info.physical_quantity = 'counterfactual_unloaded_node_voltage_CFR';
            info.network_is_complete = true;
            info.is_counterfactual = true;
            info.view_count = 2;
            info.description = ['Analysis-only counterfactual: internal node voltage ' ...
                'computed while the internal receiver load is removed.'];
        otherwise
            error('stage3a_observation_config:UnknownKind', ...
                'Unknown observation kind %s.',key);
    end
end
