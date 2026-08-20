function result = topology_joint_match(observed_views,library,feature,ofdm_cfg,weights,lambda,feature_options)
%TOPOLOGY_JOINT_MATCH Joint grid search over candidate topology and theta.
%   objective = RMS_view(feature_distance) + lambda*R(theta). The grid and
%   lambda are configured simulation assumptions; the result is not a proof
%   that CFR uniquely identifies topology or continuous parameters.

    if nargin<7||isempty(feature_options),feature_options=struct();end
    if ~iscell(observed_views)||isempty(observed_views)||isempty(library)
        error('topology_joint_match:EmptyInput','Observed views and library are required.');
    end
    if ~(isscalar(lambda)&&isreal(lambda)&&isfinite(lambda)&&lambda>=0)
        error('topology_joint_match:InvalidLambda','lambda must be finite and nonnegative.');
    end
    if ~(isnumeric(weights)&&numel(weights)==2&&all(isfinite(weights))&& ...
            all(weights>=0)&&sum(weights)>0)
        error('topology_joint_match:InvalidWeights', ...
            'weights must contain two nonnegative finite values with positive sum.');
    end
    prepared=isstruct(library)&&isscalar(library)&& ...
        isfield(library,'is_prepared_parameter_library')&&library.is_prepared_parameter_library;
    if prepared
        data_distance=fast_prepared_distance(observed_views,library,feature, ...
            ofdm_cfg,weights,feature_options);
        regularization=library.regularization;
        items=library.items;
        topology_indices=library.topology_indices;
    else
        data_distance=zeros(1,numel(library));
        for k=1:numel(library)
            if numel(library(k).views)~=numel(observed_views)
                error('topology_joint_match:ViewCountMismatch','Library view counts must match observation.');
            end
            per=zeros(1,numel(observed_views));
            for v=1:numel(observed_views)
                per(v)=topology_feature_distance(observed_views{v},library(k).views{v}, ...
                    feature,ofdm_cfg,weights,feature_options);
            end
            data_distance(k)=sqrt(mean(per.^2));
        end
        regularization=[library.regularization];items=library;
        topology_indices=[library.topology_index];
    end
    score=data_distance+lambda*regularization;
    [best,index]=min(score);
    result=struct('predicted_index',items(index).topology_index, ...
        'predicted_id',items(index).topology_id,'theta_hat',items(index).theta, ...
        'template_index',index,'objective',best,'data_distance',data_distance(index), ...
        'scores',score,'data_distances',data_distance,'lambda',lambda, ...
        'template_topology_indices',topology_indices, ...
        'feature',char(feature),'view_count',numel(observed_views));
end

function distance=fast_prepared_distance(observed,cache,feature,ofdm_cfg,weights,options)
    if numel(observed)~=cache.view_count
        error('topology_joint_match:ViewCountMismatch','Prepared library view count mismatch.');
    end
    weights=weights(:).'/sum(weights);key=lower(char(feature));
    threshold=get_option(options,'phase_mask_threshold_db',-40);
    accumulated=zeros(size(cache.topology_indices));
    for v=1:cache.view_count
        obs=observed{v}(:).';
        if numel(obs)~=size(cache.H{v},2)||any(~isfinite(obs))
            error('topology_joint_match:InvalidObservedView','Observed view is invalid.');
        end
        switch key
            case {'amp_phase_joint_weighted','joint_weighted'}
                obs_amp=abs(obs);scale=sqrt(sum(obs_amp.^2));
                if scale<=realmin,obs_norm=zeros(size(obs_amp));else,obs_norm=obs_amp/scale;end
                amp_sq=mean((cache.amp_norm{v}-obs_norm).^2,2);
                phase_sq=weighted_phase_squared(obs,obs_amp,cache,v,threshold);
                per_sq=weights(1)*amp_sq+weights(2)*phase_sq;
            case {'complex','cfr_complex'}
                scale=sqrt(sum(abs(obs).^2));if scale<=realmin,obsn=zeros(size(obs));else,obsn=obs/scale;end
                per_sq=mean(abs(cache.complex_norm{v}-obsn).^2,2);
            case {'amp','amplitude','cfr_amplitude'}
                obs_amp=abs(obs);scale=sqrt(sum(obs_amp.^2));if scale<=realmin,obsn=zeros(size(obs_amp));else,obsn=obs_amp/scale;end
                per_sq=mean((cache.amp_norm{v}-obsn).^2,2);
            otherwise
                % Less common audit features retain the scalar reference path.
                n=numel(cache.items);per_sq=zeros(n,1);
                for k=1:n
                    d=topology_feature_distance(obs,cache.items(k).views{v}, ...
                        feature,ofdm_cfg,weights,options);per_sq(k)=d^2;
                end
        end
        accumulated=accumulated+per_sq(:).';
    end
    distance=sqrt(accumulated/cache.view_count);
end

function phase_sq=weighted_phase_squared(obs,obs_amp,cache,v,threshold)
    difference=unwrap(angle(obs))-cache.phase_unwrapped{v};
    amplitude=min(cache.amp{v},obs_amp);
    row_max=max(amplitude,[],2);mask=amplitude>=row_max*10^(threshold/20);
    [~,first]=max(mask,[],2);rows=(1:size(mask,1)).';
    offsets=difference(sub2ind(size(difference),rows,first));
    circular=angle(exp(1i*(difference-offsets)));
    amplitude(~mask)=0;den=sum(amplitude,2);den(den<=0)=1;
    phase_sq=(sum(amplitude.*circular.^2,2)./den)/(pi^2);
end

function value=get_option(options,name,default_value)
    if isfield(options,name)&&~isempty(options.(name)),value=options.(name);else,value=default_value;end
end
