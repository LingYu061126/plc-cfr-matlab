function out=stage7a12_estimate_ci(measured,lambda)
%STAGE7A12_ESTIMATE_CI OLS, post-symmetry and constrained ridge of R only.
%   U/I are N-by-T V/A. Ridge embeds real symmetric R during regression;
%   this is not the paper's full joint R/X SCRR implementation.
    U=measured.U;I=measured.I;[n,t]=size(U);
    assert(isequal(size(I),[n t])&&t>n&&lambda>=0, ...
        'stage7a12:RegressionShape');
    ols=U/I;post=(ols+ols.')/2;
    pairs=n*(n+1)/2;H=zeros(n*t,pairs);index=zeros(pairs,2);q=0;
    for b=1:n
        for a=1:b
            q=q+1;index(q,:)=[a b];basis=zeros(n,t);
            basis(a,:)=I(b,:);
            if a~=b,basis(b,:)=I(a,:);end
            H(:,q)=basis(:);
        end
    end
    theta=(H.'*H+lambda*eye(pairs))\(H.'*U(:));
    R=zeros(n);
    for k=1:pairs
        a=index(k,1);b=index(k,2);R(a,b)=theta(k);R(b,a)=theta(k);
    end
    out=struct('ols',ols,'post_symmetric',post,'symmetric_ridge',R, ...
        'lambda',lambda,'rank_design',rank(H),'condition_design',cond(H));
end
