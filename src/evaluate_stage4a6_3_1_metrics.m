function metrics = evaluate_stage4a6_3_1_metrics(decisions,labels)
%EVALUATE_STAGE4A6_3_1_METRICS Independent-scenario and selective metrics.
    methods=unique({decisions.method_id},'stable');cats=unique({labels.category},'stable');metrics=repmat(row(),0,1);
    for i=1:numel(methods)
        for j=1:numel(cats)
            ix=strcmp({labels.category},cats{j});lab=labels(ix);ids={lab.sample_id};di=strcmp({decisions.method_id},methods{i})&ismember({decisions.sample_id},ids);d=decisions(di);if isempty(d),continue;end
            keep=true(1,numel(lab));phys={lab.physical_scenario_id};if ~isempty(phys),[~,ia]=unique(phys,'stable');keep=false(1,numel(lab));keep(ia)=true;end
            lab=lab(keep);[~,loc]=ismember({lab.sample_id},{d.sample_id});d=d(loc(loc>0));n=numel(d);truth={lab.truth_topology_id};
            accepted=~startsWith({d.topology_status},'reject_')&~strcmp({d.topology_status},'parameter_not_evaluated');sets={d.topology_set};eq=false(1,n);strict=false(1,n);for k=1:n,ss=strsplit(sets{k},',');eq(k)=any(strcmp(ss,truth{k}));strict(k)=strcmp(d(k).topology_status,'unique_topology')&&numel(ss)==1&&eq(k);end
            outood=strcmp({lab.parameter_domain_truth},'out_of_domain');pout=strcmp({d.parameter_domain_status},'parameter_out_suspected');pin=strcmp({d.parameter_domain_status},'parameter_in_domain');ind=strcmp({d.parameter_domain_status},'parameter_domain_indeterminate')|strcmp({d.parameter_domain_status},'parameter_not_evaluated');decided=~ind;wrong=decided&~eq;
            r=row();r.method_id=methods{i};r.category=cats{j};r.nominal_row_count=sum(di);r.unique_physical_scenario_count=n;r.duplicate_observation_count=sum(di)-n;r.effective_denominator=n;
            [r.topology_set_accuracy,r.topology_set_ci_low,r.topology_set_ci_high]=rate(sum(accepted&eq),n);[r.strict_unique_accuracy,r.strict_ci_low,r.strict_ci_high]=rate(sum(strict),n);[r.false_unique_numerator,r.false_unique_denominator,r.false_unique_rate]=rawrate(sum(outood&strcmp({d.topology_status},'unique_topology')),sum(outood));
            [r.ood_recall,r.ood_ci_low,r.ood_ci_high]=rate(sum(outood&pout),sum(outood));[r.ood_false_accept_rate,r.ood_fa_ci_low,r.ood_fa_ci_high]=rate(sum(outood&pin),sum(outood));[r.in_domain_false_alarm,r.in_fa_ci_low,r.in_fa_ci_high]=rate(sum(~outood&pout),sum(~outood));[r.indeterminate_rate,r.ind_ci_low,r.ind_ci_high]=rate(sum(ind),n);[r.coverage,r.coverage_ci_low,r.coverage_ci_high]=rate(sum(decided),n);[r.selective_risk,r.risk_ci_low,r.risk_ci_high]=rate(sum(wrong&decided),sum(decided));r.accepted_count=sum(accepted);metrics(end+1)=r; %#ok<AGROW>
        end
    end
end
function r=row(),r=struct('method_id','','category','','nominal_row_count',0,'unique_physical_scenario_count',0,'duplicate_observation_count',0,'effective_denominator',0,'topology_set_accuracy',NaN,'topology_set_ci_low',NaN,'topology_set_ci_high',NaN,'strict_unique_accuracy',NaN,'strict_ci_low',NaN,'strict_ci_high',NaN,'false_unique_numerator',0,'false_unique_denominator',0,'false_unique_rate',NaN,'ood_recall',NaN,'ood_ci_low',NaN,'ood_ci_high',NaN,'ood_false_accept_rate',NaN,'ood_fa_ci_low',NaN,'ood_fa_ci_high',NaN,'in_domain_false_alarm',NaN,'in_fa_ci_low',NaN,'in_fa_ci_high',NaN,'indeterminate_rate',NaN,'ind_ci_low',NaN,'ind_ci_high',NaN,'coverage',NaN,'coverage_ci_low',NaN,'coverage_ci_high',NaN,'selective_risk',NaN,'risk_ci_low',NaN,'risk_ci_high',NaN,'accepted_count',0);end
function [p,l,h]=rate(a,b),if b==0,p=NaN;l=NaN;h=NaN;else,p=a/b;ci=stage4a6_3_wilson_interval(a,b);l=ci(1);h=ci(2);end,end
function [a,b,p]=rawrate(x,y),a=x;b=y;if y==0,p=NaN;else,p=x/y;end,end
