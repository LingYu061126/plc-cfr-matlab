function result=run_stage7a1_diagnostic(root,mode)
%RUN_STAGE7A1_DIAGNOSTIC Independent Stage 7A.1 diagnostic entry point.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    result=exp_stage7a1_diagnostic(root,mode);
end
