function test_stage2_3()
%TEST_STAGE2_3 Equivalence-class and fair-comparison regression checks.
    fprintf('Running stage-2.3 observability/equivalence tests...\n');
    root=fileparts(fileparts(mfilename('fullpath')));cfg=default_config(root);
    cfg.frequency_hz=linspace(2e6,30e6,61); f=cfg.frequency_hz;
    all_candidates=topology_candidates(cfg);
    candidates=all_candidates(cfg.stage2_3.candidate_indices);
    nominal=struct('source_impedance_ohm',50,'receiver_impedance_ohm',50);
    refs=make_references('siso_forward',candidates,nominal,cfg,f);
    symmetric=topology_observability_classes(refs,candidates,cfg.ofdm, ...
        cfg.stage2_3.tie_tolerance);
    t3=find(strcmp({candidates.id},'T3'));t5=find(strcmp({candidates.id},'T5'));
    assert(symmetric.pairwise_complex_distance(t3,t5)<=cfg.stage2_3.tie_tolerance && ...
        symmetric.class_index(t3)==symmetric.class_index(t5) && ...
        symmetric.structural_indistinguishable_group_count==1, ...
        'Symmetric SISO did not record T3/T5 as a physical equivalence class.');
    exact=cell(1,numel(candidates));
    for k=1:numel(candidates)
        exact{k}=topology_equivalence_match(refs{k},refs,candidates,symmetric, ...
            'complex',cfg.ofdm,[.5,.5]);
    end
    ideal=topology_equivalence_evaluation(1:numel(candidates),exact,candidates,symmetric);
    % Exact self-reference happens to retain the source index, but strict
    % accuracy remains a tie-break statistic; unique strict is 2/4.
    assert(abs(ideal.strict_topology_accuracy-1)<eps && ...
        abs(ideal.equivalence_class_accuracy-1)<eps && ...
        abs(ideal.unique_strict_accuracy-0.5)<eps && ...
        abs(ideal.ambiguity_rate-0.5)<eps && ideal.false_unique_rate==0, ...
        'Exact symmetric-SISO evaluation mixed strict ties and equivalence classes.');
    assert(~exact{t3}.unique_identification && ...
        strcmp(exact{t3}.equivalence_class,'{T3,T5}'), ...
        'T3/T5 exact tie was incorrectly presented as unique.');
    fprintf('  PASS symmetric T3/T5 class, strict/group/unique metrics and tie output\n');

    asym=struct('source_impedance_ohm',50,'receiver_impedance_ohm',75);
    asym_refs=make_references('siso_forward_asymmetric',candidates,asym,cfg,f);
    asymmetric=topology_observability_classes(asym_refs,candidates,cfg.ofdm, ...
        cfg.stage2_3.tie_tolerance);
    assert(asymmetric.pairwise_complex_distance(t3,t5)>1e-6 && ...
        asymmetric.class_index(t3)~=asymmetric.class_index(t5), ...
        'Asymmetric complete-network SISO did not break the nominal T3/T5 class.');
    fprintf('  PASS configuration-specific class audit distinguishes asymmetric endpoint SISO\n');

    forced=exact;forced{t3}.ambiguous=false;forced{t5}.ambiguous=false;
    forced_metrics=topology_equivalence_evaluation(1:numel(candidates),forced,candidates,symmetric);
    assert(abs(forced_metrics.false_unique_rate-0.5)<eps, ...
        'False-unique rate did not flag a forced singleton output in a tied class.');
    fprintf('  PASS numerical tie and physical false-unique statistics are separate\n');

    feature='amp_phase_joint_weighted';
    nominal_match=topology_equivalence_match(refs{1},refs,candidates,symmetric, ...
        feature,cfg.ofdm,[.5,.5]);
    grid=topology_parameter_grid(cfg.stage2_3.search);
    zero_grid=grid([grid.regularization]==0);
    library=topology_prepare_parameter_library(topology_parameter_library(f,candidates, ...
        zero_grid,'siso_forward',cfg));
    joint=topology_joint_match(refs{1},library,feature,cfg.ofdm,[.5,.5], ...
        cfg.stage2_3.regularization_lambda,struct('phase_mask_threshold_db',-40));
    assert(strcmp(nominal_match.selected_feature,feature) && ...
        strcmp(joint.feature,feature) && joint.predicted_index==1, ...
        'Nominal and joint matchers cannot be compared on the same feature.');
    fprintf('  PASS fair nominal/joint interface uses an identical declared feature\n');
    fprintf('ALL STAGE-2.3 TESTS PASSED\n');
end

function refs=make_references(kind,candidates,theta,cfg,f)
    refs=cell(1,numel(candidates));
    for k=1:numel(candidates)
        m=plc_measurement_bundle(kind,candidates(k).network,theta,cfg);
        refs{k}=plc_multiview_response(f,candidates(k).network,m,cfg);
    end
end
