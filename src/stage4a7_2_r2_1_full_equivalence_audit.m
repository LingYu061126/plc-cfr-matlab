function summary = stage4a7_2_r2_1_full_equivalence_audit(root)
%STAGE4A7_2_R2_1_FULL_EQUIVALENCE_AUDIT Audit candidate-pair distances.
%   Same-theta distances are evaluated for every candidate pair.  Full
%   cross-theta/profile distances are evaluated for the nearest same-theta
%   competitor of each candidate, in bounded blocks.  This deliberately
%   avoids constructing a candidate-pair-by-template-by-frequency tensor.
    if nargin < 1 || isempty(root)
        root = fileparts(fileparts(mfilename('fullpath')));
    end
    addpath(fullfile(root,'src'),fullfile(root,'config'));
    formal_dir = fullfile(root,'results','data','stage4a7_2_r2_1','formal');
    out_dir = fullfile(root,'results','data','stage4a7_2_r2_1','independent35');
    ensure_dir(out_dir);
    z = load(fullfile(formal_dir,'checkpoint_identity.mat'),'cache','scored','ids');
    cache = z.cache;
    n = numel(z.scored);
    tol = 1e-10;
    pair_rows = repmat(pair_template(),0,1);
    tic_id = tic;
    fprintf('Equivalence audit: %d candidates, %d pairs.\n',n,n*(n-1)/2);
    for i = 1:n-1
        A = double(cache.H{i});
        for j = i+1:n
            B = double(cache.H{j});
            same2 = mean(abs(A-B).^2,2);
            [same2_min, same_idx] = min(same2);
            r = pair_template();
            r.candidate_i = char(cache.candidate_ids{i});
            r.candidate_j = char(cache.candidate_ids{j});
            r.same_theta_distance = sqrt(max(0,same2_min));
            r.same_theta_template_i = same_idx;
            r.same_theta_template_j = same_idx;
            r.numerical_tolerance = tol;
            r.noise_resolution_threshold = NaN;
            r.same_theta_numerically_equivalent = r.same_theta_distance <= tol;
            r.cross_theta_scope = 'not_evaluated_until_nearest_same_theta_pair';
            r.source_formal_experiment_hash = z.ids.experiment_hash;
            pair_rows(end+1) = r; %#ok<AGROW>
        end
        if mod(i,10)==0 || i==n-1
            fprintf('Equivalence audit progress: candidate %d/%d, elapsed %.3f s.\n',i,n,toc(tic_id));
        end
    end
    write_rows(fullfile(out_dir,'same_theta_equivalence_pairs.csv'),pair_rows);

    nearest = repmat(nearest_template(),n,1);
    for i = 1:n
        ids_i = false(numel(pair_rows),1);
        for q = 1:numel(pair_rows)
            ids_i(q) = strcmp(pair_rows(q).candidate_i,cache.candidate_ids{i}) || ...
                strcmp(pair_rows(q).candidate_j,cache.candidate_ids{i});
        end
        subset = pair_rows(ids_i);
        [~,qbest] = min([subset.same_theta_distance]);
        best = subset(qbest);
        nearest(i).candidate_id = char(cache.candidate_ids{i});
        nearest(i).same_theta_nearest_candidate = other_id(best,nearest(i).candidate_id);
        nearest(i).same_theta_distance = best.same_theta_distance;
        nearest(i).same_theta_numerically_equivalent = best.same_theta_numerically_equivalent;
        nearest(i).numerical_tolerance = tol;
        nearest(i).noise_resolution_threshold = NaN;
        nearest(i).cross_theta_scope = 'full_profile_for_same_theta_nearest_pair';
        nearest(i).source_formal_experiment_hash = z.ids.experiment_hash;
    end

    unique_pairs = unique_pair_indices(nearest);
    for q = 1:numel(unique_pairs)
        p = unique_pairs(q);
        ia = find(strcmp(cache.candidate_ids,nearest(p).candidate_id),1);
        ib = find(strcmp(cache.candidate_ids,nearest(p).same_theta_nearest_candidate),1);
        [profile_d,ti,tj] = profile_minimum(cache.H{ia},cache.H{ib});
        [same_d,si] = same_theta_minimum(cache.H{ia},cache.H{ib});
        [cd,md,pd] = distance_components(cache.H{ia}(si,:),cache.H{ib}(si,:));
        [cp,mp,pp] = distance_components(cache.H{ia}(ti,:),cache.H{ib}(tj,:));
        for p2 = find(strcmp({nearest.candidate_id},nearest(p).candidate_id) | ...
                strcmp({nearest.candidate_id},nearest(p).same_theta_nearest_candidate))
            nearest(p2).cross_theta_profile_distance = profile_d;
            nearest(p2).cross_theta_template_i = ti;
            nearest(p2).cross_theta_template_j = tj;
            nearest(p2).same_theta_complex_distance = cd;
            nearest(p2).same_theta_magnitude_distance = md;
            nearest(p2).same_theta_phase_distance_rad = pd;
            nearest(p2).cross_theta_complex_distance = cp;
            nearest(p2).cross_theta_magnitude_distance = mp;
            nearest(p2).cross_theta_phase_distance_rad = pp;
            nearest(p2).cross_theta_numerically_equivalent = profile_d <= tol;
        end
    end
    write_rows(fullfile(out_dir,'nearest_competitor_full_equivalence.csv'),nearest);
    summary = struct('status','completed','candidate_count',n, ...
        'pair_count',numel(pair_rows),'same_theta_numerical_equivalent_pair_count', ...
        nnz([pair_rows.same_theta_numerically_equivalent]), ...
        'nearest_candidate_count',n,'cross_theta_pair_count',numel(unique_pairs), ...
        'cross_theta_numerical_equivalent_pair_count', ...
        nnz([nearest.cross_theta_numerically_equivalent]), ...
        'numerical_tolerance',tol,'noise_resolution_threshold',NaN, ...
        'cross_theta_scope','same_theta_nearest_pairs_only', ...
        'source_formal_experiment_hash',z.ids.experiment_hash,'runtime_s',toc(tic_id));
    write_rows(fullfile(out_dir,'equivalence_audit_summary.csv'),summary);
    save(fullfile(out_dir,'equivalence_audit_summary.mat'),'summary','pair_rows','nearest','-v7');
    fprintf('Equivalence audit completed: %d pairs, %.3f s.\n',numel(pair_rows),summary.runtime_s);
end

function [d,idx] = same_theta_minimum(A,B)
    x = mean(abs(double(A)-double(B)).^2,2);
    [d2,idx] = min(x);
    d = sqrt(max(0,d2));
end

function [d,idx_i,idx_j] = profile_minimum(A,B)
    A = double(A); B = double(B); nf = size(A,2);
    a2 = sum(abs(A).^2,2)/nf; b2 = sum(abs(B).^2,2).'/nf;
    best = Inf; idx_i = 1; idx_j = 1; block = 32;
    for i = 1:block:size(A,1)
        ii = i:min(i+block-1,size(A,1));
        d2 = a2(ii) + b2 - 2*real(A(ii,:)*B')/nf;
        [v,jj] = min(d2,[],2);
        [vb,ib] = min(v);
        if vb < best
            best = vb; idx_i = ii(ib); idx_j = jj(ib);
        end
    end
    d = sqrt(max(0,best));
end

function [cd,md,pd] = distance_components(x,y)
    x = x(:); y = y(:); cd = sqrt(mean(abs(x-y).^2));
    md = sqrt(mean((abs(x)-abs(y)).^2));
    pd = sqrt(mean(angle(x.*conj(y)).^2));
end

function id = other_id(r,current)
    if strcmp(r.candidate_i,current), id = r.candidate_j; else, id = r.candidate_i; end
end

function ix = unique_pair_indices(rows)
    keys = cell(numel(rows),1);
    for k = 1:numel(rows)
        a = sort({rows(k).candidate_id,rows(k).same_theta_nearest_candidate});
        keys{k} = strjoin(a,'|');
    end
    [~,ix] = unique(keys,'stable');
end

function r = pair_template()
    r = struct('candidate_i','','candidate_j','','same_theta_distance',NaN, ...
        'same_theta_template_i',0,'same_theta_template_j',0, ...
        'numerical_tolerance',NaN,'noise_resolution_threshold',NaN, ...
        'same_theta_numerically_equivalent',false,'cross_theta_scope','', ...
        'source_formal_experiment_hash','');
end

function r = nearest_template()
    r = struct('candidate_id','','same_theta_nearest_candidate','', ...
        'same_theta_distance',NaN,'same_theta_numerically_equivalent',false, ...
        'numerical_tolerance',NaN,'noise_resolution_threshold',NaN, ...
        'cross_theta_scope','','cross_theta_profile_distance',NaN, ...
        'cross_theta_template_i',0,'cross_theta_template_j',0, ...
        'same_theta_complex_distance',NaN,'same_theta_magnitude_distance',NaN, ...
        'same_theta_phase_distance_rad',NaN,'cross_theta_complex_distance',NaN, ...
        'cross_theta_magnitude_distance',NaN,'cross_theta_phase_distance_rad',NaN, ...
        'cross_theta_numerically_equivalent',false,'source_formal_experiment_hash','');
end

function ensure_dir(p), if ~exist(p,'dir'), mkdir(p); end, end
function write_rows(p,x), writetable(struct2table(x),p); end
