function rows = evaluate_stage4a6_1_metrics(decisions,labels)
%EVALUATE_STAGE4A6_1_METRICS Coverage-aware metrics with NaN semantics.
    if numel(decisions)~=numel(labels),error('stage4a6_1:Alignment','Decision/label mismatch.');end
    keys=cell(1,numel(decisions));for k=1:numel(decisions),keys{k}=sprintf('%s|%s|%s|%s|%s|%s',decisions(k).method_id,decisions(k).grid_id,decisions(k).replicate_id,labels(k).category,labels(k).outlier_dimension,labels(k).outlier_severity);end
    u=unique(keys,'stable');rows=repmat(template(),numel(u),1);
    for g=1:numel(u)
        ix=strcmp(keys,u{g});d=decisions(ix);l=labels(ix);r=template();
        r.method_id=d(1).method_id;r.grid_id=d(1).grid_id;r.replicate_id=d(1).replicate_id;
        r.category=l(1).category;r.outlier_dimension=l(1).outlier_dimension;r.outlier_severity=l(1).outlier_severity;r.sample_count=numel(d);
        accepted=ismember({d.topology_status},{'unique_topology','unique_given_prior','equivalence_class'});hit=false(1,numel(d));
        for j=1:numel(d),hit(j)=contains_id(d(j).topology_set,l(j).truth_topology_id);end
        r.topology_set_accuracy=mean(accepted&hit);r.topology_rejection_rate=mean(~accepted);r.wrong_topology_acceptance_rate=mean(accepted&~hit);r.false_unique_rate=mean(strcmp({d.topology_status},'unique_topology')&[l.truth_is_nonunique]);
        if strcmp(d(1).method_id,'A6_1_M0_topology_only')
            r.parameter_status='not_applicable';r.parameter_ood_recall=NaN;r.parameter_in_domain_false_alarm=NaN;r.parameter_ood_miss_rate=NaN;r.parameter_indeterminate_rate=NaN;r.optimization_failure_rate=NaN;r.profile_reliability_rate=NaN;
        else
            out=strcmp({l.parameter_domain_truth},'out_of_domain');ind=strcmp({l.parameter_domain_truth},'in_domain');sus=strcmp({d.parameter_domain_status},'parameter_out_suspected');inp=strcmp({d.parameter_domain_status},'parameter_in_domain');unk=strcmp({d.parameter_domain_status},'parameter_domain_indeterminate');
            r.parameter_status='evaluated';r.parameter_ood_recall=ratio(sum(out&sus),sum(out));r.parameter_in_domain_false_alarm=ratio(sum(ind&sus),sum(ind));r.parameter_ood_miss_rate=ratio(sum(out&inp),sum(out));r.parameter_indeterminate_rate=ratio(sum(unk),numel(d));r.optimization_failure_rate=mean(~[d.optimizer_converged]);r.profile_reliability_rate=mean([d.profile_reliable]);
        end
        rows(g)=r;
    end
end
function t=template()
    t=struct('method_id','','grid_id','','replicate_id','','category','','outlier_dimension','','outlier_severity','','sample_count',0,'topology_set_accuracy',NaN,'topology_rejection_rate',NaN,'wrong_topology_acceptance_rate',NaN,'false_unique_rate',NaN,'parameter_status','','parameter_ood_recall',NaN,'parameter_in_domain_false_alarm',NaN,'parameter_ood_miss_rate',NaN,'parameter_indeterminate_rate',NaN,'optimization_failure_rate',NaN,'profile_reliability_rate',NaN);
end
function y=ratio(a,b),if b==0,y=NaN;else,y=a/b;end,end
function tf=contains_id(a,b),tf=~isempty(a)&&any(strcmp(strsplit(a,','),b));end
