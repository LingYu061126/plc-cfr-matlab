function out = run_stage4a6_3_parameter_domain_validation(mode)
%RUN_STAGE4A6_3_PARAMETER_DOMAIN_VALIDATION Stage 4A.6.3 entry point.
    if nargin < 1 || isempty(mode), mode='pilot'; end
    root=fileparts(mfilename('fullpath'));
    addpath(fullfile(root,'src'),fullfile(root,'config'),fullfile(root,'experiments'));
    out=exp_stage4a6_3_parameter_domain_validation(root,mode);
end
