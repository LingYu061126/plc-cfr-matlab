function model = estimate_cfr_noise_covariance(residuals, options)
%ESTIMATE_CFR_NOISE_COVARIANCE Estimate a frozen CFR noise covariance.
%   residuals is N-by-F or N-by-(2F) real/complex calibration residuals.
%   This is an empirical calibration object; it is not inferred from Pilot
%   truth labels and does not by itself establish a Gaussian likelihood.
    if nargin<2||isempty(options),options=struct();end
    if isempty(residuals),error('stage4a7_1:EmptyNoiseCalibration','Noise calibration residuals are empty.');end
    r=double(residuals); if isvector(r),r=r(:).';end
    center=mean(r,1); rc=r-center;
    if size(r,1)<2
        sigma2=max(mean(abs(rc(:)).^2),getf(options,'floor',eps));
        covariance=sigma2*eye(size(r,2));status='scalar_fallback_insufficient_rows';
    else
        covariance=(rc'*rc)/max(size(r,1)-1,1);covariance=(covariance+covariance')/2;status='empirical_calibration';
        floor_value=getf(options,'regularization_floor',1e-12*max(trace(covariance)/size(covariance,1),1));
        [~,p]=chol(covariance); if p~=0,covariance=covariance+floor_value*eye(size(covariance));status='empirical_regularized';end
    end
    model=struct('covariance',covariance,'mean',center,'sample_count',size(r,1),'dimension',size(r,2), ...
        'status',status,'source','independent_calibration_residuals','regularization_floor',getf(options,'regularization_floor',NaN));
end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
