function [clusters,audit]=build_stage4a7_2_nonunique_clusters(candidates,cfg,count,seed,tau_exact,tau_profile)
%BUILD_STAGE4A7_2_NONUNIQUE_CLUSTERS Generate independent equivalence cases.
%   Same-theta and coarse profile equivalence are recorded separately.
    if nargin<3||isempty(count),count=100;end
    if nargin<4||isempty(seed),seed=20262701;end
    if nargin<5||isempty(tau_exact),tau_exact=1e-10;end
    if nargin<6||isempty(tau_profile),tau_profile=1e-8;end
    f=linspace(2e6,30e6,61);
    pair=find_pair(candidates,{'G004','G007'});
    if isempty(pair),error('stage4a7_2:NoSymmetryPair','No tested candidate pair is available.');end
    grid=topology_parameter_grid(stage4a5_1_integrity_config(cfg,'formal').parameter_search);
    nom=grid(find([grid.regularization]==0,1));
    empty=struct('cluster_id','','truth_set','','generation_mechanism','','parameter_hash','', ...
        'observation_hash','','same_theta_distance',NaN,'profile_distance',NaN, ...
        'profile_equivalent',false,'tau_exact',tau_exact,'tau_profile',tau_profile,'independent',true);
    clusters=repmat(empty,0,1);
    stream=RandStream('mt19937ar','Seed',seed);
    for q=1:count
        t=nom;
        t.main_length_scale=.97+.06*rand(stream);
        t.branch_length_scale=.96+.08*rand(stream);
        t.branch_load_scale=.85+.30*rand(stream);
        t.source_impedance_ohm=45+10*rand(stream);
        t.receiver_impedance_ohm=t.source_impedance_ohm;
        t.regularization=NaN;
        h=cell(1,2);
        for z=1:2
            [n,l]=topology_apply_parameters(candidates(pair(z)).network,cfg,t);
            [m,~]=plc_measurement_bundle('siso_forward',n,t,l);
            [v,~]=plc_multiview_response(f,n,m,l);h{z}=v{1};
        end
        d=sqrt(mean(abs(h{1}-h{2}).^2));
        if d<=tau_exact
            pd=profile_distance(candidates(pair),cfg,t,f);
            r=empty;
            r.cluster_id=sprintf('stage4a7_2_nonunique_%04d',q);
            r.truth_set=strjoin(candidate_ids(candidates,pair),',');
            r.generation_mechanism='same_theta_symmetry_preserving_Zs_equals_Zr';
            r.parameter_hash=stage4a4_scientific_config_hash(t);
            r.observation_hash=stage4a4_scientific_config_hash(h{1});
            r.same_theta_distance=d;r.profile_distance=pd;
            r.profile_equivalent=pd<=r.tau_profile;
            clusters(end+1)=r; %#ok<AGROW>
        end
    end
    audit=struct('requested_count',count,'generated_count',numel(clusters), ...
        'seed',seed,'tau_exact',tau_exact,'candidate_pair',{candidate_ids(candidates,pair)}, ...
        'independent_parameter_hash_count',numel(unique({clusters.parameter_hash})), ...
        'independent_observation_hash_count',numel(unique({clusters.observation_hash})), ...
        'profile_equivalent_count',nnz([clusters.profile_equivalent]), ...
        'status',ternary(numel(clusters)>=50,'sufficient_for_pilot','insufficient_nonunique_clusters'));
end

function dmin=profile_distance(c,cfg,t,f)
    vals(1)=t;vals(2)=t;vals(2).branch_load_scale=t.branch_load_scale*1.02;
    vals(3)=t;vals(3).main_length_scale=t.main_length_scale*.99;
    dmin=Inf;
    for a=1:numel(vals)
        [n1,l1]=topology_apply_parameters(c(1).network,cfg,vals(a));
        [m1,~]=plc_measurement_bundle('siso_forward',n1,vals(a),l1);
        [v1,~]=plc_multiview_response(f,n1,m1,l1);
        for b=1:numel(vals)
            [n2,l2]=topology_apply_parameters(c(2).network,cfg,vals(b));
            [m2,~]=plc_measurement_bundle('siso_forward',n2,vals(b),l2);
            [v2,~]=plc_multiview_response(f,n2,m2,l2);
            dmin=min(dmin,sqrt(mean(abs(v1{1}-v2{1}).^2)));
        end
    end
end

function ids=candidate_ids(c,p)
    ids=cell(1,numel(p));
    for j=1:numel(p)
        if isfield(c,'id')&&~isempty(c(p(j)).id),ids{j}=c(p(j)).id;
        else,ids{j}=c(p(j)).graph_candidate_id;end
    end
end

function p=find_pair(c,ids)
    keys=cell(1,numel(c));
    for j=1:numel(c)
        if isfield(c,'id')&&~isempty(c(j).id),keys{j}=c(j).id;
        elseif isfield(c,'graph_candidate_id'),keys{j}=c(j).graph_candidate_id;
        else,keys{j}='';end
    end
    p=zeros(1,2);
    for k=1:2,p(k)=find(strcmp(keys,ids{k}),1);end
    if any(p==0),p=[];end
end
function x=ternary(tf,a,b),if tf,x=a;else,x=b;end,end
