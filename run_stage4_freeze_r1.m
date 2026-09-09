function summary=run_stage4_freeze_r1(root,mode)
%RUN_STAGE4_FREEZE_R1 Run the final Stage 4A reproducibility closure.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    summary=exp_stage4a_freeze_r1(root,mode);
end
