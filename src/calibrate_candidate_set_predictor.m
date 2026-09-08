function model = calibrate_candidate_set_predictor(calibration_scores, alpha, options)
%CALIBRATE_CANDIDATE_SET_PREDICTOR Empirical class-conditional candidate set.
%   Each row needs candidate_id and score.  Lower score is better; the
%   applied p-value follows (1+# calibration scores >= test score)/(n+1).
    if nargin<2||isempty(alpha),alpha=0.05;end
    if nargin<3||isempty(options),options=struct();end
    if ~isscalar(alpha)||alpha<=0||alpha>=1,error('stage4a7_1:InvalidAlpha','alpha must lie in (0,1).');end
    rows=normalize_rows(calibration_scores);ids={rows.candidate_id};unique_ids=stable_unique(ids);minimum=getf(options,'minimum_per_candidate',1);
    cls=repmat(struct('candidate_id','','scores',[],'sample_count',0,'minimum_attainable_p',NaN,'status',''),1,numel(unique_ids));
    for k=1:numel(unique_ids)
        z=[rows(strcmp(ids,unique_ids{k})).score];z=z(isfinite(z));cls(k).candidate_id=unique_ids{k};cls(k).scores=sort(z);cls(k).sample_count=numel(z);cls(k).minimum_attainable_p=1/(numel(z)+1);cls(k).status=ternary(numel(z)>=minimum,'calibrated','insufficient_calibration');
    end
    model=struct('alpha',alpha,'classes',cls,'candidate_ids',{unique_ids},'minimum_per_candidate',minimum, ...
        'status',ternary(all([cls.sample_count]>=minimum),'calibrated','insufficient_calibration'), ...
        'calibration_sample_count',numel(rows),'definition','empirical_class_conditional_candidate_set_v1', ...
        'tie_rule','greater_or_equal_counted_as_not_smaller','source','independent_calibration_only', ...
        'compatibility_hash',getf(options,'compatibility_hash',''),'calibration_hash',stage4a4_scientific_config_hash(struct('alpha',alpha,'rows',rows,'definition','candidate_set_v1')));
end
function out=apply_dummy %#ok<DEFNU>
end
function rows=normalize_rows(x)
    if istable(x),rows=table2struct(x);elseif isstruct(x),rows=x;else,error('stage4a7_1:InvalidCalibrationScores','Expected struct or table.');end
    if isempty(rows),error('stage4a7_1:EmptyCalibrationScores','Calibration scores are empty.');end
    for k=1:numel(rows),if ~isfield(rows(k),'candidate_id')||~isfield(rows(k),'score'),error('stage4a7_1:MissingCalibrationField','candidate_id and score are required.');end,end
end
function y=stable_unique(x),y={};for k=1:numel(x),if ~any(strcmp(y,x{k})),y{end+1}=x{k};end,end,end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
