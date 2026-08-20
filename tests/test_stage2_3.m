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
    raw=topology_feature_distance(2*refs{1}{1},refs{1}{1},'complex_raw',cfg.ofdm,[.5,.5]);
    normalized=topology_feature_distance(2*refs{1}{1},refs{1}{1},'complex',cfg.ofdm,[.5,.5]);
    assert(raw>0 && normalized<1e-12,'Raw and normalized complex CFR distances are not distinct.');
    fields={'name','value'};empty=struct('name',{},'value',{});single=struct('name','x','value',1);
    assert(height(stage2_3_struct_table(empty,fields))==0 && height(stage2_3_struct_table(single,fields))==1 && ...
        height(stage2_3_struct_table([single,single],fields))==2 && height(stage2_3_struct_table([single;single],fields))==2, ...
        'Stage-2.3 result struct conversion is not shape safe.');
    pair_fields={'measurement_kind','topology_i','topology_j'};
    ordered=stage2_3_struct_table(single,{'value','name'});
    assert(isequal(ordered.Properties.VariableNames,{'value','name'}) && ...
        width(stage2_3_struct_table(struct([]),pair_fields))==3 && ...
        height(stage2_3_struct_table(struct([]),pair_fields))==0, ...
        'An empty pairwise result does not preserve its CSV header schema.');
    missing_rejected=false;try,stage2_3_struct_table(single,{'missing_field'});catch ME,missing_rejected=strcmp(ME.identifier,'stage2_3_struct_table:MissingField');end
    assert(missing_rejected,'Missing requested result field was not rejected.');
    total_pairs=0;kinds=cfg.stage2_3.measurement_kinds;
    for q=1:numel(kinds),t=nominal;if ~ismember(kinds{q},{'siso_forward','dual_receiver_complete','three_view_complete'}),t.receiver_impedance_ohm=75;end;r=make_references(kinds{q},candidates,t,cfg,f);a=topology_observability_classes(r,candidates,cfg.ofdm,cfg.stage2_3.tie_tolerance);total_pairs=total_pairs+nnz(triu(ones(numel(candidates)),1));assert(numel(a.pairwise_complex_distance)==16 && isfield(a,'pairwise_complex_distance_raw') && all(isfinite(a.pairwise_complex_distance_raw(:))));end
    assert(total_pairs==42,'Seven measurement kinds must contribute 42 topology pairs.');
    fprintf('  PASS safe result tables, raw/normalized complex distance and 42-pair audit\n');

    isolated=tempname;mkdir(isolated);cleaner=onCleanup(@()rmdir(isolated,'s'));
    for q=1:numel(kinds)
        kind=kinds{q};mode='smoke';sc=struct('measurement_kinds',{{kind}});config=struct('measurement_kind',kind);save(fullfile(isolated,sprintf('stage2_3_smoke_partial_%s_b1_results.mat',kind)),'mode','sc','config','-v7');
        for b=1:2
            mode='formal';sc=struct('measurement_kinds',{{kind}});config=struct('measurement_kind',kind);save(fullfile(isolated,sprintf('stage2_3_formal_partial_%s_b%d_results.mat',kind,b)),'mode','sc','config','-v7');
        end
    end
    [smoke_files,smoke_expected]=stage2_3_partial_files(isolated,kinds,'smoke');
    [formal_files,formal_expected]=stage2_3_partial_files(isolated,kinds,'formal');
    assert(numel(smoke_files)==7 && smoke_expected==7 && numel(formal_files)==14 && formal_expected==14, ...
        'Smoke/formal batch discovery is not mode-isolated.');
    stage2_3_validate_partial_mode(struct('mode','smoke'),'smoke','test batch');
    rejected=false;try,stage2_3_validate_partial_mode(struct('mode','formal'),'smoke','test batch');catch ME,rejected=strcmp(ME.identifier,'stage2_3_validate_partial_mode:ModeMismatch');end
    assert(rejected,'A renamed formal batch was accepted by smoke-mode validation.');
    fprintf('  PASS smoke/formal partial-file discovery is mode isolated\n');
    fprintf('ALL STAGE-2.3 TESTS PASSED\n');
end

function refs=make_references(kind,candidates,theta,cfg,f)
    refs=cell(1,numel(candidates));
    for k=1:numel(candidates)
        m=plc_measurement_bundle(kind,candidates(k).network,theta,cfg);
        refs{k}=plc_multiview_response(f,candidates(k).network,m,cfg);
    end
end
