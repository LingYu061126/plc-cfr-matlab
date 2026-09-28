function result=run_stage7a11_legacy_diagnostic(root,run_id)
%RUN_STAGE7A11_LEGACY_DIAGNOSTIC Read-only legacy reproduction audit.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(run_id),run_id='audit1';end
    addpath(fullfile(root,'src'),fullfile(root,'config'), ...
        fullfile(root,'experiments'));
    result=exp_stage7a11_diagnose_legacy(root,run_id);
end
