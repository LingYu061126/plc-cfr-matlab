function metrics = evaluate_stage4a7_1_pilot_metrics(decisions, labels)
%EVALUATE_STAGE4A7_1_PILOT_METRICS Offline independent-scenario metrics.
%   Truth-bearing labels are accepted only here, after all decision rows
%   have been produced.  Every binomial metric reports numerator,
%   denominator and Wilson 95% interval.
    methods=stable_unique({decisions.method_id});categories=stable_unique({labels.category});
    metrics=repmat(metric_row(),0,1);
    for m=1:numel(methods)
        metrics=append_group(metrics,decisions,labels,methods{m},'all');
        for c=1:numel(categories),metrics=append_group(metrics,decisions,labels,methods{m},categories{c});end
    end
end

function rows=append_group(rows,d,l,method,category)
    ix=strcmp({d.method_id},method);dd=d(ix);ll=l;
    if ~strcmp(category,'all'),keep=strcmp({ll.category},category);ll=ll(keep);dd=dd(ismember({dd.sample_id},{ll.sample_id}));end
    if isempty(ll),return;end
    [~,o]=ismember({ll.sample_id},{dd.sample_id});dd=dd(o);
    inlib=~strcmp({ll.category},'structure_out');accepted=~cellfun(@isempty,{dd.accepted_candidate_set});
    hit=false(1,numel(ll));setsize=zeros(1,numel(ll));uniqueout=false(1,numel(ll));
    for k=1:numel(ll)
        a=parse_set(dd(k).accepted_candidate_set);setsize(k)=numel(a);hit(k)=any(strcmp(a,ll(k).truth_topology_id));
        uniqueout(k)=strcmp(dd(k).decision,'unique_topology')||strcmp(dd(k).decision,'unique_given_prior');
    end
    truth_nonunique=[ll.truth_equivalence_member_count]>1 & [ll.equivalence_evaluable];
    evaluable=[ll.equivalence_evaluable];ood=strcmp({ll.parameter_domain_truth},'out_of_domain');
    structure=strcmp({ll.category},'structure_out');
    rows=add(rows,method,category,'topology_set_accuracy',sum(hit&inlib),sum(inlib));
    rows=add(rows,method,category,'accepted_coverage',sum(accepted),numel(ll));
    rows=add(rows,method,category,'topology_selective_risk',sum(accepted&~hit&inlib),sum(accepted&inlib));
    rows=add(rows,method,category,'unique_output_precision',sum(uniqueout&hit&inlib),sum(uniqueout&inlib));
    rows=add(rows,method,category,'singleton_rate',sum(setsize==1),numel(ll));
    rows=add(rows,method,category,'ambiguous_set_rate',sum(strcmp({dd.decision},'ambiguous_candidate_set')),numel(ll));
    rows=add(rows,method,category,'equivalence_class_rate',sum(strcmp({dd.decision},'equivalence_class')),numel(ll));
    rows=add(rows,method,category,'rejection_rate',sum(~accepted),numel(ll));
    rows=add(rows,method,category,'false_unique_unconditional',sum(uniqueout&truth_nonunique),sum(evaluable));
    rows=add(rows,method,category,'false_unique_conditional',sum(uniqueout&truth_nonunique),sum(truth_nonunique));
    rows=add(rows,method,category,'parameter_ood_false_acceptance',sum(accepted&ood),sum(ood));
    rows=add(rows,method,category,'structure_ood_false_acceptance',sum(accepted&structure),sum(structure));
    r=metric_row();r.method_id=method;r.category=category;r.metric_name='average_candidate_set_size';r.numerator=sum(setsize);r.denominator=numel(ll);r.rate=mean(setsize);r.ci_low=NaN;r.ci_high=NaN;r.evaluable_count=numel(ll);rows(end+1)=r;
end
function rows=add(rows,method,category,name,num,den)
    r=metric_row();r.method_id=method;r.category=category;r.metric_name=name;r.numerator=num;r.denominator=den;r.evaluable_count=den;
    if den>0,r.rate=num/den;ci=stage4a6_3_wilson_interval(num,den);r.ci_low=ci(1);r.ci_high=ci(2);end
    rows(end+1)=r;
end
function a=parse_set(s),if isempty(s),a={};else,a=strsplit(char(s),',');a=a(~cellfun(@isempty,a));end,end
function y=stable_unique(x),y={};for k=1:numel(x),if ~any(strcmp(y,x{k})),y{end+1}=x{k};end,end,end
function r=metric_row(),r=struct('method_id','','category','','metric_name','','numerator',0,'denominator',0,'rate',NaN,'ci_low',NaN,'ci_high',NaN,'evaluable_count',0,'definition_version','stage4a7_1_independent_scenario_metrics_v1');end
