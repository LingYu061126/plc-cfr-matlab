function result = apply_stage4a5_confirmation(raw, model, spec)
%APPLY_STAGE4A5_CONFIRMATION Apply an observation-only M0--M3 rule.
%   spec is frozen before final-test evaluation and contains only method
%   family and hyperparameters, never truth or coverage labels.
    if nargin<3||~isfield(spec,'family'),error('stage4a5:MissingMethod','spec.family is required.');end
    family=char(spec.family);decision='';reason='';result_submax=NaN;result_subq=NaN;ns=NaN;nm=NaN;qstable=NaN;
    if raw.candidate_count_after_prior==0
        decision='reject_no_feasible_candidate';reason='empty feasible candidate cache';
    elseif raw.best_distance>model.thresholds.residual_threshold
        decision='reject_model_mismatch';reason='best full-band residual exceeds calibration threshold';
    else
        if ismember(family,{'M1','M2','M3'})
            [submax,subq]=subband_stats(raw,model,spec.M,spec.q);
            result_submax=submax;result_subq=subq;
            if submax>model.subband.(key_for(spec.M,spec.q)).max_threshold || subq>model.subband.(key_for(spec.M,spec.q)).q_threshold
                decision='reject_subband_mismatch';reason='one or more calibrated subband residual statistics fail';
            end
        else,result_submax=NaN;result_subq=NaN;
        end
        if isempty(decision)&&ismember(family,{'M2','M3'})
            nk=model.neighborhood.(sprintf('K%d',spec.K));kidx=find([raw.topk_evidence.k_values]==spec.K,1);
            ns=raw.topk_evidence.selected_neighborhood_scores(kidx);nm=raw.topk_evidence.selected_neighborhood_margins(kidx);
            if ns>nk.score_threshold||nm<nk.margin_threshold
                decision='reject_neighborhood_mismatch';reason='top-K neighborhood score or margin fails';
            end
        else
            if isfield(raw,'topk_evidence')&&isfield(raw.topk_evidence,'k_values')
                kidx=find([raw.topk_evidence.k_values]==get_option(spec,'K',5),1);
                if isempty(kidx),kidx=1;end
                ns=raw.topk_evidence.selected_neighborhood_scores(kidx);nm=raw.topk_evidence.selected_neighborhood_margins(kidx);
            else,ns=NaN;nm=NaN;end
        end
        if isempty(decision)&&strcmp(family,'M3')
            if raw.current_class_size>1,qstable=raw.stability.best_class_stability;else,qstable=raw.stability.best_topology_stability;end
            if qstable<spec.stability_threshold
                decision='reject_low_stability';reason='contiguous-block selection stability below frozen threshold';
            end
        else,qstable=NaN;
        end
        if isempty(decision)&&raw.margin<model.thresholds.margin_threshold
            decision='reject_low_margin';reason='class margin below calibration threshold';
        end
        if isempty(decision)
            if raw.current_class_size>1
                decision='equivalence_class';reason='best observation class has multiple members';
            elseif raw.baseline_P0_equivalence_class_size>1
                decision='unique_given_prior';reason='prior removed members of a baseline observational class';
            else
                decision='unique_topology';reason='singleton baseline class passed all frozen rules';
            end
        end
    end
    accepted='';if ismember(decision,{'unique_topology','unique_given_prior','equivalence_class'}),accepted=raw.best_equivalence_members;end
    result=raw;result.method_id=method_name(spec);result.method_family=family;result.method_spec=spec;result.decision=decision;result.decision_reason=reason;result.accepted_topology_set=accepted;
    result.residual_threshold=model.thresholds.residual_threshold;result.margin_threshold=model.thresholds.margin_threshold;
    result.subband_max_stat=result_submax;result.subband_quantile_stat=result_subq;result.neighborhood_score=ns;result.neighborhood_margin=nm;result.stability_value=qstable;result.stability_threshold=get_option(spec,'stability_threshold',NaN);
    result.calibration_hash=model.configuration_hash;
end
function [mx,qq]=subband_stats(raw,model,M,q)
    [d,c]=aggregate_subbands(raw.best_subband_distance,raw.subband_counts,M);key=key_for(M,q);s=model.subband.(key);z=(d-s.center)./(s.scale+1e-12);mx=max(z);qq=q_local(z,q);
end
function [d,c]=aggregate_subbands(x,c0,M)
    N=numel(x);if M==N,d=x;c=c0;elseif mod(N,M)==0,r=N/M;d=zeros(1,M);c=zeros(1,M);for j=1:M,ix=(j-1)*r+(1:r);c(j)=sum(c0(ix));d(j)=sqrt(sum((x(ix).^2).*c0(ix))/c(j));end;else,error('stage4a5:SubbandResolution','M must divide max subband count.');end
end
function key=key_for(M,q),key=sprintf('M%d_q%03d',M,round(1000*q));end
function x=get_option(s,n,d),if isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function y=q_local(x,p),x=sort(x(isfinite(x)));if isempty(x),y=NaN;elseif numel(x)==1,y=x;else,t=1+(numel(x)-1)*p;l=floor(t);h=ceil(t);y=x(l)+(t-l)*(x(h)-x(l));end,end
function n=method_name(s),n=sprintf('%s_M%d_q%03d_K%d_qs%02d',s.family,get_option(s,'M',0),round(1000*get_option(s,'q',0)),get_option(s,'K',0),round(100*get_option(s,'stability_threshold',0)));end
