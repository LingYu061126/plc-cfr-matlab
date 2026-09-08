function [lo,hi] = stage4a7_2_wilson_interval(successes,trials)
%STAGE4A7_2_WILSON_INTERVAL Wilson 95 percent interval for a binomial rate.
%   Zero trials are explicitly not applicable and return NaN bounds.
    if trials<=0 || ~isfinite(trials)
        lo=NaN; hi=NaN; return;
    end
    z=1.959963984540054;
    p=max(0,min(1,successes/trials));
    den=1+z^2/trials;
    center=(p+z^2/(2*trials))/den;
    half=z*sqrt(max(0,p*(1-p)/trials+z^2/(4*trials^2)))/den;
    lo=max(0,center-half); hi=min(1,center+half);
end
