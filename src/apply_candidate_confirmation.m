function result = apply_candidate_confirmation(raw,calibration_model,options)
%APPLY_CANDIDATE_CONFIRMATION Apply frozen observation-only decision rules.
%   raw is produced by the candidate-cache scorer.  No offline labels are
%   required or read here.
    if nargin<3 || ~isfield(options,'method'), error('stage4a4:MissingMethod','options.method is required.'); end
    method=char(options.method);
    [raw.robust_best_score,raw.robust_margin]=robust_values(raw,calibration_model);
    if raw.candidate_count_after_prior==0
        decision='reject_no_feasible_candidate'; reason='empty feasible candidate cache';
    else
        t=calibration_model.thresholds; decision=''; reason='';
        if raw.best_distance>t.residual_threshold
            decision='reject_model_mismatch'; reason='best residual exceeds frozen absolute threshold';
        else
            pass=true;
            switch method
                case 'baseline_abs_margin'
                    pass=raw.margin>=t.margin_threshold; if ~pass, reason='class margin below frozen threshold'; end
                case 'absolute_ratio'
                    pass=raw.rho<=t.rho_threshold; if ~pass, reason='distance ratio exceeds frozen threshold'; end
                case 'joint_abs_margin_ratio'
                    pass=raw.margin>=t.margin_threshold && raw.rho<=t.rho_threshold;
                    if ~pass, reason='absolute residual, margin and ratio joint rule failed'; end
                case 'class_conditioned'
                    pass=raw.robust_best_score<=t.robust_score_threshold && raw.robust_margin>=t.robust_margin_threshold;
                    if ~pass, reason='class-conditioned robust score or margin failed'; end
                otherwise, error('stage4a4:UnknownMethod','Unknown method %s.',method);
            end
            if ~pass
                decision='reject_low_margin';
            elseif raw.current_class_size>1
                decision='equivalence_class'; reason='best observation class has multiple members';
            elseif raw.baseline_P0_equivalence_class_size>1
                decision='unique_given_prior'; reason='prior removed members of a baseline observational class';
            else
                decision='unique_topology'; reason='singleton baseline class passed frozen rule';
            end
        end
    end
    accepted='';
    if ismember(decision,{'unique_topology','unique_given_prior','equivalence_class'})
        if raw.current_class_size>1, accepted=raw.best_equivalence_members; else, accepted=raw.best_topology_id; end
    end
    result=raw;
    result.method_id=method; result.decision=decision; result.decision_reason=reason;
    result.accepted_topology_set=accepted; result.thresholds=calibration_model.thresholds;
    result.calibration_hash=calibration_model.configuration_hash;
    result.residual_threshold=calibration_model.thresholds.residual_threshold;
    result.margin_threshold=calibration_model.thresholds.margin_threshold;
    result.rho_threshold=calibration_model.thresholds.rho_threshold;
    result.robust_score_threshold=calibration_model.thresholds.robust_score_threshold;
    result.robust_margin_threshold=calibration_model.thresholds.robust_margin_threshold;
    result.robust_best_score=get_option(raw,'robust_best_score',NaN);
    result.robust_margin=get_option(raw,'robust_margin',NaN);
end
function x=get_option(s,name,d)
    if isfield(s,name)&&~isempty(s.(name)),x=s.(name);else,x=d;end
end
function [best,margin]=robust_values(raw,model)
    if ~isfield(raw,'class_scores') || isempty(raw.class_scores) || ~isfield(model,'classes')
        best=Inf; margin=NaN; return;
    end
    if isfield(raw,'baseline_class_scores') && ~isempty(raw.baseline_class_scores)
        scores=raw.baseline_class_scores; labels=raw.baseline_class_labels;
    else
        scores=raw.class_scores; labels=raw.class_labels;
    end
    z=Inf(1,numel(scores)); e=model.quantiles.epsilon;
    for k=1:numel(model.classes)
        j=find(strcmp(labels,model.classes(k).label),1);
        if ~isempty(j), z(j)=(scores(j)-model.classes(k).center)/(model.classes(k).scale+e); end
    end
    if all(isinf(z))
        best=(raw.best_distance-model.pooled_center)/(model.pooled_scale+e);
        margin=raw.margin/(model.pooled_scale+e);
    else
        [best,j]=min(z); z(j)=Inf; margin=min(z)-best;
    end
end
