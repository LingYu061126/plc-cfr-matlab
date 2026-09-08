function [calibration, pilot, final_reserved] = generate_stage4a7_1_scenarios(sc, candidates)
%GENERATE_STAGE4A7_1_SCENARIOS Independent model-internal Stage-4A.7.1 data.
%   Calibration and Pilot contain physical network/parameter truth solely
%   for forward simulation and later offline scoring.  Decision functions
%   receive only generated CFR observations.  final_reserved contains seed
%   identity only and is deliberately not materialized in this stage.

    a5 = sc.stage4a5_1_config;
    a5.development_seeds = sc.seeds.calibration;
    a5.development.training_continuous_per_graph = 0;
    a5.development.training_grid_per_graph = 0;
    a5.development.calibration_continuous_per_graph = sc.scenario_design.calibration_count_per_candidate;
    a5.development.calibration_grid_per_graph = 0;
    a5.development.validation_continuous_per_graph = 0;
    a5.development.validation_grid_per_graph = 0;
    a5.development.structure_validation_count = 0;
    a5.development.parameter_validation_count = 0;
    raw_cal = generate_stage4a5_1_trial_bank(a5,'development');
    raw_cal = raw_cal(strcmp({raw_cal.split},'development_calibration'));
    calibration = normalize_rows(raw_cal,'calibration','cal',candidates,sc);

    a5.final_seeds = sc.seeds.pilot;
    a5.final.calibration_continuous_per_graph = 0;
    a5.final.calibration_grid_per_graph = 0;
    a5.final.test_continuous_per_graph = sc.scenario_design.pilot_continuous_per_candidate;
    a5.final.test_grid_per_graph = sc.scenario_design.pilot_nominal_per_candidate;
    a5.final.structure_test_count = sc.scenario_design.structure_out_count;
    a5.final.parameter_test_count = sc.scenario_design.parameter_out_count;
    raw_pilot = generate_stage4a5_1_trial_bank(a5,'final');
    raw_pilot = raw_pilot(strcmp({raw_pilot.split},'final_replication_test'));
    pilot = normalize_rows(raw_pilot,'pilot','pilot',candidates,sc);
    if isfield(sc.scenario_design,'require_active_outlier_dimension') && sc.scenario_design.require_active_outlier_dimension
        pilot = remove_inactive_parameter_outliers(pilot,candidates);
    end
    pilot = apply_parameter_severity(pilot,sc.parameter_search);

    final_reserved = struct('split','final_reserved','master_seed',sc.seeds.final_reserved, ...
        'status','manifest_only_not_materialized','scenario_count',0, ...
        'identity_hash',stage4a4_scientific_config_hash(struct('stage',sc.stage_name, ...
        'split','final_reserved','seed',sc.seeds.final_reserved,'status','not_executed')));
    assert(isempty(intersect({calibration.sample_id},{pilot.sample_id})), ...
        'stage4a7_1:SplitSampleOverlap','Calibration and Pilot sample IDs overlap.');
    assert(sc.seeds.calibration~=sc.seeds.pilot && sc.seeds.calibration~=sc.seeds.final_reserved && ...
        sc.seeds.pilot~=sc.seeds.final_reserved,'stage4a7_1:SplitSeedOverlap','Split seeds must be distinct.');
end

function rows=remove_inactive_parameter_outliers(rows,candidates)
    keep=true(size(rows));
    for k=1:numel(rows)
        if ~strcmp(rows(k).category,'parameter_out') || ...
                ~ismember(rows(k).outlier_dimension,{'branch_length_scale','branch_load_scale'})
            continue;
        end
        j=find(strcmp({candidates.topology_id},rows(k).truth_topology_id),1);
        if isempty(j) || ~topology_active_parameter_mask(candidates(j),{rows(k).outlier_dimension})
            keep(k)=false;
        end
    end
    rows=rows(keep);
end

function rows = normalize_rows(raw,split,prefix,candidates,sc)
    empty = row_template(); rows = repmat(empty,numel(raw),1);
    for k=1:numel(raw)
        r=empty; r.sample_id=sprintf('stage4a7_1_%s_%04d',prefix,k); r.split=split;
        r.replicate_id=sprintf('%s_%04d',prefix,k); r.category=raw(k).category;
        r.truth_topology_id=raw(k).truth_topology_id; r.canonical_key=raw(k).canonical_key;
        r.truth_network=raw(k).truth_network; r.truth_theta=raw(k).truth_theta;
        r.outlier_dimension=raw(k).outlier_dimension; r.outlier_direction=raw(k).outlier_direction;
        r.severity='not_applicable'; r.master_seed=split_seed(sc,split);
        r.case_seed=stable_case_seed(r.master_seed,r.sample_id);
        r.truth_candidate_index=find(strcmp({candidates.topology_id},r.truth_topology_id),1);
        if isempty(r.truth_candidate_index),r.truth_candidate_index=0;end
        r.parameter_domain_truth=ternary(strcmp(r.category,'parameter_out'),'out_of_domain','in_domain');
        if strcmp(r.category,'structure_out'),r.parameter_domain_truth='not_evaluable';end
        r.physical_scenario_id=sprintf('%s_%s',split,r.sample_id);
        r.parameter_vector_hash=theta_hash(r.truth_theta);
        rows(k)=r;
    end
end

function rows = apply_parameter_severity(rows,search)
    ix=find(strcmp({rows.category},'parameter_out'));
    levels={'near','medium','far'};
    for q=1:numel(ix)
        k=ix(q);level=levels{1+mod(q-1,3)};rows(k).severity=level;
        rows(k).truth_theta=set_outlier(rows(k).truth_theta,search,rows(k).outlier_dimension,rows(k).outlier_direction,level,q);
        rows(k).parameter_vector_hash=theta_hash(rows(k).truth_theta);
    end
    nom=find(strcmp({rows.category},'in_library_grid'));
    for q=1:numel(nom),rows(nom(q)).category='symmetry_preserving_nominal';end
    cont=find(strcmp({rows.category},'in_library_continuous'));
    for q=1:numel(cont),rows(cont(q)).category='in_domain_interior';end
end

function t=set_outlier(t,s,name,direction,level,index)
    frac=struct('near',0.08,'medium',0.30,'far',0.75);f=frac.(level);
    names={'main_length_scale','branch_length_scale','branch_load_scale','source_impedance_ohm','receiver_impedance_ohm'};
    if strcmp(name,'joint_parameter_set')
        for j=1:numel(names)
            % Keep severity bands disjoint while making each replicate a
            % distinct physical parameter vector.  The deterministic
            % jitter depends only on case index and parameter position.
            u=mod(index*37+j*17,997)/996;
            fj=f*(0.90+0.20*u);
            t=set_one(t,s,names{j},ternary(mod(j+index,2)==0,'above_max','below_min'),fj);
        end
    else
        t=set_one(t,s,name,direction,f);
    end
    t.regularization=NaN;t.outlier_dimension=name;t.outlier_direction=direction;
end

function t=set_one(t,s,name,direction,f)
    lo=min(s.(name));hi=max(s.(name));span=max(hi-lo,max(abs([lo hi]))*0.05);
    if contains(direction,'below'),t.(name)=lo-f*span;else,t.(name)=hi+f*span;end
end

function seed=split_seed(sc,split),if strcmp(split,'calibration'),seed=sc.seeds.calibration;else,seed=sc.seeds.pilot;end,end
function seed=stable_case_seed(master,id),seed=master+mod(sum(double(id).*(1:numel(id))),1000003);end
function h=theta_hash(t)
    names={'main_length_scale','branch_length_scale','branch_load_scale','source_impedance_ohm','receiver_impedance_ohm'};
    x=zeros(1,numel(names));for j=1:numel(names),x(j)=t.(names{j});end
    h=stage4a4_scientific_config_hash(struct('parameter_names',{names},'values',x));
end
function r=row_template()
    r=struct('sample_id','','physical_scenario_id','','split','','replicate_id','','category','', ...
        'truth_topology_id','','canonical_key','','truth_candidate_index',0,'truth_network',struct(), ...
        'truth_theta',struct(),'parameter_domain_truth','','outlier_dimension','','outlier_direction','', ...
        'severity','','master_seed',0,'case_seed',0,'parameter_vector_hash','', ...
        'noiseless_cfr_hash','','observation_hash','','truth_equivalence_set','', ...
        'truth_equivalence_member_count',0,'truth_unique_under_observation',false,'equivalence_evaluable',false);
end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
