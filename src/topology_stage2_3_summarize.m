function summary = topology_stage2_3_summarize(records, candidates)
%TOPOLOGY_STAGE2_3_SUMMARIZE Aggregate sealed stage-2.3 trial records.
    key=cell(numel(records),1);
    for k=1:numel(records)
        key{k}=sprintf('%s|%s|%g|%s|%s',records(k).measurement_kind, ...
            records(k).condition,records(k).snr_db,records(k).method,records(k).feature);
    end
    groups=unique(key,'stable');summary=repmat(empty_summary(),0,1);
    for g=1:numel(groups)
        x=records(strcmp(key,groups{g}));row=empty_summary();
        row.measurement_kind=x(1).measurement_kind;row.condition=x(1).condition;row.snr_db=x(1).snr_db;row.method=x(1).method;row.feature=x(1).feature;row.sample_count=numel(x);row.trials=numel(unique([x.trial]));
        row.strict_accuracy=mean([x.strict_correct]);row.equivalence_class_accuracy=mean([x.class_correct]);row.unique_strict_accuracy=mean([x.unique_strict_correct]);row.ambiguity_rate=mean([x.ambiguous]);row.false_unique_rate=mean([x.false_unique]);
        [row.accuracy_std,row.ci_low,row.ci_high]=trial_ci(x);row.mean_margin=mean([x.distance_margin]);row.mean_intra=mean([x.class_intra_distance]);row.mean_inter=mean([x.nearest_class_inter_distance]);row.intra_inter_ratio=row.mean_intra/row.mean_inter;
        row.nmse=mean([x.nmse]);row.amplitude_rmse_db=mean([x.amplitude_rmse_db]);row.raw_phase_rmse_deg=mean([x.raw_phase_rmse_deg]);row.weighted_phase_rmse_deg=mean([x.weighted_phase_rmse_deg]);row.valid_phase_fraction=mean([x.valid_phase_fraction]);row.runtime_s=mean([x.runtime_s]);
        truth=cellfun(@(z)find(strcmp({candidates.id},z),1),{x.true_id});pred=cellfun(@(z)find(strcmp({candidates.id},z),1),{x.predicted_id});em=topology_evaluation_metrics(truth,pred,candidates,[x.ambiguous]);row.edge_precision=em.edge_micro.precision;row.edge_recall=em.edge_micro.recall;row.edge_f1=em.edge_micro.f1;summary(end+1)=row; %#ok<AGROW>
    end
end
function [s,lo,hi]=trial_ci(x)
    trials=unique([x.trial]);a=zeros(size(trials));for k=1:numel(trials),a(k)=mean([x([x.trial]==trials(k)).strict_correct]);end;s=std(a,0);half=1.96*s/sqrt(numel(a));lo=max(0,mean(a)-half);hi=min(1,mean(a)+half);
end
function r=empty_summary(),r=struct('measurement_kind','','condition','','snr_db',0,'method','','feature','','sample_count',0,'trials',0,'strict_accuracy',NaN,'equivalence_class_accuracy',NaN,'unique_strict_accuracy',NaN,'ambiguity_rate',NaN,'false_unique_rate',NaN,'accuracy_std',NaN,'ci_low',NaN,'ci_high',NaN,'mean_margin',NaN,'mean_intra',NaN,'mean_inter',NaN,'intra_inter_ratio',NaN,'nmse',NaN,'amplitude_rmse_db',NaN,'raw_phase_rmse_deg',NaN,'weighted_phase_rmse_deg',NaN,'valid_phase_fraction',NaN,'runtime_s',NaN,'edge_precision',NaN,'edge_recall',NaN,'edge_f1',NaN);end
