function [candidate, report] = check_forward_model_compatibility(candidate, cfg)
%CHECK_FORWARD_MODEL_COMPATIBILITY Validate and adapt an engineering graph.
    if isfield(candidate,'edges') && ~isempty(candidate.edges)
        [candidate, report] = adapt_engineering_candidate_to_forward_model(candidate,cfg);
        return;
    end
    report=struct('forward_model_compatible',false,'reason_code','missing_edge_representation', ...
        'compatibility_reason','Candidate has no engineering edges.','adapter_hash','', ...
        'scored_library_included',false,'candidate_id',getf(candidate,'graph_candidate_id',getf(candidate,'id','')));
    candidate.forward_model_compatible=false; candidate.compatibility_reason=report.compatibility_reason;
    candidate.scored_library_included=false; candidate.adapter_hash='';
end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
