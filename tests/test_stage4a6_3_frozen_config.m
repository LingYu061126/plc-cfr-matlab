function test_stage4a6_3_frozen_config()
%TEST_STAGE4A6_3_FROZEN_CONFIG A-only and serial defaults are explicit.
    root=fileparts(fileparts(mfilename('fullpath')));cfg=default_config(root);
    sc=stage4a6_3_parameter_domain_config(cfg,'pilot');
    assert(numel(sc.grids)==1);assert(strcmp(sc.grids(1).id,'A_stage4a1_quick61'));
    assert(~sc.execution.use_parallel && sc.execution.num_workers==1);
    assert(strcmp(sc.profile.grid_strategy,'fixed_grid_with_midpoints'));
    assert(~sc.profile.use_adaptive_refinement);
end
