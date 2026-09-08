function out = score_candidate_set_metrics(ranked_ids, accepted_ids, truth_id, truth_set)
%SCORE_CANDIDATE_SET_METRICS Small truth-bearing offline scoring helper.
%   This function is deliberately separate from candidate generation and
%   confirmation.  truth_set is used only for evaluation.
    if nargin<4||isempty(truth_set),truth_set={truth_id};end
    ranked_ids=stage4a7_1_cellstr(ranked_ids);accepted_ids=stage4a7_1_cellstr(accepted_ids);truth_set=stage4a7_1_cellstr(truth_set);
    accepted=~isempty(accepted_ids);contains_truth=any(ismember(truth_set,accepted_ids));
    unique_output=accepted&&numel(accepted_ids)==1;
    nonunique_truth=numel(truth_set)>1;
    out=struct('accepted',accepted,'contains_truth',contains_truth,'unique_output',unique_output, ...
        'truth_nonunique',nonunique_truth,'false_unique',unique_output&&nonunique_truth, ...
        'truth_id',truth_id,'truth_set',strjoin(truth_set,','),'accepted_set',strjoin(accepted_ids,','), ...
        'best_id',ternary(~isempty(ranked_ids),ranked_ids{1},''));
end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
