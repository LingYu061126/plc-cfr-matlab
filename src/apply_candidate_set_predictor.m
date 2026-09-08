function out = apply_candidate_set_predictor(scores, model, alpha)
%APPLY_CANDIDATE_SET_PREDICTOR Apply a frozen empirical candidate set.
    if nargin<3||isempty(alpha),alpha=model.alpha;end
    rows=normalize_scores(scores);ids={rows.candidate_id};p=NaN(1,numel(rows));status=cell(1,numel(rows));
    for k=1:numel(rows)
        j=find(strcmp({model.classes.candidate_id},ids{k}),1);
        if isempty(j)||~strcmp(model.classes(j).status,'calibrated'),status{k}='insufficient_calibration';continue;end
        z=model.classes(j).scores;p(k)=(1+sum(z>=rows(k).score))/(numel(z)+1);status{k}='calibrated';
    end
    candidate_ids=stable_unique(ids);keep=false(1,numel(candidate_ids));
    for k=1:numel(candidate_ids),j=find(strcmp(ids,candidate_ids{k}),1);keep(k)=isfinite(p(j))&&p(j)>alpha;end
    out=struct('candidate_ids',{candidate_ids},'p_values',p,'score_rows',rows,'accepted_candidate_set',{candidate_ids(keep)}, ...
        'alpha',alpha,'status',ternary(any(keep),'accepted_set','empty_set'),'minimum_attainable_p',min([model.classes.minimum_attainable_p]), ...
        'point_status',{status},'calibration_hash',getf(model,'calibration_hash',''),'compatibility_hash',getf(model,'compatibility_hash',''));
end
function rows=normalize_scores(x),if istable(x),rows=table2struct(x);elseif isstruct(x),rows=x;else,error('stage4a7_1:InvalidScores','Expected struct or table.');end,end
function y=stable_unique(x),y={};for k=1:numel(x),if ~any(strcmp(y,x{k})),y{end+1}=x{k};end,end,end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
