function bank = generate_stage4a6_trial_bank(sc,split_kind)
%GENERATE_STAGE4A6_TRIAL_BANK Independent domain-diagnostic trial bank.
    if nargin<2,split_kind='all';end;base=generate_radial_topology_candidates(sc.generator);domain=build_extended_parameter_domain(sc.parameter_search,1);bank=repmat(row(),0,1);
    if ismember(lower(split_kind),{'all','development'})
        for r=1:numel(sc.development_seeds),rep=sprintf('dev%02d',r);bank=add_cal(bank,base,sc,domain,rep,'stage4a6_calibration',sc.development_seeds(r));bank=add_eval(bank,base,sc,domain,rep,'stage4a6_validation',sc.development_seeds(r)+31,r);end
    end
    if ismember(lower(split_kind),{'all','final'})
        for r=1:numel(sc.final_seeds),rep=sprintf('final%02d',r);bank=add_cal(bank,base,sc,domain,rep,'stage4a6_final_calibration',sc.final_seeds(r));bank=add_eval(bank,base,sc,domain,rep,'stage4a6_final_test',sc.final_seeds(r)+31,r);end
    end
end
function b=add_cal(b,base,sc,d,rep,split,seed),rng(seed,'twister');for g=1:numel(base),for q=1:sc.sample_design.calibration_per_graph,t=inside(d,rand(1,5));b(end+1)=make(sprintf('%s_cal_G%03d_%02d',rep,g,q),rep,split,'parameter_in_domain',base(g),t,'','','in_domain',seed);end,end,end
function b=add_eval(b,base,sc,d,rep,split,seed,rep_index),rng(seed,'twister');n=sc.sample_design.in_domain_per_replicate;for k=1:n,g=1+mod(k-1,numel(base));u=rand(1,5);if mod(k,2)==0,u(1)=0.03;end;t=inside(d,u);b(end+1)=make(sprintf('%s_test_in_%02d',rep,k),rep,split,'parameter_in_domain',base(g),t,'','','in_domain',seed);end
    dims=sc.sample_design.dimensions;sev={'near','medium','far'};
    for k=1:numel(dims),g=1+mod(k+rep_index-2,numel(base));s=sev{1+mod(k+rep_index-2,3)};t=outside(d,dims{k},s,rand(1,5));b(end+1)=make(sprintf('%s_test_out_%s_%s',rep,dims{k},s),rep,split,'parameter_out_of_domain',base(g),t,dims{k},s,'out_of_domain',seed);end
end
function t=inside(d,u),x=d.in_lower+(d.in_upper-d.in_lower).*(0.02+0.96*u);t=vec(x,d.names);end
function t=outside(d,dim,severity,u),x=d.in_lower+(d.in_upper-d.in_lower).*(0.1+0.8*u);mult=struct('near',0.08,'medium',0.30,'far',0.70);a=mult.(severity);if strcmp(dim,'joint_parameter_set'),x([1 3 4])=d.in_upper([1 3 4])+a*(d.in_upper([1 3 4])-d.in_lower([1 3 4]));x([2 5])=max(d.ext_lower([2 5]),d.in_lower([2 5])-a*(d.in_upper([2 5])-d.in_lower([2 5])));else,k=find(strcmp(d.names,dim));if mod(sum(double(dim)),2),x(k)=d.in_upper(k)+a*(d.in_upper(k)-d.in_lower(k));else,x(k)=max(d.ext_lower(k),d.in_lower(k)-a*(d.in_upper(k)-d.in_lower(k)));end,end;t=vec(x,d.names);end
function t=vec(x,n),t=struct();for k=1:numel(n),t.(n{k})=x(k);end,t.regularization=NaN;end
function z=row(),z=struct('sample_id','','replicate_id','','split','','category','','truth_topology_id','','canonical_key','','truth_network',struct(),'truth_theta',struct(),'outlier_dimension','','outlier_severity','','parameter_domain_truth','','seed',0);end
function z=make(id,rep,split,cat,g,t,dim,sev,truth,seed),z=row();z.sample_id=id;z.replicate_id=rep;z.split=split;z.category=cat;z.truth_topology_id=g.topology_id;z.canonical_key=g.canonical_key;z.truth_network=g.network;z.truth_theta=t;z.outlier_dimension=dim;z.outlier_severity=sev;z.parameter_domain_truth=truth;z.seed=seed;end
