function summary = stage4a7_2_r2_1_full_equivalence_audit(root,formal_dir,out_dir)
%STAGE4A7_2_R2_1_FULL_EQUIVALENCE_AUDIT Auditable candidate-pair distances.
%   Same-theta distances are computed for every unordered candidate pair.
%   Cross-theta/profile distances are computed once for each candidate's
%   nearest same-theta pair.  Pair-level and candidate-level outputs are
%   joined by an explicit pair_key; no endpoint broadcast is used.
    if nargin < 1 || isempty(root), root=fileparts(fileparts(mfilename('fullpath'))); end
    if nargin < 2 || isempty(formal_dir), formal_dir=fullfile(root,'results','data','stage4a7_2_r2_1','formal'); end
    if nargin < 3 || isempty(out_dir), out_dir=fullfile(root,'results','data','stage4a7_2_r2_1','independent35'); end
    addpath(fullfile(root,'src'),fullfile(root,'config')); ensure_dir(out_dir);
    z=load(fullfile(formal_dir,'checkpoint_identity.mat'),'cache','scored','ids');
    cache=z.cache; n=numel(z.scored); tol=1e-10; t0=tic;
    pair_rows=repmat(pair_template(),0,1);
    fprintf('Equivalence audit: %d candidates, %d unordered pairs.\n',n,n*(n-1)/2);
    for i=1:n-1
        A=double(cache.H{i});
        for j=i+1:n
            B=double(cache.H{j}); [same_d,si]=same_theta_minimum(A,B);
            r=pair_template(); r.pair_key=pair_key(cache.candidate_ids{i},cache.candidate_ids{j});
            r.candidate_i=char(cache.candidate_ids{i}); r.candidate_j=char(cache.candidate_ids{j});
            r.same_theta_distance=same_d; r.same_theta_template_i=si; r.same_theta_template_j=si;
            r.numerical_tolerance=tol; r.noise_resolution_threshold=NaN; r.same_theta_numerically_equivalent=same_d<=tol;
            r.cross_theta_scope='nearest_same_theta_pairs_only'; r.source_formal_experiment_hash=z.ids.experiment_hash;
            pair_rows(end+1)=r; %#ok<AGROW>
        end
        if mod(i,10)==0 || i==n-1, fprintf('Equivalence audit progress: %d/%d, %.3f s.\n',i,n,toc(t0)); end
    end
    assert_unique_pair_keys(pair_rows); write_rows(fullfile(out_dir,'same_theta_equivalence_pairs.csv'),pair_rows);

    projection=repmat(projection_template(),n,1); nearest_keys=cell(n,1);
    for i=1:n
        q=find(strcmp({pair_rows.candidate_i},cache.candidate_ids{i}) | strcmp({pair_rows.candidate_j},cache.candidate_ids{i}));
        if isempty(q), error('stage4a7_2_r2_1:NoCompetitorForCandidate','Candidate %s has no competitor.',char(cache.candidate_ids{i})); end
        [~,u]=min([pair_rows(q).same_theta_distance]); p=q(u); pair=pair_rows(p);
        projection(i).candidate_id=char(cache.candidate_ids{i}); projection(i).nearest_pair_key=pair.pair_key;
        projection(i).same_theta_nearest_candidate=other_id(pair,projection(i).candidate_id);
        projection(i).same_theta_distance=pair.same_theta_distance;
        projection(i).same_theta_template_i=pair.same_theta_template_i; projection(i).same_theta_template_j=pair.same_theta_template_j;
        projection(i).same_theta_numerically_equivalent=pair.same_theta_numerically_equivalent;
        projection(i).numerical_tolerance=tol; projection(i).noise_resolution_threshold=NaN;
        projection(i).cross_theta_scope='nearest_same_theta_pairs_only'; projection(i).source_formal_experiment_hash=z.ids.experiment_hash;
        nearest_keys{i}=pair.pair_key;
    end
    unique_keys=unique(nearest_keys,'stable'); cross_rows=repmat(cross_template(),0,1);
    for q=1:numel(unique_keys)
        p=find(strcmp({pair_rows.pair_key},unique_keys{q}),1); pair=pair_rows(p);
        ia=find(strcmp(cache.candidate_ids,pair.candidate_i),1); ib=find(strcmp(cache.candidate_ids,pair.candidate_j),1);
        [pd,ti,tj]=profile_minimum(cache.H{ia},cache.H{ib}); [same_d,si]=same_theta_minimum(cache.H{ia},cache.H{ib});
        [scd,smd,spd]=distance_components(cache.H{ia}(si,:),cache.H{ib}(si,:));
        [cp,cmp,cpp]=distance_components(cache.H{ia}(ti,:),cache.H{ib}(tj,:));
        r=cross_template(); r.pair_key=pair.pair_key; r.candidate_i=pair.candidate_i; r.candidate_j=pair.candidate_j;
        r.same_theta_distance=same_d; r.same_theta_template_i=si; r.same_theta_template_j=si;
        r.same_theta_complex_distance=scd; r.same_theta_magnitude_distance=smd; r.same_theta_phase_distance_rad=spd;
        r.cross_theta_profile_distance=pd; r.cross_theta_template_i=ti; r.cross_theta_template_j=tj;
        r.cross_theta_complex_distance=cp; r.cross_theta_magnitude_distance=cmp; r.cross_theta_phase_distance_rad=cpp;
        r.cross_theta_numerically_equivalent=pd<=tol; r.numerical_tolerance=tol; r.noise_resolution_threshold=NaN;
        r.cross_theta_scope='nearest_same_theta_pairs_only'; r.source_formal_experiment_hash=z.ids.experiment_hash;
        cross_rows(end+1)=r; %#ok<AGROW>
    end
    assert_unique_pair_keys(cross_rows); write_rows(fullfile(out_dir,'cross_theta_nearest_pair_audit.csv'),cross_rows);
    for i=1:n
        q=find(strcmp({cross_rows.pair_key},projection(i).nearest_pair_key),1);
        if isempty(q), error('stage4a7_2_r2_1:MissingPairProjection','Missing cross pair for %s.',projection(i).candidate_id); end
        r=cross_rows(q); projection(i).cross_theta_profile_distance=r.cross_theta_profile_distance;
        projection(i).cross_theta_template_i=r.cross_theta_template_i; projection(i).cross_theta_template_j=r.cross_theta_template_j;
        projection(i).same_theta_complex_distance=r.same_theta_complex_distance; projection(i).same_theta_magnitude_distance=r.same_theta_magnitude_distance;
        projection(i).same_theta_phase_distance_rad=r.same_theta_phase_distance_rad; projection(i).cross_theta_complex_distance=r.cross_theta_complex_distance;
        projection(i).cross_theta_magnitude_distance=r.cross_theta_magnitude_distance; projection(i).cross_theta_phase_distance_rad=r.cross_theta_phase_distance_rad;
        projection(i).cross_theta_numerically_equivalent=r.cross_theta_numerically_equivalent;
    end
    assert_projection(projection,pair_rows,cross_rows); write_rows(fullfile(out_dir,'candidate_nearest_competitor_projection.csv'),projection);
    summary=struct('status','completed','candidate_count',n,'pair_count',numel(pair_rows), ...
        'same_theta_numerical_equivalent_pair_count',nnz([pair_rows.same_theta_numerically_equivalent]), ...
        'nearest_candidate_count',n,'cross_theta_pair_count',numel(cross_rows), ...
        'cross_theta_numerical_equivalent_pair_count',nnz([cross_rows.cross_theta_numerically_equivalent]), ...
        'numerical_tolerance',tol,'noise_resolution_threshold',NaN,'cross_theta_scope','nearest_same_theta_pairs_only', ...
        'source_formal_experiment_hash',z.ids.experiment_hash,'runtime_s',toc(t0));
    write_rows(fullfile(out_dir,'equivalence_audit_summary.csv'),summary);
    save(fullfile(out_dir,'equivalence_audit_summary.mat'),'summary','pair_rows','cross_rows','projection','-v7');
    fprintf('Equivalence audit completed: %d pairs, %d unique nearest pairs, %.3f s.\n',numel(pair_rows),numel(cross_rows),summary.runtime_s);
end

function [d,idx]=same_theta_minimum(A,B),x=mean(abs(double(A)-double(B)).^2,2);[d2,idx]=min(x);d=sqrt(max(0,d2));end
function [d,idx_i,idx_j]=profile_minimum(A,B)
    A=double(A); B=double(B); nf=size(A,2); a2=sum(abs(A).^2,2)/nf; b2=sum(abs(B).^2,2).'; best=Inf; idx_i=1; idx_j=1; block=32;
    for i=1:block:size(A,1)
        ii=i:min(i+block-1,size(A,1)); d2=a2(ii)+b2-2*real(A(ii,:)*B')/nf; [v,jj]=min(d2,[],2); [vb,ib]=min(v);
        if vb<best, best=vb; idx_i=ii(ib); idx_j=jj(ib); end
    end
    d=sqrt(max(0,best));
end
function [cd,md,pd]=distance_components(x,y),x=x(:);y=y(:);cd=sqrt(mean(abs(x-y).^2));md=sqrt(mean((abs(x)-abs(y)).^2));pd=sqrt(mean(angle(x.*conj(y)).^2));end
function k=pair_key(a,b),z=sort({char(a),char(b)});k=[z{1} '|' z{2}];end
function id=other_id(r,current),if strcmp(r.candidate_i,current),id=r.candidate_j;else,id=r.candidate_i;end,end
function assert_unique_pair_keys(rows),keys={rows.pair_key};if numel(unique(keys))~=numel(keys),error('stage4a7_2_r2_1:DuplicatePairKey','Pair table contains duplicate pair keys.');end,end
function assert_projection(pairs,all_pairs,cross_pairs)
    for k=1:numel(pairs)
        assert(any(strcmp({all_pairs.pair_key},pairs(k).nearest_pair_key)),'Projection references an absent same-theta pair.');
        assert(any(strcmp({cross_pairs.pair_key},pairs(k).nearest_pair_key)),'Projection references an absent cross-theta pair.');
        assert(isfinite(pairs(k).same_theta_distance)&&isfinite(pairs(k).cross_theta_profile_distance),'Projection has nonfinite pair distances.');
    end
end
function r=pair_template(),r=struct('pair_key','','candidate_i','','candidate_j','','same_theta_distance',NaN,'same_theta_template_i',0,'same_theta_template_j',0,'numerical_tolerance',NaN,'noise_resolution_threshold',NaN,'same_theta_numerically_equivalent',false,'cross_theta_scope','','source_formal_experiment_hash','');end
function r=cross_template(),r=struct('pair_key','','candidate_i','','candidate_j','','same_theta_distance',NaN,'same_theta_template_i',0,'same_theta_template_j',0,'same_theta_complex_distance',NaN,'same_theta_magnitude_distance',NaN,'same_theta_phase_distance_rad',NaN,'cross_theta_profile_distance',NaN,'cross_theta_template_i',0,'cross_theta_template_j',0,'cross_theta_complex_distance',NaN,'cross_theta_magnitude_distance',NaN,'cross_theta_phase_distance_rad',NaN,'cross_theta_numerically_equivalent',false,'numerical_tolerance',NaN,'noise_resolution_threshold',NaN,'cross_theta_scope','','source_formal_experiment_hash','');end
function r=projection_template(),r=struct('candidate_id','','nearest_pair_key','','same_theta_nearest_candidate','','same_theta_distance',NaN,'same_theta_template_i',0,'same_theta_template_j',0,'same_theta_numerically_equivalent',false,'numerical_tolerance',NaN,'noise_resolution_threshold',NaN,'cross_theta_scope','','cross_theta_profile_distance',NaN,'cross_theta_template_i',0,'cross_theta_template_j',0,'same_theta_complex_distance',NaN,'same_theta_magnitude_distance',NaN,'same_theta_phase_distance_rad',NaN,'cross_theta_complex_distance',NaN,'cross_theta_magnitude_distance',NaN,'cross_theta_phase_distance_rad',NaN,'cross_theta_numerically_equivalent',false,'source_formal_experiment_hash','');end
function ensure_dir(p),if ~exist(p,'dir'),mkdir(p);end,end
function write_rows(p,x),writetable(struct2table(x),p);end
