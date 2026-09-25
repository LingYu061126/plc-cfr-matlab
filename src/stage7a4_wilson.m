function [low,high]=stage7a4_wilson(k,n)
%STAGE7A4_WILSON Two-sided 95% binomial Wilson interval for k of n.
    if n==0,low=NaN;high=NaN;return;end
    z=1.95996398454005;p=k/n;den=1+z^2/n;
    mid=(p+z^2/(2*n))/den;
    span=z*sqrt(p*(1-p)/n+z^2/(4*n^2))/den;
    low=max(0,mid-span);high=min(1,mid+span);
end
