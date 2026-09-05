function metrics = evaluate_stage4a4_metrics(decisions,labels)
%EVALUATE_STAGE4A4_METRICS Offline evaluation with independent labels.
%   Rejected samples never contribute to accepted accuracy numerators.
    if numel(decisions)~=numel(labels), error('stage4a4:MetricAlignment','Decision and label counts differ.'); end
    if isempty(decisions), metrics=repmat(metric_template(),0,1); return; end
    keys=cell(1,numel(decisions));
    for k=1:numel(decisions), keys{k}=[decisions(k).method_id '|' decisions(k).grid_id '|' decisions(k).scenario_id '|' labels(k).category]; end
    groups=stable_unique(keys); metrics=repmat(metric_template(),0,1);
    for q=1:numel(groups)
        ix=strcmp(keys,groups{q}); d=decisions(ix); l=labels(ix); n=numel(d);
        accepted=ismember({d.decision},{'unique_topology','unique_given_prior','equivalence_class'});
        unique_out=ismember({d.decision},{'unique_topology','unique_given_prior'});
        covered=[l.truth_covered]; truth_ids={l.truth_topology_id};
        nearest=strcmp({d.best_topology_id},truth_ids);
        nearest_class=false(1,n); set_hit=false(1,n);
        for i=1:n
            nearest_class(i)=class_contains(d(i).best_equivalence_class,l(i).baseline_P0_equivalence_class);
            set_hit(i)=class_contains(d(i).accepted_topology_set,l(i).truth_topology_id);
        end
        x=metric_template(); x.method_id=d(1).method_id; x.grid_id=d(1).grid_id; x.scenario_id=d(1).scenario_id; x.category=l(1).category; x.sample_count=n;
        [x.truth_coverage_rate,x.truth_coverage_num,x.truth_coverage_den,x.truth_coverage_ci_low,x.truth_coverage_ci_high]=rate_ci(sum(covered),n);
        [x.unique_accuracy_given_covered,x.unique_accuracy_num,x.unique_accuracy_den,x.unique_accuracy_ci_low,x.unique_accuracy_ci_high]=rate_ci(sum(covered&unique_out&nearest),sum(covered));
        [x.set_accuracy_given_covered,x.set_accuracy_num,x.set_accuracy_den,x.set_accuracy_ci_low,x.set_accuracy_ci_high]=rate_ci(sum(covered&accepted&set_hit),sum(covered));
        [x.nearest_topology_hit_rate,x.nearest_topology_hit_num,x.nearest_topology_hit_den,x.nearest_topology_hit_ci_low,x.nearest_topology_hit_ci_high]=rate_ci(sum(covered&nearest),sum(covered));
        [x.nearest_class_hit_rate,x.nearest_class_hit_num,x.nearest_class_hit_den,x.nearest_class_hit_ci_low,x.nearest_class_hit_ci_high]=rate_ci(sum(covered&nearest_class),sum(covered));
        [x.in_library_rejection_rate,x.in_library_rejection_num,x.in_library_rejection_den,x.in_library_rejection_ci_low,x.in_library_rejection_ci_high]=rate_ci(sum(covered&~accepted),sum(covered));
        nonunique= [l.truth_is_observationally_nonunique];
        [x.false_unique_rate_given_nonunique,x.false_unique_num,x.false_unique_den,x.false_unique_ci_low,x.false_unique_ci_high]=rate_ci(sum(nonunique&strcmp({d.decision},'unique_topology')),sum(nonunique));
        [x.unique_output_precision,x.unique_output_precision_num,x.unique_output_precision_den,x.unique_output_precision_ci_low,x.unique_output_precision_ci_high]=rate_ci(sum(unique_out&nearest),sum(unique_out));
        prior=strcmp({d.decision},'unique_given_prior'); [x.unique_given_prior_rate,x.unique_given_prior_num,x.unique_given_prior_den,x.unique_given_prior_ci_low,x.unique_given_prior_ci_high]=rate_ci(sum(prior),n);
        [x.unique_given_prior_accuracy,x.unique_given_prior_accuracy_num,x.unique_given_prior_accuracy_den,x.unique_given_prior_accuracy_ci_low,x.unique_given_prior_accuracy_ci_high]=rate_ci(sum(prior&nearest),sum(prior));
        is_struct=strcmp({l.category},'structure_out'); is_param=strcmp({l.category},'parameter_out'); excluded=strcmp({l.coverage_status},'excluded_by_prior');
        [x.structure_out_false_accept_rate,x.structure_out_false_accept_num,x.structure_out_false_accept_den,x.structure_out_false_accept_ci_low,x.structure_out_false_accept_ci_high]=rate_ci(sum(is_struct&accepted),sum(is_struct));
        [x.parameter_out_false_accept_rate,x.parameter_out_false_accept_num,x.parameter_out_false_accept_den,x.parameter_out_false_accept_ci_low,x.parameter_out_false_accept_ci_high]=rate_ci(sum(is_param&accepted),sum(is_param));
        [x.excluded_by_prior_false_accept_rate,x.excluded_by_prior_false_accept_num,x.excluded_by_prior_false_accept_den,x.excluded_by_prior_false_accept_ci_low,x.excluded_by_prior_false_accept_ci_high]=rate_ci(sum(excluded&accepted),sum(excluded));
        [x.reject_model_mismatch_rate,x.reject_model_mismatch_num,x.reject_model_mismatch_den,x.reject_model_mismatch_ci_low,x.reject_model_mismatch_ci_high]=rate_ci(sum(strcmp({d.decision},'reject_model_mismatch')),n);
        [x.reject_low_margin_rate,x.reject_low_margin_num,x.reject_low_margin_den,x.reject_low_margin_ci_low,x.reject_low_margin_ci_high]=rate_ci(sum(strcmp({d.decision},'reject_low_margin')),n);
        [x.reject_no_feasible_candidate_rate,x.reject_no_feasible_candidate_num,x.reject_no_feasible_candidate_den,x.reject_no_feasible_candidate_ci_low,x.reject_no_feasible_candidate_ci_high]=rate_ci(sum(strcmp({d.decision},'reject_no_feasible_candidate')),n);
        [x.accepted_rate,x.accepted_num,x.accepted_den,x.accepted_ci_low,x.accepted_ci_high]=rate_ci(sum(accepted),n);
        x.mean_best_distance=mean([d.best_distance]); x.mean_margin=mean([d.margin]); x.mean_rho=mean([d.rho]);
        x.mean_accepted_set_size=mean(arrayfun(@(z)set_size(z.accepted_topology_set),d)); x.mean_candidate_count_after_prior=mean([d.candidate_count_after_prior]);
        metrics(end+1)=x; %#ok<AGROW>
    end
end

function x=metric_template()
    x=struct('method_id','','grid_id','','scenario_id','','category','','sample_count',0, ...
        'truth_coverage_rate',NaN,'truth_coverage_num',0,'truth_coverage_den',0,'truth_coverage_ci_low',NaN,'truth_coverage_ci_high',NaN, ...
        'unique_accuracy_given_covered',NaN,'unique_accuracy_num',0,'unique_accuracy_den',0,'unique_accuracy_ci_low',NaN,'unique_accuracy_ci_high',NaN, ...
        'set_accuracy_given_covered',NaN,'set_accuracy_num',0,'set_accuracy_den',0,'set_accuracy_ci_low',NaN,'set_accuracy_ci_high',NaN, ...
        'nearest_topology_hit_rate',NaN,'nearest_topology_hit_num',0,'nearest_topology_hit_den',0,'nearest_topology_hit_ci_low',NaN,'nearest_topology_hit_ci_high',NaN, ...
        'nearest_class_hit_rate',NaN,'nearest_class_hit_num',0,'nearest_class_hit_den',0,'nearest_class_hit_ci_low',NaN,'nearest_class_hit_ci_high',NaN, ...
        'in_library_rejection_rate',NaN,'in_library_rejection_num',0,'in_library_rejection_den',0,'in_library_rejection_ci_low',NaN,'in_library_rejection_ci_high',NaN, ...
        'false_unique_rate_given_nonunique',NaN,'false_unique_num',0,'false_unique_den',0,'false_unique_ci_low',NaN,'false_unique_ci_high',NaN, ...
        'unique_output_precision',NaN,'unique_output_precision_num',0,'unique_output_precision_den',0,'unique_output_precision_ci_low',NaN,'unique_output_precision_ci_high',NaN, ...
        'unique_given_prior_rate',NaN,'unique_given_prior_num',0,'unique_given_prior_den',0,'unique_given_prior_ci_low',NaN,'unique_given_prior_ci_high',NaN, ...
        'unique_given_prior_accuracy',NaN,'unique_given_prior_accuracy_num',0,'unique_given_prior_accuracy_den',0,'unique_given_prior_accuracy_ci_low',NaN,'unique_given_prior_accuracy_ci_high',NaN, ...
        'structure_out_false_accept_rate',NaN,'structure_out_false_accept_num',0,'structure_out_false_accept_den',0,'structure_out_false_accept_ci_low',NaN,'structure_out_false_accept_ci_high',NaN, ...
        'parameter_out_false_accept_rate',NaN,'parameter_out_false_accept_num',0,'parameter_out_false_accept_den',0,'parameter_out_false_accept_ci_low',NaN,'parameter_out_false_accept_ci_high',NaN, ...
        'excluded_by_prior_false_accept_rate',NaN,'excluded_by_prior_false_accept_num',0,'excluded_by_prior_false_accept_den',0,'excluded_by_prior_false_accept_ci_low',NaN,'excluded_by_prior_false_accept_ci_high',NaN, ...
        'reject_model_mismatch_rate',NaN,'reject_model_mismatch_num',0,'reject_model_mismatch_den',0,'reject_model_mismatch_ci_low',NaN,'reject_model_mismatch_ci_high',NaN, ...
        'reject_low_margin_rate',NaN,'reject_low_margin_num',0,'reject_low_margin_den',0,'reject_low_margin_ci_low',NaN,'reject_low_margin_ci_high',NaN, ...
        'reject_no_feasible_candidate_rate',NaN,'reject_no_feasible_candidate_num',0,'reject_no_feasible_candidate_den',0,'reject_no_feasible_candidate_ci_low',NaN,'reject_no_feasible_candidate_ci_high',NaN, ...
        'accepted_rate',NaN,'accepted_num',0,'accepted_den',0,'accepted_ci_low',NaN,'accepted_ci_high',NaN, ...
        'mean_best_distance',NaN,'mean_margin',NaN,'mean_rho',NaN,'mean_accepted_set_size',NaN,'mean_candidate_count_after_prior',NaN);
end
function [r,num,den,lo,hi]=rate_ci(num,den)
    if den==0, r=NaN;lo=NaN;hi=NaN;num=0;return;end
    r=num/den; z=1.95996398454005; den0=1+z^2/den; cen=(r+z^2/(2*den))/den0; half=z*sqrt(r*(1-r)/den+z^2/(4*den^2))/den0; lo=max(0,cen-half);hi=min(1,cen+half);
end
function tf=class_contains(a,b),tf=strcmp(a,b)||(~isempty(b)&&~isempty(strfind([',' a ','],[',' b ','])));end %#ok<STREMP>
function n=set_size(x),if isempty(x),n=0;else,n=numel(strsplit(x,','));end,end
function y=stable_unique(x),y={};for k=1:numel(x),if ~any(strcmp(y,x{k})),y{end+1}=x{k};end,end,end
