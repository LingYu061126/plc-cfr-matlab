function result = match_candidate_library_calibrated(observed_views,cache,calibration_model,options)
%MATCH_CANDIDATE_LIBRARY_CALIBRATED Score a truth-free candidate cache.
%   With options.return_raw=true this returns reusable distance diagnostics;
%   otherwise it applies the requested calibrated confirmation method.
%   The interface accepts only observations, templates and calibration data.
    required={'feature','weights','method'};
    for k=1:numel(required)
        if ~isfield(options,required{k}), error('stage4a4:MissingOption','options.%s is required.',required{k}); end
    end
    if isempty(cache) || ~isfield(cache,'templates') || isempty(cache.templates)
        raw=empty_raw(cache); result=apply_candidate_confirmation(raw,calibration_model,options); return;
    end
    if ~iscell(observed_views) || isempty(observed_views), error('stage4a4:InvalidObservation','A nonempty view cell is required.'); end
    n=numel(cache.templates); nv=numel(observed_views);
    if isfield(cache,'cfr_views') && numel(cache.cfr_views)~=nv, error('stage4a4:ViewCountMismatch','View count mismatch.'); end
    tic; distances=Inf(1,n);
    for k=1:n
        dv=zeros(1,nv);
        for v=1:nv
            ref=cached_view(cache,k,v);
            if numel(ref)~=numel(observed_views{v}), error('stage4a4:FrequencyMismatch','Frequency dimensions differ.'); end
            if is_raw_feature(options.feature)
                dv(v)=sqrt(mean(abs(observed_views{v}(:).'-ref).^2));
            else
                dv(v)=topology_feature_distance(observed_views{v},ref,options.feature,cache.ofdm_config,options.weights,get_option(options,'distance_options',cache.distance_options));
            end
        end
        distances(k)=sqrt(mean(dv.^2));
    end
    elapsed=toc;
    ids={cache.templates.topology_id}; class_ids={cache.templates.equivalence_class};
    topology_labels=stable_unique(ids); class_labels=stable_unique(class_ids);
    class_members=cell(1,numel(class_labels));
    topology_scores=Inf(1,numel(topology_labels)); topology_best=zeros(1,numel(topology_labels));
    class_scores=Inf(1,numel(class_labels)); class_best=zeros(1,numel(class_labels));
    for k=1:numel(topology_labels)
        ix=find(strcmp(ids,topology_labels{k})); [topology_scores(k),j]=min(distances(ix)); topology_best(k)=ix(j);
    end
    for k=1:numel(class_labels)
        ix=find(strcmp(class_ids,class_labels{k})); [class_scores(k),j]=min(distances(ix)); class_best(k)=ix(j);
        class_members{k}=stable_unique(ids(ix));
    end
    baseline_labels=stable_unique({cache.templates.baseline_P0_equivalence_class});
    baseline_labels=baseline_labels(~cellfun(@isempty,baseline_labels));
    baseline_scores=Inf(1,numel(baseline_labels));
    for k=1:numel(baseline_labels)
        ix=find(strcmp({cache.templates.baseline_P0_equivalence_class},baseline_labels{k}));
        if ~isempty(ix), baseline_scores(k)=min(distances(ix)); end
    end
    [d1,bi]=min(class_scores); other=class_scores; other(bi)=Inf; [d2,si]=min(other);
    if isinf(d2), second_class=''; else, second_class=class_labels{si}; end
    bt=class_best(bi); best=cache.templates(bt); margin=d2-d1;
    raw=struct('best_template_id',best.template_id,'best_topology_id',best.topology_id, ...
        'best_topology_index',best.topology_index,'best_equivalence_class',class_labels{bi}, ...
        'baseline_P0_equivalence_class',best.baseline_P0_equivalence_class, ...
        'baseline_P0_equivalence_class_size',best.baseline_P0_equivalence_class_size, ...
        'prior_conditioned_equivalence_class',class_labels{bi}, ...
        'prior_conditioned_equivalence_class_size',best.equivalence_class_size, ...
        'best_parameter_values',best.theta,'best_distance',d1,'second_competing_class',second_class, ...
        'second_distance',d2,'margin',margin,'rho',d1/(d2+get_option(options,'epsilon',1e-12)), ...
        'topology_scores',topology_scores,'topology_labels',{topology_labels}, ...
        'topology_best_template',topology_best,'class_scores',class_scores, ...
        'class_labels',{class_labels},'class_best_template',class_best, ...
        'class_members',{class_members},'best_equivalence_members',strjoin(class_members{bi},','), ...
        'baseline_class_scores',baseline_scores,'baseline_class_labels',{baseline_labels}, ...
        'candidate_count_before_prior',get_option(options,'candidate_count_before_prior',cache.candidate_count), ...
        'candidate_count_after_prior',cache.candidate_count,'parameter_template_count',cache.parameter_template_count, ...
        'composite_template_count',cache.composite_template_count,'distance_evaluations',n*nv, ...
        'matching_time_s',elapsed,'cache_hit',true,'configuration_hash',cache.configuration_hash, ...
        'current_class_size',best.equivalence_class_size,'class_index',bi,'second_class_index',si, ...
        'cache_frequency_grid_id',cache.frequency_grid_id);
    if get_option(options,'return_raw',false), result=raw; else, result=apply_candidate_confirmation(raw,calibration_model,options); end
end

function raw=empty_raw(cache)
    hash=''; n=0; p=0; grid_id='';
    if ~isempty(cache), hash=get_option(cache,'configuration_hash',''); n=get_option(cache,'candidate_count',0); p=get_option(cache,'parameter_template_count',0); grid_id=get_option(cache,'frequency_grid_id',''); end
    raw=struct('best_template_id','','best_topology_id','','best_topology_index',NaN,'best_equivalence_class','', ...
        'baseline_P0_equivalence_class','','baseline_P0_equivalence_class_size',0,'prior_conditioned_equivalence_class','', ...
        'prior_conditioned_equivalence_class_size',0,'best_parameter_values',struct(),'best_distance',Inf, ...
        'second_competing_class','','second_distance',Inf,'margin',NaN,'rho',NaN,'topology_scores',[], ...
        'topology_labels',{{}},'topology_best_template',[],'class_scores',[],'class_labels',{{}}, ...
        'class_best_template',[],'class_members',{{}},'best_equivalence_members','', ...
        'baseline_class_scores',[],'baseline_class_labels',{{}}, ...
        'candidate_count_before_prior',get_option(cache,'candidate_count',n), ...
        'candidate_count_after_prior',0,'parameter_template_count',p,'composite_template_count',0, ...
        'distance_evaluations',0,'matching_time_s',0,'cache_hit',false,'configuration_hash',hash, ...
        'current_class_size',0,'class_index',NaN,'second_class_index',NaN,'cache_frequency_grid_id',grid_id);
end
function x=cached_view(cache,k,v)
    if isfield(cache,'cfr_views') && ~isempty(cache.cfr_views), x=cache.cfr_views{v}(k,:); else, x=cache.templates(k).views{v}; end
end
function y=stable_unique(x)
    y={}; for k=1:numel(x), if ~any(strcmp(y,x{k})), y{end+1}=x{k}; end, end
end
function tf=is_raw_feature(x), tf=ismember(lower(char(x)),{'complex_raw','cfr_complex_raw','raw_complex'}); end
function x=get_option(s,name,d)
    if isfield(s,name)&&~isempty(s.(name)), x=s.(name); else, x=d; end
end
