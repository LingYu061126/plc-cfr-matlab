function rows = stage4a7_2_r2_exact_topk_audit(spec, top_k_values)
%STAGE4A7_2_R2_EXACT_TOPK_AUDIT Compare ordered lazy output with exhaustive.
%   The comparison is on canonical graph keys, prior costs and deterministic
%   tie ordering.  Membership alone is intentionally insufficient.
    if nargin < 2 || isempty(top_k_values), top_k_values = [1 3 5 10]; end
    t0 = tic;
    [exhaustive, exhaustive_audit] = generate_engineering_topology_candidates(spec);
    exhaustive_runtime = toc(t0);
    exhaustive = sort_candidates(exhaustive);
    all_keys = {exhaustive.canonical_graph_key};
    all_costs = [exhaustive.prior_cost];
    rows = repmat(row_template(),1,numel(top_k_values));
    for q = 1:numel(top_k_values)
        k = min(top_k_values(q),numel(exhaustive));
        t = tic;
        [lazy,audit] = generate_topk_topology_candidates(spec,k);
        lazy_runtime = toc(t);
        lazy = sort_candidates(lazy);
        lazy_keys = {lazy.canonical_graph_key};
        lazy_costs = [lazy.prior_cost];
        expected_keys = all_keys(1:k);
        expected_costs = all_costs(1:k);
        rows(q).top_k = top_k_values(q);
        rows(q).total_feasible_candidates = numel(exhaustive);
        rows(q).returned_count = numel(lazy);
        rows(q).exact_first_k_match = isequal(lazy_keys,expected_keys);
        rows(q).ordered_key_match = rows(q).exact_first_k_match;
        rows(q).cost_match = numel(lazy_costs)==numel(expected_costs) && ...
            all(abs(lazy_costs-expected_costs)<=1e-12*max(1,max(abs(expected_costs))));
        rows(q).tie_break_match = rows(q).ordered_key_match && ...
            tie_order_match(lazy,exhaustive,k);
        rows(q).duplicate_count = numel(lazy_keys)-numel(unique(lazy_keys));
        rows(q).exhaustive_runtime_s = exhaustive_runtime;
        rows(q).topk_runtime_s = lazy_runtime;
        rows(q).speedup = exhaustive_runtime/max(lazy_runtime,eps);
        rows(q).states_pushed = getf(audit,'states_pushed',NaN);
        rows(q).states_popped = getf(audit,'states_popped',NaN);
        rows(q).states_expanded = getf(audit,'states_expanded',NaN);
        rows(q).peak_queue_size = getf(audit,'peak_queue_size',NaN);
        rows(q).prototype_status = getf(audit,'prototype_status','');
        rows(q).exhaustive_audit_status = ternary(~isempty(exhaustive_audit), ...
            'completed','empty');
        rows(q).candidate_keys = strjoin(lazy_keys,';');
        rows(q).candidate_costs = strjoin(arrayfun(@(x)sprintf('%.17g',x), ...
            lazy_costs,'UniformOutput',false),';');
    end
end

function c = sort_candidates(c)
    if isempty(c), return; end
    keys = {c.canonical_graph_key}; costs = [c.prior_cost].';
    [~,ord] = sortrows([costs,(1:numel(c)).']);
    % sortrows above only provides a numeric tie order; apply key tie-break.
    qcost = round(costs/1e-12)*1e-12;
    groups = unique(qcost(ord),'stable'); out = repmat(c(1),1,0);
    for i=1:numel(groups)
        ix = ord(qcost(ord)==groups(i));
        [~,ko] = sort(keys(ix)); out = [out c(ix(ko))]; %#ok<AGROW>
    end
    c = out;
end

function tf = tie_order_match(lazy,exhaustive,k)
    if isempty(lazy), tf = k==0; return; end
    n = min(k,numel(lazy));
    tf = isequal({lazy(1:n).canonical_graph_key}, ...
        {exhaustive(1:n).canonical_graph_key});
end

function r = row_template()
    r = struct('top_k',0,'total_feasible_candidates',0,'returned_count',0, ...
        'exact_first_k_match',false,'ordered_key_match',false,'cost_match',false, ...
        'tie_break_match',false,'duplicate_count',0,'exhaustive_runtime_s',NaN, ...
        'topk_runtime_s',NaN,'speedup',NaN,'states_pushed',NaN, ...
        'states_popped',NaN,'states_expanded',NaN,'peak_queue_size',NaN, ...
        'prototype_status','','exhaustive_audit_status','','candidate_keys','', ...
        'candidate_costs','');
end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
