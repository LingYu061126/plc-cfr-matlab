function [tf,reason] = stage4a7_2_r2_1_2_assess_directional_winner(selected, comparisons, eligible_methods)
%STAGE4A7_2_R2_1_2_ASSESS_DIRECTIONAL_WINNER Check every competitor.
%   A deterministic ordering is not a scientific unique winner unless the
%   selected method has predeclared directional bootstrap support against
%   every eligible competitor.  Missing comparisons, CI overlap, ties and
%   an empty eligible set are all non-supporting outcomes.
    tf=false;reason='no_eligible_competitor_comparison';
    if isempty(selected)||strcmp(selected,'no_method_meets_gate')
        reason='no_selected_method';return;
    end
    eligible_methods=cellstr(eligible_methods(:));
    competitors=setdiff(eligible_methods,{selected},'stable');
    if isempty(competitors),reason='no_competitor';return;end
    for k=1:numel(competitors)
        ix=find((strcmp({comparisons.method_a},selected)&strcmp({comparisons.method_b},competitors{k})) | ...
            (strcmp({comparisons.method_b},selected)&strcmp({comparisons.method_a},competitors{k})),1);
        if isempty(ix),reason=['missing_comparison:' competitors{k}];return;end
        if ~isfield(comparisons,'selected_directional_superiority') || ~comparisons(ix).selected_directional_superiority
            reason=['insufficient_directional_evidence:' competitors{k}];return;
        end
    end
    tf=true;reason='all_eligible_competitors_directionally_separated';
end
