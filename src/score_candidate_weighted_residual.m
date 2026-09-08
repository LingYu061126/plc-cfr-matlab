function out = score_candidate_weighted_residual(observed, predicted, covariance, options)
%SCORE_CANDIDATE_WEIGHTED_RESIDUAL Noise-weighted CFR residual.
%   For Sigma=sigma^2 I this returns the whitened squared residual.  The
%   output is called weighted residual, not a likelihood, unless a caller
%   separately supplies and documents a proper complex Gaussian model.
    if nargin<4||isempty(options),options=struct();end
    r=observed(:)-predicted(:);n=numel(r);reg=getf(options,'regularization',0);status='provided_covariance';
    if nargin<3||isempty(covariance),covariance=eye(n);status='identity_default';end
    if isscalar(covariance),covariance=covariance*eye(n);end
    if isvector(covariance)&&numel(covariance)==n,covariance=diag(covariance(:));end
    if ~isequal(size(covariance),[n n]),error('stage4a7_1:CovarianceDimension','Covariance dimension does not match CFR residual.');end
    covariance=(covariance+covariance')/2;
    [~,p]=chol(covariance);if p~=0
        if reg<=0,reg=1e-10*max(trace(abs(covariance))/max(n,1),1);end
        covariance=covariance+reg*eye(n);status='regularized_covariance';
    end
    if any(~isfinite(covariance(:))),error('stage4a7_1:NonfiniteCovariance','Covariance is nonfinite.');end
    q=real(r'*(covariance\r));
    out=struct('raw_residual',r,'weighted_squared_residual',q,'weighted_residual',sqrt(max(q,0)), ...
        'covariance',covariance,'covariance_status',status,'regularization',reg,'dimension',n, ...
        'noise_model_interpretation','weighted_residual_only');
end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
