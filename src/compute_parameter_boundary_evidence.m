function out = compute_parameter_boundary_evidence(observed_views,frequency_hz,candidate,cfg,in_result,domain,options)
%COMPUTE_PARAMETER_BOUNDARY_EVIDENCE Boundary hits and outward finite differences.
    x=in_result.theta_vector;lo=domain.in_lower;hi=domain.in_upper;w=hi-lo;step=getopt(options,'finite_difference_step',1e-3);trend=zeros(size(x));
    for k=1:numel(x)
        if in_result.near_lower(k),q=x;q(k)=max(domain.ext_lower(k),x(k)-step*w(k));trend(k)=distance(q)-in_result.distance;
        elseif in_result.near_upper(k),q=x;q(k)=min(domain.ext_upper(k),x(k)+step*w(k));trend(k)=distance(q)-in_result.distance;
        else,trend(k)=NaN;end
    end
    out=struct('near_lower',in_result.near_lower,'near_upper',in_result.near_upper,'minimum_normalized_boundary_distance',in_result.minimum_boundary_distance,'outward_distance_change',trend,'outward_decrease',any(trend<0),'boundary_hit',any(in_result.near_lower|in_result.near_upper));
    function d=distance(q),th=vec(q,domain.names);[net,lc]=topology_apply_parameters(candidate.network,cfg,th);[m,~]=plc_measurement_bundle('siso_forward',net,th,lc);[v,~]=plc_multiview_response(frequency_hz,net,m,lc);e=0;n=0;for j=1:numel(v),z=v{j}(:).'-observed_views{j}(:).';e=e+sum(abs(z).^2);n=n+numel(z);end;d=sqrt(e/n);end
end
function t=vec(x,n),t=struct();for k=1:numel(n),t.(n{k})=x(k);end,t.regularization=NaN;end
function x=getopt(s,n,d),if isfield(s,n),x=s.(n);else,x=d;end,end
