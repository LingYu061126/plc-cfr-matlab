function summary=run_stage6a_candidate_generation(root,mode)
%RUN_STAGE6A_CANDIDATE_GENERATION Stage 6A project-root entry point.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    summary=exp_stage6a_candidate_generation(root,mode);
end
