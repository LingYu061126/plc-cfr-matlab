function [flat, relative_dynamic_range, absolute_dynamic_range] = stage4a6_2_flatness_rule(distances, relative_threshold, absolute_threshold)
%STAGE4A6_2_FLATNESS_RULE Apply independent relative and absolute gates.
    x=distances(isfinite(distances));
    if isempty(x),flat=false;relative_dynamic_range=NaN;absolute_dynamic_range=NaN;return;end
    absolute_dynamic_range=max(x)-min(x);
    relative_dynamic_range=absolute_dynamic_range/max(abs(min(x)),1e-12);
    flat=relative_dynamic_range<=relative_threshold && absolute_dynamic_range<=absolute_threshold;
end
