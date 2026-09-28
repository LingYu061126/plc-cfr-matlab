function out=run_stage7a10_study(root,mode,run_id)
%RUN_STAGE7A10_STUDY Independent synthetic multiview CFR comparison.
%   Run from repository root. Each run_id is immutable; no historical data
%   are overwritten. All parameter units and seeds come from the config.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='smoke';end
    if nargin<3||isempty(run_id),run_id='initial';end
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    out=exp_stage7a10_study(root,mode,run_id);
end
