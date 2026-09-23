function test_stage6a_candidate_generation()
%TEST_STAGE6A_CANDIDATE_GENERATION Partial-prior constraints and interfaces.
    root=fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    base=default_config(root);sc=stage6a_candidate_generation_config(base,'smoke');
    expected=[7 2 4];libraries=cell(1,3);
    for p=1:3
        [raw,ga]=generate_candidate_topologies(sc.partial_prior_cases(p));
        [valid,ca]=apply_topology_constraints(raw,sc.partial_prior_cases(p));
        [ranked,ra]=rank_candidate_complexity(valid,sc.rank);
        [library,ea]=export_candidate_library(ranked,base,sc.export);
        assert(numel(raw)==expected(p)&&numel(valid)==expected(p)&&numel(library)==expected(p), ...
            'Stage 6A case %d candidate count changed.',p);
        assert(ga.candidate_count==expected(p)&&ca.rejected_candidate_count==0&& ...
            ra.candidate_count==expected(p)&&ea.incompatible_candidate_count==0,'Stage 6A audit counts disagree.');
        assert(all([ranked.constraint_valid])&&all(diff([ranked.complexity_score])>=0), ...
            'Constraint validity or deterministic complexity order failed.');
        assert(all(isfield(library,{'topology_id','canonical_key','network'})), ...
            'Exported candidates do not satisfy the forward interface.');
        libraries{p}=library;
    end

    legacy=generate_radial_topology_candidates(sc.legacy_grammar);
    legacy_keys=sort(arrayfun(@(x)signature(x.network),legacy,'UniformOutput',false));
    broad_keys=sort(arrayfun(@(x)signature(x.network),libraries{1},'UniformOutput',false));
    assert(isequal(legacy_keys,broad_keys),'Broad Stage 6A prior does not reproduce the legacy seven-network set.');
    truth=legacy(arrayfun(@(x)isequal(sort([x.network.branches.node]),2),legacy));
    truth_key=signature(truth.network);
    assert(any(strcmp(arrayfun(@(x)signature(x.network),libraries{2},'UniformOutput',false),truth_key)), ...
        'Informative switch prior lost the controlled true topology.');
    assert(~any(strcmp(arrayfun(@(x)signature(x.network),libraries{3},'UniformOutput',false),truth_key)), ...
        'Stale open-switch prior should exclude the controlled true topology.');

    bad=sc.partial_prior_cases(1);
    for k=1:4,bad.allowed_edges(k).length_max_m=19;end
    [raw,~]=generate_candidate_topologies(bad);[valid,audit]=apply_topology_constraints(raw,bad);
    assert(isempty(valid)&&audit.rejected_candidate_count==7&&isfield(audit.rejection_reason_counts,'edge_length_range'), ...
        'Declared edge-length constraints were not enforced.');

    refs=topology_reference_cfr(sc.frequency_hz,libraries{2},base);
    assert(all(arrayfun(@(x)all(isfinite(x.reference_H)),refs)),'Exported Stage 6A network produced nonfinite CFR.');
    distances=[0.01 0.50];margin=compute_candidate_margin(distances,{libraries{2}.topology_id});
    confidence=compute_candidate_confidence(distances,10,{libraries{2}.topology_id});
    model=struct('margin_threshold',0.1,'top1_confidence_threshold',0.7,'normalized_entropy_threshold',0.5);
    frozen=struct('candidate_set_size',1,'domain_accepted',true,'best_candidate_in_set',true);
    decision=classify_stage5b1_decision_state(frozen,struct('margin',margin.margin), ...
        struct('top1_confidence',confidence.top1_confidence,'normalized_entropy',confidence.normalized_entropy),model);
    assert(strcmp(decision.enhanced_decision_state,'UNIQUE_CONFIDENT'),'Stage 5B.1 interface rejected a clear Stage 6A candidate case.');
    fprintf('  PASS Stage 6A partial-prior constraints, legacy equivalence, export and decision interfaces\n');
end

function key=signature(network)
    b=network.branches;
    if isempty(b)
        bt='none';
    else
        rows=zeros(numel(b),4);
        for k=1:numel(b),rows(k,:)=[b(k).node b(k).length b(k).cable_type real(b(k).load)];end
        rows=sortrows(rows);bt=sprintf('%.12g,%.12g,%.12g,%.12g;',rows.');
    end
    key=sprintf('M=%s|T=%s|B=%s',sprintf('%.12g,',network.main_lengths),sprintf('%.12g,',network.main_cable_type),bt);
end
