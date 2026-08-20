function library = topology_parameter_library(f_hz,candidates,theta_grid,measurement_kind,cfg)
%TOPOLOGY_PARAMETER_LIBRARY Precompute full-network views over (G,theta).
%   Every template stores its topology index, nuisance parameters, complete-
%   network observation views and regularization value.

    if isempty(candidates)||isempty(theta_grid)
        error('topology_parameter_library:EmptyInput','Candidates and theta_grid are required.');
    end
    item=struct('topology_index',0,'topology_id','','theta',struct(), ...
        'views',{{}},'regularization',NaN,'measurement_kind',char(measurement_kind));
    library=repmat(item,1,numel(candidates)*numel(theta_grid)); cursor=0;
    for t=1:numel(candidates)
        for q=1:numel(theta_grid)
            cursor=cursor+1; theta=theta_grid(q);
            [net,local_cfg]=topology_apply_parameters(candidates(t).network,cfg,theta);
            [measurements,~]=plc_measurement_bundle(measurement_kind,net,theta,local_cfg);
            [views,~]=plc_multiview_response(f_hz,net,measurements,local_cfg);
            library(cursor)=struct('topology_index',t,'topology_id',candidates(t).id, ...
                'theta',theta,'views',{views},'regularization',theta.regularization, ...
                'measurement_kind',char(measurement_kind));
        end
    end
end
