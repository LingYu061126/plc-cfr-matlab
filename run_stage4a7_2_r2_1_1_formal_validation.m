function summary=run_stage4a7_2_r2_1_1_formal_validation(root)
%RUN_STAGE4A7_2_R2_1_1_FORMAL_VALIDATION Entry point for the isolated rerun.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    summary=exp_stage4a7_2_r2_1_1_formal_validation(root);
end
