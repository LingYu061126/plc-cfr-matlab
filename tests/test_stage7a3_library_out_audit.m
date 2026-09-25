function test_stage7a3_library_out_audit()
%TEST_STAGE7A3_LIBRARY_OUT_AUDIT Unit tests for the isolated Stage 7A.3 gate.
    addpath('src','config');
    cache=struct('frequency_hz',1:9,'candidate_ids',{{'A','B'}}, ...
        'H',{{[zeros(1,9);ones(1,9)],[3*ones(1,9)]}});
    profile=struct('profile_distances',[1 1],'best_template_indices',[1 1]);
    y=complex(zeros(1,9));out=stage7a3_band_residual(y,cache,profile);
    assert(out.best_index==1&&strcmp(out.best_candidate,'A'), ...
        'Tied candidate distances must resolve by stable candidate order.');
    assert(isequal(out.band_edges,[1 3 6 8 10]),'Unexpected four-band boundaries.');
    assert(all(out.band_relative_residual==0), ...
        'Zero observation should use eps denominator and return zero for an exact zero fit.');

    y=ones(1,9);
    profile_ones=struct('profile_distances',[0 1],'best_template_indices',[2 1]);
    out=stage7a3_band_residual(y,cache,profile_ones);
    assert(isequal(out.band_relative_residual,[0 0 0 0]), ...
        'The best constant template should exactly fit the constant observation.');

    gate=stage7a3_calibrate_residual_gate((1:20).',0.10,'unit-test-identity');
    assert(gate.order_statistic_rank==19&&gate.threshold==19, ...
        'Split calibration must use ceil((n+1)*(1-alpha)) order statistic.');
    assert(strcmp(gate.statistic,'max_four_band_normalized_complex_residual'));
    multi=struct('decision_state','MULTIPLE_AMBIGUOUS','decision_reason','test', ...
        'candidate_set_size',2,'candidate_set','A,B');
    kept=stage7a3_apply_residual_gate(multi,18,gate);
    rejected=stage7a3_apply_residual_gate(multi,20,gate);
    assert(strcmp(kept.decision_state,'MULTIPLE_AMBIGUOUS')&& ...
        strcmp(rejected.decision_state,'REJECTED')&&rejected.candidate_set_size==2&& ...
        strcmp(rejected.candidate_set,'A,B'), ...
        'The one-way gate may reject but must preserve a non-singleton candidate set.');
    low=struct('decision_state','LOW_CONFIDENCE','decision_reason','test', ...
        'candidate_set_size',1,'candidate_set','A');
    low_after=stage7a3_apply_residual_gate(low,18,gate);
    assert(strcmp(low_after.decision_state,'LOW_CONFIDENCE'));

    base=default_config(pwd);cfg=stage7a3_library_out_config(base,'smoke');
    patterns=cfg.library_out_patterns;
    historical=[0 0 1;0 0 2;0 0 3];
    assert(~any(ismember(patterns,historical,'rows')), ...
        'Final holdout pattern list must differ from Stage 7A.2 historical patterns.');
    for q=1:3
        grammar=cfg.legacy.stage7a.stage6b.scale.grammars(q);
        lib=generate_radial_topology_candidates(grammar);
        grammar.allowed_branch_main_nodes=[1 2 3];grammar.max_side_branches_per_node=3;
        grammar.max_branches=5;grammar.max_nodes=10;grammar.max_candidates=128;
        all_candidates=generate_radial_topology_candidates(grammar);
        known=arrayfun(@(z)stage6b_network_signature(z.network),lib,'UniformOutput',false);
        signatures=arrayfun(@(z)stage6b_network_signature(z.network),all_candidates,'UniformOutput',false);
        for k=1:size(patterns,1)
            ix=find(arrayfun(@(z)isequal(count_pattern(z.network),patterns(k,:)),all_candidates),1);
            assert(~isempty(ix)&&~ismember(signatures{ix},known), ...
                'A pre-registered final topology is missing or is in the candidate library.');
        end
    end
end

function p=count_pattern(net)
    p=zeros(1,3);
    for k=1:numel(net.branches),p(net.branches(k).node)=p(net.branches(k).node)+1;end
end
