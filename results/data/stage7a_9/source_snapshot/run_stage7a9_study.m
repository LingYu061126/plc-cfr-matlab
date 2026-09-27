function out=run_stage7a9_study(root,mode)
%RUN_STAGE7A9_STUDY Paired nominal C37 Stage 7A.8/7A.9 experiment.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='smoke';end
    addpath(fullfile(root,'src'),fullfile(root,'config'), ...
        fullfile(root,'experiments'));
    out=exp_stage7a9_study(root,mode);
end
