function [views, details] = plc_multiview_response(f_hz, network, measurements, cfg)
%PLC_MULTIVIEW_RESPONSE Evaluate labelled views on the same complete network.
%   measurements is a struct array. Each element is one physical excitation
%   state accepted by plc_full_network_response and may contain multiple
%   simultaneously loaded receiver_nodes. views is a cell array with one CFR
%   per receiver, in measurement order. Separate excitation states do not
%   truncate or otherwise alter the network topology.

    if ~isstruct(measurements) || isempty(measurements)
        error('plc_multiview_response:InvalidMeasurements', ...
            'measurements must be a nonempty struct array.');
    end
    views = {};
    solve_details = cell(1,numel(measurements));
    view_meta = repmat(struct('measurement_index',0,'receiver_index',0, ...
        'source_node',0,'receiver_node',0,'label',''),0,1);
    for m = 1:numel(measurements)
        [H,d] = plc_full_network_response(f_hz,network,measurements(m),cfg);
        solve_details{m}=d;
        for r = 1:size(H.H_port,1)
            views{end+1}=H.H_port(r,:); %#ok<AGROW>
            label = sprintf('%s_to_%s',d.source_node_label,d.receiver_node_labels{r});
            view_meta(end+1)=struct('measurement_index',m,'receiver_index',r, ...
                'source_node',d.source_node,'receiver_node',d.receiver_nodes(r), ...
                'label',label); %#ok<AGROW>
        end
    end
    details = struct('full_network_for_every_view',true, ...
        'measurement_count',numel(measurements),'view_count',numel(views), ...
        'solve_details',{solve_details},'view_metadata',view_meta);
end
