function rows = evaluate_stage4a5_metrics(decisions,labels)
%EVALUATE_STAGE4A5_METRICS Compute micro/macro and outlier-stratified metrics.
%   Decisions and scoring labels are joined only after observation-only
%   matching.  Rejected decisions cannot contribute to accuracy numerators.
    if numel(decisions)~=numel(labels),error('stage4a5:MetricAlignment','Decision and label counts differ.');end
    if isempty(decisions),rows=repmat(metric_template(),0,1);return;end
    key=cell(1,numel(decisions));
    for i=1:numel(decisions),key{i}=sprintf('%s|%s|%s|%s|%s|%s',decisions(i).method_id,decisions(i).grid_id,decisions(i).scenario_id,decisions(i).replicate_id,labels(i).category,labels(i).outlier_dimension);end
    groups=stable_unique(key);rows=repmat(metric_template(),0,1);
    for g=1:numel(groups),ix=strcmp(key,groups{g});rows(end+1)=make_detail(decisions(ix),labels(ix));end %#ok<AGROW>
    basekey=cell(1,numel(decisions));
    for i=1:numel(decisions),basekey{i}=sprintf('%s|%s|%s|%s',decisions(i).method_id,decisions(i).grid_id,decisions(i).scenario_id,decisions(i).replicate_id);end
    bgroups=stable_unique(basekey);
    for g=1:numel(bgroups)
        ix=strcmp(basekey,bgroups{g}) & ismember({labels.category},{'in_library_continuous','in_library_grid'});
        if ~any(ix),continue;end
        r=make_detail(decisions(ix),labels(ix));r.category='in_library_summary';r.outlier_dimension='';
        cats=stable_unique({labels(ix).category});catvals=[];
        for c=1:numel(cats)
            j=ix & strcmp({labels.category},cats{c});z=make_detail(decisions(j),labels(j));catvals(end+1)=z.set_accuracy_given_covered; %#ok<AGROW>
        end
        r.set_accuracy_macro=mean(catvals,'omitnan');r.set_accuracy_macro_component_count=sum(isfinite(catvals));
        r.metric_scope='micro_and_macro';rows(end+1)=r; %#ok<AGROW>
    end
end

function r=make_detail(d,l)
    r=metric_template();r.method_id=d(1).method_id;r.grid_id=d(1).grid_id;r.scenario_id=d(1).scenario_id;r.replicate_id=d(1).replicate_id;r.category=l(1).category;r.outlier_dimension=l(1).outlier_dimension;r.sample_count=numel(d);
    accepted=ismember({d.decision},{'unique_topology','unique_given_prior','equivalence_class'});unique_out=ismember({d.decision},{'unique_topology','unique_given_prior'});covered=[l.truth_covered];truth={l.truth_topology_id};nearest=strcmp({d.best_topology_id},truth);sethit=false(1,numel(d));
    for i=1:numel(d),sethit(i)=contains_id(d(i).accepted_topology_set,l(i).truth_topology_id);end
    r.truth_coverage_rate=rate_field(sum(covered),numel(d));r.truth_coverage_num=sum(covered);r.truth_coverage_den=numel(d);
    [r.unique_accuracy_given_covered,r.unique_accuracy_num,r.unique_accuracy_den,r.unique_accuracy_ci_low,r.unique_accuracy_ci_high]=rate_ci(sum(covered&accepted&unique_out&nearest),sum(covered));
    [r.set_accuracy_given_covered,r.set_accuracy_num,r.set_accuracy_den,r.set_accuracy_ci_low,r.set_accuracy_ci_high]=rate_ci(sum(covered&accepted&sethit),sum(covered));
    [r.nearest_topology_hit_rate,r.nearest_topology_hit_num,r.nearest_topology_hit_den,r.nearest_topology_hit_ci_low,r.nearest_topology_hit_ci_high]=rate_ci(sum(covered&nearest),sum(covered));
    non=[l.truth_is_observationally_nonunique];[r.false_unique_rate_given_nonunique,r.false_unique_num,r.false_unique_den,r.false_unique_ci_low,r.false_unique_ci_high]=rate_ci(sum(non&strcmp({d.decision},'unique_topology')),sum(non));
    [r.accepted_rate,r.accepted_num,r.accepted_den,r.accepted_ci_low,r.accepted_ci_high]=rate_ci(sum(accepted),numel(d));
    [r.unique_output_precision,r.unique_output_precision_num,r.unique_output_precision_den,r.unique_output_precision_ci_low,r.unique_output_precision_ci_high]=rate_ci(sum(unique_out&nearest),sum(unique_out));
    [r.reject_model_mismatch_rate,r.reject_model_mismatch_num,r.reject_model_mismatch_den,r.reject_model_mismatch_ci_low,r.reject_model_mismatch_ci_high]=rate_ci(sum(strcmp({d.decision},'reject_model_mismatch')),numel(d));
    [r.reject_subband_mismatch_rate,r.reject_subband_mismatch_num,r.reject_subband_mismatch_den,r.reject_subband_mismatch_ci_low,r.reject_subband_mismatch_ci_high]=rate_ci(sum(strcmp({d.decision},'reject_subband_mismatch')),numel(d));
    [r.reject_neighborhood_mismatch_rate,r.reject_neighborhood_mismatch_num,r.reject_neighborhood_mismatch_den,r.reject_neighborhood_mismatch_ci_low,r.reject_neighborhood_mismatch_ci_high]=rate_ci(sum(strcmp({d.decision},'reject_neighborhood_mismatch')),numel(d));
    [r.reject_low_stability_rate,r.reject_low_stability_num,r.reject_low_stability_den,r.reject_low_stability_ci_low,r.reject_low_stability_ci_high]=rate_ci(sum(strcmp({d.decision},'reject_low_stability')),numel(d));
    [r.reject_low_margin_rate,r.reject_low_margin_num,r.reject_low_margin_den,r.reject_low_margin_ci_low,r.reject_low_margin_ci_high]=rate_ci(sum(strcmp({d.decision},'reject_low_margin')),numel(d));
    r.structure_out_false_accept_rate=NaN;r.parameter_out_false_accept_rate=NaN;r.parameter_out_unique_accept_rate=NaN;r.structure_out_unique_accept_rate=NaN;
    if strcmp(r.category,'structure_out'),[r.structure_out_false_accept_rate,r.structure_out_false_accept_num,r.structure_out_false_accept_den,r.structure_out_false_accept_ci_low,r.structure_out_false_accept_ci_high]=rate_ci(sum(accepted),numel(d));r.structure_out_unique_accept_rate=mean(strcmp({d.decision},'unique_topology')|strcmp({d.decision},'unique_given_prior'));end
    if strcmp(r.category,'parameter_out'),[r.parameter_out_false_accept_rate,r.parameter_out_false_accept_num,r.parameter_out_false_accept_den,r.parameter_out_false_accept_ci_low,r.parameter_out_false_accept_ci_high]=rate_ci(sum(accepted),numel(d));r.parameter_out_unique_accept_rate=mean(strcmp({d.decision},'unique_topology')|strcmp({d.decision},'unique_given_prior'));end
    r.unique_given_prior_rate=mean(strcmp({d.decision},'unique_given_prior'));r.mean_best_distance=mean([d.best_distance]);r.mean_margin=mean([d.margin]);r.mean_subband_max=mean([d.subband_max_stat],'omitnan');r.mean_neighborhood_score=mean([d.neighborhood_score],'omitnan');r.mean_stability=mean([d.stability_value],'omitnan');r.mean_accepted_set_size=mean(arrayfun(@(x)size_ids(x.accepted_topology_set),d));r.metric_scope='detail';
end

function r=metric_template()
    r=struct('method_id','','grid_id','','scenario_id','','replicate_id','','category','','outlier_dimension','','metric_scope','','sample_count',0,'truth_coverage_rate',NaN,'truth_coverage_num',0,'truth_coverage_den',0,'unique_accuracy_given_covered',NaN,'unique_accuracy_num',0,'unique_accuracy_den',0,'unique_accuracy_ci_low',NaN,'unique_accuracy_ci_high',NaN,'set_accuracy_given_covered',NaN,'set_accuracy_num',0,'set_accuracy_den',0,'set_accuracy_ci_low',NaN,'set_accuracy_ci_high',NaN,'set_accuracy_macro',NaN,'set_accuracy_macro_component_count',0,'nearest_topology_hit_rate',NaN,'nearest_topology_hit_num',0,'nearest_topology_hit_den',0,'nearest_topology_hit_ci_low',NaN,'nearest_topology_hit_ci_high',NaN,'false_unique_rate_given_nonunique',NaN,'false_unique_num',0,'false_unique_den',0,'false_unique_ci_low',NaN,'false_unique_ci_high',NaN,'accepted_rate',NaN,'accepted_num',0,'accepted_den',0,'accepted_ci_low',NaN,'accepted_ci_high',NaN,'unique_output_precision',NaN,'unique_output_precision_num',0,'unique_output_precision_den',0,'unique_output_precision_ci_low',NaN,'unique_output_precision_ci_high',NaN,'structure_out_false_accept_rate',NaN,'structure_out_false_accept_num',0,'structure_out_false_accept_den',0,'structure_out_false_accept_ci_low',NaN,'structure_out_false_accept_ci_high',NaN,'parameter_out_false_accept_rate',NaN,'parameter_out_false_accept_num',0,'parameter_out_false_accept_den',0,'parameter_out_false_accept_ci_low',NaN,'parameter_out_false_accept_ci_high',NaN,'structure_out_unique_accept_rate',NaN,'parameter_out_unique_accept_rate',NaN,'unique_given_prior_rate',NaN,'reject_model_mismatch_rate',NaN,'reject_model_mismatch_num',0,'reject_model_mismatch_den',0,'reject_model_mismatch_ci_low',NaN,'reject_model_mismatch_ci_high',NaN,'reject_subband_mismatch_rate',NaN,'reject_subband_mismatch_num',0,'reject_subband_mismatch_den',0,'reject_subband_mismatch_ci_low',NaN,'reject_subband_mismatch_ci_high',NaN,'reject_neighborhood_mismatch_rate',NaN,'reject_neighborhood_mismatch_num',0,'reject_neighborhood_mismatch_den',0,'reject_neighborhood_mismatch_ci_low',NaN,'reject_neighborhood_mismatch_ci_high',NaN,'reject_low_stability_rate',NaN,'reject_low_stability_num',0,'reject_low_stability_den',0,'reject_low_stability_ci_low',NaN,'reject_low_stability_ci_high',NaN,'reject_low_margin_rate',NaN,'reject_low_margin_num',0,'reject_low_margin_den',0,'reject_low_margin_ci_low',NaN,'reject_low_margin_ci_high',NaN,'mean_best_distance',NaN,'mean_margin',NaN,'mean_subband_max',NaN,'mean_neighborhood_score',NaN,'mean_stability',NaN,'mean_accepted_set_size',NaN);
end
function [r,num,den,lo,hi]=rate_ci(num,den),if den==0,r=NaN;num=0;lo=NaN;hi=NaN;return;end;r=num/den;z=1.95996398454005;d=1+z^2/den;c=(r+z^2/(2*den))/d;h=z*sqrt(max(0,r*(1-r)/den)+z^2/(4*den^2))/d;lo=max(0,c-h);hi=min(1,c+h);end
function r=rate_field(num,den),if den==0,r=NaN;else,r=num/den;end,end
function tf=contains_id(a,b),tf=~isempty(b)&&(~isempty(a)&&any(strcmp(strsplit(a,','),b)));end
function n=size_ids(x),if isempty(x),n=0;else,n=numel(strsplit(x,','));end,end
function y=stable_unique(x),y={};for k=1:numel(x),if ~any(strcmp(y,x{k})),y{end+1}=x{k};end,end,end
