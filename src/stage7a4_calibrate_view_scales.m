function sigma=stage7a4_calibrate_view_scales(e_samples,cfg)
%STAGE7A4_CALIBRATE_VIEW_SCALES Error RMS in each view's physical units.
%   Uses only the independent E split. Zin errors are ohm; CFR errors use
%   the H_port normalization. Each view remains separate, including repeat.
    nv=numel(cfg.view_names);accum=zeros(1,nv);
    assert(~isempty(e_samples),'stage7a4:EmptyErrorCalibration');
    for i=1:numel(e_samples)
        for v=1:nv
            residual=e_samples(i).observed{v}-e_samples(i).clean{v};
            accum(v)=accum(v)+mean(abs(residual).^2);
        end
    end
    sigma=sqrt(accum/numel(e_samples));
    assert(all(isfinite(sigma))&&all(sigma>0),'stage7a4:InvalidCalibratedScale');
end
