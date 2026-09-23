function result=run_stage7a_profile_search(root,mode)
%RUN_STAGE7A_PROFILE_SEARCH Independent Stage 7A experiment entry point.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    result=exp_stage7a_profile_search(root,mode);
end
