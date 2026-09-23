function summary=run_stage5b1_objective_confirmation_upgrade(root,mode)
%RUN_STAGE5B1_OBJECTIVE_CONFIRMATION_UPGRADE Stage 5B.1 entry point.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    summary=exp_stage5b1_objective_confirmation_upgrade(root,mode);
end
