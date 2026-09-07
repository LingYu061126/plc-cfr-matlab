function bank = stage4a6_3_1_r_generate_independent_scenarios(sc,split_kind,candidates)
%STAGE4A6_3_1_R_GENERATE_INDEPENDENT_SCENARIOS Generate varied physics.
    if nargin<2||isempty(split_kind),split_kind='pilot';end
    if nargin<3||isempty(candidates),candidates=generate_radial_topology_candidates(sc.generator);end
    d=build_extended_parameter_domain(sc.parameter_search,sc.extended_domain_eta);names=d.names(:).';kind=lower(char(split_kind));bank=repmat(template(),0,1);
    if strcmp(kind,'final_reserved')
        for g=1:min(numel(candidates),sc.trial_design.final_reserved_count)
            z=template();z.sample_id=sprintf('reserved_G%03d_01',g);z.split=kind;z.seed=stable_seed(sc.seeds.final_reserved,z.sample_id);z.truth_topology_id=candidates(g).topology_id;z.canonical_key=candidates(g).canonical_key;z.physical_scenario_id=['final_reserved_' z.sample_id];z.category='reserved_not_executed';z.source_tag=sc.source_tag;bank(end+1)=z; %#ok<AGROW>
        end
        return;
    end
    if ~ismember(kind,{'calibration','pilot'}),error('stage4a6_3_1_r:InvalidSplit','Unknown split.');end
    if strcmp(kind,'calibration')
      for g=1:numel(candidates)
        for q=1:sc.trial_design.calibration_per_graph
            id=sprintf('r_%s_G%03d_interior_%02d',kind,g,q);bank(end+1)=make_in(id,kind,sc.seeds.(kind),g,candidates(g),d,names,q); %#ok<AGROW>
        end
      end
    end
    if strcmp(kind,'calibration'),return;end
    for g=1:numel(candidates)
        for q=1:sc.trial_design.pilot_in_domain_per_graph
            id=sprintf('r_pilot_G%03d_interior_%02d',g,q);bank(end+1)=make_in(id,kind,sc.seeds.pilot,g,candidates(g),d,names,q); %#ok<AGROW>
        end
        for q=1:sc.trial_design.pilot_boundary_per_graph
            id=sprintf('r_pilot_G%03d_boundary_%02d',g,q);bank(end+1)=make_boundary(id,kind,sc.seeds.pilot,g,candidates(g),d,names,q); %#ok<AGROW>
        end
        mask=topology_active_parameter_mask(candidates(g),names);an=names(mask);
        for q=1:sc.trial_design.pilot_out_per_graph
            target=an{1+mod(g+q-2,numel(an))};sev=sc.trial_design.severity_names{q};dirn=sc.trial_design.direction_names{1+mod(g+q,2)};id=sprintf('r_pilot_G%03d_%s_%s_%s_%02d',g,target,sev,dirn,q);bank(end+1)=make_out(id,kind,sc.seeds.pilot,g,candidates(g),d,names,target,sev,dirn,q); %#ok<AGROW>
        end
    end
    ids={bank.sample_id};if numel(unique(ids))~=numel(ids),error('stage4a6_3_1_r:DuplicateSampleID','Duplicate sample ID.');end
end
function z=make_in(id,split,master,g,c,d,names,q),seed=stable_seed(master,id);rng(seed,'twister');x=d.in_lower+0.15*(d.in_upper-d.in_lower)+0.70*(d.in_upper-d.in_lower).*rand(1,numel(names));z=base(id,split,seed,g,c,names);z.truth_theta=theta(x,names);z.category='in_domain_interior';z.parameter_domain_truth='in_domain';z.replicate_id=sprintf('%s_%02d',split,q);z.nuisance_sample_id=[id '_nuisance'];end
function z=make_boundary(id,split,master,g,c,d,names,q),seed=stable_seed(master,id);rng(seed,'twister');x=d.in_lower+0.20*(d.in_upper-d.in_lower)+0.60*(d.in_upper-d.in_lower).*rand(1,numel(names));k=find(strcmp(names,'main_length_scale'),1);if mod(g,2)==0,x(k)=d.in_lower(k)+0.01*(d.in_upper(k)-d.in_lower(k));else,x(k)=d.in_upper(k)-0.01*(d.in_upper(k)-d.in_lower(k));end;z=base(id,split,seed,g,c,names);z.truth_theta=theta(x,names);z.category='in_domain_boundary';z.parameter_domain_truth='in_domain';z.outlier_dimension='main_length_scale';z.outlier_direction=ternary(mod(g,2)==0,'lower','upper');z.replicate_id=sprintf('%s_%02d',split,q);z.nuisance_sample_id=[id '_nuisance'];end
function z=make_out(id,split,master,g,c,d,names,target,sev,dirn,q),seed=stable_seed(master,id);rng(seed,'twister');x=d.in_lower+0.15*(d.in_upper-d.in_lower)+0.70*(d.in_upper-d.in_lower).*rand(1,numel(names));k=find(strcmp(names,target),1);w=d.in_upper(k)-d.in_lower(k);bands=struct('near',[0.05 0.15],'medium',[0.25 0.40],'far',[0.60 0.80]);u=bands.(sev);delta=(u(1)+(u(2)-u(1))*rand)*w;if strcmp(dirn,'lower'),x(k)=max(d.ext_lower(k)/2,d.in_lower(k)-delta);else,x(k)=d.in_upper(k)+delta;end;z=base(id,split,seed,g,c,names);z.truth_theta=theta(x,names);z.category=['out_of_domain_' sev];z.outlier_dimension=target;z.outlier_severity=sev;z.outlier_direction=dirn;z.parameter_domain_truth='out_of_domain';z.replicate_id=sprintf('%s_%02d',split,q);z.nuisance_sample_id=[id '_nuisance'];end
function z=base(id,split,seed,g,c,names),z=template();z.sample_id=id;z.split=split;z.seed=seed;z.truth_topology_id=c.topology_id;z.canonical_key=c.canonical_key;z.truth_network=c.network;mask=topology_active_parameter_mask(c,names);z.active_parameter_names=strjoin(names(mask),',');z.active_parameter_count=sum(mask);z.has_branch=any(mask(strcmp(names,'branch_length_scale')));z.physical_scenario_id=[split '_' id];z.parameter_jitter_fraction=0.08;z.source_tag='synthetic_demo_prior_not_field_data';end
function z=template(),z=struct('sample_id','','split','','replicate_id','','seed',0,'truth_topology_id','','canonical_key','','truth_network',struct(),'truth_theta',struct(),'active_parameter_names','','active_parameter_count',0,'has_branch',false,'category','','outlier_dimension','','outlier_severity','','outlier_direction','','parameter_domain_truth','','physical_scenario_id','','nuisance_sample_id','','parameter_jitter_fraction',NaN,'grid_id','A_stage4a1_quick61','frequency_count',61,'source_tag','synthetic_demo_prior_not_field_data','parameter_vector_hash','','noiseless_cfr_hash','','observation_hash','');end
function t=theta(x,n),t=struct();for k=1:numel(n),t.(n{k})=x(k);end;t.regularization=NaN;end
function s=stable_seed(master,id),v=double(char(id));s=max(1,round(mod(double(master)+sum(v.*(1:numel(v))),2^31-1)));end
function y=ternary(tf,a,b),if tf,y=a;else,y=b;end,end
