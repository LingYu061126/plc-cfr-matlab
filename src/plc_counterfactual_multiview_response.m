function [views,details] = plc_counterfactual_multiview_response(f_hz,network,measurement,cfg)
%PLC_COUNTERFACTUAL_MULTIVIEW_RESPONSE Unloaded internal-node comparison.
%   The endpoint receiver remains a real shunt in the complete network. The
%   internal node voltage is read from that same solve without adding an
%   internal receiver load. This is an analysis-only counterfactual, not a
%   realizable zero-loading instrument model.
    if numel(measurement.receiver_nodes)~=1
        error('plc_counterfactual_multiview_response:InvalidMeasurement', ...
            'The counterfactual requires one loaded endpoint receiver.');
    end
    nmain=numel(network.main_lengths)+1; mid=ceil(nmain/2);
    [H,d]=plc_full_network_response(f_hz,network,measurement,cfg);
    scale=((measurement.source_impedance_ohm+measurement.port_reference_ohm)/ ...
        measurement.port_reference_ohm)/measurement.source_voltage_v;
    internal=scale*d.node_voltage_v(mid,:);
    views={H.H_port(1,:),internal};
    details=struct('full_network_for_every_view',true,'counterfactual',true, ...
        'internal_receiver_loaded',false,'endpoint_receiver_loaded',true, ...
        'internal_node',mid,'measurement',measurement,'solve_details',d, ...
        'view_count',2,'description','Analysis-only unloaded internal-node voltage.');
end
