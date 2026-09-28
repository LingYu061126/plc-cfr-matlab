function out=run_stage7a10r1_study(root,mode,run_id)
%RUN_STAGE7A10R1_STUDY Independent paired node-state pressure experiment.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='smoke';end
    if nargin<3||isempty(run_id),run_id='smoke1';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    logdir=fullfile(root,'results','logs','stage7a_10_r1');
    if exist(logdir,'dir')~=7,mkdir(logdir);end
    logfile=fullfile(logdir,[mode '_' run_id '.log']);
    assert(exist(logfile,'file')~=2,'stage7a10r1:ExistingLog');
    diary(logfile);
    cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
    out=exp_stage7a10r1_study(root,mode,run_id);
end
