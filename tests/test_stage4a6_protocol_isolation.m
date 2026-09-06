function test_stage4a6_protocol_isolation()
%TEST_STAGE4A6_PROTOCOL_ISOLATION Split and configuration invariants.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));cfg=default_config(root);sc=stage4a6_parameter_domain_config(cfg,'formal');b=generate_stage4a6_trial_bank(sc,'all');dev={b(startsWith({b.replicate_id},'dev')).sample_id};fin={b(startsWith({b.replicate_id},'final')).sample_id};assert(isempty(intersect(dev,fin)),'Development/final IDs overlap.');
    assert(numel(sc.development_seeds)>=2&&numel(sc.final_seeds)>=5,'Frozen seed counts are insufficient.');d=build_extended_parameter_domain(sc.parameter_search,1);assert(all(d.ext_lower<=d.in_lower)&all(d.ext_upper>=d.in_upper),'Extended domain does not contain in-domain bounds.');
    a=struct('root_dir','/machine/a','model',sc.parameter_search);c=struct('root_dir','/machine/b','model',sc.parameter_search);assert(strcmp(stage4a4_scientific_config_hash(a),stage4a4_scientific_config_hash(c)),'Scientific hash depends on runtime path.');
    fprintf('ALL STAGE 4A.6 PROTOCOL ISOLATION TESTS PASSED\n');
end
