function H_active = stage3a_interpolate_cfr(pilot_frequency_hz,H_pilot,active_frequency_hz)
%STAGE3A_INTERPOLATE_CFR Interpolate real/imaginary CFR components.
    x=pilot_frequency_hz(:); h=H_pilot(:); q=active_frequency_hz(:);
    if numel(x)~=numel(h)||isempty(x)||any(~isfinite(x))||any(~isfinite(h))|| ...
            any(~isfinite(q))||any(diff(x)<=0)
        error('stage3a_interpolate_cfr:InvalidGrid','Invalid pilot interpolation grid.');
    end
    if numel(x)==1
        H_active=repmat(h(1),1,numel(q)); return;
    end
    H_active=(interp1(x,real(h),q,'linear','extrap')+ ...
        1i*interp1(x,imag(h),q,'linear','extrap')).';
end
