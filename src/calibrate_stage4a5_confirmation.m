function model = calibrate_stage4a5_confirmation(calibration_raw, sc, grid_id, hash, seed)
%CALIBRATE_STAGE4A5_CONFIRMATION Freeze thresholds from development/final calibration.
%   Only raw observation evidence is used.  Truth labels are deliberately
%   absent from this interface.
    if nargin<5||isempty(seed),seed=NaN;end
    if isempty(calibration_raw),error('stage4a5:EmptyCalibration','Calibration raw evidence is empty.');end
    d=[calibration_raw.best_distance];m=[calibration_raw.margin];d=d(isfinite(d));m=m(isfinite(m));
    if numel(d)<sc.calibration.minimum_samples||numel(m)<sc.calibration.minimum_samples
        error('stage4a5:InsufficientCalibration','Calibration sample count is below the frozen minimum.');
    end
    th=struct('residual_threshold',q_local(d,sc.calibration.residual_quantile)*sc.calibration.residual_safety_factor, ...
        'margin_threshold',q_local(m,sc.calibration.margin_quantile));
    sub=struct();
    for M=sc.subband_counts
        key=key_for(M,0.75); %#ok<NASGU>
        [raw_d,counts]=subband_matrix(calibration_raw,M); %#ok<ASGLU>
        center=median(raw_d,1);scale=1.4826*mad_columns(raw_d); pooled=1.4826*mad_local(raw_d(:));
        if ~isfinite(pooled)||pooled<sc.epsilon,pooled=max(std(raw_d(:)),sc.epsilon);end
        scale(~isfinite(scale)|scale<sc.epsilon)=pooled;
        z=(raw_d-center)./(scale+sc.epsilon); smax=max(z,[],2);
        for q=sc.subband_quantiles
            sq=quantile_rows(z,q);
            sub.(key_for(M,q))=struct('M',M,'q',q,'center',center,'scale',scale, ...
                'max_threshold',q_local(smax,sc.calibration.subband_quantile)*sc.calibration.subband_safety_factor, ...
                'q_threshold',q_local(sq,sc.calibration.subband_quantile)*sc.calibration.subband_safety_factor, ...
                'calibration_count',size(raw_d,1),'subband_counts',counts);
        end
    end
    nb=struct();
    for K=sc.neighborhood_K
        kidx=find([calibration_raw(1).topk_evidence.k_values]==K,1);
        vals=Inf(1,numel(calibration_raw)); marg=Inf(1,numel(calibration_raw));
        for i=1:numel(calibration_raw)
            ev=calibration_raw(i).topk_evidence;vals(i)=ev.selected_neighborhood_scores(kidx);marg(i)=ev.selected_neighborhood_margins(kidx);
        end
        vals=vals(isfinite(vals));marg=marg(isfinite(marg));
        if numel(vals)<sc.calibration.minimum_samples||numel(marg)<sc.calibration.minimum_samples
            error('stage4a5:InsufficientNeighborhoodCalibration','Insufficient neighborhood calibration samples.');
        end
        nb.(sprintf('K%d',K))=struct('K',K,'score_threshold',q_local(vals,sc.calibration.neighborhood_quantile)*sc.calibration.neighborhood_safety_factor, ...
            'margin_threshold',q_local(marg,sc.calibration.neighborhood_margin_quantile), ...
            'calibration_count',numel(vals));
    end
    model=struct('stage_name','Stage 4A.5','grid_id',grid_id,'configuration_hash',hash, ...
        'thresholds',th,'subband',sub,'neighborhood',nb,'calibration_seed',seed, ...
        'calibration_sample_count',numel(calibration_raw),'source','P0 calibration raw evidence only', ...
        'calibration_rule',sc.calibration,'method_threshold_name',sc.calibration.threshold_name);
end
function [x,counts]=subband_matrix(raw,M)
    n=numel(raw);x=zeros(n,M);counts=raw(1).subband_counts;N=numel(counts);
    if M==N
        for i=1:n,x(i,:)=raw(i).best_subband_distance;end
    elseif mod(N,M)==0
        ratio=N/M;counts=zeros(1,M);
        for j=1:M
            ix=(j-1)*ratio+(1:ratio);counts(j)=sum(raw(1).subband_counts(ix));
            for i=1:n
                z=raw(i).best_subband_distance(ix);c=raw(i).subband_counts(ix);x(i,j)=sqrt(sum((z.^2).*c)/sum(c));
            end
        end
    else,error('stage4a5:SubbandResolution','M must divide the maximum subband count.');end
end
function y=quantile_rows(z,p),y=zeros(size(z,1),1);for i=1:size(z,1),y(i)=q_local(z(i,:),p);end,end
function y=mad_columns(x),y=zeros(1,size(x,2));for k=1:size(x,2),y(k)=mad_local(x(:,k));end,end
function y=mad_local(x),x=x(isfinite(x));if isempty(x),y=NaN;else,y=median(abs(x-median(x)));end,end
function y=q_local(x,p),x=sort(x(isfinite(x)));if isempty(x),y=NaN;elseif numel(x)==1,y=x;else,t=1+(numel(x)-1)*p;l=floor(t);h=ceil(t);y=x(l)+(t-l)*(x(h)-x(l));end,end
function key=key_for(M,q),key=sprintf('M%d_q%03d',M,round(1000*q));end
