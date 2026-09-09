function summary=run_stage4_freeze_r1_1(root,mode,freeze_root_override,source_override)
%RUN_STAGE4_FREEZE_R1_1 Run Freeze-R.1.1 smoke or clean-source formal.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    summary=exp_stage4a_freeze_r1_1(root,mode,freeze_root_override,source_override);
end
