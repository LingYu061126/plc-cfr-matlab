function result = test_stage4a6_3_1_r2_equivalence_parallel(root)
%TEST_STAGE4A6_3_1_R2_EQUIVALENCE_PARALLEL Metric, identity and seed tests.
    if nargin < 1 || isempty(root), root=fileparts(fileparts(mfilename('fullpath'))); end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    cfg=default_config(root);
    s1=stage4a6_3_1_r2_protocol_config(cfg,'pilot',false,1);
    s4=stage4a6_3_1_r2_protocol_config(cfg,'pilot',true,4);
    assert(strcmp(s1.parallel_execution_version,s4.parallel_execution_version));
    assert(s1.seeds.calibration~=s1.seeds.pilot);
    assert(s1.seeds.pilot~=s1.seeds.final_reserved);
    assert(stage4a6_3_1_r2_seed(s1,'calibration','x') == ...
        stage4a6_3_1_r2_seed(s1,'calibration','x'));
    assert(stage4a6_3_1_r2_seed(s1,'calibration','x') ~= ...
        stage4a6_3_1_r2_seed(s1,'pilot','x'));
    assert(stage4a6_3_1_r2_seed(s1,'pilot','x') == ...
        stage4a6_3_1_r2_seed(s4,'pilot','x'));

    % A parameter-OOD but scenario-unique sample is not false-unique.
    labels=label('u','out_of_domain','G001','G001',1,true);
    decisions=decision('u','unique_topology','G001','parameter_out_suspected');
    m=stage4a6_3_1_r2_evaluate_metrics(decisions,labels);
    assert(m.false_unique_numerator==0);
    assert(m.false_unique_unconditional_denominator==1);
    assert(isnan(m.false_unique_conditional_rate));

    % One true nonunique scenario plus one unique scenario: the same
    % numerator has different unconditional and conditional denominators.
    labels(2)=label('n','in_domain','G002','G002,G005',2,false);
    decisions(2)=decision('n','unique_topology','G002','parameter_in_domain');
    labels(2).same_theta_equivalence_set='G002,G005';
    labels(2).same_theta_equivalence_member_count=2;
    labels(2).same_theta_equivalence_evaluable=true;
    m=stage4a6_3_1_r2_evaluate_metrics(decisions,labels);
    assert(m.false_unique_numerator==1);
    assert(m.false_unique_unconditional_denominator==2);
    assert(m.false_unique_conditional_denominator==1);
    assert(m.false_unique_unconditional_rate==0.5);
    assert(m.false_unique_conditional_rate==1);

    % No reliable equivalence labels means the rate is not evaluable.
    z=label('z','in_domain','G001','',NaN,NaN);
    z.same_theta_equivalence_set='';z.same_theta_equivalence_member_count=NaN;
    z.same_theta_equivalence_evaluable=false;
    mz=stage4a6_3_1_r2_evaluate_metrics(decision('z','unique_topology','G001','parameter_in_domain'),z);
    assert(isnan(mz.false_unique_unconditional_rate));
    assert(isnan(mz.false_unique_conditional_rate));

    assert(isfield(s1.execution,'use_parallel'));
    fprintf('PASS R.2 metric denominators, split seeds and parallel config\n');
    fprintf('ALL STAGE 4A.6.3.1-R.2 TARGETED TESTS PASSED\n');
    result=struct('name','test_stage4a6_3_1_r2_equivalence_parallel','status','passed');
end

function seed=stage4a6_3_1_r2_seed(sc,split,id)
    seed=double(sc.seeds.(split));v=double(char([split '_' id]));
    seed=max(1,round(mod(seed+sum(v.*(1:numel(v))),2^31-1)));
end
function r=label(id,truth_type,truth,eq,n,unique_flag)
    r=struct('sample_id',id,'category','test','truth_topology_id',truth, ...
        'truth_equivalence_set',eq,'truth_equivalence_member_count',n, ...
        'truth_unique_under_observation',unique_flag,'same_theta_equivalence_set',eq, ...
        'same_theta_equivalence_member_count',n,'same_theta_equivalence_evaluable',isfinite(n), ...
        'equivalence_audit_hash','eq','equivalence_configuration_hash','eq', ...
        'parameter_domain_truth',truth_type,'physical_scenario_id',['p_' id], ...
        'parameter_vector_hash',['p_' id],'noiseless_cfr_hash',['c_' id], ...
        'observation_hash',['c_' id]);
end
function r=decision(id,status,set,pstatus)
    r=struct('sample_id',id,'method_id','m','decision',status, ...
        'topology_status',status,'topology_set',set,'accepted_topology_set',set, ...
        'parameter_domain_status',pstatus);
end
