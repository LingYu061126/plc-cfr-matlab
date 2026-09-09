function c = stage4a7_2_r2_compare_text(a,b)
%STAGE4A7_2_R2_COMPARE_TEXT Deterministic three-way lexical comparison.
%   Returns -1 when a<b, 0 when equal, and +1 when a>b.  MATLAB strcmp is
%   a predicate and is therefore deliberately not used as a three-way
%   comparator.
    a=char(a); b=char(b);
    if strcmp(a,b), c=0; return; end
    z=sort({a,b});
    if strcmp(z{1},a), c=-1; else, c=1; end
end
