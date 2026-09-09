function out = stage4a7_2_r2_1_2_cluster_bootstrap(a, b, cluster_ids, options)
%STAGE4A7_2_R2_1_2_CLUSTER_BOOTSTRAP Candidate-cluster paired bootstrap.
%   A and B are aligned row-level method outcomes.  Resampling is by
%   candidate cluster: every sampled candidate contributes all of its
%   category/replicate rows, preserving their within-candidate pairing.
    if nargin < 4 || isempty(options), options = struct(); end
    required = {'hit','accepted','set_size'};
    for k=1:numel(required)
        assert(isfield(a,required{k}) && isfield(b,required{k}), ...
            'stage4a7_2_r2_1_2:BootstrapInput','Missing %s.',required{k});
    end
    cluster_ids = cellstr(cluster_ids(:)); n=numel(cluster_ids);
    assert(numel(a.hit)==n && numel(b.hit)==n, ...
        'stage4a7_2_r2_1_2:BootstrapAlignment','Outcome and cluster sizes differ.');
    clusters=unique(cluster_ids,'stable'); nc=numel(clusters); assert(nc>0, ...
        'stage4a7_2_r2_1_2:BootstrapClusters','No candidate clusters supplied.');
    B=getf(options,'replicates',2000); seed=getf(options,'seed',20263021);
    alpha=getf(options,'alpha',0.05); multiplicity=max(1,getf(options,'multiplicity_count',1));
    alpha_adjusted=alpha/multiplicity;
    rs=RandStream('mt19937ar','Seed',seed);
    dc=NaN(B,1); ds=NaN(B,1); dr=NaN(B,1);
    for q=1:B
        draw=randi(rs,nc,nc,1); ix=[];
        for j=1:nc
            ix=[ix; find(strcmp(cluster_ids,clusters{draw(j)}))]; %#ok<AGROW>
        end
        dc(q)=mean(double(a.hit(ix)))-mean(double(b.hit(ix)));
        ds(q)=mean(double(a.set_size(ix)))-mean(double(b.set_size(ix)));
        ra=risk(a.accepted(ix),a.hit(ix)); rb=risk(b.accepted(ix),b.hit(ix));
        if isfinite(ra) && isfinite(rb), dr(q)=ra-rb; end
    end
    [clo,chi]=interval(dc,alpha_adjusted); [slo,shi]=interval(ds,alpha_adjusted); [rlo,rhi]=interval(dr,alpha_adjusted);
    out=struct('coverage_difference',mean(double(a.hit))-mean(double(b.hit)), ...
        'coverage_ci_low',clo,'coverage_ci_high',chi, ...
        'mean_set_size_difference',mean(double(a.set_size))-mean(double(b.set_size)), ...
        'mean_set_size_ci_low',slo,'mean_set_size_ci_high',shi, ...
        'selective_risk_difference',risk(a.accepted,a.hit)-risk(b.accepted,b.hit), ...
        'selective_risk_ci_low',rlo,'selective_risk_ci_high',rhi, ...
        'cluster_count',nc,'cluster_ids',{clusters},'resampling_unit','candidate_id_cluster', ...
        'bootstrap_replicates',B,'bootstrap_seed',seed,'alpha',alpha, ...
        'alpha_adjusted',alpha_adjusted,'multiplicity_count',multiplicity, ...
        'ci_method','cluster_percentile_bootstrap_v1','effective_resample_count',B);
end

function r=risk(accepted,hit)
    d=nnz(accepted); if d==0,r=NaN;else,r=nnz(accepted & ~hit)/d;end
end
function [lo,hi]=interval(v,alpha)
    v=sort(v(isfinite(v))); if isempty(v),lo=NaN;hi=NaN;return;end
    lo=v(max(1,min(numel(v),ceil((alpha/2)*numel(v)))));
    hi=v(max(1,min(numel(v),ceil((1-alpha/2)*numel(v)))));
end
function x=getf(s,n,d)
    if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end
end
