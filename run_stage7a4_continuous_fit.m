function result=run_stage7a4_continuous_fit(root,mode)
%RUN_STAGE7A4_CONTINUOUS_FIT Independent weak-pair nuisance-fit audit.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'), ...
        fullfile(root,'experiments'));
    result=exp_stage7a4_continuous_fit(root,mode);
end
