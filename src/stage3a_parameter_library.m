function library = stage3a_parameter_library(f_hz,candidates,theta_grid,measurement_kind,base_cfg)
%STAGE3A_PARAMETER_LIBRARY Complete-network templates over (G,theta).
%   This is the Stage-3A.1 analogue of topology_parameter_library and also
%   supports RLGC and complex coupler_gain fields from stage3a_apply_parameters.
    if isempty(candidates)||isempty(theta_grid)
        error('stage3a_parameter_library:EmptyInput','Candidates and theta_grid are required.');
    end
    item=struct('topology_index',0,'topology_id','','theta',struct(), ...
        'views',{{}},'regularization',NaN,'measurement_kind',char(measurement_kind));
    library=repmat(item,1,numel(candidates)*numel(theta_grid));cursor=0;
    for t=1:numel(candidates)
        for q=1:numel(theta_grid)
            cursor=cursor+1;theta=theta_grid(q);
            [views,~]=stage3a_compute_observations(f_hz,candidates(t),base_cfg,theta,measurement_kind);
            library(cursor)=struct('topology_index',t,'topology_id',candidates(t).id, ...
                'theta',theta,'views',{views},'regularization',theta.regularization, ...
                'measurement_kind',char(measurement_kind));
        end
    end
end
