function out = compute_stage4a6_1_jacobian(frequency_hz,candidate,cfg,theta,domain,options)
%COMPUTE_STAGE4A6_1_JACOBIAN Normalized finite-difference CFR Jacobian.
%   Only active parameters are differentiated. Inactive branch parameters
%   therefore cannot create artificial zero-sensitivity columns.

    names = domain.names(:).';
    mask = topology_active_parameter_mask(candidate,names);
    names = names(mask);
    lo = domain.in_lower(mask); hi = domain.in_upper(mask);
    x = zeros(1,numel(names));
    for k = 1:numel(names), x(k) = theta.(names{k}); end
    step = get_option(options,'finite_difference_step',1e-3);
    base = response(x,names);
    J = zeros(2*numel(base),numel(names));
    for k = 1:numel(names)
        dx = step*(hi(k)-lo(k));
        xp=x; xm=x; xp(k)=min(domain.ext_upper(find(strcmp(domain.names,names{k}))),x(k)+dx);
        xm(k)=max(domain.ext_lower(find(strcmp(domain.names,names{k}))),x(k)-dx);
        yp=response(xp,names); ym=response(xm,names);
        dz=(yp-ym)/max(xp(k)-xm(k),eps)*(hi(k)-lo(k));
        J(:,k)=[real(dz(:));imag(dz(:))];
    end
    out=struct('J',J,'parameter_names',{names},'active_mask',mask, ...
        'normalized_step',step,'base_response',base);

    function y=response(q,n)
        t=theta; for j=1:numel(n),t.(n{j})=q(j);end; t.regularization=NaN;
        [net,lc]=topology_apply_parameters(candidate.network,cfg,t);
        [m,~]=plc_measurement_bundle('siso_forward',net,t,lc);
        [v,~]=plc_multiview_response(frequency_hz,net,m,lc); y=[v{:}];
    end
end
function v=get_option(s,n,d),if isfield(s,n)&&~isempty(s.(n)),v=s.(n);else,v=d;end,end
