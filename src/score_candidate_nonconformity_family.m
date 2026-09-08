function family = score_candidate_nonconformity_family(distances, candidate_ids, equivalence_group, scales)
%SCORE_CANDIDATE_NONCONFORMITY_FAMILY Distance-based physical scores.
%   Each row is an observation and each column is a candidate.  Lower is
%   better for all returned score families.  Candidates in the same
%   equivalence group are excluded from the competitor calculation.
    d=double(distances); ids=stage4a7_1_cellstr(candidate_ids); n=size(d,1); m=size(d,2);
    if numel(ids)~=m,error('stage4a7_2:ScoreDimension','Candidate IDs do not match distance columns.');end
    groups=stage4a7_1_cellstr(equivalence_group);if numel(groups)~=m,groups=repmat({'__unique__'},1,m);end
    if nargin<4||isempty(scales),scales=ones(1,m);end;scales=double(scales(:).');if numel(scales)~=m,error('stage4a7_2:ScaleDimension','Scale count does not match candidates.');end
    eps0=1e-15; competitor=Inf(n,m);
    for i=1:n
        for j=1:m
            mask=true(1,m); mask(j)=false; mask(strcmp(groups,groups{j}))=false;
            z=d(i,mask); if ~isempty(z),competitor(i,j)=min(z);end
        end
    end
    family=struct('candidate_ids',{ids},'absolute',d,'scaled',d./max(scales,eps0), ...
        'competitor',competitor,'ratio',d./max(competitor,eps0),'margin',d-competitor, ...
        'scales',scales,'equivalence_group',{groups},'definition_version','stage4a7_2_nonconformity_family_v1');
end
