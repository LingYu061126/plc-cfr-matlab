function model=calibrate_candidate_confirmation(training_raw,training_labels,calibration_raw,calibration_labels,sc,grid_id,hash)
%CALIBRATE_CANDIDATE_CONFIRMATION Fit Stage-4A.4 rules without test data.
%   Training observations provide robust class centers/scales; calibration
%   observations provide frozen residual, margin and ratio thresholds.
    if isempty(calibration_raw) || isempty(calibration_labels), error('stage4a4:InsufficientCalibration','Calibration data are required.'); end
    if numel(training_raw)~=numel(training_labels)||numel(calibration_raw)~=numel(calibration_labels), error('stage4a4:CalibrationAlignment','Raw and label counts differ.'); end
    epsv=sc.calibration.epsilon; classes=stable_unique({training_labels.baseline_P0_equivalence_class}); classes=classes(~cellfun(@isempty,classes));
    stats=repmat(struct('label','','center',NaN,'scale',NaN,'count',0),0,1);
    all_scores=[];
    for k=1:numel(training_raw), all_scores=[all_scores,training_raw(k).class_scores]; end %#ok<AGROW>
    pooled_center=median(all_scores); pooled_scale=1.4826*mad_local(all_scores); if ~isfinite(pooled_scale)||pooled_scale<epsv, pooled_scale=max(std(all_scores),epsv); end
    for k=1:numel(classes)
        values=[];
        for i=1:numel(training_raw)
            if strcmp(training_labels(i).baseline_P0_equivalence_class,classes{k})
                j=find(strcmp(training_raw(i).class_labels,classes{k}),1); if ~isempty(j), values(end+1)=training_raw(i).class_scores(j); end %#ok<AGROW>
            end
        end
        if isempty(values), center=pooled_center; scale=pooled_scale; else, center=median(values); scale=1.4826*mad_local(values); if ~isfinite(scale)||scale<epsv, scale=pooled_scale; end, end
        stats(end+1)=struct('label',classes{k},'center',center,'scale',scale,'count',numel(values)); %#ok<AGROW>
    end
    cal_cov=arrayfun(@(x)x.truth_covered,calibration_labels); d=[calibration_raw(cal_cov).best_distance]; d=d(isfinite(d));
    if numel(d)<sc.calibration.minimum_samples, error('stage4a4:InsufficientCalibration','Too few residual calibration samples.'); end
    eligible=false(1,numel(calibration_raw));
    for i=1:numel(calibration_raw)
        eligible(i)=cal_cov(i) && calibration_raw(i).baseline_P0_equivalence_class_size==1 && ...
            class_contains(calibration_raw(i).best_equivalence_class,calibration_labels(i).baseline_P0_equivalence_class);
    end
    margins=[calibration_raw(eligible).margin]; margins=margins(isfinite(margins));
    if numel(margins)<sc.calibration.minimum_samples, error('stage4a4:InsufficientCalibration','Too few margin calibration samples.'); end
    rhos=[calibration_raw(cal_cov).rho]; rhos=rhos(isfinite(rhos));
    if isempty(rhos), error('stage4a4:InsufficientCalibration','No finite ratio calibration samples.'); end
    z=[]; zm=[];
    for i=1:numel(calibration_raw)
        if ~cal_cov(i), continue; end
        [zv,mv]=robust_values(calibration_raw(i),stats,epsv); if isfinite(zv),z(end+1)=zv;end; if isfinite(mv),zm(end+1)=mv;end
    end
    if isempty(z)||isempty(zm)
        % A defensive pooled fallback is retained for a sparse smoke design
        % or a class-label mismatch.  Formal runs still have one calibration
        % sample for every P0 graph and use the class-conditioned path above.
        z=[]; zm=[];
        for i=1:numel(calibration_raw)
            if ~cal_cov(i), continue; end
            z(end+1)=(calibration_raw(i).best_distance-pooled_center)/(pooled_scale+epsv); %#ok<AGROW>
            if isfinite(calibration_raw(i).margin), zm(end+1)=calibration_raw(i).margin/(pooled_scale+epsv); end %#ok<AGROW>
        end
    end
    thresholds=struct('residual_threshold',quantile_local(d,sc.calibration.residual_quantile)*sc.calibration.residual_safety_factor, ...
        'margin_threshold',quantile_local(margins,sc.calibration.margin_quantile), ...
        'rho_threshold',quantile_local(rhos,sc.calibration.rho_quantile), ...
        'robust_score_threshold',quantile_local(z,sc.calibration.robust_score_quantile), ...
        'robust_margin_threshold',quantile_local(zm,sc.calibration.robust_margin_quantile));
    model=struct('grid_id',grid_id,'configuration_hash',hash,'classes',stats,'thresholds',thresholds, ...
        'training_sample_count',numel(training_raw),'calibration_sample_count',numel(calibration_raw), ...
        'pooled_center',pooled_center,'pooled_scale',pooled_scale, ...
        'residual_calibration_count',numel(d),'margin_calibration_count',numel(margins), ...
        'ratio_calibration_count',numel(rhos),'robust_calibration_count',numel(z), ...
        'quantiles',sc.calibration,'source','training class statistics + P0 calibration only', ...
        'calibration_seed',sc.calibration_seed,'test_seed',sc.test_seed);
end

function [best,margin]=robust_values(raw,stats,epsv)
    z=Inf(1,numel(raw.class_scores));
    for k=1:numel(stats)
        j=find(strcmp(raw.class_labels,stats(k).label),1); if ~isempty(j),z(j)=(raw.class_scores(j)-stats(k).center)/(stats(k).scale+epsv);end
    end
    [best,j]=min(z); other=z;other(j)=Inf; margin=min(other)-best;
end
function [best,margin]=class_stat(raw,stats,epsv), [best,margin]=robust_values(raw,stats,epsv); end %#ok<DEFNU>
function tf=class_contains(a,b), tf=strcmp(a,b)||(~isempty(b)&&~isempty(strfind([',' a ','],[',' b ',']))); end %#ok<STREMP>
function m=mad_local(x), x=x(isfinite(x)); if isempty(x),m=NaN;else,m=median(abs(x-median(x)));end,end
function q=quantile_local(x,p)
    x=sort(x(isfinite(x))); if isempty(x),q=NaN;elseif numel(x)==1,q=x;else,t=1+(numel(x)-1)*p;lo=floor(t);hi=ceil(t);q=x(lo)+(t-lo)*(x(hi)-x(lo));end
end
function y=stable_unique(x),y={};for k=1:numel(x),if ~any(strcmp(y,x{k})),y{end+1}=x{k};end,end,end
