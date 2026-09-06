function ci = stage4a6_3_wilson_interval(successes, trials, z)
%STAGE4A6_3_WILSON_INTERVAL Wilson interval for a binomial proportion.
    if nargin < 3 || isempty(z), z = 1.959963984540054; end
    if trials <= 0, ci = [NaN NaN]; return; end
    p = successes/trials; den=1+z^2/trials;
    center=(p+z^2/(2*trials))/den;
    half=z*sqrt(p*(1-p)/trials+z^2/(4*trials^2))/den;
    ci=[max(0,center-half),min(1,center+half)];
end
