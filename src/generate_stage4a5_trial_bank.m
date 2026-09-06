function bank = generate_stage4a5_trial_bank(sc, split_kind)
%GENERATE_STAGE4A5_TRIAL_BANK Generate independent development/final banks.
%   The returned truth fields are for offline scoring and forward-model
%   generation only.  They are never passed to a confirmation function.
    if nargin < 1 || isempty(sc), error('stage4a5:MissingConfig','sc is required.'); end
    if nargin < 2 || isempty(split_kind), split_kind = 'all'; end
    split_kind = lower(char(split_kind));
    base = generate_radial_topology_candidates(sc.generator);
    grid = topology_parameter_grid(sc.parameter_search);
    nominal = grid(find([grid.regularization] == 0,1));
    bank = empty_rows();
    if ismember(split_kind,{'all','development'})
        for k = 1:numel(sc.development_seeds)
            prefix = sprintf('dev%02d',k); seed = sc.development_seeds(k);
            bank = append_graph_split(bank,base,nominal,sc,prefix,'development_training',seed+11, ...
                sc.development.training_continuous_per_graph,sc.development.training_grid_per_graph);
            bank = append_graph_split(bank,base,nominal,sc,prefix,'development_calibration',seed+17, ...
                sc.development.calibration_continuous_per_graph,sc.development.calibration_grid_per_graph);
            bank = append_graph_split(bank,base,nominal,sc,prefix,'development_validation',seed+23, ...
                sc.development.validation_continuous_per_graph,sc.development.validation_grid_per_graph);
            bank = append_outliers(bank,base,sc,prefix,'development_validation',seed+29, ...
                sc.development.structure_validation_count,sc.development.parameter_validation_count);
        end
    end
    if ismember(split_kind,{'all','final'})
        for k = 1:numel(sc.final_seeds)
            prefix = sprintf('final%02d',k); seed = sc.final_seeds(k);
            bank = append_graph_split(bank,base,nominal,sc,prefix,'final_replication_calibration',seed+31, ...
                sc.final.calibration_continuous_per_graph,sc.final.calibration_grid_per_graph);
            bank = append_graph_split(bank,base,nominal,sc,prefix,'final_replication_test',seed+37, ...
                sc.final.test_continuous_per_graph,sc.final.test_grid_per_graph);
            bank = append_outliers(bank,base,sc,prefix,'final_replication_test',seed+43, ...
                sc.final.structure_test_count,sc.final.parameter_test_count);
        end
    end
    bank = bank(:);
end

function bank = append_graph_split(bank,base,nominal,sc,prefix,split,seed,ncont,ngrid)
    rng(seed,'twister');
    for g = 1:numel(base)
        for k = 1:ncont
            bank(end+1) = make_row(sprintf('%s_%s_cont_G%03d_%02d',prefix,split,g,k),prefix,split, ...
                'in_library_continuous',base(g),random_theta(sc.parameter_search),sc.source_tag,'','',seed); %#ok<AGROW>
        end
        for k = 1:ngrid
            bank(end+1) = make_row(sprintf('%s_%s_grid_G%03d_%02d',prefix,split,g,k),prefix,split, ...
                'in_library_grid',base(g),nominal,sc.source_tag,'','',seed); %#ok<AGROW>
        end
    end
end

function bank = append_outliers(bank,base,sc,prefix,split,seed,nstruct,nparam)
    rng(seed,'twister'); out = structure_out_candidates(sc.generator,base);
    for k = 1:nstruct
        j = 1 + mod(k-1,numel(out));
        bank(end+1) = make_row(sprintf('%s_%s_structure_out_%02d',prefix,split,k),prefix,split, ...
            'structure_out',out(j),random_theta(sc.parameter_search),sc.source_tag, ...
            sprintf('structure_key_%02d',j),'legal_one_level_tree_outside_P0',seed); %#ok<AGROW>
    end
    dims={'main_length_scale','branch_length_scale','branch_load_scale', ...
        'source_impedance_ohm','receiver_impedance_ohm','joint_parameter_set'};
    for k = 1:nparam
        j = 1 + mod(k-1,numel(base)); dim=dims{1+mod(k-1,numel(dims))};
        theta=parameter_out_theta(sc.parameter_search,dim,k);
        bank(end+1) = make_row(sprintf('%s_%s_parameter_out_%02d',prefix,split,k),prefix,split, ...
            'parameter_out',base(j),theta,sc.source_tag,dim,theta.outlier_direction,seed); %#ok<AGROW>
    end
end

function out=structure_out_candidates(generator,base)
    g=generator; g.max_branches=max(2,g.max_branches); g.max_side_branches_per_node=max(2,g.max_side_branches_per_node);
    g.max_nodes=max(12,g.max_nodes); g.max_candidates=max(64,g.max_candidates);
    allc=generate_radial_topology_candidates(g); keys={base.canonical_key};
    allc=allc(~ismember({allc.canonical_key},keys));
    if numel(allc)<3, error('stage4a5:InsufficientStructureDiversity','Need at least three structure-out keys.'); end
    out=allc(1:3);
end

function theta=random_theta(search)
    theta=struct('main_length_scale',draw_off(search.main_length_scale), ...
        'branch_length_scale',draw_off(search.branch_length_scale), ...
        'branch_load_scale',draw_off(search.branch_load_scale), ...
        'source_impedance_ohm',draw_off(search.source_impedance_ohm), ...
        'receiver_impedance_ohm',draw_off(search.receiver_impedance_ohm), ...
        'regularization',NaN,'outlier_dimension','','outlier_direction','');
end
function x=draw_off(v)
    lo=min(v);hi=max(v);if hi==lo,x=lo;return;end
    x=lo+(hi-lo)*rand;if any(abs(x-v)<1e-8*max(1,hi-lo)),x=lo+(hi-lo)*0.371;end
end
function theta=parameter_out_theta(search,dim,k)
    theta=random_theta(search);
    switch dim
        case 'main_length_scale',theta.main_length_scale=max(search.main_length_scale)+0.07+0.002*mod(k,3);theta.outlier_direction='above_max';
        case 'branch_length_scale',theta.branch_length_scale=min(search.branch_length_scale)-0.07-0.002*mod(k,3);theta.outlier_direction='below_min';
        case 'branch_load_scale',theta.branch_load_scale=max(search.branch_load_scale)+0.25+0.01*mod(k,3);theta.outlier_direction='above_max';
        case 'source_impedance_ohm',theta.source_impedance_ohm=max(search.source_impedance_ohm)+10+mod(k,3);theta.outlier_direction='above_max';
        case 'receiver_impedance_ohm',theta.receiver_impedance_ohm=min(search.receiver_impedance_ohm)-10-mod(k,3);theta.outlier_direction='below_min';
        otherwise
            theta.main_length_scale=max(search.main_length_scale)+0.06;theta.branch_length_scale=min(search.branch_length_scale)-0.06;
            theta.branch_load_scale=max(search.branch_load_scale)+0.20;theta.source_impedance_ohm=max(search.source_impedance_ohm)+8;
            theta.receiver_impedance_ohm=min(search.receiver_impedance_ohm)-8;theta.outlier_direction='joint_above_below';
    end
    theta.outlier_dimension=dim;theta.regularization=NaN;
end
function row=empty_rows()
    row=struct('sample_id','','replicate_id','','split','','category','','truth_topology_id','', ...
        'canonical_key','','truth_network',struct(),'truth_theta',struct(),'source_tag','', ...
        'outlier_dimension','','outlier_direction','','seed',0);row=repmat(row,0,1);
end
function row=make_row(id,rep,split,category,candidate,theta,tag,dim,direction,seed)
    row=struct('sample_id',id,'replicate_id',rep,'split',split,'category',category, ...
        'truth_topology_id',candidate.topology_id,'canonical_key',candidate.canonical_key, ...
        'truth_network',candidate.network,'truth_theta',theta,'source_tag',tag, ...
        'outlier_dimension',dim,'outlier_direction',direction,'seed',seed);
end
