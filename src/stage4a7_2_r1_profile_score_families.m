function family=stage4a7_2_r1_profile_score_families(distances,scales,resolution)
%STAGE4A7_2_R1_PROFILE_SCORE_FAMILIES Scores used for development selection.
    d=double(distances);if nargin<2||isempty(scales),scales=median(d,1,'omitnan');end
    if nargin<3||isempty(resolution),resolution=eps;end
    scales(~isfinite(scales)|scales<=0)=1;
    if ~isfinite(resolution)||resolution<=0
        resolution=eps;
    end
    m=size(d,2);comp=Inf(size(d));
    for i=1:size(d,1)
        for j=1:m
            z=d(i,:);z(j)=Inf;comp(i,j)=min(z);
        end
    end
    family=struct('absolute',d,'scaled',d./scales,'ratio',d./max(comp,eps), ...
        'margin',d-comp,'absolute_I',d./max(resolution,eps), ...
        'competitor',comp,'scales',scales,'resolution',resolution, ...
        'definition_version','stage4a7_2_r1_profile_score_family_v1');
end
