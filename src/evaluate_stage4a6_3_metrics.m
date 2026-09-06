function metrics = evaluate_stage4a6_3_metrics(decisions, labels)
%EVALUATE_STAGE4A6_3_METRICS Coverage-aware parameter-domain summaries.
%   Labels are joined only after truth-free decisions have been generated.
    methods=unique({decisions.method_id},'stable');cats=unique({labels.category},'stable');metrics=repmat(row(),0,1);
    for i=1:numel(methods)
        for j=1:numel(cats)
            ids={labels(strcmp({labels.category},cats{j})).sample_id};sel=strcmp({decisions.method_id},methods{i})&ismember({decisions.sample_id},ids);d=decisions(sel);if isempty(d),continue;end
            lab=repmat(label_template(),numel(d),1);for k=1:numel(d),q=find(strcmp({labels.sample_id},d(k).sample_id),1);lab(k)=labels(q);end
            ood=strcmp({lab.truth_parameter_domain},'out_of_domain');ind=strcmp({d.parameter_domain_status},'parameter_domain_indeterminate')|strcmp({d.parameter_domain_status},'parameter_not_evaluated');out=strcmp({d.parameter_domain_status},'parameter_out_suspected');inside=strcmp({d.parameter_domain_status},'parameter_in_domain');
            [ood_rec,ood_ci]=rate_ci(sum(ood&out),sum(ood));[ood_fa,~]=rate_ci(sum(ood&inside),sum(ood));[in_fa,in_ci]=rate_ci(sum(~ood&out),sum(~ood));[indr,ind_ci]=rate_ci(sum(ind),numel(d));[cov,cov_ci]=rate_ci(sum(~ind),numel(d));
            r=row();r.method_id=methods{i};r.category=cats{j};r.sample_count=numel(d);r.ood_out_numerator=sum(ood&out);r.ood_denominator=sum(ood);r.ood_recall=ood_rec;r.ood_ci_low=ood_ci(1);r.ood_ci_high=ood_ci(2);r.ood_false_accept_numerator=sum(ood&inside);r.ood_false_accept_rate=ood_fa;r.in_domain_false_alarm_numerator=sum(~ood&out);r.in_domain_denominator=sum(~ood);r.in_domain_false_alarm_rate=in_fa;r.in_domain_ci_low=in_ci(1);r.in_domain_ci_high=in_ci(2);r.indeterminate_numerator=sum(ind);r.indeterminate_rate=indr;r.indeterminate_ci_low=ind_ci(1);r.indeterminate_ci_high=ind_ci(2);r.decision_coverage_numerator=sum(~ind);r.decision_coverage=cov;r.coverage_ci_low=cov_ci(1);r.coverage_ci_high=cov_ci(2);metrics(end+1)=r; %#ok<AGROW>
        end
    end
end
function r=row(),r=struct('method_id','','category','','sample_count',0,'ood_out_numerator',0,'ood_denominator',0,'ood_recall',NaN,'ood_ci_low',NaN,'ood_ci_high',NaN,'ood_false_accept_numerator',0,'ood_false_accept_rate',NaN,'in_domain_false_alarm_numerator',0,'in_domain_denominator',0,'in_domain_false_alarm_rate',NaN,'in_domain_ci_low',NaN,'in_domain_ci_high',NaN,'indeterminate_numerator',0,'indeterminate_rate',NaN,'indeterminate_ci_low',NaN,'indeterminate_ci_high',NaN,'decision_coverage_numerator',0,'decision_coverage',NaN,'coverage_ci_low',NaN,'coverage_ci_high',NaN);end
function r=label_template(),r=struct('sample_id','','category','','outlier_dimension','','outlier_severity','','outlier_direction','','truth_topology_id','','truth_parameter_domain','');end
function [p,ci]=rate_ci(a,b),if b==0,p=NaN;ci=[NaN NaN];else,p=a/b;ci=stage4a6_3_wilson_interval(a,b);end,end
