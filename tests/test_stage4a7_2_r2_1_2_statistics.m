function test_stage4a7_2_r2_1_2_statistics()
%TEST_STAGE4A7_2_R2_1_2_STATISTICS Cluster bootstrap and directional gate.
    a=struct('hit',[1;1;1;1;1;1;1;1],'accepted',true(8,1),'set_size',ones(8,1));
    b=struct('hit',[0;0;0;0;1;1;1;1],'accepted',true(8,1),'set_size',2*ones(8,1));
    clusters={'G1';'G1';'G2';'G2';'G3';'G3';'G4';'G4'};
    z=stage4a7_2_r2_1_2_cluster_bootstrap(a,b,clusters,struct('replicates',200,'seed',7,'alpha',.05,'multiplicity_count',2));
    assert(z.cluster_count==4&&strcmp(z.resampling_unit,'candidate_id_cluster'),'Cluster bootstrap unit was not candidate_id.');
    assert(z.coverage_difference>0&&z.mean_set_size_difference<0,'Bootstrap direction is wrong.');
    assert(z.effective_resample_count==200&&z.alpha_adjusted==.025,'Bootstrap multiplicity metadata is wrong.');
    c=struct('method_a',{'margin','margin'},'method_b',{'ratio','scaled'}, ...
        'selected_directional_superiority',{true,false});
    [win,why]=stage4a7_2_r2_1_2_assess_directional_winner('margin',c,{'margin','ratio','scaled'});
    assert(~win&&contains(why,'scaled'),'A win against only one eligible competitor must not be scientific uniqueness.');
    c(2).selected_directional_superiority=true;
    [win,why]=stage4a7_2_r2_1_2_assess_directional_winner('margin',c,{'margin','ratio','scaled'});
    assert(win&&strcmp(why,'all_eligible_competitors_directionally_separated'),'All-competitor directional support was not recognized.');
    [win,why]=stage4a7_2_r2_1_2_assess_directional_winner('margin',c(1),{'margin','ratio','scaled'});
    assert(~win&&contains(why,'missing_comparison'),'Missing comparisons must block scientific uniqueness.');
    model=stage4a7_3_calibrate_domain_model((1:40)', 'profile_min_distance',struct('minimum_count',20,'quantile',.95,'near_boundary_quantile',.80));
    lo=stage4a7_3_apply_domain_model(1,model);mid=stage4a7_3_apply_domain_model(model.near_boundary_threshold+.01,model);hi=stage4a7_3_apply_domain_model(model.threshold+.01,model);
    assert(strcmp(lo.parameter_domain_status,'in_parameter_domain')&&strcmp(mid.parameter_domain_status,'near_parameter_boundary')&&strcmp(hi.parameter_domain_status,'out_of_parameter_domain'),'Domain status thresholds are not ordered.');
    assert_throws(@()stage4a7_3_calibrate_domain_model(1:5,'x',struct('minimum_count',20)), 'stage4a7_3:InsufficientCalibration');
    fprintf('  PASS Stage 4A.7.2-R.2.1.2 cluster bootstrap and frozen domain threshold semantics\n');
end
function assert_throws(f,id)
    ok=false;try,f();catch e,ok=strcmp(e.identifier,id);end;assert(ok,'Expected error %s.',id);
end
