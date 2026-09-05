function result = match_composite_topology_library(observed_views, f_hz, candidates, theta_grid, cfg, options)
%MATCH_COMPOSITE_TOPOLOGY_LIBRARY Streamed CFR matching with auditable output.
%   The nominated class audit uses nominal full-complex CFR equivalence.
%   Template scores are searched in bounded batches; parameter templates in
%   the same physical class never become the reported second competitor.

    required={'measurement_kind','tie_tolerance','distance_feature','distance_weights', ...
        'distance_options','batch_size','thresholds','candidate_count_before_prior','coverage_status'};
    for k=1:numel(required), if ~isfield(options,required{k}), error('match_composite_topology_library:MissingOption','options.%s is required.',required{k}); end,end
    if isempty(candidates)
        result=empty_reject(options,numel(theta_grid)); return;
    end
    nominal_index=find([theta_grid.regularization]==0,1);
    if isempty(nominal_index), error('match_composite_topology_library:NoNominalTemplate','A regularization=0 nominal template is required.'); end
    nominal=build_composite_topology_library(f_hz,candidates,theta_grid(nominal_index), ...
        options.measurement_kind,cfg,numel(candidates));
    class_audit=audit_candidate_observability(candidates,nominal,cfg,options.tie_tolerance);
    scores=Inf(1,numel(candidates)); best_parameter=zeros(1,numel(candidates)); best_template=cell(1,numel(candidates));
    cursor=1; total=0;
    while cursor<=numel(candidates)*numel(theta_grid)
        batch=stream_composite_library_templates(candidates,theta_grid,cursor,options.batch_size);
        for q=1:numel(batch.items)
            x=batch.items(q); views=template_views(f_hz,candidates(x.topology_index).network,x.theta,options.measurement_kind,cfg);
            d=view_distance(observed_views,views,options.distance_feature,cfg.ofdm,options.distance_weights,options.distance_options);
            if d<scores(x.topology_index)
                scores(x.topology_index)=d; best_parameter(x.topology_index)=x.parameter_grid_index; best_template{x.topology_index}=x.template_id;
            end
        end
        total=total+numel(batch.items); cursor=batch.next_index;
    end
    ci=class_audit.core.class_index; nc=max(ci); class_score=Inf(1,nc); class_topology=zeros(1,nc);
    for c=1:nc
        members=find(ci==c); [class_score(c),local]=min(scores(members)); class_topology(c)=members(local);
    end
    [best_distance,best_class]=min(class_score); competing=class_score; competing(best_class)=Inf;
    [second_distance,second_class]=min(competing);
    if isinf(second_distance), margin=Inf; second_label=''; else, margin=second_distance-best_distance; second_label=class_audit.core.class_labels{find(ci==second_class,1)}; end
    best_index=class_topology(best_class); best_label=class_audit.core.class_labels{best_index};
    status=decision_status(best_distance,margin,class_audit.core.class_sizes(best_class),options.thresholds,options.coverage_status);
    result=struct('best_template_id',best_template{best_index},'best_topology_id',candidates(best_index).topology_id, ...
        'best_topology_index',best_index,'best_equivalence_class',best_label, ...
        'best_parameter_values',theta_grid(best_parameter(best_index)),'best_distance',best_distance, ...
        'second_competing_class',second_label,'second_distance',second_distance,'margin',margin, ...
        'topology_scores',scores,'class_scores',class_score,'class_audit',class_audit, ...
        'candidate_count_before_prior',options.candidate_count_before_prior, ...
        'candidate_count_after_prior',numel(candidates),'parameter_template_count',numel(theta_grid), ...
        'composite_template_count',total,'streaming_used',true,'coverage_status',options.coverage_status, ...
        'decision',status,'thresholds',options.thresholds);
end

function result=empty_reject(options,np)
    result=struct('best_template_id','','best_topology_id','','best_topology_index',NaN, ...
        'best_equivalence_class','','best_parameter_values',struct(),'best_distance',Inf, ...
        'second_competing_class','','second_distance',Inf,'margin',NaN,'topology_scores',[], ...
        'class_scores',[],'class_audit',struct(),'candidate_count_before_prior',options.candidate_count_before_prior, ...
        'candidate_count_after_prior',0,'parameter_template_count',np,'composite_template_count',0, ...
        'streaming_used',true,'coverage_status','no_feasible_candidate','decision','reject_no_feasible_candidate', ...
        'thresholds',options.thresholds);
end
function views=template_views(f,network,theta,kind,cfg)
    [net,local]=topology_apply_parameters(network,cfg,theta);
    [measurement,~]=plc_measurement_bundle(kind,net,theta,local);
    views=plc_multiview_response(f,net,measurement,local);
end
function d=view_distance(a,b,feature,ofdm,weights,options)
    if numel(a)~=numel(b), error('match_composite_topology_library:ViewCount','Observed/reference views differ.'); end
    per=zeros(1,numel(a));
    for v=1:numel(a),per(v)=topology_feature_distance(a{v},b{v},feature,ofdm,weights,options);end
    d=sqrt(mean(per.^2));
end
function status=decision_status(d,margin,class_size,t,coverage)
    if ~strcmp(coverage,'covered'), status='reject_no_feasible_candidate'; return; end
    if d>t.mismatch_distance_threshold, status='reject_model_mismatch'; return; end
    if class_size>1 || margin<t.margin_threshold, status='equivalence_class'; else, status='unique_topology'; end
end
