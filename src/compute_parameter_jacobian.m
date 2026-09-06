function out = compute_parameter_jacobian(frequency_hz,candidate,cfg,theta,domain,options)
%COMPUTE_PARAMETER_JACOBIAN Normalized finite-difference complex CFR Jacobian.
    names=domain.names;x=zeros(1,numel(names));for k=1:numel(names),x(k)=theta.(names{k});end;h=getopt(options,'finite_difference_step',1e-3);base=response(x);J=complex(zeros(2*numel(base),numel(x)));
    for k=1:numel(x),step=h*(domain.in_upper(k)-domain.in_lower(k));xp=x;xm=x;xp(k)=min(domain.ext_upper(k),x(k)+step);xm(k)=max(domain.ext_lower(k),x(k)-step);yp=response(xp);ym=response(xm);dz=(yp-ym)/max(xp(k)-xm(k),eps)*(domain.in_upper(k)-domain.in_lower(k));J(:,k)=[real(dz(:));imag(dz(:))];end
    out=struct('J',J,'parameter_names',{names},'normalized_step',h,'base_response',base);
    function y=response(q),t=vec(q,names);[net,lc]=topology_apply_parameters(candidate.network,cfg,t);[m,~]=plc_measurement_bundle('siso_forward',net,t,lc);[v,~]=plc_multiview_response(frequency_hz,net,m,lc);y=[v{:}];end
end
function t=vec(x,n),t=struct();for k=1:numel(n),t.(n{k})=x(k);end,t.regularization=NaN;end
function x=getopt(s,n,d),if isfield(s,n),x=s.(n);else,x=d;end,end
