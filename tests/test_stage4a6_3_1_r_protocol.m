function result=test_stage4a6_3_1_r_protocol(root)
%TEST_STAGE4A6_3_1_R_PROTOCOL Protocol and truth-isolation checks.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    cfg=default_config(root);sc=stage4a6_3_1_r_protocol_config(cfg,'pilot');c=generate_radial_topology_candidates(sc.generator);
    assert(strcmp(sc.grid_id,'A_stage4a1_quick61'));assert(sc.seeds.calibration~=sc.seeds.pilot);assert(sc.seeds.pilot~=sc.seeds.final_reserved);
    a=stage4a6_3_1_r_generate_independent_scenarios(sc,'pilot',c);b=stage4a6_3_1_r_generate_independent_scenarios(sc,'pilot',c);
    assert(isequal({a.sample_id},{b.sample_id}));assert(isequaln({a.truth_theta},{b.truth_theta}));
    assert(numel(unique({a.physical_scenario_id}))==numel(a));
    assert(isempty(strfind(fileread(fullfile(root,'experiments','exp_stage4a6_3_1_r_independent_pilot.m')),'match_nominal')));
    assert(isempty(strfind(fileread(fullfile(root,'src','stage4a6_3_1_r_confirm_with_frozen_stage4a5_1.m')),'truth_topology_id')));
    r=struct('compatibility_hash','','source_tree_hash','','parameter_name','','status','');
    assert(isfield(r,'parameter_name'));
    result=struct('name','test_stage4a6_3_1_r_protocol','status','passed','sample_count',numel(a));
end
