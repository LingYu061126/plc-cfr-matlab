function out=stage4a7_2_r1_profile_distance(observed_views,cache,options)
%STAGE4A7_2_R1_PROFILE_DISTANCE Candidate-independent profile distance.
%   Only observed views and a truth-free candidate template cache are inputs.
%   The true generating parameter is intentionally not part of this API.
    if nargin<3||isempty(options),options=struct();end
    if ~iscell(observed_views)||isempty(observed_views),observed_views={observed_views};end
    n=numel(cache.candidates);d=Inf(1,n);best=zeros(1,n);details=repmat(struct( ...
        'candidate_id','','profile_distance',Inf,'best_template_index',0, ...
        'best_theta',struct(),'finite_template_count',0,'template_count',0),1,n);
    t0=tic;
    for k=1:n
        H=cache.H{k};score=Inf(size(H,1),1);
        for q=1:size(H,1)
            per=zeros(1,numel(observed_views));
            for v=1:numel(observed_views)
                y=observed_views{v}(:).';x=H(q,:);
                if numel(y)~=numel(x),error('stage4a7_2_r1:ProfileFrequencyMismatch','Frequency size mismatch.');end
                feature=getf(options,'feature','complex_raw');
                if ismember(lower(char(feature)),{'complex_raw','cfr_complex_raw','raw_complex'})
                    % This is exactly D_complex_raw from topology_feature_distance,
                    % evaluated directly to avoid computing unused phase/CIR metrics.
                    per(v)=sqrt(mean(abs(y-x).^2));
                else
                    per(v)=topology_feature_distance(y,x,feature, ...
                        getf(options,'ofdm_config',struct()),getf(options,'weights',[1 1]), ...
                        getf(options,'distance_options',struct()));
                end
            end
            score(q)=sqrt(mean(per.^2));
        end
        [d(k),best(k)]=min(score);
        details(k).candidate_id=cache.candidate_ids{k};
        details(k).profile_distance=d(k);details(k).best_template_index=best(k);
        details(k).best_theta=cache.theta_grid(best(k));
        details(k).finite_template_count=nnz(isfinite(score));details(k).template_count=numel(score);
    end
    [~,ord]=sortrows([d(:),(1:n).']);
    out=struct('profile_distances',d,'best_template_indices',best, ...
        'best_theta',{arrayfun(@(x)x.best_theta,details,'UniformOutput',false)}, ...
        'details',details,'ranked_indices',ord(:).','ranked_ids',{cache.candidate_ids(ord)}, ...
        'runtime_s',toc(t0),'definition_version','independent_discrete_profile_distance_v1');
end
function x=getf(s,n,d),if isstruct(s)&&isfield(s,n)&&~isempty(s.(n)),x=s.(n);else,x=d;end,end
