function out=run_stage7a4_15m_continuous(root,mode)
%RUN_STAGE7A4_15M_CONTINUOUS Independent original-mirror synthetic audit.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    cfg=stage7a4_15m_continuous_config(default_config(root),mode);
    if ~exist(cfg.log_dir,'dir'),mkdir(cfg.log_dir);end
    log=fullfile(cfg.log_dir,[mode '.log']);diary(log);cleaner=onCleanup(@()diary('off')); %#ok<NASGU>
    fprintf('post-commit reproduction / Stage 7A.4 original 15m continuous audit\n');
    out=exp_stage7a4_15m_continuous(root,mode);
end
