function summary=run_stage4a7_2_r2_1_independent_validation(mode)
%RUN_STAGE4A7_2_R2_1_INDEPENDENT_VALIDATION Run controlled R.2.1 protocol.
    if nargin<1||isempty(mode),mode='smoke';end
    root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    summary=exp_stage4a7_2_r2_1_independent_validation(root,mode);
end
