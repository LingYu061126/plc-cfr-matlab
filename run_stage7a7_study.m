function out=run_stage7a7_study(root,mode,condition)
%RUN_STAGE7A7_STUDY Serial Stage 7A.7 synthetic CFR/Zin audit entry.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='smoke';end
    if nargin<3||isempty(condition),condition='nominal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'), ...
        fullfile(root,'experiments'));
    out=exp_stage7a7_study(root,mode,condition);
end
