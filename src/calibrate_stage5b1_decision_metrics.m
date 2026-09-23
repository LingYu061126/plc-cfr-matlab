function model = calibrate_stage5b1_decision_metrics(distances, truth_index, candidate_set_size, options)
%CALIBRATE_STAGE5B1_DECISION_METRICS Calibrate only the added evidence layer.
%   The frozen Stage 4A model and data are not modified. Reference rows are
%   calibration observations whose stable Top-1 is the known truth and whose
%   frozen Stage 4A candidate set is a singleton. Pilot/OOD rows are forbidden.
    if nargin<4||isempty(options),options=struct();end
    d=double(distances);truth_index=truth_index(:);candidate_set_size=candidate_set_size(:);
    assert(size(d,1)==numel(truth_index)&&size(d,1)==numel(candidate_set_size), ...
        'stage5b1:CalibrationShape','Calibration arrays have inconsistent row counts.');
    ids=getf(options,'candidate_ids',arrayfun(@(k)sprintf('C%03d',k),1:size(d,2),'UniformOutput',false));
    margin=compute_candidate_margin(d,ids);
    reference=(margin.best_index==truth_index)&(candidate_set_size==1)&isfinite(margin.margin)&(margin.margin>0);
    minimum_count=getf(options,'minimum_reference_count',100);
    assert(nnz(reference)>=minimum_count,'stage5b1:InsufficientReferenceCalibration', ...
        'Only %d reference calibration rows; need at least %d.',nnz(reference),minimum_count);
    margin_q=getf(options,'margin_quantile',0.05);confidence_q=getf(options,'confidence_quantile',0.05);
    entropy_q=getf(options,'entropy_quantile',0.95);target_odds=getf(options,'temperature_target_odds',9);
    assert(margin_q>0&&margin_q<0.5&&confidence_q>0&&confidence_q<0.5&&entropy_q>0.5&&entropy_q<1, ...
        'stage5b1:InvalidCalibrationQuantile','Evidence calibration quantiles are invalid.');
    assert(target_odds>1,'stage5b1:InvalidTargetOdds','Temperature target odds must exceed one.');
    reference_margin=margin.margin(reference);median_margin=median(reference_margin);
    beta=log(target_odds)/median_margin;
    confidence=compute_candidate_confidence(d,beta,ids);
    model=struct('beta',beta,'margin_threshold',fixed_quantile(reference_margin,margin_q), ...
        'top1_confidence_threshold',fixed_quantile(confidence.top1_confidence(reference),confidence_q), ...
        'normalized_entropy_threshold',fixed_quantile(confidence.normalized_entropy(reference),entropy_q), ...
        'margin_quantile',margin_q,'confidence_quantile',confidence_q,'entropy_quantile',entropy_q, ...
        'temperature_target_odds',target_odds,'reference_median_margin',median_margin, ...
        'calibration_sample_count',size(d,1),'reference_sample_count',nnz(reference), ...
        'reference_definition','truth_is_stable_top1_and_frozen_stage4a_set_is_singleton', ...
        'pilot_used_for_calibration',false,'status','calibrated', ...
        'definition_version','stage5b1_evidence_calibration_v1');
    if exist('stage4a4_scientific_config_hash','file')==2
        model.calibration_hash=stage4a4_scientific_config_hash(model);
    else
        model.calibration_hash='hash_function_unavailable';
    end
end

function y=fixed_quantile(x,q)
    x=sort(double(x(:)));y=x(max(1,min(numel(x),ceil(q*numel(x)))));
end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
