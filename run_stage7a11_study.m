function result=run_stage7a11_study(root,mode,run_id)
%RUN_STAGE7A11_STUDY Serial synthetic paired Stage 7A.11 study.
%   Run from repository root. Existing result run IDs are never overwritten.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='smoke';end
    if nargin<3||isempty(run_id),run_id='initial';end
    addpath(fullfile(root,'config'),fullfile(root,'src'), ...
        fullfile(root,'experiments'));
    result=exp_stage7a11_study(root,mode,run_id);
end
