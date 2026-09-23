function y=stage6b_forward_cfr(network,theta,base,frequency_hz,measurement_kind)
%STAGE6B_FORWARD_CFR Thin wrapper around the existing Stage 4A forward path.
    if nargin<5||isempty(measurement_kind),measurement_kind='siso_forward';end
    [net,local]=topology_apply_parameters(network,base,theta);
    [measurement,~]=plc_measurement_bundle(measurement_kind,net,theta,local);
    [views,~]=plc_multiview_response(frequency_hz,net,measurement,local);
    y=views{1}(:).';
end
