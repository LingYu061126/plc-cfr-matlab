function out=stage7a9_holdout_stat(observed,network,params,base,cfg,views,sigma)
%STAGE7A9_HOLDOUT_STAT Unchanged normalized holdout statistic.
%   Parameters are dimensionless scales; Zin is ohm and CFR dimensionless.
    ix=cfg.frequency_holdout_indices;
    theta=struct('main_length_scale',params(1),'branch_length_scale',1, ...
        'branch_load_scale',params(2),'first_segment_scale',1, ...
        'source_impedance_ohm',50,'receiver_impedance_ohm',50);
    z=stage7a9_forward_state(network,theta,base,cfg.frequency_hz(ix),cfg.state_50);
    pred={z.H_endpoint,z.Zin};sum_sq=0;
    for v=views
        r=sqrt(mean(abs(pred{v}-observed{v}(ix)).^2))/sigma(v);
        sum_sq=sum_sq+r^2;
    end
    out=struct('statistic',sqrt(sum_sq/numel(views)), ...
        'frequency_count',numel(ix),'forward_calls',1,'params',params);
end
