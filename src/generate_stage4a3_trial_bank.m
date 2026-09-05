function bank=generate_stage4a3_trial_bank(cfg,sc)
base=generate_prior_constrained_candidates(sc.generator,sc.scenarios(1).asset_prior);rng(sc.seed_calibration,'twister');bank=struct('sample_id',{},'split',{},'category',{},'truth_topology_id',{},'truth_network',{},'truth_theta',{});id=0;
for split=1:2
 seed=[sc.seed_calibration sc.seed_test];rng(seed(split),'twister');n=[sc.per_graph_calibration sc.per_graph_test];
 for g=1:numel(base),for k=1:n(split),id=id+1;t=random_theta(sc.parameter_search);bank(id)=row(sprintf('%s_G%03d_%02d',tern(split==1,'cal','test'),g,k),tern(split==1,'calibration','test'),'in_library_continuous',base(g),t);end,end
end
all=generate_radial_topology_candidates(setfield(sc.generator,'max_branches',3)); %#ok<SFLD>
for kind={'structure_out','parameter_out'}
 id=id+1;if strcmp(kind{1},'structure_out'),truth=all(end);t=random_theta(sc.parameter_search);else,truth=base(1);t=random_theta(sc.parameter_search);t.main_length_scale=1.12;t.branch_length_scale=.88;t.branch_load_scale=1.35;t.source_impedance_ohm=60;t.receiver_impedance_ohm=40;end
 bank(id)=row(['test_' kind{1}], 'test',kind{1},truth,t);
end
end
function x=row(id,split,kind,g,t),x=struct('sample_id',id,'split',split,'category',kind,'truth_topology_id',g.topology_id,'truth_network',g.network,'truth_theta',t);end
function t=random_theta(s)
t=struct('main_length_scale',rand_range(s.main_length_scale),'branch_length_scale',rand_range(s.branch_length_scale),'branch_load_scale',rand_range(s.branch_load_scale),'source_impedance_ohm',rand_range(s.source_impedance_ohm),'receiver_impedance_ohm',rand_range(s.receiver_impedance_ohm),'regularization',NaN);end
function x=rand_range(v),x=min(v)+(max(v)-min(v))*rand; if any(abs(x-v)<1e-8),x=x+1e-4;end,end
function x=tern(c,a,b),if c,x=a;else,x=b;end,end
