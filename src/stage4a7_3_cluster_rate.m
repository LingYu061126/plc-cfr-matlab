function r=stage4a7_3_cluster_rate(success,cluster_ids,opts)
%STAGE4A7_3_CLUSTER_RATE Candidate-cluster percentile interval for a rate.
    if nargin<3||isempty(opts),opts=struct();end
    success=logical(success(:));cluster_ids=cellstr(cluster_ids(:));assert(numel(success)==numel(cluster_ids),'stage4a7_3:ClusterRateAlignment','Size mismatch.');
    clusters=unique(cluster_ids,'stable');nc=numel(clusters);B=getf(opts,'replicates',2000);seed=getf(opts,'seed',20263161);alpha=getf(opts,'alpha',.05);
    rs=RandStream('mt19937ar','Seed',seed);z=NaN(B,1);
    for b=1:B
        draw=randi(rs,nc,nc,1);ix=[];for k=1:nc,ix=[ix;find(strcmp(cluster_ids,clusters{draw(k)}))];end %#ok<AGROW>
        z(b)=mean(success(ix));
    end
    z=sort(z);lo=z(max(1,min(B,ceil(alpha/2*B))));hi=z(max(1,min(B,ceil((1-alpha/2)*B))));
    r=struct('numerator',nnz(success),'denominator',numel(success),'rate',mean(success), ...
        'ci_low',lo,'ci_high',hi,'cluster_count',nc,'resampling_unit','candidate_id_cluster', ...
        'bootstrap_replicates',B,'bootstrap_seed',seed,'ci_method','cluster_percentile_bootstrap_v1');
end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
