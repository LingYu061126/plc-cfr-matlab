function result=run_stage7a12_study(root,mode,run_id)
%RUN_STAGE7A12_STUDY Serial independent LF-CI/CFR paired simulation.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='smoke';end
    if nargin<3||isempty(run_id),run_id='initial';end
    addpath(fullfile(root,'config'),fullfile(root,'src'), ...
        fullfile(root,'experiments'));
    result=exp_stage7a12_study(root,mode,run_id);
end
