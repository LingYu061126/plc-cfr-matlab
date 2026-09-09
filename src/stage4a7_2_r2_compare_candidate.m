function c = stage4a7_2_r2_compare_candidate(a,b,tolerance)
%STAGE4A7_2_R2_COMPARE_CANDIDATE Shared prior-cost/key comparator.
    if nargin<3 || isempty(tolerance), tolerance=1e-12; end
    scale=max([1 abs(double(a.prior_cost)) abs(double(b.prior_cost))]);
    tol=tolerance*scale; da=double(a.prior_cost); db=double(b.prior_cost);
    if da < db-tol, c=-1; return; end
    if da > db+tol, c=1; return; end
    c=stage4a7_2_r2_compare_text(get_key(a),get_key(b));
end
function k=get_key(a)
    if isfield(a,'canonical_graph_key') && ~isempty(a.canonical_graph_key)
        k=char(a.canonical_graph_key);
    elseif isfield(a,'state_key')
        k=char(a.state_key);
    else
        k='';
    end
end
