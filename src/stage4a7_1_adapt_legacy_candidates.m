function adapted = stage4a7_1_adapt_legacy_candidates(legacy)
%STAGE4A7_1_ADAPT_LEGACY_CANDIDATES Add Stage-4A.7.1 layer metadata.
%   The underlying legacy candidate structs and their order are untouched.
%   This adapter is the compatibility boundary for the historical seven
%   restricted-grammar candidates.
    adapted=legacy;
    for k=1:numel(adapted)
        if isfield(adapted,'id'),id=adapted(k).id;else,id=adapted(k).topology_id;end
        adapted(k).graph_candidate_id=id;
        if isfield(adapted,'canonical_key'),adapted(k).canonical_graph_key=adapted(k).canonical_key;else,adapted(k).canonical_graph_key=['legacy_' id];end
        adapted(k).generation_route='legacy_restricted_grammar';
        adapted(k).generation_trace=struct('legacy_adapter_version','stage4a7_1_legacy_adapter_v1','source','generate_radial_topology_candidates');
        adapted(k).satisfied_constraints={'radial','connected','legacy_restricted_grammar'};
        adapted(k).prior_cost=0;adapted(k).prior_source='synthetic_demo_prior_not_field_data';adapted(k).prior_config_hash='legacy_stage4a1';
        adapted(k).forward_model_compatible=NaN;adapted(k).compatibility_reason='not_checked';adapted(k).adapter_hash='';adapted(k).scored_library_included=false;
    end
end
