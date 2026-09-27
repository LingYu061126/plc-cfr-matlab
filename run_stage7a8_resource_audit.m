function out=run_stage7a8_resource_audit(root,mode)
%RUN_STAGE7A8_RESOURCE_AUDIT Replay formal T with retained-memory snapshots.
%   No calibration or historical result is rewritten. VmRSS before/after is
%   not a per-call peak; VmHWM is the running process high-water mark.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'), ...
        fullfile(root,'experiments'));
    out=exp_stage7a8_resource_audit(root,mode);
end
