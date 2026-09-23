function summary=run_stage6b_robustness(root,mode)
%RUN_STAGE6B_ROBUSTNESS Project-root Stage 6B entry point.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    summary=exp_stage6b_robustness(root,mode);
end
