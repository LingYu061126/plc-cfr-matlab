function out=run_stage7a5(root,mode)
%RUN_STAGE7A5 Run the isolated synthetic candidate-extension study.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'), ...
        fullfile(root,'experiments'),fullfile(root,'tests'));
    out=exp_stage7a5_candidate_extension(root,mode);
end
