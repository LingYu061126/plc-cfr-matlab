function bank = generate_stage4a6_3_1_independent_trials(sc,split_kind,candidates)
%GENERATE_STAGE4A6_3_1_INDEPENDENT_TRIALS Generate genuinely varied physics.
% No truth field is intended for a matcher; it remains in the offline bank.
    if nargin<2||isempty(split_kind),split_kind='pilot';end
    if nargin<3||isempty(candidates),candidates=generate_radial_topology_candidates(sc.generator);end
    d=build_extended_parameter_domain(sc.parameter_search,sc.extended_domain_eta);
    names=d.names(:).';bank=repmat(template(),0,1);kind=lower(char(split_kind));
    if ismember(kind,{'calibration','pilot'})
        for g=1:numel(candidates)
            for q=1:sc.trial_design.calibration_per_graph
                id=sprintf('cal_G%03d_%02d',g,q);bank(end+1)=make_in(id,'calibration',sc.seeds.calibration,g,candidates(g),d,names,q); %#ok<AGROW>
            end
        end
    end
    if strcmp(kind,'pilot')
        for g=1:numel(candidates)
            q=1;id=sprintf('pilot_G%03d_in_%02d',g,q);bank(end+1)=make_in(id,'pilot',sc.seeds.pilot,g,candidates(g),d,names,q); %#ok<AGROW>
            active=topology_active_parameter_mask(candidates(g),names);an=names(active);
            for j=1:numel(an)
                for z=1:4
                    if z==1,sev='near';dirn='lower';elseif z==2,sev='near';dirn='upper';elseif z==3,sev='medium';dirn='lower';else,sev='far';dirn='upper';end
                    id=sprintf('pilot_G%03d_%s_%s_%s_%02d',g,an{j},sev,dirn,z);
                    bank(end+1)=make_out(id,'pilot',sc.seeds.pilot,g,candidates(g),d,names,an{j},sev,dirn,j); %#ok<AGROW>
                end
            end
        end
    end
    ids={bank.sample_id};if numel(unique(ids))~=numel(ids),error('stage4a6_3_1:DuplicateSampleID','Duplicate sample ID.');end
end
function z=template(),z=struct('sample_id','','split','','replicate_id','','seed',0,'truth_topology_id','','canonical_key','', ...
    'truth_network',struct(),'truth_theta',struct(),'active_parameter_names','','active_parameter_count',0,'has_branch',false, ...
    'category','','outlier_dimension','','outlier_severity','','outlier_direction','','parameter_domain_truth','', ...
    'physical_scenario_id','','nuisance_sample_id','','parameter_jitter_fraction',NaN,'grid_id','A_stage4a1_quick61', ...
    'frequency_count',61,'source_tag','synthetic_demo_prior_not_field_data');end
function z=make_in(id,split,master,g,c,d,names,q)
    seed=stable_seed(master,id);rng(seed,'twister');x=d.in_lower+0.15*(d.in_upper-d.in_lower)+0.70*(d.in_upper-d.in_lower).*rand(1,numel(names));
    z=base(id,split,seed,g,c,d,names);z.truth_theta=theta(x,names);z.category='in_domain_interior';z.parameter_domain_truth='in_domain';z.replicate_id=sprintf('%s_%02d',split,q);z.nuisance_sample_id=[id '_nuisance'];
end
function z=make_out(id,split,master,g,c,d,names,target,sev,dirn,q)
    seed=stable_seed(master,id);rng(seed,'twister');x=d.in_lower+0.15*(d.in_upper-d.in_lower)+0.70*(d.in_upper-d.in_lower).*rand(1,numel(names));
    k=find(strcmp(names,target),1);w=d.in_upper(k)-d.in_lower(k);bands=struct('near',[0.05 0.15],'medium',[0.25 0.40],'far',[0.60 0.80]);u=bands.(sev);delta=(u(1)+(u(2)-u(1))*rand)*w;
    if strcmp(dirn,'lower'),x(k)=max(d.ext_lower(k)/2,d.in_lower(k)-delta);else,x(k)=d.in_upper(k)+delta;end
    z=base(id,split,seed,g,c,d,names);z.truth_theta=theta(x,names);z.category=['out_of_domain_' sev];z.outlier_dimension=target;z.outlier_severity=sev;z.outlier_direction=dirn;z.parameter_domain_truth='out_of_domain';z.replicate_id=sprintf('%s_%02d',split,q);z.nuisance_sample_id=[id '_nuisance'];z.parameter_jitter_fraction=0.08;
end
function z=base(id,split,seed,g,c,d,names),z=template();z.sample_id=id;z.split=split;z.seed=seed;z.truth_topology_id=c.topology_id;z.canonical_key=c.canonical_key;z.truth_network=c.network;mask=topology_active_parameter_mask(c,names);z.active_parameter_names=strjoin(names(mask),',');z.active_parameter_count=sum(mask);z.has_branch=any(mask(strcmp(names,'branch_length_scale')));z.physical_scenario_id=[split '_' id];z.parameter_jitter_fraction=0.08;end
function t=theta(x,n),t=struct();for k=1:numel(n),t.(n{k})=x(k);end;t.regularization=NaN;end
function s=stable_seed(master,id),v=double(char(id));s=mod(double(master)+sum(v.*(1:numel(v))),2^31-1);s=max(1,round(s));end
