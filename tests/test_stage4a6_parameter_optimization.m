function test_stage4a6_parameter_optimization()
%TEST_STAGE4A6_PARAMETER_OPTIMIZATION Bounds, reproducibility and evidence.
    root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'),fullfile(root,'config'));cfg=default_config(root);sc=stage4a6_parameter_domain_config(cfg,'smoke');g=generate_radial_topology_candidates(sc.generator);d=build_extended_parameter_domain(sc.parameter_search,0.5);f=sc.grids(1).frequency_hz;
    x=(d.in_lower+d.in_upper)/2;t=vec(x,d.names);[net,lc]=topology_apply_parameters(g(1).network,cfg,t);[m,~]=plc_measurement_bundle('siso_forward',net,t,lc);[obs,~]=plc_multiview_response(f,net,m,lc);opt=sc.optimization;opt.max_iterations=30;opt.max_function_evaluations=100;
    b=struct('names',{d.names},'lower',d.in_lower,'upper',d.in_upper);r1=optimize_topology_parameters_bounded(obs,f,g(1),cfg,b,t,opt);r2=optimize_topology_parameters_bounded(obs,f,g(1),cfg,b,t,opt);
    assert(all(r1.theta_vector>=d.in_lower)&all(r1.theta_vector<=d.in_upper),'In-domain optimizer escaped bounds.');assert(norm(r1.theta_vector-r2.theta_vector)<1e-10&&abs(r1.distance-r2.distance)<1e-12,'Multistart result is not deterministic.');assert(r1.distance<1e-5,'Known synthetic parameter did not fit its own observation.');
    eb=struct('names',{d.names},'lower',d.ext_lower,'upper',d.ext_upper);re=optimize_topology_parameters_bounded(obs,f,g(1),cfg,eb,t,opt);assert(all(re.theta_vector>=d.ext_lower)&all(re.theta_vector<=d.ext_upper),'Extended optimizer escaped diagnostic bounds.');
    fprintf('ALL STAGE 4A.6 PARAMETER OPTIMIZATION TESTS PASSED\n');
end
function t=vec(x,n),t=struct();for k=1:numel(n),t.(n{k})=x(k);end,t.regularization=NaN;end
