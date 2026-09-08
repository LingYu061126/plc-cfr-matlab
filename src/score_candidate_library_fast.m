function out = score_candidate_library_fast(observed, templates, candidate_ids, options)
%SCORE_CANDIDATE_LIBRARY_FAST Vectorized exact candidate score helper.
%   No approximate pre-screen is performed.  Templates are rows or a cell
%   array of vectors; output ordering is deterministic and stable by ID.
    if nargin<4||isempty(options),options=struct();end
    ids=stage4a7_1_cellstr(candidate_ids);
    if iscell(templates),m=numel(templates);X=zeros(m,numel(observed));for k=1:m,X(k,:)=templates{k}(:).';end
    else,X=templates;end
    y=observed(:).';if size(X,2)~=numel(y),error('stage4a7_1:TemplateDimension','Template dimensions differ.');end
    R=X-y;weights=getf(options,'weights',ones(1,size(X,2)));weights=weights(:).';
    scores=sqrt(mean(abs(R).^2.*weights,2));
    [sorted_scores,ord]=sort(scores,'ascend');
    out=struct('scores',scores,'ranked_candidate_ids',{ids(ord)},'ranked_scores',sorted_scores, ...
        'best_candidate_id',ids{ord(1)},'best_score',sorted_scores(1),'second_score',get_second(sorted_scores), ...
        'margin',get_second(sorted_scores)-sorted_scores(1),'template_count',size(X,1), ...
        'parameter_dimension',getf(options,'parameter_dimension',NaN),'template_count_per_candidate',getf(options,'template_count_per_candidate',NaN), ...
        'complexity_audit_status',ternary(isfinite(getf(options,'parameter_dimension',NaN)),'reported','not_provided'));
end
function x=get_second(z),if numel(z)>=2,x=z(2);else,x=Inf;end,end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
