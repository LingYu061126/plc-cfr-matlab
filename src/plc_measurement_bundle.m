function [measurements, metadata] = plc_measurement_bundle(kind, network, theta, cfg)
%PLC_MEASUREMENT_BUNDLE Define physically labelled complete-network views.
%   source/receiver impedances in theta are role impedances for forward
%   measurement. endpoint-fixed reverse measurement swaps them because the
%   physical endpoint hardware remains at the same location. role-fixed
%   reverse measurement instead moves the same transmitter/receiver roles.

    nmain=numel(network.main_lengths)+1;
    mid=ceil(nmain/2);
    Ztx=get_theta(theta,'source_impedance_ohm',cfg.Zs);
    Zrx=get_theta(theta,'receiver_impedance_ohm',cfg.Zr);
    base=struct('source_node',1,'source_impedance_ohm',Ztx, ...
        'receiver_nodes',nmain,'receiver_loads_ohm',Zrx, ...
        'source_voltage_v',1,'port_reference_ohm',cfg.port_reference_ohm);
    key=lower(char(kind));
    switch key
        case {'siso_forward','siso_forward_asymmetric'}
            measurements=base;
            meaning='forward: endpoint A transmitter, endpoint B receiver';
        case 'siso_reverse_role_fixed'
            measurements=base; measurements.source_node=nmain;
            measurements.receiver_nodes=1;
            meaning=['reverse with role-fixed impedances: transmitter/receiver ' ...
                'devices move between endpoints'];
        case 'siso_reverse_endpoint_fixed'
            measurements=base; measurements.source_node=nmain;
            measurements.source_impedance_ohm=Zrx;
            measurements.receiver_nodes=1; measurements.receiver_loads_ohm=Ztx;
            meaning=['reverse with endpoint-fixed impedances: physical endpoint ' ...
                'terminations are retained and source/load values swap roles'];
        case 'bidirectional_endpoint_fixed'
            forward=base;
            reverse=base; reverse.source_node=nmain; reverse.source_impedance_ohm=Zrx;
            reverse.receiver_nodes=1; reverse.receiver_loads_ohm=Ztx;
            measurements=[forward,reverse];
            meaning='two separate full-network excitations with endpoint-fixed impedances';
        case 'dual_receiver_complete'
            measurements=base; measurements.receiver_nodes=[nmain,mid];
            measurements.receiver_loads_ohm=[Zrx,Zrx];
            meaning='one full-network excitation with endpoint and internal receiver loads simultaneously connected';
        case 'dual_receiver_highz_complete'
            measurements=base; measurements.receiver_nodes=[nmain,mid];
            measurements.receiver_loads_ohm=[Zrx,1e6];
            meaning=['one full-network excitation with an endpoint receiver and ' ...
                'a finite high-input-impedance internal receiver'];
        case 'three_view_complete'
            forward=base; forward.receiver_nodes=[nmain,mid];
            forward.receiver_loads_ohm=[Zrx,Zrx];
            reverse=base; reverse.source_node=nmain; reverse.source_impedance_ohm=Zrx;
            reverse.receiver_nodes=1; reverse.receiver_loads_ohm=Ztx;
            measurements=[forward,reverse];
            meaning='two forward receiver voltages plus one endpoint-fixed reverse view';
        otherwise
            error('plc_measurement_bundle:UnknownKind','Unknown measurement kind %s.',key);
    end
    metadata=struct('kind',key,'physical_meaning',meaning,'main_node_count',nmain, ...
        'internal_receiver_node',mid,'network_is_truncated',false, ...
        'source_impedance_role_ohm',Ztx,'receiver_impedance_role_ohm',Zrx);
end

function value=get_theta(theta,name,default_value)
    if isfield(theta,name)&&~isempty(theta.(name)),value=theta.(name);else,value=default_value;end
end
