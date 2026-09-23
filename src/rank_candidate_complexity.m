function [ranked, audit] = rank_candidate_complexity(candidates, options)
%RANK_CANDIDATE_COMPLEXITY Deterministically rank feasible candidates.
%   score = edge_count + branch_penalty*branch_count +
%           prior_cost_weight*prior_cost.
%   This transparent engineering rank is not a CFR likelihood or posterior.
    if nargin<2||isempty(options),options=struct();end
    branch_weight=get_field(options,'branch_penalty',1);
    prior_weight=get_field(options,'prior_cost_weight',1);
    validateattributes(branch_weight,{'numeric'},{'scalar','finite','nonnegative'});
    validateattributes(prior_weight,{'numeric'},{'scalar','finite','nonnegative'});
    if isempty(candidates)
        ranked=candidates;audit=struct('candidate_count',0,'formula',formula_text(branch_weight,prior_weight), ...
            'minimum_score',NaN,'maximum_score',NaN);return;
    end
    ranked=candidates;
    scores=zeros(numel(ranked),1); prior=zeros(numel(ranked),1); branches=zeros(numel(ranked),1);
    for k=1:numel(ranked)
        prior(k)=get_field(ranked(k),'prior_cost',0);
        branches(k)=get_field(ranked(k),'branch_count',NaN);
        if ~isfinite(branches(k)),branches(k)=max(0,get_field(ranked(k),'edge_count',numel(ranked(k).edges))-1);end
        edges=get_field(ranked(k),'edge_count',numel(ranked(k).edges));
        scores(k)=edges+branch_weight*branches(k)+prior_weight*prior(k);
        ranked(k).complexity_score=scores(k);
        ranked(k).complexity_formula=formula_text(branch_weight,prior_weight);
    end
    [~,key_order]=sort({ranked.canonical_graph_key});ranked=ranked(key_order);scores=scores(key_order);prior=prior(key_order);branches=branches(key_order);
    [~,order]=sortrows([scores prior branches],[1 2 3]);ranked=ranked(order);scores=scores(order);
    for k=1:numel(ranked),ranked(k).complexity_rank=k;end
    audit=struct('candidate_count',numel(ranked),'formula',formula_text(branch_weight,prior_weight), ...
        'minimum_score',min(scores),'maximum_score',max(scores));
end
function s=formula_text(a,b),s=sprintf('edge_count + %.12g*branch_count + %.12g*prior_cost',a,b);end
function x=get_field(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
