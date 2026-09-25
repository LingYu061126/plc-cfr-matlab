function result=run_stage7a4_mirror_observation(root,mode)
%RUN_STAGE7A4_MIRROR_OBSERVATION Rebuild independent D/E then fixed T study.
%   Run from the repository root. Outputs go only to Stage 7A.4 paths.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    explore=exp_stage7a4_exploration(root,mode);
    result=exp_stage7a4_evaluation(root,mode,explore);
end
