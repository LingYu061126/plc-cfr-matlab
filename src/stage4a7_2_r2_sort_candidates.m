function candidates = stage4a7_2_r2_sort_candidates(candidates,tolerance)
%STAGE4A7_2_R2_SORT_CANDIDATES Stable deterministic candidate ordering.
    if nargin<2 || isempty(tolerance), tolerance=1e-12; end
    for i=2:numel(candidates)
        x=candidates(i); j=i-1;
        while j>=1 && stage4a7_2_r2_compare_candidate(x,candidates(j),tolerance)<0
            candidates(j+1)=candidates(j); j=j-1;
        end
        candidates(j+1)=x;
    end
end
