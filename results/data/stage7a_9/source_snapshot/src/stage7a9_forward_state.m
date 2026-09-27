function out=stage7a9_forward_state(network,theta,base,frequency_hz,state)
%STAGE7A9_FORWARD_STATE Same physical views with call-local cable spectra reuse.
%   Lengths are m, frequency_hz is Hz, H_endpoint is dimensionless and Zin
%   is ohm. The nodal solver and port normalization are unchanged.
    [net,local]=topology_apply_parameters(network,base,theta);
    if isfield(theta,'first_segment_scale')
        net.main_lengths(1)=net.main_lengths(1)*theta.first_segment_scale;
    end
    nmain=numel(net.main_lengths)+1;
    meas=struct('source_node',1,'source_impedance_ohm',50, ...
        'receiver_nodes',nmain,'receiver_loads_ohm',state.receiver_ohm, ...
        'source_voltage_v',1,'port_reference_ohm',50);
    if state.node_index>0
        assert(state.node_index>1&&state.node_index<nmain,'stage7a9:InvalidNode');
        meas.receiver_nodes=[nmain,state.node_index];
        meas.receiver_loads_ohm=[state.receiver_ohm,state.node_load_ohm];
    end
    [h,d]=stage7a9_network_response(frequency_hz,net,meas,local,true);
    v0=d.node_voltage_v(1,:);
    source_current=(meas.source_voltage_v-v0)/meas.source_impedance_ohm;
    assert(all(abs(source_current)>1e-13),'stage7a9:OpenInput');
    zin=v0./source_current;
    assert(all(isfinite(zin)),'stage7a9:NonfiniteZin');
    out=struct('H_endpoint',h.H_port(1,:),'Zin',zin, ...
        'Gamma50',(zin-50)./(zin+50),'H_node',[], ...
        'node_index',state.node_index,'node_load_ohm',state.node_load_ohm, ...
        'receiver_ohm',state.receiver_ohm,'source_ohm',50, ...
        'source_node_voltage_v',v0, ...
        'spectrum_requests',d.spectrum_requests, ...
        'spectrum_evaluations',d.spectrum_evaluations);
    if state.node_index>0,out.H_node=h.H_port(2,:);end
end
