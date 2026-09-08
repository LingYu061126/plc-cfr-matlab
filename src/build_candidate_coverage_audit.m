function audit = build_candidate_coverage_audit(engineering_candidates, scored_ids, truth)
%BUILD_CANDIDATE_COVERAGE_AUDIT Report coverage loss before classifier scoring.
    if nargin<2||isempty(scored_ids),scored_ids={};end
    if nargin<3||isempty(truth),truth=struct();end
    eids=cellfun(@(x)get_id(x),num2cell(engineering_candidates),'UniformOutput',false);
    compatible=arrayfun(@(x)get_bool(x,'forward_model_compatible',false),engineering_candidates);
    scored=ismember(eids,stage4a7_1_cellstr(scored_ids));
    truth_id=getf(truth,'truth_topology_id','');
    in_eng=any(strcmp(eids,truth_id));in_forward=any(strcmp(eids(compatible),truth_id));in_scored=any(strcmp(eids(scored),truth_id));
    reason='';if ~in_eng,reason='truth_outside_engineering_candidate_space';elseif ~in_forward,reason='truth_forward_model_incompatible';elseif ~in_scored,reason='truth_excluded_from_scored_library';else,reason='covered';end
    audit=struct('engineering_candidate_count',numel(engineering_candidates),'forward_compatible_candidate_count',nnz(compatible), ...
        'scored_candidate_count',nnz(scored),'truth_topology_id',truth_id,'truth_in_engineering_space',in_eng, ...
        'truth_forward_model_compatible',in_forward,'truth_in_scored_library',in_scored,'coverage_failure_reason',reason);
end
function x=get_id(c),if isfield(c,'id')&&~isempty(c.id),x=c.id;elseif isfield(c,'graph_candidate_id'),x=c.graph_candidate_id;elseif isfield(c,'topology_id'),x=c.topology_id;else,x='';end,end
function x=get_bool(s,n,d),if isfield(s,n),x=logical(s.(n));else,x=d;end,end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n),x=s.(n);else,x=d;end,end
