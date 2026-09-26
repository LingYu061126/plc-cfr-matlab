function out=run_stage7a6(root,mode,budget)
%RUN_STAGE7A6 Run one isolated Stage 7A.6 budget in serial MATLAB.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    if nargin<3||isempty(budget),budget=17;end
    addpath(fullfile(root,'src'),fullfile(root,'config'), ...
        fullfile(root,'experiments'),fullfile(root,'tests'));
    out=exp_stage7a6_budget_audit(root,mode,budget);
end
