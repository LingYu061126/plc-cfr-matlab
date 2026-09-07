function result=test_stage4a6_3_1_r_reproducibility(root)
%TEST_STAGE4A6_3_1_R_REPRODUCIBILITY Check portable identity and metrics.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));cfg=default_config(root);sc=stage4a6_3_1_r_protocol_config(cfg,'pilot');c=generate_radial_topology_candidates(sc.generator);tg=topology_parameter_grid(sc.parameter_search);
    cache=struct('cache_configuration_hash','cache','compatibility_hash','');sh='source';[h1,~,~]=stage4a6_3_1_r_build_compatibility_hash(sc,c,tg,sh,cache);sc2=sc;sc2.seeds.pilot=sc.seeds.pilot+1;[h2,~,~]=stage4a6_3_1_r_build_compatibility_hash(sc2,c,tg,sh,cache);assert(strcmp(h1,h2));
    sc3=sc;sc3.confirmation.K=sc.confirmation.K+1;[h3,~,~]=stage4a6_3_1_r_build_compatibility_hash(sc3,c,tg,sh,cache);assert(~strcmp(h1,h3));
    d=repmat(struct('sample_id','','method_id','m','topology_status','unique_topology','topology_set','G001','parameter_domain_status','parameter_not_evaluated'),2,1);d(1).sample_id='a';d(2).sample_id='b';l=repmat(struct('sample_id','','category','in_domain_interior','truth_topology_id','G001','parameter_domain_truth','in_domain','physical_scenario_id','same'),2,1);l(1).sample_id='a';l(2).sample_id='b';m=stage4a6_3_1_r_evaluate_metrics(d,l);assert(m.unique_physical_scenario_count==1);assert(m.effective_denominator==1);
    result=struct('name','test_stage4a6_3_1_r_reproducibility','status','passed','compatibility_hash',h1);
end
