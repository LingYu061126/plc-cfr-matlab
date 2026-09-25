function result=run_stage7a2_set_coverage(root,mode)
%RUN_STAGE7A2_SET_COVERAGE Independent Stage 7A.2 synthetic experiment.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    result=exp_stage7a2_set_coverage(root,mode);
end
