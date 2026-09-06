function test_stage4a6_1_active_mask()
%TEST_STAGE4A6_1_ACTIVE_MASK Inactive branch parameters are excluded.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));cfg=default_config(root);sc=stage4a6_1_optimizer_config(cfg,'smoke');g=generate_radial_topology_candidates(sc.generator);names=stage4a6_1_parameter_names();m0=topology_active_parameter_mask(g(1),names);m1=topology_active_parameter_mask(g(end),names);assert(sum(m0)==3,'No-branch topology must have three active parameters.');assert(sum(m1)==5,'Branched topology must have five active parameters.');assert(~m0(2)&&~m0(3),'Inactive branch parameters were not masked.');fprintf('ALL STAGE 4A.6.1 ACTIVE MASK TESTS PASSED\n');
end
