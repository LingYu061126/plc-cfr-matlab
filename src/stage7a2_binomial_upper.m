function upper=stage7a2_binomial_upper(k,n,delta)
%STAGE7A2_BINOMIAL_UPPER Exact one-sided Clopper-Pearson bound, no toolbox.
%   Upper bound on Bernoulli error probability from k errors in n selected.
    assert(isscalar(k)&&isscalar(n)&&k==fix(k)&&n==fix(n)&&n>=0&&k>=0&&k<=n&& ...
        isscalar(delta)&&delta>0&&delta<1,'stage7a2:BinomialArgs','Invalid binomial arguments.');
    if n==0||k==n,upper=1;return;end
    low=0;high=1;
    for t=1:70
        p=(low+high)/2;
        % P_p(X<=k) = I_{1-p}(n-k,k+1), decreasing in p.
        tail=betainc(1-p,n-k,k+1);
        if tail>delta,low=p;else,high=p;end
    end
    upper=high;
end
