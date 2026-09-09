function model=stage4a7_3_calibrate_domain_model(calibration_scores,method_id,opts)
%STAGE4A7_3_CALIBRATE_DOMAIN_MODEL Fit a truth-free score threshold on an
% independently generated in-domain calibration split.
    if nargin<3||isempty(opts),opts=struct();end
    x=double(calibration_scores(:));x=x(isfinite(x));
    min_n=getf(opts,'minimum_count',20);q=getf(opts,'quantile',.95);qb=getf(opts,'near_boundary_quantile',.80);
    if numel(x)<min_n,error('stage4a7_3:InsufficientCalibration','%s has %d valid scores; need %d.',method_id,numel(x),min_n);end
    assert(q>0&&q<1&&qb>0&&qb<q,'stage4a7_3:InvalidQuantile','Invalid frozen quantiles.');
    x=sort(x);model=struct('method_id',char(method_id),'calibration_scores',x(:).', ...
        'sample_count',numel(x),'threshold',quantile_fixed(x,q),'near_boundary_threshold',quantile_fixed(x,qb), ...
        'quantile',q,'near_boundary_quantile',qb,'status','calibrated', ...
        'calibration_hash',stage4a4_scientific_config_hash(struct('method',method_id,'scores',x,'q',q,'qb',qb)), ...
        'definition_version','stage4a7_3_domain_score_quantile_v1');
end
function y=quantile_fixed(x,q)
    n=numel(x); y=x(max(1,min(n,ceil(q*n))));
end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
