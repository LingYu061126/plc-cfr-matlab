function out=run_stage7a10r1_audit(root)
%RUN_STAGE7A10R1_AUDIT Derive corrected statistics without changing confirm1.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    addpath(fullfile(root,'src'),fullfile(root,'experiments'));
    logdir=fullfile(root,'results','logs','stage7a_10_r1');
    if exist(logdir,'dir')~=7,mkdir(logdir);end
    diary(fullfile(logdir,'confirm1_readonly_audit.log'));
    cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
    out=exp_stage7a10r1_audit(root);
end
