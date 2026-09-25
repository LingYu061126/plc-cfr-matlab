function out=stage7a4_information_distance(bank,pair_indices,view_indices,sigma)
%STAGE7A4_INFORMATION_DISTANCE Minimum two-topology joint template gap.
%   Each topology may choose its own allowed nuisance row, but all views
%   within one row share exactly that row. Distances are complex RMS per
%   view divided by independently calibrated error RMS, then RMS over views.
    assert(numel(pair_indices)==2,'stage7a4:PairRequired');
    assert(all(sigma(view_indices)>0),'stage7a4:InvalidScale');
    a=pair_indices(1);b=pair_indices(2);n=size(bank.params,1);
    best=Inf;pa=0;pb=0;
    for i=1:n
        accum=zeros(n,1);
        for j=1:numel(view_indices)
            v=view_indices(j);ha=bank.templates{a,v}(i,:);hb=bank.templates{b,v};
            dd=sqrt(mean(abs(hb-ha).^2,2))/sigma(v);
            accum=accum+dd.^2;
        end
        [val,j]=min(sqrt(accum/numel(view_indices)));
        if val<best,best=val;pa=i;pb=j;end
    end
    nominal=find(all(abs(bank.params-[1 1 1])<1e-12,2),1);
    assert(~isempty(nominal),'stage7a4:NominalTemplateMissing');
    fixed=zeros(1,numel(view_indices));optimized=fixed;relative=fixed;
    for j=1:numel(view_indices)
        v=view_indices(j);
        ha=bank.templates{a,v}(nominal,:);hb=bank.templates{b,v}(nominal,:);
        fixed(j)=sqrt(mean(abs(ha-hb).^2));
        relative(j)=fixed(j)/max(sqrt(mean(abs(ha).^2)),eps);
        optimized(j)=sqrt(mean(abs(bank.templates{a,v}(pa,:)- ...
            bank.templates{b,v}(pb,:)).^2));
    end
    fixed_joint=sqrt(mean((fixed./sigma(view_indices)).^2));
    out=struct('min_joint_distance',best,'fixed_joint_distance',fixed_joint, ...
        'best_template_a',pa,'best_template_b',pb, ...
        'best_params_a',bank.params(pa,:),'best_params_b',bank.params(pb,:), ...
        'fixed_abs_rms_per_view',fixed,'fixed_relative_rms_per_view',relative, ...
        'profiled_abs_rms_per_view',optimized,'view_indices',view_indices, ...
        'numerically_identical_at_nominal',all(relative<=1e-12));
end
