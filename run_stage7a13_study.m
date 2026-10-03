function result=run_stage7a13_study(root,mode,run_id)
%RUN_STAGE7A13_STUDY Independent Stage 7A.13 synthetic experiment entry.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='smoke';end
    if nargin<3||isempty(run_id),run_id='smoke1';end
    addpath(fullfile(root,'src'),fullfile(root,'config'), ...
        fullfile(root,'experiments'));
    result=exp_stage7a13_study(root,mode,run_id);
end
