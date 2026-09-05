function batch = stream_composite_library_templates(candidates, theta_grid, start_index, batch_size)
%STREAM_COMPOSITE_LIBRARY_TEMPLATES Deterministic metadata batches for (G,theta).
%   This function deliberately returns only a bounded template description,
%   not precomputed CFRs. The matcher evaluates and releases each batch.

    total=numel(candidates)*numel(theta_grid);
    if nargin<3 || isempty(start_index),start_index=1;end
    if nargin<4 || isempty(batch_size),batch_size=32;end
    if start_index>total, batch=struct('items',struct([]),'next_index',total+1,'total',total);return;end
    last=min(total,start_index+batch_size-1);
    item=repmat(struct('linear_index',0,'topology_index',0,'parameter_grid_index',0, ...
        'template_id','','topology_id','','canonical_key','','theta',struct()),1,last-start_index+1);
    np=numel(theta_grid);
    for k=1:numel(item)
        linear=start_index+k-1; gi=ceil(linear/np); pi=linear-(gi-1)*np;
        item(k)=struct('linear_index',linear,'topology_index',gi,'parameter_grid_index',pi, ...
            'template_id',sprintf('%s_P%03d',candidates(gi).topology_id,pi), ...
            'topology_id',candidates(gi).topology_id,'canonical_key',candidates(gi).canonical_key, ...
            'theta',theta_grid(pi));
    end
    batch=struct('items',item,'next_index',last+1,'total',total);
end
