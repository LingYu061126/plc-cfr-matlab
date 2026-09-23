function out = compute_candidate_margin(distances, candidate_ids)
%COMPUTE_CANDIDATE_MARGIN Stable Top-1/Top-2 distance separation.
%   DISTANCES is N-by-M (lower is better), with M >= 2. CANDIDATE_IDS is
%   a 1-by-M cell array/string array. Ties are resolved by candidate order.
    d = double(distances);
    if isvector(d), d = reshape(d, 1, []); end
    assert(size(d,2) >= 2, 'stage5b1:TooFewCandidates', ...
        'At least two candidate distances are required.');
    assert(all(isfinite(d(:))), 'stage5b1:NonfiniteDistance', ...
        'Candidate distances must be finite.');
    ids = normalize_ids(candidate_ids, size(d,2));
    n = size(d,1);
    best_index = zeros(n,1); second_index = zeros(n,1);
    d1 = zeros(n,1); d2 = zeros(n,1);
    for k = 1:n
        ranked = sortrows([d(k,:).', (1:size(d,2)).'], [1 2]);
        best_index(k) = ranked(1,2); second_index(k) = ranked(2,2);
        d1(k) = ranked(1,1); d2(k) = ranked(2,1);
    end
    out = struct('best_index',best_index,'second_index',second_index, ...
        'best_candidate',{ids(best_index)},'second_candidate',{ids(second_index)}, ...
        'd1',d1,'d2',d2,'margin',d2-d1, ...
        'definition_version','stage5b1_top1_top2_margin_v1');
end

function ids = normalize_ids(x, n)
    if isstring(x), ids = cellstr(x(:).');
    elseif iscell(x), ids = cellfun(@char,x(:).','UniformOutput',false);
    else, error('stage5b1:InvalidCandidateIds','Candidate IDs must be strings or a cell array.');
    end
    assert(numel(ids)==n,'stage5b1:CandidateIdCount','Candidate ID count does not match distances.');
end
