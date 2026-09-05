function bank = generate_stage4a4_trial_bank(sc)
%GENERATE_STAGE4A4_TRIAL_BANK Generate one shared four-way truth bank.
%   Truth fields are retained for offline scoring only.  The matcher is
%   called later with observations and caches, never with this structure.
    if nargin < 1 || isempty(sc), error('stage4a4:MissingConfig','sc is required.'); end
    base = generate_radial_topology_candidates(sc.generator);
    nominal_grid = topology_parameter_grid(sc.parameter_search);
    nominal = nominal_grid(find([nominal_grid.regularization] == 0,1));
    bank = empty_row(); cursor = 0;
    c = sc.split_counts;
    splits = {'training','calibration','validation','test'};
    seeds = [sc.training_seed,sc.calibration_seed,sc.validation_seed,sc.test_seed];
    cont_counts = [c.continuous_train_per_graph,c.continuous_calibration_per_graph, ...
        c.continuous_validation_per_graph,c.continuous_test_per_graph];
    grid_counts = [c.grid_train_per_graph,c.grid_calibration_per_graph, ...
        c.grid_validation_per_graph,c.grid_test_per_graph];
    for s = 1:numel(splits)
        rng(seeds(s),'twister');
        for g = 1:numel(base)
            for k = 1:cont_counts(s)
                cursor=cursor+1;
                bank(cursor)=make_row(sprintf('%s_cont_G%03d_%02d',splits{s},g,k), ...
                    splits{s},'in_library_continuous',base(g), ...
                    random_continuous_theta(sc.parameter_search),sc.source_tag,'',''); %#ok<AGROW>
            end
            for k = 1:grid_counts(s)
                cursor=cursor+1;
                bank(cursor)=make_row(sprintf('%s_grid_G%03d_%02d',splits{s},g,k), ...
                    splits{s},'in_library_grid',base(g),nominal,sc.source_tag,'',''); %#ok<AGROW>
            end
        end
        if strcmp(splits{s},'validation') || strcmp(splits{s},'test')
            nstruct = c.(['structure_' splits{s} '_count']);
            nparam = c.(['parameter_' splits{s} '_count']);
            out = structure_out_candidates(sc.generator,base);
            for k=1:nstruct
                g=out(1+mod(k-1,numel(out)));
                cursor=cursor+1;
                bank(cursor)=make_row(sprintf('%s_structure_out_%02d',splits{s},k), ...
                    splits{s},'structure_out',g,random_continuous_theta(sc.parameter_search), ...
                    sc.source_tag,sprintf('structure_key_%02d',1+mod(k-1,numel(out))), ...
                    'legal_one_level_tree_outside_P0'); %#ok<AGROW>
            end
            dimensions={'main_length_scale','branch_length_scale','branch_load_scale', ...
                'source_impedance_ohm','receiver_impedance_ohm','joint_parameter_set'};
            for k=1:nparam
                g=base(1+mod(k-1,numel(base)));
                dim=dimensions{1+mod(k-1,numel(dimensions))};
                theta=parameter_out_theta(sc.parameter_search,dim,k);
                cursor=cursor+1;
                bank(cursor)=make_row(sprintf('%s_parameter_out_%02d',splits{s},k), ...
                    splits{s},'parameter_out',g,theta,sc.source_tag,dim,theta.outlier_direction); %#ok<AGROW>
            end
        end
    end
    bank=bank(:);
end

function out=structure_out_candidates(generator,base)
    g=generator; g.max_branches=max(2,g.max_branches); g.max_side_branches_per_node=max(2,g.max_side_branches_per_node);
    g.max_nodes=max(12,g.max_nodes); g.max_candidates=max(64,g.max_candidates);
    allc=generate_radial_topology_candidates(g); keys={base.canonical_key};
    allc=allc(~ismember({allc.canonical_key},keys));
    if numel(allc)<3, error('stage4a4:InsufficientStructureDiversity','Need at least 3 out keys.'); end
    out=allc(1:3);
end

function row=empty_row()
    row=struct('sample_id','','split','','category','','truth_topology_id','', ...
        'canonical_key','','truth_network',struct(),'truth_theta',struct(), ...
        'source_tag','','outlier_dimension','','outlier_direction','');
    row=repmat(row,0,1);
end
function row=make_row(id,split,category,candidate,theta,tag,dim,direction)
    row=struct('sample_id',id,'split',split,'category',category, ...
        'truth_topology_id',candidate.topology_id,'canonical_key',candidate.canonical_key, ...
        'truth_network',candidate.network,'truth_theta',theta,'source_tag',tag, ...
        'outlier_dimension',dim,'outlier_direction',direction);
end
function theta=random_continuous_theta(search)
    theta=struct('main_length_scale',draw_off(search.main_length_scale), ...
        'branch_length_scale',draw_off(search.branch_length_scale), ...
        'branch_load_scale',draw_off(search.branch_load_scale), ...
        'source_impedance_ohm',draw_off(search.source_impedance_ohm), ...
        'receiver_impedance_ohm',draw_off(search.receiver_impedance_ohm), ...
        'regularization',NaN,'outlier_dimension','','outlier_direction','');
end
function x=draw_off(v)
    lo=min(v); hi=max(v); if hi==lo, x=lo; return; end
    x=lo+(hi-lo)*rand; if any(abs(x-v)<1e-8*max(1,hi-lo)), x=lo+(hi-lo)*0.371; end
end
function theta=parameter_out_theta(search,dim,k)
    theta=random_continuous_theta(search);
    switch dim
        case 'main_length_scale', theta.main_length_scale=max(search.main_length_scale)+0.07+0.002*mod(k,3); theta.outlier_direction='above_max';
        case 'branch_length_scale', theta.branch_length_scale=min(search.branch_length_scale)-0.07-0.002*mod(k,3); theta.outlier_direction='below_min';
        case 'branch_load_scale', theta.branch_load_scale=max(search.branch_load_scale)+0.25+0.01*mod(k,3); theta.outlier_direction='above_max';
        case 'source_impedance_ohm', theta.source_impedance_ohm=max(search.source_impedance_ohm)+10+mod(k,3); theta.outlier_direction='above_max';
        case 'receiver_impedance_ohm', theta.receiver_impedance_ohm=min(search.receiver_impedance_ohm)-10-mod(k,3); theta.outlier_direction='below_min';
        otherwise
            theta.main_length_scale=max(search.main_length_scale)+0.06; theta.branch_length_scale=min(search.branch_length_scale)-0.06;
            theta.branch_load_scale=max(search.branch_load_scale)+0.20; theta.source_impedance_ohm=max(search.source_impedance_ohm)+8;
            theta.receiver_impedance_ohm=min(search.receiver_impedance_ohm)-8; theta.outlier_direction='joint_above_below';
    end
    theta.outlier_dimension=dim; theta.regularization=NaN;
end
