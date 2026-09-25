function out=stage7a4_forward_state(network,theta,base,frequency_hz,state)
%STAGE7A4_FORWARD_STATE Compute one known boundary state's complex views.
%   Network line lengths are m; frequency_hz is 1-by-F in Hz. Output H is
%   50-ohm-reference port-normalized CFR, Zin is line-side source impedance
%   in ohm, and H_node is a loaded internal receiver CFR when requested.
%   The source is M0 with 50-ohm Thevenin impedance and 1-V open voltage.
    [net,local]=topology_apply_parameters(network,base,theta);
    if isfield(theta,'first_segment_scale')
        net.main_lengths(1)=net.main_lengths(1)*theta.first_segment_scale;
    end
    nmain=numel(net.main_lengths)+1;
    meas=struct('source_node',1,'source_impedance_ohm',50, ...
        'receiver_nodes',nmain,'receiver_loads_ohm',state.receiver_ohm, ...
        'source_voltage_v',1,'port_reference_ohm',50);
    if state.node_index>0
        assert(state.node_index>1&&state.node_index<nmain,'stage7a4:InvalidNode');
        meas.receiver_nodes=[nmain,state.node_index];
        meas.receiver_loads_ohm=[state.receiver_ohm,state.node_load_ohm];
    end
    [h,d]=plc_full_network_response(frequency_hz,net,meas,local);
    v0=d.node_voltage_v(1,:);
    source_current=(meas.source_voltage_v-v0)/meas.source_impedance_ohm;
    assert(all(abs(source_current)>1e-13),'stage7a4:OpenInput');
    zin=v0./source_current;
    assert(all(isfinite(zin)),'stage7a4:NonfiniteZin');
    out=struct('H_endpoint',h.H_port(1,:),'Zin',zin, ...
        'Gamma50',(zin-50)./(zin+50),'H_node',[], ...
        'node_index',state.node_index,'node_load_ohm',state.node_load_ohm, ...
        'receiver_ohm',state.receiver_ohm,'source_ohm',50, ...
        'source_node_voltage_v',v0);
    if state.node_index>0,out.H_node=h.H_port(2,:);end
end
