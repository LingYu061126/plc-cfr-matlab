function rows=stage4a7_2_r1_nonunique_metrics(decisions,scientific_hash)
%STAGE4A7_2_R1_NONUNIQUE_METRICS Score non-unique truth sets separately.
%   A singleton output is false-unique whenever the frozen truth set has more
%   than one observation-equivalent member, even if that singleton belongs to
%   the truth set.
    n=numel(decisions);evaluable=false(n,1);nonunique=false(n,1);falseu=false(n,1);multi=false(n,1);empty=false(n,1);hit=false(n,1);
    for k=1:n
        m=getf(decisions(k),'truth_member_count',0);evaluable(k)=m>=1;nonunique(k)=m>1;sz=getf(decisions(k),'set_size',0);falseu(k)=evaluable(k)&&nonunique(k)&&sz==1;multi(k)=evaluable(k)&&sz>1;empty(k)=evaluable(k)&&sz==0;hit(k)=evaluable(k)&&getf(decisions(k),'hit',false);
    end
    specs={'truth_set_coverage','false_unique_unconditional_rate','false_unique_conditional_rate','multi_candidate_rate','empty_set_rate'};
    num=[nnz(hit),nnz(falseu),nnz(falseu),nnz(multi),nnz(empty)];den=[nnz(evaluable),nnz(evaluable),nnz(nonunique),nnz(evaluable),nnz(evaluable)];
    rows=repmat(struct('metric_id','','numerator',0,'denominator',0,'rate',NaN,'ci_low',NaN,'ci_high',NaN,'evaluable_count',0,'true_nonunique_count',nnz(nonunique),'definition_version','stage4a7_2_r1_nonunique_v1','scientific_hash',''),numel(specs),1);
    for k=1:numel(specs),rows(k).metric_id=specs{k};rows(k).numerator=num(k);rows(k).denominator=den(k);rows(k).evaluable_count=nnz(evaluable);if den(k)>0,rows(k).rate=num(k)/den(k);[rows(k).ci_low,rows(k).ci_high]=stage4a7_2_wilson_interval(num(k),den(k));end;rows(k).scientific_hash=scientific_hash;end
end
function x=getf(s,n,d),if isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
