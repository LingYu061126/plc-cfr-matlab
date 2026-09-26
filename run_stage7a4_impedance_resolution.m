function result=run_stage7a4_impedance_resolution(root,mode)
%RUN_STAGE7A4_IMPEDANCE_RESOLUTION Independent 1-ohm/read resolution audit.
%   Run at repository root; old Stage 7A.4 results are read-only.
    if nargin<1||isempty(root),root=fileparts(mfilename('fullpath'));end
    if nargin<2||isempty(mode),mode='formal';end
    addpath(fullfile(root,'src'),fullfile(root,'config'), ...
        fullfile(root,'experiments'));
    result=exp_stage7a4_impedance_resolution(root,mode);
end
