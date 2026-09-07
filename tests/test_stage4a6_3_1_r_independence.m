function result=test_stage4a6_3_1_r_independence(root)
%TEST_STAGE4A6_3_1_R_INDEPENDENCE Verify true parameter perturbations.
    if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
    addpath(fullfile(root,'src'),fullfile(root,'config'));cfg=default_config(root);sc=stage4a6_3_1_r_protocol_config(cfg,'pilot');c=generate_radial_topology_candidates(sc.generator);
    a=stage4a6_3_1_r_generate_independent_scenarios(sc,'pilot',c);
    assert(numel(unique({a.sample_id}))==numel(a));
    ix=find(strcmp({a.category},'in_domain_interior'));assert(numel(ix)>=2);
    assert(~isequal(a(ix(1)).truth_theta,a(ix(2)).truth_theta));
    % The physical hash is materialized by the same public function used by
    % the experiment, so the test checks the actual forward-model output.
    assert(all(cellfun(@(x)~isempty(x),{a.physical_scenario_id})));
    f=sc.grids(1).frequency_hz(:).';[a1,h1]=stage4a6_3_1_r_materialize_scenario(a(ix(1)),cfg,f);[a2,h2]=stage4a6_3_1_r_materialize_scenario(a(ix(2)),cfg,f);
    assert(~strcmp(a1.parameter_vector_hash,a2.parameter_vector_hash));assert(~strcmp(a1.noiseless_cfr_hash,a2.noiseless_cfr_hash));assert(~strcmp(hashes_to_text(h1),hashes_to_text(h2)));
    result=struct('name','test_stage4a6_3_1_r_independence','status','passed','sample_count',numel(a),'hashes_differ',true);
end
function s=hashes_to_text(v)
    s=stage4a4_scientific_config_hash(struct('real',{cellfun(@real,v,'UniformOutput',false)},'imag',{cellfun(@imag,v,'UniformOutput',false)}));
end
