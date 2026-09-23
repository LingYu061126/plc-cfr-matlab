function out = compute_candidate_confidence(distances, beta, candidate_ids)
%COMPUTE_CANDIDATE_CONFIDENCE Normalized confidence score and entropy.
%   The returned scores are softmax(-BETA*distance). They are auxiliary
%   normalized confidence scores, not posterior probabilities.
    d = double(distances);
    if isvector(d), d = reshape(d,1,[]); end
    assert(~isempty(d)&&all(isfinite(d(:))),'stage5b1:InvalidConfidenceDistance', ...
        'Distances must be a nonempty finite matrix.');
    assert(isscalar(beta)&&isfinite(beta)&&beta>0,'stage5b1:InvalidBeta', ...
        'Beta must be a positive finite scalar.');
    ids = normalize_ids(candidate_ids,size(d,2));
    shifted = d-min(d,[],2);
    weights = exp(-beta*shifted);
    scores = weights./sum(weights,2);
    entropy = -sum(scores.*log(max(scores,realmin)),2);
    if size(d,2)>1, normalized_entropy=entropy/log(size(d,2));else,normalized_entropy=zeros(size(entropy));end
    [top1_confidence,top1_index]=max(scores,[],2);
    out=struct('normalized_confidence_scores',scores,'top1_index',top1_index, ...
        'top1_candidate',{ids(top1_index)},'top1_confidence',top1_confidence, ...
        'entropy',entropy,'normalized_entropy',normalized_entropy,'beta',beta, ...
        'candidate_count',size(d,2), ...
        'definition_version','stage5b1_normalized_confidence_entropy_v1', ...
        'probability_semantics','normalized_confidence_score_not_posterior_probability');
end

function ids=normalize_ids(x,n)
    if isstring(x)
        ids=cellstr(x(:).');
    elseif iscell(x)
        ids=cellfun(@char,x(:).','UniformOutput',false);
    else
        error('stage5b1:InvalidCandidateIds','Candidate IDs must be strings or a cell array.');
    end
    assert(numel(ids)==n,'stage5b1:CandidateIdCount','Candidate ID count does not match distances.');
end
