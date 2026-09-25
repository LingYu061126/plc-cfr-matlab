function model=stage7a2_calibrate_set(distances,truth_index,ids,alpha,kind,identity)
%STAGE7A2_CALIBRATE_SET Independent A-split calibration; lower RMS is better.
%   DISTANCES is observations-by-candidates. TRUTH_INDEX is used only here.
    d=double(distances);truth_index=truth_index(:);m=numel(ids);
    assert(size(d,1)==numel(truth_index)&&size(d,2)==m&& ...
        all(isfinite(d(:)))&&all(d(:)>=0)&&all(truth_index>=1&truth_index<=m&truth_index==fix(truth_index)), ...
        'stage7a2:InvalidCalibration','Invalid calibration distances or truth indices.');
    assert(alpha>0&&alpha<1,'stage7a2:Alpha','Alpha must be in (0,1).');
    kind=char(kind);n=size(d,1);
    switch kind
        case 'class_conditional'
            counts=accumarray(truth_index,1,[m 1]);
            assert(all(counts>=2),'stage7a2:ClassSupport','Each class needs at least two A rows.');
            options=struct('minimum_per_candidate',2,'resolution',eps, ...
                'compatibility_hash',identity);
            topology=stage4a7_2_r1_calibrate_profile_method(d,truth_index,ids,'absolute',alpha,options);
            threshold=NaN;
        case 'pooled_empirical'
            z=sort(d(sub2ind(size(d),(1:n).',truth_index)));
            k=ceil((n+1)*(1-alpha));
            if k>n,threshold=Inf;else,threshold=z(k);end
            topology=[];counts=accumarray(truth_index,1,[m 1]);
        otherwise
            error('stage7a2:UnknownSetKind','Unknown set kind %s.',kind);
    end
    model=struct('kind',kind,'alpha',alpha,'candidate_ids',{ids}, ...
        'class_counts',counts,'pooled_threshold',threshold,'topology_model',topology, ...
        'calibration_count',n,'identity',identity, ...
        'calibration_hash',stage4a4_scientific_config_hash(struct( ...
            'kind',kind,'alpha',alpha,'ids',{ids},'scores',d,'truth_index',truth_index, ...
            'identity',identity)));
end
