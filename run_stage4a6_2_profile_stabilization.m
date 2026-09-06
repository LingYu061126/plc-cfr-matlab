function out=run_stage4a6_2_profile_stabilization(mode)
%RUN_STAGE4A6_2_PROFILE_STABILIZATION Entry point for Stage 4A.6.2 smoke.
    if nargin<1||isempty(mode),mode='smoke';end
    root=fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    out=exp_stage4a6_2_profile_stabilization(root,mode);
end
