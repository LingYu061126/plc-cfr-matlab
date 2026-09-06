function bank = generate_stage4a6_3_trial_bank(sc, split_kind, candidates)
%GENERATE_STAGE4A6_3_TRIAL_BANK Generate isolated A-grid trial identities.
%   Truth fields stay in the offline bank and are never passed to a matcher.
    if nargin < 2 || isempty(split_kind), split_kind='all'; end
    if nargin < 3 || isempty(candidates), candidates=generate_radial_topology_candidates(sc.generator); end
    domain=build_extended_parameter_domain(sc.parameter_search,sc.extended_domain_eta);
    bank=repmat(template(),0,1); names=domain.names(:).';
    if ismember(lower(split_kind),{'all','development','pilot'})
        seed=sc.seeds.development(1);
        for g=1:numel(candidates)
            active=topology_active_parameter_mask(candidates(g),names);
            bank(end+1)=make_interior(sprintf('dev_G%03d_interior',g),'development',seed,g,candidates(g),domain,active,1); %#ok<AGROW>
            active_names=names(active);
            if ~isempty(active_names)
                bank(end+1)=make_out(sprintf('dev_G%03d_ood_near',g),'development',seed,g,candidates(g),domain,active_names{1},'near','lower',active); %#ok<AGROW>
                bank(end+1)=make_out(sprintf('dev_G%03d_ood_medium',g),'development',seed,g,candidates(g),domain,active_names{1},'medium','upper',active); %#ok<AGROW>
                bank(end+1)=make_out(sprintf('dev_G%03d_ood_far',g),'development',seed,g,candidates(g),domain,active_names{1},'far','upper',active); %#ok<AGROW>
            end
        end
    end
    if ismember(lower(split_kind),{'all','calibration'})
        seed=sc.seeds.calibration; n=sc.trial_design.calibration_per_graph;
        for g=1:numel(candidates)
            active=topology_active_parameter_mask(candidates(g),names);
            for q=1:n
                bank(end+1)=make_interior(sprintf('cal_G%03d_%03d',g,q),'calibration',seed+q,g,candidates(g),domain,active,q); %#ok<AGROW>
            end
        end
    end
    if ismember(lower(split_kind),{'all','final'})
        seeds=sc.seeds.final;
        for si=1:numel(seeds)
            seed=seeds(si); n=sc.trial_design.final_in_domain_per_graph;
            for g=1:numel(candidates)
                active=topology_active_parameter_mask(candidates(g),names);
                for q=1:n
                    bank(end+1)=make_interior(sprintf('final_s%02d_G%03d_in_%03d',si,g,q),'final',seed+q+1000*si,g,candidates(g),domain,active,q+10*si); %#ok<AGROW>
                end
                active_names=names(active);
                for pi=1:numel(active_names)
                    for vi=1:numel(sc.trial_design.severities)
                        sev=sc.trial_design.severities{vi};
                        for di=1:numel(sc.trial_design.directions)
                            dirn=sc.trial_design.directions{di};
                            for q=1:sc.trial_design.final_per_parameter_severity_direction
                                id=sprintf('final_s%02d_G%03d_%s_%s_%s_%02d',si,g,active_names{pi},sev,dirn,q);
                                bank(end+1)=make_out(id,'final',seed+q+1000*pi+10000*si,g,candidates(g),domain,active_names{pi},sev,dirn,active); %#ok<AGROW>
                            end
                        end
                    end
                end
            end
        end
    end
    ids={bank.sample_id}; if numel(unique(ids))~=numel(ids),error('stage4a6_3:DuplicateSampleID','Duplicate trial ID.');end
end

function z=template()
    z=struct('sample_id','','split','','replicate_id','','seed',0,'truth_topology_id','', ...
        'canonical_key','','truth_network',struct(),'truth_theta',struct(), ...
        'active_parameter_names','','active_parameter_count',0,'has_branch',false, ...
        'category','','outlier_dimension','','outlier_severity','','outlier_direction','', ...
        'parameter_domain_truth','','grid_id','A_stage4a1_quick61','frequency_count',61, ...
        'source_tag','synthetic_demo_prior_not_field_data');
end
function z=make_interior(id,split,seed,g,c,d,active,q)
    z=template();z.sample_id=id;z.split=split;z.replicate_id=split;z.seed=seed;z.truth_topology_id=c.topology_id;z.canonical_key=c.canonical_key;z.truth_network=c.network;z.truth_theta=inside_theta(d,q);z.active_parameter_names=strjoin(d.names(active),',');z.active_parameter_count=sum(active);z.has_branch=any(active(strcmp(d.names,'branch_length_scale')));z.category='in_domain_interior';z.parameter_domain_truth='in_domain';
end
function z=make_out(id,split,seed,g,c,d,p,sev,dirn,active)
    z=template();z.sample_id=id;z.split=split;z.replicate_id=split;z.seed=seed;z.truth_topology_id=c.topology_id;z.canonical_key=c.canonical_key;z.truth_network=c.network;z.truth_theta=outside_theta(d,p,sev,dirn);z.active_parameter_names=strjoin(d.names(active),',');z.active_parameter_count=sum(active);z.has_branch=any(active(strcmp(d.names,'branch_length_scale')));z.category=['out_of_domain_' sev];z.outlier_dimension=p;z.outlier_severity=sev;z.outlier_direction=dirn;z.parameter_domain_truth='out_of_domain';
end
function t=inside_theta(d,q)
    x=zeros(1,numel(d.names));
    for k=1:numel(x),u=0.20+0.60*mod(0.173*q+0.071*k,1);x(k)=d.in_lower(k)+(d.in_upper(k)-d.in_lower(k))*u;end
    t=to_theta(x,d.names);
end
function t=outside_theta(d,name,sev,dirn)
    x=(d.in_lower+d.in_upper)/2;k=find(strcmp(d.names,name),1);a=struct('near',0.08,'medium',0.30,'far',0.70);delta=a.(sev)*(d.in_upper(k)-d.in_lower(k));
    if strcmp(dirn,'lower'),x(k)=d.in_lower(k)-delta;else,x(k)=d.in_upper(k)+delta;end
    t=to_theta(x,d.names);
end
function t=to_theta(x,n)
    t=struct();for k=1:numel(n),t.(n{k})=x(k);end;t.regularization=NaN;
end
