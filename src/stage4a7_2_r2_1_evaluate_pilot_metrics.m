function rows = stage4a7_2_r2_1_evaluate_pilot_metrics(decisions,experiment_hash)
%STAGE4A7_2_R2_1_EVALUATE_PILOT_METRICS Score set-valued Pilot outputs.
%   Truth-bearing fields are consumed only here, after candidate-set
%   decisions have been produced.  Each row is one independently
%   materialized scenario in the current R2.1 protocol.
    if nargin<2,experiment_hash='';end
    n=numel(decisions);
    if n==0,rows=struct([]);return;end
    accepted=~[decisions.empty];hit=[decisions.hit];singleton=[decisions.set_size]==1;
    [lo,hi]=ci(nnz(hit),n);rows(1)=row('truth_set_coverage',nnz(hit),n,lo,hi,n,experiment_hash,decisions);
    [lo,hi]=ci(nnz(accepted),n);rows(2)=row('topology_acceptance_coverage',nnz(accepted),n,lo,hi,n,experiment_hash,decisions);
    [lo,hi]=ci(nnz(singleton),n);rows(3)=row('singleton_rate',nnz(singleton),n,lo,hi,n,experiment_hash,decisions);
    empty=~accepted;[lo,hi]=ci(nnz(empty),n);rows(4)=row('empty_set_rate',nnz(empty),n,lo,hi,n,experiment_hash,decisions);
    [lo,hi]=ci(nnz(singleton&hit),n);rows(5)=row('singleton_correct_rate',nnz(singleton&hit),n,lo,hi,n,experiment_hash,decisions);
    wrong=accepted&~hit;[lo,hi]=ci(nnz(wrong),nnz(accepted));rows(6)=row('topology_selective_risk',nnz(wrong),nnz(accepted),lo,hi,n,experiment_hash,decisions);
    sizes=[decisions.set_size];rows(7)=row('mean_set_size',sum(sizes),n,NaN,NaN,n,experiment_hash,decisions);rows(7).rate=mean(sizes);rows(7).median_set_size=median(sizes);
end
function r=row(name,num,den,lo,hi,evaluable,h,decisions)
    r=struct('metric_id',name,'numerator',num,'denominator',den,'rate',ratio(num,den), ...
        'ci_low',lo,'ci_high',hi,'evaluable_count',evaluable,'mean_set_size',mean([decisions.set_size]), ...
        'median_set_size',median([decisions.set_size]),'experiment_hash',h, ...
        'calibration_hash',decisions(1).calibration_hash,'definition_version','stage4a7_2_r2_1_pilot_metrics_v1');
end
function [lo,hi]=ci(a,b),if b<=0,lo=NaN;hi=NaN;else,[lo,hi]=stage4a7_2_wilson_interval(a,b);end,end
function x=ratio(a,b),if b<=0,x=NaN;else,x=a/b;end,end
