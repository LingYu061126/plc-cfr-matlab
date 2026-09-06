function domain = build_extended_parameter_domain(search,eta)
%BUILD_EXTENDED_PARAMETER_DOMAIN Build in/ext bounds from frozen ranges.
    names={'main_length_scale','branch_length_scale','branch_load_scale','source_impedance_ohm','receiver_impedance_ohm'};
    if ~(isscalar(eta)&&isfinite(eta)&&eta>=0),error('stage4a6:InvalidEta','eta must be nonnegative.');end
    lo=zeros(1,numel(names));hi=lo;for k=1:numel(names),lo(k)=min(search.(names{k}));hi(k)=max(search.(names{k}));end
    w=hi-lo;elo=max([zeros(1,3),eps,eps],lo-eta*w);ehi=hi+eta*w;
    domain=struct('names',{names},'in_lower',lo,'in_upper',hi,'ext_lower',elo,'ext_upper',ehi,'eta',eta,'definition','symmetric interval-width extension clipped to positive physical values');
end
